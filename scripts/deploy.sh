#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

# Параметры SSH (адаптированы под WSL)
SSH_KEY="/mnt/c/Users/User/.ssh/devops_vm"
SSH_PORT="2222"
REMOTE_IP="172.22.0.1" # IP Windows из WSL

# Абсолютный путь к корню репозитория
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO_ROOT" ]]; then
    echo "Ошибка: скрипт должен запускаться из репозитория Git" >&2
    exit 1
fi
LOCAL_DIR="${REPO_ROOT}/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
elif [[ $# -gt 0 ]]; then
    echo "Неизвестный аргумент: $1" >&2
    exit 1
fi

# 2. Проверка наличия site/index.html
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл ${LOCAL_DIR}index.html не найден" >&2
    exit 1
fi

# 3. Проверка на незафиксированные изменения в Git
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
    exit 1
fi

# 4. Синхронизация (не более одного SSH-соединения)
RSYNC_CMD=(rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} -e "ssh -i ${SSH_KEY} -p ${SSH_PORT} -o BatchMode=yes -o ConnectTimeout=5" "${LOCAL_DIR}" "devops@${REMOTE_IP}:${REMOTE_DIR}/")

"${RSYNC_CMD[@]}"

# При --dry-run завершаем работу с кодом 0
if [[ -n "${DRY_RUN}" ]]; then
    echo "Пробный запуск завершён (изменения не внесены)."
    exit 0
fi

# 5. Проверка доступности ресурса (с проверкой сертификата)
if ! curl -f --cacert "${CA_CERT}" -s -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
    exit 1
fi

# Успех
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Успешно доставлено. Коммит: ${COMMIT_HASH}"
exit 0
