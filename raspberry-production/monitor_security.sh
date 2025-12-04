#!/bin/bash

# Скрипт мониторинга безопасности для production сервера
# Показывает статус всех компонентов безопасности

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "🔒 =============================================="
    echo "   Мониторинг безопасности"
    echo "   Raspberry Pi Production Server"
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

# Проверка firewall
check_firewall() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Firewall Status:"
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_success "UFW активен"
            echo ""
            ufw status numbered | head -20
        else
            print_error "UFW неактивен"
        fi
    else
        print_warning "UFW не установлен"
    fi
    echo ""
}

# Проверка fail2ban
check_fail2ban() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Fail2ban Status:"
    
    if command -v fail2ban-client &> /dev/null; then
        if systemctl is-active --quiet fail2ban; then
            print_success "Fail2ban активен"
            echo ""
            fail2ban-client status web-interceptor 2>/dev/null || print_warning "Jail web-interceptor не настроен"
            echo ""
            print_info "Все активные jails:"
            fail2ban-client status | grep "Jail list" || true
        else
            print_error "Fail2ban неактивен"
        fi
    else
        print_warning "Fail2ban не установлен"
    fi
    echo ""
}

# Проверка автоматических обновлений
check_updates() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Автоматические обновления:"
    
    if systemctl is-active --quiet unattended-upgrades; then
        print_success "Автоматические обновления активны"
    else
        print_warning "Автоматические обновления неактивны"
    fi
    
    # Проверка последних обновлений
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        print_info "Последние обновления:"
        tail -5 /var/log/unattended-upgrades/unattended-upgrades.log | grep "Packages" || true
    fi
    echo ""
}

# Проверка логов безопасности
check_security_logs() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Логи безопасности:"
    
    if [ -f /var/log/security-monitor/security.log ]; then
        print_info "Последние записи (последние 10 строк):"
        tail -10 /var/log/security-monitor/security.log
    else
        print_warning "Лог безопасности не найден"
    fi
    echo ""
}

# Проверка неудачных попыток входа
check_failed_logins() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Неудачные попытки входа (последние 24 часа):"
    
    if [ -f /var/log/auth.log ]; then
        FAILED_COUNT=$(grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)
        if [ "$FAILED_COUNT" -gt 0 ]; then
            print_warning "Обнаружено $FAILED_COUNT неудачных попыток входа"
            echo ""
            print_info "Последние 5 попыток:"
            grep "Failed password" /var/log/auth.log | tail -5
        else
            print_success "Неудачных попыток входа не обнаружено"
        fi
    else
        print_warning "Лог auth.log не найден"
    fi
    echo ""
}

# Проверка системы
check_system() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Статус системы:"
    
    # Температура CPU
    if command -v vcgencmd &> /dev/null; then
        TEMP=$(vcgencmd measure_temp | cut -d= -f2)
        TEMP_NUM=$(echo $TEMP | cut -d. -f1)
        if [ "$TEMP_NUM" -gt 70 ]; then
            print_warning "Температура CPU: $TEMP (высокая!)"
        else
            print_success "Температура CPU: $TEMP"
        fi
    fi
    
    # Использование памяти
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$MEM_USAGE" -gt 90 ]; then
        print_warning "Использование памяти: ${MEM_USAGE}% (высокое!)"
    else
        print_success "Использование памяти: ${MEM_USAGE}%"
    fi
    
    # Использование диска
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        print_warning "Использование диска: ${DISK_USAGE}% (высокое!)"
    else
        print_success "Использование диска: ${DISK_USAGE}%"
    fi
    
    echo ""
}

# Проверка Docker контейнеров
check_docker() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Docker контейнеры:"
    
    if command -v docker &> /dev/null; then
        RUNNING=$(docker ps --format "{{.Names}}" | wc -l)
        TOTAL=$(docker ps -a --format "{{.Names}}" | wc -l)
        print_info "Запущено: $RUNNING из $TOTAL"
        
        if [ "$RUNNING" -gt 0 ]; then
            echo ""
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        fi
    else
        print_warning "Docker не установлен"
    fi
    echo ""
}

# Проверка резервных копий
check_backups() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Резервные копии:"
    
    if [ -d /var/backups/web-interceptor ]; then
        BACKUP_COUNT=$(ls -1 /var/backups/web-interceptor/*.tar.gz 2>/dev/null | wc -l)
        if [ "$BACKUP_COUNT" -gt 0 ]; then
            print_success "Найдено резервных копий: $BACKUP_COUNT"
            echo ""
            print_info "Последние 5 резервных копий:"
            ls -lh /var/backups/web-interceptor/*.tar.gz 2>/dev/null | tail -5 | awk '{print $9, "(" $5 ")"}'
        else
            print_warning "Резервные копии не найдены"
        fi
    else
        print_warning "Директория резервных копий не найдена"
    fi
    echo ""
}

# Основная функция
main() {
    print_header
    
    check_firewall
    check_fail2ban
    check_updates
    check_failed_logins
    check_security_logs
    check_system
    check_docker
    check_backups
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Мониторинг завершен"
    print_info "Для детального просмотра логов:"
    print_info "  - Безопасность: tail -f /var/log/security-monitor/security.log"
    print_info "  - Система: tail -f /var/log/security-monitor/system.log"
    print_info "  - Firewall: tail -f /var/log/ufw.log"
    print_info "  - Fail2ban: tail -f /var/log/fail2ban.log"
}

main "$@"

