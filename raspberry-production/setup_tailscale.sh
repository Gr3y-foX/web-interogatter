#!/bin/bash

# Настройка Tailscale VPN для безопасного доступа к Raspberry Pi
# Создает приватную VPN сеть для доступа к вашим устройствам

set -e

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "🔐 =============================================="
echo "   Tailscale VPN Setup для Raspberry Pi"
echo "   Безопасный приватный доступ"
echo "=============================================="
echo -e "${NC}"

# Проверка установки Tailscale
if command -v tailscale &> /dev/null; then
    echo -e "${GREEN}✅ Tailscale уже установлен${NC}"
    TAILSCALE_VERSION=$(tailscale version | head -1)
    echo -e "${GREEN}   Версия: $TAILSCALE_VERSION${NC}"
else
    echo -e "${BLUE}ℹ️  Установка Tailscale...${NC}"
    
    # Установка Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    echo -e "${GREEN}✅ Tailscale установлен${NC}"
fi

# Проверка статуса
echo
echo -e "${BLUE}ℹ️  Проверка статуса Tailscale...${NC}"

if sudo tailscale status &> /dev/null; then
    echo -e "${GREEN}✅ Tailscale запущен${NC}"
    echo
    sudo tailscale status
    echo
    
    # Получение IP адреса Tailscale
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")
    if [ "$TAILSCALE_IP" != "N/A" ]; then
        echo -e "${GREEN}🌐 Ваш Tailscale IP: $TAILSCALE_IP${NC}"
        echo -e "${GREEN}📡 Доступ к приложению: http://$TAILSCALE_IP:5000${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Tailscale не подключен${NC}"
    echo
    read -p "Подключиться к Tailscale сейчас? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}ℹ️  Запуск Tailscale...${NC}"
        echo -e "${YELLOW}⚠️  Откроется браузер для авторизации${NC}"
        echo
        sudo tailscale up
        
        # Получение IP после подключения
        sleep 2
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")
        if [ "$TAILSCALE_IP" != "N/A" ]; then
            echo
            echo -e "${GREEN}✅ Tailscale подключен!${NC}"
            echo -e "${GREEN}🌐 Ваш Tailscale IP: $TAILSCALE_IP${NC}"
            echo -e "${GREEN}📡 Доступ к приложению: http://$TAILSCALE_IP:5000${NC}"
        fi
    fi
fi

echo
echo -e "${BLUE}📋 Как использовать:${NC}"
echo "1. Установите Tailscale на своем устройстве (телефон/компьютер)"
echo "2. Войдите с тем же аккаунтом"
echo "3. Используйте Tailscale IP для доступа к Raspberry Pi"
echo
echo -e "${GREEN}✅ Преимущества Tailscale:${NC}"
echo "  - Приватная VPN сеть"
echo "  - Шифрование трафика"
echo "  - Работает через NAT"
echo "  - Бесплатно до 100 устройств"
echo

