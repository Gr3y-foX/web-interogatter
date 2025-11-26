#!/bin/bash

# Docker Entrypoint для Web Server Interceptor
# Управление запуском Tor и Flask приложения

set -e

# Цвета для логирования
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для инициализации директорий
init_directories() {
    log_info "Инициализация директорий..."
    
    # Создание директорий с правильными правами
    mkdir -p /app/data /app/reports /app/logs
    mkdir -p /var/lib/tor-interceptor/hidden_service
    
    # Инициализация базы данных если не существует
    if [ ! -f "/app/data/intercepts.db" ]; then
        log_info "Создание базы данных..."
        python3 -c "
import sqlite3
import sys
sys.path.append('/app')
from app import init_db
init_db()
" 2>/dev/null || log_warning "Не удалось инициализировать базу данных"
        
        # Перемещение базы в data директорию
        if [ -f "/app/intercepts.db" ]; then
            mv /app/intercepts.db /app/data/
            ln -sf /app/data/intercepts.db /app/intercepts.db
        fi
    else
        ln -sf /app/data/intercepts.db /app/intercepts.db 2>/dev/null || true
    fi
    
    log_success "Директории инициализированы"
}

# Функция запуска Tor
start_tor() {
    log_info "Запуск Tor..."
    
    # Проверка существования конфигурации
    if [ ! -f "/etc/tor/torrc-interceptor" ]; then
        log_warning "Конфигурация Tor не найдена, создание базовой..."
        cat > /tmp/torrc-interceptor << EOF
SocksPort 0.0.0.0:9050
ControlPort 0.0.0.0:9051
HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C
DataDirectory /var/lib/tor-interceptor
Log notice file /app/logs/tor.log

# Hidden Service
HiddenServiceDir /var/lib/tor-interceptor/hidden_service/
HiddenServicePort 80 127.0.0.1:5000
HiddenServiceVersion 3

# Security settings
ExitPolicy reject *:*
ExitRelay 0
PublishServerDescriptor 0
EOF
    else
        cp /etc/tor/torrc-interceptor /tmp/torrc-interceptor
    fi
    
    # Запуск Tor в фоне
    tor -f /tmp/torrc-interceptor --quiet &
    TOR_PID=$!
    
    # Ожидание запуска Tor
    log_info "Ожидание запуска Tor..."
    for i in {1..30}; do
        if netstat -tuln 2>/dev/null | grep -q ":9050 " && netstat -tuln 2>/dev/null | grep -q ":9051 "; then
            log_success "Tor запущен (PID: $TOR_PID)"
            echo $TOR_PID > /tmp/tor.pid
            return 0
        fi
        sleep 2
    done
    
    log_error "Не удалось запустить Tor"
    return 1
}

# Функция получения .onion адреса
get_onion_address() {
    log_info "Получение .onion адреса..."
    
    # Ожидание создания hidden service
    for i in {1..60}; do
        if [ -f "/var/lib/tor-interceptor/hidden_service/hostname" ]; then
            ONION_ADDRESS=$(cat /var/lib/tor-interceptor/hidden_service/hostname)
            log_success "Hidden Service: http://$ONION_ADDRESS"
            echo "ONION_ADDRESS=$ONION_ADDRESS" > /app/data/onion.env
            return 0
        fi
        sleep 2
    done
    
    log_warning "Hidden Service адрес пока не готов"
    return 1
}

# Функция запуска Flask приложения
start_flask() {
    log_info "Запуск Flask приложения..."
    
    # Установка переменных окружения
    export FLASK_APP=app.py
    export FLASK_ENV=${FLASK_ENV:-production}
    export DATABASE_PATH=/app/data/intercepts.db
    
    # Запуск приложения
    cd /app
    python3 app.py &
    FLASK_PID=$!
    
    # Проверка запуска
    for i in {1..20}; do
        if netstat -tuln 2>/dev/null | grep -q ":5000 "; then
            log_success "Flask приложение запущено (PID: $FLASK_PID)"
            echo $FLASK_PID > /tmp/flask.pid
            return 0
        fi
        sleep 2
    done
    
    log_error "Не удалось запустить Flask приложение"
    return 1
}

# Функция проверки здоровья сервисов
health_check() {
    log_info "Проверка здоровья сервисов..."
    
    # Проверка Tor
    if ! netstat -tuln 2>/dev/null | grep -q ":9050 "; then
        log_error "Tor SOCKS прокси недоступен"
        return 1
    fi
    
    # Проверка Flask
    if ! curl -f http://localhost:5000/ >/dev/null 2>&1; then
        log_error "Flask приложение недоступно"
        return 1
    fi
    
    log_success "Все сервисы работают корректно"
    return 0
}

# Функция остановки сервисов
stop_services() {
    log_info "Остановка сервисов..."
    
    # Остановка Flask
    if [ -f "/tmp/flask.pid" ]; then
        FLASK_PID=$(cat /tmp/flask.pid)
        if kill -0 $FLASK_PID 2>/dev/null; then
            kill $FLASK_PID
            log_success "Flask остановлен"
        fi
        rm -f /tmp/flask.pid
    fi
    
    # Остановка Tor
    if [ -f "/tmp/tor.pid" ]; then
        TOR_PID=$(cat /tmp/tor.pid)
        if kill -0 $TOR_PID 2>/dev/null; then
            kill $TOR_PID
            log_success "Tor остановлен"
        fi
        rm -f /tmp/tor.pid
    fi
}

# Функция мониторинга сервисов
monitor_services() {
    log_info "Запуск мониторинга сервисов..."
    
    while true; do
        sleep 30
        
        # Проверка Tor
        if ! netstat -tuln 2>/dev/null | grep -q ":9050 "; then
            log_warning "Tor недоступен, перезапуск..."
            start_tor
        fi
        
        # Проверка Flask
        if ! curl -f http://localhost:5000/ >/dev/null 2>&1; then
            log_warning "Flask недоступен, перезапуск..."
            start_flask
        fi
        
        # Вывод статистики
        if [ -f "/app/data/intercepts.db" ]; then
            INTERCEPTS_COUNT=$(sqlite3 /app/data/intercepts.db "SELECT COUNT(*) FROM intercepts;" 2>/dev/null || echo "0")
            log_info "Всего перехвачено: $INTERCEPTS_COUNT запросов"
        fi
    done
}

# Обработка сигналов
trap 'log_warning "Получен сигнал завершения"; stop_services; exit 0' TERM INT

# Основная логика
case "${1:-start}" in
    "start")
        log_info "🚀 Запуск Web Server Interceptor в Docker контейнере"
        
        init_directories
        start_tor
        sleep 5
        get_onion_address &
        start_flask
        
        log_success "✅ Все сервисы запущены!"
        log_info "📊 Веб-интерфейс: http://localhost:5000"
        log_info "🔧 Админ панель: http://localhost:5000/admin/reports"
        
        # Запуск мониторинга в фоне
        monitor_services &
        
        # Ожидание сигналов
        wait
        ;;
        
    "stop")
        stop_services
        ;;
        
    "health")
        health_check
        ;;
        
    "shell")
        log_info "Запуск интерактивной оболочки"
        exec /bin/bash
        ;;
        
    *)
        log_error "Неизвестная команда: $1"
        echo "Доступные команды: start, stop, health, shell"
        exit 1
        ;;
esac
