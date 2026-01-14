#!/bin/bash

# Настройка Cloudflare Tunnel для удаленного доступа к Raspberry Pi
# Бесплатный и безопасный способ доступа извне локальной сети

set -e

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "☁️  =============================================="
echo "   Cloudflare Tunnel Setup для Raspberry Pi"
echo "   Безопасный доступ извне локальной сети"
echo "=============================================="
echo -e "${NC}"

# Проверка архитектуры
ARCH=$(uname -m)
echo -e "${BLUE}ℹ️  Архитектура: $ARCH${NC}"

# Установка cloudflared
echo -e "${BLUE}ℹ️  Установка cloudflared...${NC}"

if command -v cloudflared &> /dev/null; then
    echo -e "${GREEN}✅ cloudflared уже установлен${NC}"
else
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        # ARM64 версия для Raspberry Pi
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared
        sudo mv cloudflared /usr/local/bin/
        sudo chmod +x /usr/local/bin/cloudflared
        echo -e "${GREEN}✅ cloudflared установлен${NC}"
    else
        echo -e "${RED}❌ Неподдерживаемая архитектура: $ARCH${NC}"
        exit 1
    fi
fi

# Проверка версии
CLOUDFLARED_VERSION=$(cloudflared --version)
echo -e "${GREEN}✅ $CLOUDFLARED_VERSION${NC}"

echo
echo -e "${YELLOW}📋 Инструкция по настройке:${NC}"
echo
echo "1. Войдите в Cloudflare Dashboard:"
echo "   https://dash.cloudflare.com/"
echo
echo "2. Перейдите в Zero Trust > Access > Tunnels"
echo
echo "3. Создайте новый туннель и скопируйте токен"
echo
echo "4. Запустите туннель с токеном:"
echo "   cloudflared tunnel --url http://localhost:5000 run <YOUR_TOKEN>"
echo
echo "Или используйте быстрый туннель (без регистрации, временный):"
echo -e "${GREEN}cloudflared tunnel --url http://localhost:5000${NC}"
echo

read -p "Запустить быстрый туннель сейчас? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Запуск туннеля...${NC}"
    echo -e "${YELLOW}⚠️  Нажмите Ctrl+C для остановки${NC}"
    echo
    cloudflared tunnel --url http://localhost:5000
fi

