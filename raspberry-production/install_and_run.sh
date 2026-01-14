#!/bin/bash

# Скрипт автоматической установки и запуска Web Server Interceptor на Raspberry Pi
# Выполняет: git pull, настройку, установку зависимостей и запуск сервера

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
    echo "🍓 =============================================="
    echo "   Web Server Interceptor - Raspberry Pi"
    echo "   Автоматическая установка и запуск"
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
PROJECT_NAME="web-interogatter"
DEFAULT_GIT_URL="https://github.com/Gr3y-foX/simple_ip_sniffer_-yet-only-local-"
PROJECT_DIR="$HOME/$PROJECT_NAME"

# Определение git URL
if [ -n "$1" ]; then
    GIT_URL="$1"
else
    # Если уже есть git репозиторий, используем его remote
    if [ -d "$PROJECT_DIR/.git" ]; then
        GIT_URL=$(cd "$PROJECT_DIR" && git remote get-url origin 2>/dev/null || echo "$DEFAULT_GIT_URL")
    else
        GIT_URL="$DEFAULT_GIT_URL"
    fi
fi

# Проверка архитектуры
check_architecture() {
    print_info "Проверка архитектуры системы..."
    
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" && "$ARCH" != "armv7l" ]]; then
        print_warning "Обнаружена архитектура: $ARCH"
        print_warning "Этот скрипт оптимизирован для Raspberry Pi (ARM)"
        read -p "Продолжить установку? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 
        fi
    else
        print_success "Архитектура ARM обнаружена: $ARCH"
    fi
}

# Клонирование или обновление проекта
setup_git_repo() {
    print_info "Настройка Git репозитория..."
    
    if [ -d "$PROJECT_DIR/.git" ]; then
        print_info "Реопзиторий уже существует, обновление..."
        cd "$PROJECT_DIR"
        
        # Сохранение локальных изменений
        if ! git diff --quiet || ! git diff --cached --quiet; then
            print_warning "Обнаружены локальные изменения"
            read -p "Сохранить изменения в stash? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                git stash save "Auto-stash before pull $(date +%Y%m%d_%H%M%S)"
                print_success "Изменения сохранены в stash"
            fi
        fi
        
        # Обновление из git
        print_info "Получение обновлений из git..."
        git fetch origin
        
        # Проверка текущей ветки
        CURRENT_BRANCH=$(git branch --show-current)
        print_info "Текущая ветка: $CURRENT_BRANCH"
        
        # Pull изменений
        if git pull origin "$CURRENT_BRANCH"; then
            print_success "Проект обновлен из git"
        else
            print_warning "Не удалось обновить из git, используем текущую версию"
        fi
    else
        print_info "Клонирование репозитория..."
        
        if [ -d "$PROJECT_DIR" ]; then
            print_warning "Директория $PROJECT_DIR уже существует, но не является git репозиторием"
            read -p "Удалить и пересоздать? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$PROJECT_DIR"
            else
                print_error "Отменено"
                exit 1
            fi
        fi
        
        # Клонирование
        if git clone "$GIT_URL" "$PROJECT_DIR"; then
            print_success "Проект клонирован"
        else
            print_error "Не удалось клонировать репозиторий"
            print_info "Проверьте URL: $GIT_URL"
            print_info "Или укажите правильный URL: $0 <git-url>"
            exit 1
        fi
    fi
    
    cd "$PROJECT_DIR"
}

# Установка системных зависимостей
install_system_deps() {
    print_info "Установка системных зависимостей..."
    
    # Обновление пакетов
    sudo apt update
    
    # Установка базовых пакетов
    sudo apt install -y \
        git \
        curl \
        wget \
        python3 \
        python3-pip \
        python3-venv \
        sqlite3 \
        tor
    
    print_success "Системные зависимости установлены"
}

# Установка Python зависимостей (без Docker)
install_python_deps() {
    print_info "Установка Python зависимостей..."
    
    cd "$PROJECT_DIR"
    
    # Установка pip пакетов
    if [ -f "requirements.txt" ]; then
        print_info "Установка пакетов из requirements.txt..."
        pip3 install --user -r requirements.txt
        print_success "Python зависимости установлены"
    else
        print_warning "Файл requirements.txt не найден"
    fi
    
    # Проверка установки критических пакетов
    print_info "Проверка установленных пакетов..."
    python3 -c "import flask" 2>/dev/null && print_success "Flask установлен" || print_warning "Flask не установлен"
    python3 -c "import stem" 2>/dev/null && print_success "Stem установлен" || print_warning "Stem не установлен"
    python3 -c "import requests" 2>/dev/null && print_success "Requests установлен" || print_warning "Requests не установлен"
}


# Настройка проекта
setup_project() {
    print_info "Настройка проекта..."
    
    cd "$PROJECT_DIR"
    
    # Создание необходимых директорий
    mkdir -p data reports logs
    mkdir -p docker/grafana/{dashboards,datasources} 2>/dev/null || true
    
    # Установка прав на скрипты в raspberry-production
    if [ -d "raspberry-production" ]; then
        chmod +x raspberry-production/*.sh
    fi
    
    print_success "Проект настроен"
}

# Запуск сервера
start_server() {
    print_info "Запуск сервера..."
    
    cd "$PROJECT_DIR/raspberry-production"
    
    # Проверка наличия скрипта
    if [ ! -f "raspberry-run.sh" ]; then
        print_error "Скрипт raspberry-run.sh не найден"
        print_info "Убедитесь, что вы находитесь в правильной директории"
        return 1
    fi
    
    # Проверка, не запущен ли уже сервер
    if [ -f "/tmp/web-interceptor-flask.pid" ]; then
        FLASK_PID=$(cat /tmp/web-interceptor-flask.pid)
        if kill -0 "$FLASK_PID" 2>/dev/null; then
            print_warning "Сервер уже запущен (PID: $FLASK_PID)"
            read -p "Перезапустить? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ./raspberry-run.sh stop
                sleep 2
            else
                print_info "Используется существующий сервер"
                ./raspberry-run.sh status
                return 0
            fi
        fi
    fi
    
    # Запуск
    ./raspberry-run.sh start
    
    print_success "Сервер запущен!"
}

# Показ информации
show_info() {
    echo
    print_success "Установка и запуск завершены!"
    echo
    print_info "Проект находится в: $PROJECT_DIR"
    print_info "Директория скриптов: $PROJECT_DIR/raspberry-production"
    echo
    print_info "Полезные команды:"
    echo "  cd $PROJECT_DIR/raspberry-production"
    echo "  ./raspberry-run.sh status      # Статус сервера"
    echo "  ./raspberry-run.sh logs        # Просмотр логов"
    echo "  ./raspberry-run.sh stop        # Остановка сервера"
    echo "  ./raspberry-run.sh restart     # Перезапуск"
    echo "  ./monitor_security.sh          # Мониторинг безопасности"
    echo
    print_info "Доступ к серверу:"
    
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo "  http://localhost:5000"
    echo "  http://$IP_ADDRESS:5000"
    echo
    
    # Получение .onion адреса (если готов)
    sleep 5
    if [ -f "/tmp/tor_interceptor/hidden_service/hostname" ] || \
       [ -f "/var/lib/tor-interceptor/hidden_service/hostname" ] || \
       [ -f "$PROJECT_DIR/data/onion_address.txt" ]; then
        ONION_ADDR=$(cat /tmp/tor_interceptor/hidden_service/hostname 2>/dev/null || \
                     cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null || \
                     cat "$PROJECT_DIR/data/onion_address.txt" 2>/dev/null | head -1)
        if [ -n "$ONION_ADDR" ] && [[ "$ONION_ADDR" == *.onion ]]; then
            print_success "Tor Hidden Service: http://$ONION_ADDR"
        else
            print_info "Tor Hidden Service еще не готов (подождите ~60 секунд)"
            print_info "Получить адрес: ./raspberry-run.sh onion"
        fi
    else
        print_info "Tor Hidden Service еще не готов (подождите ~60 секунд)"
        print_info "Получить адрес: ./raspberry-run.sh onion"
    fi
    echo
}

# Основная функция
main() {
    print_header
    
    check_architecture
    setup_git_repo
    install_system_deps
    install_python_deps
    setup_project
    
    # Опциональная настройка безопасности
    cd "$PROJECT_DIR/raspberry-production"
    print_info "Настройка безопасности..."
    read -p "Настроить усиленную защиту? (рекомендуется для production) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "setup_security.sh" ]; then
            print_warning "Запуск настройки безопасности (требует sudo)..."
            sudo ./setup_security.sh
        else
            print_warning "Скрипт setup_security.sh не найден"
        fi
    fi
    
    start_server
    show_info
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 1' INT TERM

# Запуск
main "$@"

