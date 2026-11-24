## 10. Ansible

- **Расположение проекта:** `ansible/` в репозитории `devops-course-2026`.
- **Управляющий узел:** WSL (Ubuntu) с установленным Ansible.
- **Управляемый узел:** VM `devops-vm` (Ubuntu 24.04).
- **Inventory:** `inventory/bootstrap.ini` (student, пароль) и `inventory/prod.ini` (devops, ключ).
- **Роли:**
  - `base`: установка Docker, базовых пакетов.
  - `ssh`: создание пользователя `devops`, настройка ключей, отключение паролей.
  - `nginx`: reverse proxy для приложения.
  - `app`: запуск контейнера из GHCR.
- **Образ GHCR:** `ghcr.io/karma-ofc/devops-ci-app`
- **Полный SHA:** `d07340972c9f9e25435cef93e309d723ee6b3a40`
- **Порт контейнера:** `5000` (проброшен на `127.0.0.1:5000`).
- **Health endpoint:** `http://192.168.56.101/health`
- **Команды:**
  - Первичный запуск: `ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass`
  - Повторный запуск: `ansible-playbook site.yml`
  - Аудит: `ansible-playbook verify.yml`