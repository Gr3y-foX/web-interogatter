#!/bin/bash

# Web Server Interceptor - Скрипт запуска
# Для образовательных целей в области кибербезопасности

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
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

print_header() {
    echo -e "${BLUE}"
    echo "🔍 =============================================="
    echo "   Web Server Interceptor"
    echo "   Для образовательных целей"
    echo "   Kali Linux / Cybersecurity Project"
    echo "=============================================="
    echo -e "${NC}"
}

# Проверка прав root (для некоторых операций)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Запуск от root не рекомендуется для безопасности"
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка зависимостей
check_dependencies() {
    print_info "Проверка зависимостей..."
    
    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 не найден"
        exit 1
    fi
    
    # Проверка pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 не найден"
        exit 1
    fi
    
    print_success "Python и pip найдены"
}

# Установка Python зависимостей
install_python_deps() {
    print_info "Установка Python зависимостей..."
    
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt --user
        print_success "Python зависимости установлены"
    else
        print_error "Файл requirements.txt не найден"
        exit 1
    fi
}

# Проверка и установка Tor
setup_tor() {
    print_info "Настройка Tor..."
    
    if command -v tor &> /dev/null; then
        print_success "Tor уже установлен"
    else
        print_warning "Tor не найден, попытка установки..."
        
        # Определение дистрибутива
        if [ -f /etc/debian_version ]; then
            sudo apt update
            sudo apt install -y tor
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y tor || sudo dnf install -y tor
        else
            print_error "Неизвестный дистрибутив, установите Tor вручную"
            exit 1
        fi
        
        print_success "Tor установлен"
    fi
}

# Создание директорий
create_directories() {
    print_info "Создание необходимых директорий..."
    
    mkdir -p reports
    mkdir -p templates
    mkdir -p logs
    
    print_success "Директории созданы"
}

# Проверка портов
check_ports() {
    print_info "Проверка доступности портов..."
    
    # Проверка порта 5000 (Flask)
    if netstat -tuln | grep -q ":5000 "; then
        print_warning "Порт 5000 уже используется"
        print_info "Попробуйте остановить другие сервисы или измените порт в app.py"
    fi
    
    # Проверка портов Tor
    if netstat -tuln | grep -q ":9050 "; then
        print_warning "Порт 9050 (Tor SOCKS) уже используется"
    fi
    
    if netstat -tuln | grep -q ":9051 "; then
        print_warning "Порт 9051 (Tor Control) уже используется"
    fi
}

# Запуск Tor
start_tor() {
    print_info "Запуск Tor..."
    
    if [ -f "tor_setup.py" ]; then
        python3 tor_setup.py start &
        TOR_PID=$!
        sleep 5
        
        # Проверка, что Tor запустился
        if kill -0 $TOR_PID 2>/dev/null; then
            print_success "Tor запущен (PID: $TOR_PID)"
            echo $TOR_PID > .tor_pid
        else
            print_error "Не удалось запустить Tor"
            exit 1
        fi
    else
        print_error "Файл tor_setup.py не найден"
        exit 1
    fi
}

# Запуск веб-сервера
start_webserver() {
    print_info "Запуск веб-сервера..."
    
    if [ -f "app.py" ]; then
        python3 app.py &
        FLASK_PID=$!
        sleep 3
        
        # Проверка, что Flask запустился
        if kill -0 $FLASK_PID 2>/dev/null; then
            print_success "Веб-сервер запущен (PID: $FLASK_PID)"
            echo $FLASK_PID > .flask_pid
        else
            print_error "Не удалось запустить веб-сервер"
            exit 1
        fi
    else
        print_error "Файл app.py не найден"
        exit 1
    fi
}

# Остановка сервисов
stop_services() {
    print_info "Остановка сервисов..."
    
    # Остановка Flask
    if [ -f ".flask_pid" ]; then
        FLASK_PID=$(cat .flask_pid)
        if kill -0 $FLASK_PID 2>/dev/null; then
            kill $FLASK_PID
            print_success "Веб-сервер остановлен"
        fi
        rm -f .flask_pid
    fi
    
    # Остановка Tor
    if [ -f ".tor_pid" ]; then
        TOR_PID=$(cat .tor_pid)
        if kill -0 $TOR_PID 2>/dev/null; then
            kill $TOR_PID
            print_success "Tor остановлен"
        fi
        rm -f .tor_pid
    fi
    
    # Альтернативный способ остановки Tor
    if [ -f "tor_setup.py" ]; then
        python3 tor_setup.py stop
    fi
}

# Показ статуса
show_status() {
    print_info "Статус сервисов:"
    
    # Проверка Flask
    if [ -f ".flask_pid" ] && kill -0 $(cat .flask_pid) 2>/dev/null; then
        print_success "Веб-сервер: Работает (PID: $(cat .flask_pid))"
        print_info "URL: http://localhost:5000"
        print_info "Админ панель: http://localhost:5000/admin/reports"
    else
        print_error "Веб-сервер: Не работает"
    fi
    
    # Проверка Tor
    if pgrep tor > /dev/null; then
        print_success "Tor: Работает"
        if [ -f "tor_setup.py" ]; then
            python3 tor_setup.py hidden
        fi
    else
        print_error "Tor: Не работает"
    fi
    
    # Проверка портов
    print_info "Открытые порты:"
    netstat -tuln | grep -E ":(5000|9050|9051) " || print_warning "Порты не открыты"
}

# Показ логов
show_logs() {
    print_info "Последние логи:"
    
    if [ -f "/tmp/tor_interceptor/tor.log" ]; then
        echo -e "${YELLOW}=== Tor Logs ===${NC}"
        tail -n 10 /tmp/tor_interceptor/tor.log
    fi
    
    if [ -f "intercepts.db" ]; then
        echo -e "${YELLOW}=== Последние перехваты ===${NC}"
        sqlite3 intercepts.db "SELECT timestamp, ip_address, browser FROM intercepts ORDER BY timestamp DESC LIMIT 5;"
    fi
}

# Очистка данных
cleanup() {
    print_warning "Очистка данных..."
    read -p "Удалить все отчеты и базу данных? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f intercepts.db
        rm -rf reports/*
        rm -rf /tmp/tor_interceptor
        print_success "Данные очищены"
    fi
}

# Основная функция
main() {
    print_header
    
    case "${1:-start}" in
        "start")
            check_root
            check_dependencies
            install_python_deps
            setup_tor
            create_directories
            check_ports
            start_tor
            start_webserver
            echo
            print_success "Все сервисы запущены!"
            show_status
            echo
            print_info "Для остановки используйте: ./run.sh stop"
            print_info "Для проверки статуса: ./run.sh status"
            ;;
        
        "stop")
            stop_services
            ;;
        
        "restart")
            stop_services
            sleep 2
            $0 start
            ;;
        
        "status")
            show_status
            ;;
        
        "logs")
            show_logs
            ;;
        
        "cleanup")
            stop_services
            cleanup
            ;;
        
        "install")
            check_dependencies
            install_python_deps
            setup_tor
            create_directories
            print_success "Установка завершена"
            ;;
        
        *)
            echo "Использование: $0 {start|stop|restart|status|logs|cleanup|install}"
            echo
            echo "Команды:"
            echo "  start    - Запустить все сервисы"
            echo "  stop     - Остановить все сервисы"
            echo "  restart  - Перезапустить сервисы"
            echo "  status   - Показать статус сервисов"
            echo "  logs     - Показать логи"
            echo "  cleanup  - Очистить данные"
            echo "  install  - Установить зависимости"
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Получен сигнал прерывания, остановка сервисов..."; stop_services; exit 0' INT TERM

# Запуск
main "$@"
