# VoyFy VPN Server

Скрипты для установки и управления VPN серверами (XRay VLESS + Reality).

## Быстрый старт

### 1. Получите ключ активации
В админ-панели `https://vip.necsoura.ru/admin` создайте ключ активации.

### 2. Запустите установку на новом VPS

```bash
export API_ENDPOINT="https://vip.necsoura.ru"
export ACTIVATION_KEY="voyfy_xxxxx"

curl -fsSL https://vip.necsoura.ru/vpn-server/install.sh | sudo bash
```

Или скачайте и запустите:
```bash
wget https://vip.necsoura.ru/vpn-server/install.sh
chmod +x install.sh
sudo API_ENDPOINT="https://vip.necsoura.ru" ACTIVATION_KEY="voyfy_xxxxx" ./install.sh
```

### 3. Проверка статуса
```bash
systemctl status xray
systemctl status voyfy-heartbeat
```

## Файлы

- `install.sh` - Автоматическая установка VPN сервера
- `heartbeat.sh` - Отправка статистики в API (запускается автоматически)

## Требования

- Ubuntu 20.04/22.04 или Debian 11+
- Root доступ
- Открытый порт 443/tcp
- 1GB RAM, 10GB SSD

## Что делает установка

1. Устанавливает XRay Core
2. Генерирует Reality ключи
3. Создаёт конфигурацию VLESS
4. Открывает порт 443 в фаерволе
5. Активирует сервер через API
6. Запускает heartbeat (мониторинг)

## Мониторинг

Heartbeat автоматически каждую минуту отправляет:
- Нагрузку CPU/RAM
- Количество активных пользователей
- Статус сервера

## Команды

```bash
# Перезапуск VPN
systemctl restart xray

# Логи VPN
tail -f /var/log/xray/access.log

# Логи heartbeat
journalctl -u voyfy-heartbeat -f

# Обновление конфигурации
/usr/local/bin/xray run -config /usr/local/etc/xray/config.json -test
```

## Удаление

```bash
systemctl stop xray voyfy-heartbeat
systemctl disable xray voyfy-heartbeat
rm -rf /usr/local/etc/xray /opt/voyfy /var/log/xray
# XRay останется установленным, можно удалить вручную
```
