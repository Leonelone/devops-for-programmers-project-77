![Upmon](https://app.upmon.com/badge/e79fc7d8-acf0-42b8-af74-56602b/4gWjTEao-2.svg)

### Статус тестов и линтера Hexlet:
[![Actions Status](https://github.com/Leonelone/devops-for-programmers-project-77/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Leonelone/devops-for-programmers-project-77/actions)

## Инфраструктура Terraform (Yandex Cloud)

Проект разворачивает:

- Два веб-сервера (ВМ) с nginx по HTTPS (самоподписанный сертификат)
- Сетевой балансировщик нагрузки (NLB) на TCP:443, распределяющий трафик между ВМ
- Управляемый кластер PostgreSQL (Yandex Managed DB), базу и пользователя
- DNS-зону с A-записью для домена, указывающей на IP балансировщика

### Предварительные требования

- Terraform >= 1.3
- Аккаунт в Yandex Cloud и OAuth-токен
- Публичный SSH-ключ в `~/.ssh/id_rsa.pub`

Перед запуском команд установите переменную окружения:

```bash
export YC_TOKEN=<ваш_oauth_токен_yandex_cloud>
```

Необязательные переменные можно переопределять в `terraform.tfvars` или через `-var`:

- `yc_folder_id` (значение по умолчанию в `terraform/main.tf`)
- `vpc_network_id` (ID существующей сети VPC)
- `zone` (по умолчанию `ru-central1-a`)
- `domain_name` (по умолчанию `hexlet-student.ru`)

### Использование

Инициализация backend и провайдеров:

```bash
make init
```

План изменений:

```bash
make plan
```

Применение инфраструктуры:

```bash
make apply
```

Вывод значений (IP ВМ, адрес NLB, FQDN PostgreSQL):

```bash
make output
```

Удаление инфраструктуры:

```bash
make destroy
```

### Примечания

- NLB выполняет TCP-балансировку на порту 443; каждая ВМ отдает nginx с самоподписанным сертификатом, созданным через cloud-init.
- Доступ к БД создается как ресурсы Terraform; храните секреты безопасно и периодически меняйте пароли.
- При использовании удаленного backend Terraform (например, Terraform Cloud) не прерывайте операции только локально; отменяйте через CLI или UI Terraform Cloud.

## Деплой через Ansible

Все файлы Ansible находятся в `ansible/`:

- `playbook.yml` — основной плейбук подготовки и деплоя
- `requirements.yml` — внешние роли и коллекции
- `inventory.ini` — генерируется из выходных данных Terraform
- `ansible.cfg` — конфигурация Ansible

Секреты нельзя коммитить. Используйте Ansible Vault для чувствительных значений:

```bash
ansible-vault create ansible/group_vars/all/vault.yml
# затем подключайте через vars_files в плейбуке при необходимости
```

### Подготовка

```bash
make ansible-prepare
```

Команда устанавливает роли/коллекции, генерирует инвентори из Terraform и проверяет доступность хостов (ping).

### Деплой

```bash
make ansible-deploy
```

Запускаются задачи с тегами `docker,deploy,nginx`: установка Docker, запуск контейнера приложения за nginx (TLS).

Для выборочного запуска укажите теги явно:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbook.yml -t deploy
```

## Домен и DNS

- Регистратор: зарегистрируйте домен (например, `hexlet-student.ru`).
- После `make apply` получите NS и IP через outputs:

```bash
make output
# dns_zone_name_servers = ["ns1.yandexcloud.net.", "ns2.yandexcloud.net."]
# nlb_public_address    = 203.0.113.10
# app_domain            = hexlet-student.ru
```

Шаги:
- В панели регистратора установите NS из `dns_zone_name_servers`.
- Дождитесь делегирования (от нескольких часов до суток).
- Зона DNS в Terraform создаёт A-запись для корня домена на IP балансировщика.

Ваше приложение будет доступно по адресу:

```text
https://hexlet-student.ru
```

### TLS через Let’s Encrypt

После делегирования DNS запросите и подключите сертификаты:

```bash
make ansible-tls
```

Команда установит certbot, получит сертификат для `hexlet-student.ru` и настроит nginx.

## Мониторинг Datadog

Установите агент Datadog через Ansible и создайте Synthetics HTTPS-монитор через Terraform.

### Предварительные требования

- Установите переменные окружения:

```bash
export DATADOG_API_KEY=<ваш_datadog_api_key>
export DATADOG_APP_KEY=<ваш_datadog_app_key>
```

- Создайте `ansible/group_vars/all/vault.yml` с зашифрованными секретами Vault, например:

```yaml
$ANSIBLE_VAULT;1.1;AES256
# ... зашифрованное содержимое ...
```

Файл Vault должен содержать:

```yaml
vault_datadog_api_key: ВАШ_API_KEY
```

### Установка агента Datadog

```bash
make ansible-datadog
```

### Применение Terraform-монитора Datadog

Запустите plan/apply с ключами Datadog в окружении (уже подключены в Makefile):

```bash
make plan
make apply
```
В выводах будет публичный ID Synthetics-теста.

## Отладка

Если возникают проблемы с запуском контейнера, можно использовать следующие команды для отладки:

```bash
# Проверка статуса Docker сервиса
sudo systemctl status docker

# Проверка наличия образа
docker images | grep leonelone/devops-for-programmers-project-74

# Проверка запущенных контейнеров
docker ps -a

# Просмотр логов контейнера
docker logs webapp

# Проверка сетевых настроек
docker network ls
```

Также можно запустить Ansible плейбук с флагом verbose для получения подробной информации:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbook.yml -t docker,deploy,nginx -vvv
```
