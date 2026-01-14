#!/bin/bash

# Скрипт настройки автоматического обновления через GitHub Webhook

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "🔄 =============================================="
    echo "   Настройка автоматического обновления"
    echo "   GitHub Webhook для Raspberry Pi"
    echo "=============================================="
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Переменные
PROJECT_DIR="$HOME/web-interogatter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/webhook-server.service"
SYSTEMD_DIR="/etc/systemd/system"

print_header

# Проверка прав root для systemd
if [ "$EUID" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root (sudo)"
    print_info "Запустите: sudo $0"
    exit 1
fi

# Проверка существования проекта
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Директория проекта не найдена: $PROJECT_DIR"
    print_info "Сначала запустите install_and_run.sh"
    exit 1
fi

# Проверка Python
if ! command -v python3 &> /dev/null; then
    print_error "Python3 не установлен"
    exit 1
fi

# Проверка Flask
print_info "Проверка Flask..."
if ! python3 -c "import flask" 2>/dev/null; then
    print_info "Установка Flask..."
    pip3 install flask
    print_success "Flask установлен"
else
    print_success "Flask уже установлен"
fi

# Установка прав на скрипты
print_info "Установка прав на скрипты..."
chmod +x "$PROJECT_DIR/raspberry-production/auto_update.sh"
chmod +x "$PROJECT_DIR/raspberry-production/webhook_server.py"
print_success "Права установлены"

# Генерация секрета webhook
print_info "Генерация секрета webhook..."
WEBHOOK_SECRET=$(openssl rand -hex 32)
print_success "Секрет сгенерирован: ${WEBHOOK_SECRET:0:16}..."

# Запрос порта
print_info "Настройка порта webhook сервера..."
read -p "Порт для webhook сервера (по умолчанию 9000): " WEBHOOK_PORT
WEBHOOK_PORT=${WEBHOOK_PORT:-9000}

# Запрос ветки
print_info "Настройка ветки Git..."
read -p "Ветка для отслеживания (по умолчанию master): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-master}

# Запрос пользователя
print_info "Настройка пользователя для сервиса..."
read -p "Пользователь для запуска сервиса (по умолчанию $SUDO_USER): " SERVICE_USER
SERVICE_USER=${SERVICE_USER:-$SUDO_USER}

# Создание systemd service файла
print_info "Создание systemd service..."
SERVICE_CONTENT="[Unit]
Description=GitHub Webhook Server for Auto Update
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR/raspberry-production
Environment=\"WEBHOOK_SECRET=$WEBHOOK_SECRET\"
Environment=\"WEBHOOK_PORT=$WEBHOOK_PORT\"
Environment=\"GIT_BRANCH=$GIT_BRANCH\"
ExecStart=/usr/bin/python3 $PROJECT_DIR/raspberry-production/webhook_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_CONTENT" > "$SYSTEMD_DIR/webhook-server.service"
print_success "Service файл создан"

# Перезагрузка systemd
print_info "Перезагрузка systemd..."
systemctl daemon-reload
print_success "Systemd перезагружен"

# Включение автозапуска
print_info "Включение автозапуска сервиса..."
systemctl enable webhook-server.service
print_success "Автозапуск включен"

# Запуск сервиса
print_info "Запуск webhook сервера..."
systemctl start webhook-server.service
sleep 2

# Проверка статуса
if systemctl is-active --quiet webhook-server.service; then
    print_success "Webhook сервер запущен"
else
    print_error "Не удалось запустить webhook сервер"
    print_info "Проверьте логи: sudo journalctl -u webhook-server.service -f"
    exit 1
fi

# Получение IP адреса
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Вывод информации
echo
print_success "Настройка завершена!"
echo
print_info "Информация для настройки GitHub Webhook:"
echo "  URL: http://$IP_ADDRESS:$WEBHOOK_PORT/webhook"
echo "  Секрет: $WEBHOOK_SECRET"
echo "  Ветка: $GIT_BRANCH"
echo
print_info "Управление сервисом:"
echo "  sudo systemctl status webhook-server    # Статус"
echo "  sudo systemctl restart webhook-server   # Перезапуск"
echo "  sudo systemctl stop webhook-server      # Остановка"
echo "  sudo journalctl -u webhook-server -f    # Логи"
echo
print_warning "ВАЖНО: Сохраните секрет webhook! Он понадобится при настройке GitHub"
echo
print_info "Следующие шаги:"
echo "  1. Откройте настройки репозитория на GitHub"
echo "  2. Перейдите в Settings > Webhooks > Add webhook"
echo "  3. Укажите URL: http://$IP_ADDRESS:$WEBHOOK_PORT/webhook"
echo "  4. Content type: application/json"
echo "  5. Secret: $WEBHOOK_SECRET"
echo "  6. Events: Just the push event"
echo "  7. Нажмите Add webhook"
echo
print_info "Если Raspberry Pi за NAT, используйте ngrok или настройте проброс портов"
echo
