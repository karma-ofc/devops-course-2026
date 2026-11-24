#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]  $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$PORT" != "22" ]]; then
    echo " [OK]  Порт SSH отличен от 22 (port=$PORT)"
    ((PASS++))
else
    echo " [FAIL] Порт SSH равен 22"
    ((FAIL++))
fi

check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

DEFAULT_IN=$(sudo ufw status verbose | awk '/^Default:/{print $2}')
check "Политика incoming = deny" "deny" "$DEFAULT_IN"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"

if sudo nginx -t >/dev/null 2>&1; then
    echo " [OK]  Конфигурация Nginx корректна"
    ((PASS++))
else
    echo " [FAIL] Конфигурация Nginx содержит ошибки"
    ((FAIL++))
fi

if sudo openssl x509 -in /etc/ssl/certs/devops.crt -checkend 2592000 -noout >/dev/null 2>&1; then
    echo " [OK]  Сертификат действителен более 30 дней"
    ((PASS++))
else
    echo " [FAIL] Сертификат истекает менее чем через 30 дней"
    ((FAIL++))
fi

if [[ -z "$(sudo find /var/www/devops-site -perm -o+w 2>/dev/null)" ]]; then
    echo " [OK]  Нет файлов с правом записи для всех"
    ((PASS++))
else
    echo " [FAIL] Найдены файлы с правом записи для всех"
    ((FAIL++))
fi

KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
if [[ "$KEY_PERMS" == "600" ]]; then
    echo " [OK]  Права ключа TLS равны 600"
    ((PASS++))
else
    echo " [FAIL] Права ключа TLS не равны 600 (получено: $KEY_PERMS)"
    ((FAIL++))
fi

echo "[5] Контейнеризация"

if systemctl is-active --quiet docker; then
    echo " [OK]  Служба Docker активна"
    ((PASS++))
else
    echo " [FAIL] Служба Docker не активна"
    ((FAIL++))
fi

DB_HEALTH=$(sudo docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo "missing")
if [[ "$DB_HEALTH" == "healthy" ]]; then
    echo " [OK]  Контейнер СУБД healthy"
    ((PASS++))
else
    echo " [FAIL] Контейнер СУБД не healthy (получено: $DB_HEALTH)"
    ((FAIL++))
fi

if [[ -z "$(sudo ss -tln | grep -E ':(5000|5432)\b' | grep -v '127.0.0.1')" ]]; then
    echo " [OK]  Порты 5000 и 5432 доступны только на 127.0.0.1"
    ((PASS++))
else
    echo " [FAIL] Порты 5000 или 5432 доступны на внешних адресах"
    ((FAIL++))
fi

ENV_PERMS=$(sudo stat -c '%a' /home/devops/app/.env 2>/dev/null || echo "missing")
if [[ "$ENV_PERMS" == "600" ]]; then
    echo " [OK]  Права файла .env равны 600"
    ((PASS++))
else
    echo " [FAIL] Права файла .env не равны 600 (получено: $ENV_PERMS)"
    ((FAIL++))
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
