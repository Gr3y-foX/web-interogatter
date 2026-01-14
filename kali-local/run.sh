#!/bin/bash

# Web Server Interceptor - Скрипт запуска для Kali Linux
# Версия БЕЗ Docker - запуск напрямую через Python
# Для локального использования и тестирования

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Защита от рекурсии: если скрипт был вызван из корневого run.sh (флаг установлен),
# это означает, что корневой скрипт уже определил платформу и вызвал этот скрипт.
# В этом случае мы выполняем реальную логику вместо вызова корневого скрипта снова.
if [ -n "$WEB_INTERCEPTOR_NO_RECURSE" ]; then
    # Скрипт был вызван из корневого run.sh - выполняем реальную логику
    # Сбрасываем флаг, чтобы не мешать дальнейшей работе
    unset WEB_INTERCEPTOR_NO_RECURSE
    unset WEB_INTERCEPTOR_PLATFORM
    # Продолжаем выполнение с реальной логикой ниже
else
    # Первый вызов - вызываем корневой скрипт с указанием платформы
    # Корневой скрипт определит платформу и вызовет этот скрипт снова с флагом WEB_INTERCEPTOR_NO_RECURSE
    exec ./run.sh --platform kali "$@"
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# PID файлы
TOR_PID_FILE="/tmp/web-interceptor-tor-kali.pid"
FLASK_PID_FILE="/tmp/web-interceptor-flask-kali.pid"

# Функции для красивого вывода
print_header() {
    echo -e "${PURPLE}"
    echo "🐧 =============================================="
    echo "   Web Server Interceptor - Kali Linux Edition"
    echo "   Версия БЕЗ Docker - Прямой запуск"
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

# Проверка зависимостей
check_dependencies() {
    print_info "Проверка зависимостей..."
    
    local missing_deps=()
    
    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    # Проверка Tor
    if ! command -v tor &> /dev/null; then
        missing_deps+=("tor")
    fi
    
    # Проверка pip пакетов
    if ! python3 -c "import flask" 2>/dev/null; then
        missing_deps+=("flask (pip)")
    fi
    
    if ! python3 -c "import stem" 2>/dev/null; then
        missing_deps+=("stem (pip)")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Отсутствуют зависимости: ${missing_deps[*]}"
        print_info "Установите зависимости:"
        print_info "  sudo apt update && sudo apt install -y python3 python3-pip tor"
        print_info "  pip3 install -r requirements.txt"
        exit 1
    fi
    
    print_success "Все зависимости установлены"
}

# Создание необходимых директорий
create_directories() {
    print_info "Создание директорий..."
    
    mkdir -p data reports logs
    mkdir -p /tmp/tor_interceptor_kali/hidden_service 2>/dev/null || true
    mkdir -p /var/lib/tor-interceptor/hidden_service 2>/dev/null || true
    
    print_success "Директории созданы"
}

# Инициализация базы данных
init_database() {
    print_info "Инициализация базы данных..."
    
    if [ ! -f "data/intercepts.db" ]; then
        python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
from app import init_db
init_db()
" 2>/dev/null && print_success "База данных инициализирована" || print_warning "База данных уже существует"
    else
        print_info "База данных уже существует"
    fi
}

# Запуск Tor
start_tor() {
    print_info "Запуск Tor..."
    
    # Проверка, не запущен ли уже Tor
    if [ -f "$TOR_PID_FILE" ]; then
        TOR_PID=$(cat "$TOR_PID_FILE")
        if kill -0 "$TOR_PID" 2>/dev/null; then
            print_warning "Tor уже запущен (PID: $TOR_PID)"
            return 0
        fi
    fi
    
    # Запуск Tor через tor_setup.py
    if python3 tor_setup.py start 2>/dev/null; then
        # Получение PID Tor процесса
        sleep 2
        TOR_PID=$(pgrep -f "tor.*torrc" | head -1)
        if [ -n "$TOR_PID" ]; then
            echo "$TOR_PID" > "$TOR_PID_FILE"
            print_success "Tor запущен (PID: $TOR_PID)"
            return 0
        fi
    fi
    
    # Альтернативный способ - прямой запуск Tor
    print_info "Попытка прямого запуска Tor..."
    
    # Создание конфигурации Tor
    mkdir -p /tmp/tor_interceptor_kali
    cat > /tmp/tor_interceptor_kali/torrc << EOF
SocksPort 127.0.0.1:9050
ControlPort 127.0.0.1:9051
HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C
DataDirectory /tmp/tor_interceptor_kali
Log notice file /tmp/tor_interceptor_kali/tor.log

# Hidden Service
HiddenServiceDir /tmp/tor_interceptor_kali/hidden_service/
HiddenServicePort 80 127.0.0.1:5000
HiddenServiceVersion 3

# Security settings
ExitPolicy reject *:*
ExitRelay 0
PublishServerDescriptor 0
EOF
    
    # Запуск Tor в фоне
    tor -f /tmp/tor_interceptor_kali/torrc > /dev/null 2>&1 &
    TOR_PID=$!
    echo "$TOR_PID" > "$TOR_PID_FILE"
    
    # Ожидание запуска
    for i in {1..30}; do
        if netstat -tuln 2>/dev/null | grep -q ":9050 " || ss -tuln 2>/dev/null | grep -q ":9050 "; then
            print_success "Tor запущен (PID: $TOR_PID)"
            return 0
        fi
        sleep 1
    done
    
    print_error "Не удалось запустить Tor"
    return 1
}

# Остановка Tor
stop_tor() {
    if [ -f "$TOR_PID_FILE" ]; then
        TOR_PID=$(cat "$TOR_PID_FILE")
        if kill -0 "$TOR_PID" 2>/dev/null; then
            kill "$TOR_PID" 2>/dev/null || true
            print_success "Tor остановлен"
        fi
        rm -f "$TOR_PID_FILE"
    fi
    
    # Остановка через tor_setup.py
    python3 tor_setup.py stop 2>/dev/null || true
}

# Запуск Flask приложения
start_flask() {
    print_info "Запуск Flask приложения..."
    
    # Проверка, не запущен ли уже Flask
    if [ -f "$FLASK_PID_FILE" ]; then
        FLASK_PID=$(cat "$FLASK_PID_FILE")
        if kill -0 "$FLASK_PID" 2>/dev/null; then
            print_warning "Flask уже запущен (PID: $FLASK_PID)"
            return 0
        fi
    fi
    
    # Установка переменных окружения
    export FLASK_APP=app.py
    export FLASK_ENV=production
    export DATABASE_PATH="$PROJECT_ROOT/data/intercepts.db"
    
    # Запуск Flask в фоне
    cd "$PROJECT_ROOT"
    nohup python3 app.py > logs/flask.log 2>&1 &
    FLASK_PID=$!
    echo "$FLASK_PID" > "$FLASK_PID_FILE"
    
    # Ожидание запуска
    for i in {1..20}; do
        if netstat -tuln 2>/dev/null | grep -q ":5000 " || ss -tuln 2>/dev/null | grep -q ":5000 "; then
            print_success "Flask запущен (PID: $FLASK_PID)"
            return 0
        fi
        sleep 1
    done
    
    print_error "Не удалось запустить Flask приложение"
    return 1
}

# Остановка Flask
stop_flask() {
    if [ -f "$FLASK_PID_FILE" ]; then
        FLASK_PID=$(cat "$FLASK_PID_FILE")
        if kill -0 "$FLASK_PID" 2>/dev/null; then
            kill "$FLASK_PID" 2>/dev/null || true
            print_success "Flask остановлен"
        fi
        rm -f "$FLASK_PID_FILE"
    fi
    
    # Дополнительная проверка и остановка всех процессов app.py
    pkill -f "python3.*app.py" 2>/dev/null || true
}

# Получение .onion адреса
get_onion() {
    print_info "Получение .onion адреса..."
    
    # Проверка различных путей
    ONION_PATHS=(
        "/tmp/tor_interceptor_kali/hidden_service/hostname"
        "/var/lib/tor-interceptor/hidden_service/hostname"
        "data/onion_address.txt"
    )
    
    for path in "${ONION_PATHS[@]}"; do
        if [ -f "$path" ]; then
            ONION_ADDR=$(cat "$path" 2>/dev/null | head -1)
            if [ -n "$ONION_ADDR" ] && [[ "$ONION_ADDR" == *.onion ]]; then
                print_success "🧅 Hidden Service: http://$ONION_ADDR"
                echo "$ONION_ADDR" > data/onion_address.txt
                return 0
            fi
        fi
    done
    
    # Ожидание создания hidden service
    for i in {1..45}; do
        for path in "${ONION_PATHS[@]}"; do
            if [ -f "$path" ]; then
                ONION_ADDR=$(cat "$path" 2>/dev/null | head -1)
                if [ -n "$ONION_ADDR" ] && [[ "$ONION_ADDR" == *.onion ]]; then
                    print_success "🧅 Hidden Service: http://$ONION_ADDR"
                    echo "$ONION_ADDR" > data/onion_address.txt
                    return 0
                fi
            fi
        done
        echo -n "."
        sleep 2
    done
    
    print_warning "Hidden Service адрес еще не готов"
    print_info "Попробуйте позже: ./run.sh --platform kali onion"
}

# Смена Tor идентичности
new_tor_identity() {
    print_info "Смена Tor идентичности..."
    
    if python3 tor_setup.py newip 2>/dev/null; then
        print_success "Tor идентичность изменена"
    else
        print_error "Не удалось изменить Tor идентичность"
    fi
}

# Показ URL адресов
show_urls() {
    local IP_ADDRESS=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo
    print_success "🌐 Доступные сервисы:"
    echo "  📡 Основной сайт:     http://localhost:5000"
    echo "  📡 Основной сайт:     http://$IP_ADDRESS:5000"
    echo "  🔧 Админ панель:      http://localhost:5000/admin/reports"
    echo "  📊 API отчетов:       http://localhost:5000/admin/api/reports"
    echo "  🎭 Маскировочный сайт: http://localhost:5000/mask"
    echo "  📊 Страница перехвата: http://localhost:5000/intercept"
    echo
    print_info "🧅 Tor SOCKS прокси: 127.0.0.1:9050"
    print_info "🎛️  Tor Control:      127.0.0.1:9051"
    
    # Попытка получить .onion адрес
    if [ -f "/tmp/tor_interceptor_kali/hidden_service/hostname" ] || \
       [ -f "/var/lib/tor-interceptor/hidden_service/hostname" ] || \
       [ -f "data/onion_address.txt" ]; then
        get_onion
    else
        print_warning "🧅 Hidden Service еще не готов (подождите ~60-90 секунд)"
        print_info "   Выполните: ./run.sh --platform kali onion"
    fi
    echo
}

# Показ статуса
show_status() {
    print_info "Статус сервисов:"
    echo
    
    # Статус Tor
    if [ -f "$TOR_PID_FILE" ]; then
        TOR_PID=$(cat "$TOR_PID_FILE")
        if kill -0 "$TOR_PID" 2>/dev/null; then
            print_success "Tor: запущен (PID: $TOR_PID)"
        else
            print_error "Tor: не запущен (PID файл устарел)"
        fi
    else
        if pgrep -f "tor.*torrc" > /dev/null; then
            print_warning "Tor: запущен (без PID файла)"
        else
            print_error "Tor: не запущен"
        fi
    fi
    
    # Статус Flask
    if [ -f "$FLASK_PID_FILE" ]; then
        FLASK_PID=$(cat "$FLASK_PID_FILE")
        if kill -0 "$FLASK_PID" 2>/dev/null; then
            print_success "Flask: запущен (PID: $FLASK_PID)"
        else
            print_error "Flask: не запущен (PID файл устарел)"
        fi
    else
        if pgrep -f "python3.*app.py" > /dev/null; then
            print_warning "Flask: запущен (без PID файла)"
        else
            print_error "Flask: не запущен"
        fi
    fi
    
    echo
    print_info "Использование ресурсов:"
    free -h | grep -E "^Mem|^Swap" | awk '{print "  " $1 ": " $3 "/" $2 " (" $5 ")"}'
    
    echo
    print_info "Использование диска:"
    df -h / | tail -1 | awk '{print "  Root: " $3 "/" $2 " (" $5 " использовано)"}'
}

# Показ логов
show_logs() {
    local service=${1:-""}
    
    if [ -z "$service" ]; then
        print_info "Показ последних логов..."
        echo
        echo "=== Flask лог ==="
        tail -n 20 logs/flask.log 2>/dev/null || echo "Лог Flask не найден"
        echo
        echo "=== Tor лог ==="
        tail -n 20 /tmp/tor_interceptor_kali/tor.log 2>/dev/null || echo "Лог Tor не найден"
        echo
        echo "=== Interceptor лог ==="
        tail -n 20 logs/interceptor.log 2>/dev/null || echo "Лог Interceptor не найден"
    elif [ "$service" = "flask" ]; then
        tail -f logs/flask.log
    elif [ "$service" = "tor" ]; then
        tail -f /tmp/tor_interceptor_kali/tor.log
    elif [ "$service" = "interceptor" ]; then
        tail -f logs/interceptor.log
    else
        print_error "Неизвестный сервис: $service"
        print_info "Доступные: flask, tor, interceptor"
    fi
}

# Очистка
cleanup() {
    print_warning "Очистка временных файлов..."
    
    # Остановка сервисов
    stop_flask
    stop_tor
    
    # Удаление PID файлов
    rm -f "$TOR_PID_FILE" "$FLASK_PID_FILE"
    
    print_success "Очистка завершена"
}

# Основная функция
main() {
    case "${1:-help}" in
        "start"|"up")
            print_header
            check_dependencies
            create_directories
            init_database
            start_tor
            sleep 3
            start_flask
            sleep 2
            show_urls
            ;;
            
        "stop"|"down")
            print_header
            stop_flask
            stop_tor
            cleanup
            ;;
            
        "restart")
            print_header
            stop_flask
            stop_tor
            sleep 2
            start_tor
            sleep 3
            start_flask
            sleep 2
            show_urls
            ;;
            
        "status"|"ps")
            print_header
            show_status
            ;;
            
        "logs")
            show_logs "${2}"
            ;;
            
        "urls")
            show_urls
            ;;
            
        "onion")
            get_onion
            ;;
            
        "newip")
            new_tor_identity
            ;;
            
        "cleanup")
            cleanup
            ;;
            
        "help"|*)
            echo "🐧 Web Server Interceptor - Kali Linux Management (БЕЗ Docker)"
            echo
            echo "Основные команды:"
            echo "  start, up          - Запуск сервисов"
            echo "  stop, down         - Остановка сервисов"
            echo "  restart            - Перезапуск сервисов"
            echo
            echo "Мониторинг:"
            echo "  status, ps         - Статус сервисов"
            echo "  logs [service]     - Просмотр логов (flask, tor, interceptor)"
            echo "  urls               - Показать URL адреса"
            echo
            echo "Tor управление:"
            echo "  onion              - Получить .onion адрес"
            echo "  newip              - Сменить Tor идентичность"
            echo
            echo "Утилиты:"
            echo "  cleanup            - Очистка временных файлов"
            echo
            echo "Примеры:"
            echo "  ./run.sh --platform kali start"
            echo "  ./run.sh --platform kali logs flask"
            echo "  ./kali-local/run.sh start"
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 0' INT TERM

# Запуск основной функции
main "$@"
