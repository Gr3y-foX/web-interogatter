#!/bin/bash

# Скрипт настройки firewall для Web Server Interceptor
# Для образовательных целей в области кибербезопасности

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Порт по умолчанию
PORT=${1:-5000}

echo "🔧 Настройка firewall для Web Server Interceptor"
echo "   Порт: $PORT"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Запустите скрипт с sudo: sudo ./setup_firewall.sh $PORT"
    exit 1
fi

# Определение типа firewall
if command -v ufw &> /dev/null; then
    FIREWALL="ufw"
    print_info "Обнаружен UFW firewall"
elif command -v firewall-cmd &> /dev/null; then
    FIREWALL="firewalld"
    print_info "Обнаружен Firewalld"
elif command -v iptables &> /dev/null; then
    FIREWALL="iptables"
    print_info "Обнаружен iptables"
else
    print_error "Firewall не найден. Установите ufw, firewalld или используйте iptables"
    exit 1
fi

# Настройка UFW
setup_ufw() {
    print_info "Настройка UFW..."
    
    # Разрешить порт
    ufw allow $PORT/tcp comment "Web Server Interceptor"
    print_success "Порт $PORT открыт в UFW"
    
    # Показать статус
    print_info "Текущие правила UFW:"
    ufw status | grep $PORT || true
    
    print_success "UFW настроен"
}

# Настройка Firewalld
setup_firewalld() {
    print_info "Настройка Firewalld..."
    
    # Добавить порт в постоянную зону
    firewall-cmd --permanent --add-port=$PORT/tcp
    firewall-cmd --reload
    
    print_success "Порт $PORT открыт в Firewalld"
    
    # Показать статус
    print_info "Текущие открытые порты:"
    firewall-cmd --list-ports | grep $PORT || true
    
    print_success "Firewalld настроен"
}

# Настройка iptables
setup_iptables() {
    print_info "Настройка iptables..."
    
    # Проверка существующего правила
    if iptables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null; then
        print_warning "Правило для порта $PORT уже существует"
    else
        iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
        print_success "Правило добавлено в iptables"
    fi
    
    # Сохранение правил (для разных дистрибутивов)
    if command -v iptables-save &> /dev/null; then
        if [ -d /etc/iptables ]; then
            iptables-save > /etc/iptables/rules.v4
        elif [ -f /etc/iptables/rules.v4 ]; then
            iptables-save > /etc/iptables/rules.v4
        else
            print_warning "Правила iptables не сохранены автоматически"
            print_info "Сохраните вручную: iptables-save > /etc/iptables/rules.v4"
        fi
    fi
    
    print_success "iptables настроен"
}

# Выбор метода настройки
case $FIREWALL in
    "ufw")
        setup_ufw
        ;;
    "firewalld")
        setup_firewalld
        ;;
    "iptables")
        setup_iptables
        ;;
esac

echo ""
print_success "Firewall настроен для порта $PORT"
print_info "Сервер теперь доступен извне на порту $PORT"
print_warning "⚠️  Убедитесь, что сервер защищен и используется только в образовательных целях!"

