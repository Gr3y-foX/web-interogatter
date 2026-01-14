#!/bin/bash

# Скрипт исправления конфликта порта 5000 на Raspberry Pi
# Останавливает все процессы и контейнеры, использующие порт 5000

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Исправление конфликта порта 5000${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo
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

# Остановка Docker контейнеров
stop_docker_containers() {
    print_info "Проверка Docker контейнеров..."
    
    # Проверка, установлен ли Docker
    if ! command -v docker &> /dev/null; then
        print_info "Docker не установлен, пропускаем"
        return 0
    fi
    
    # Остановка контейнера interceptor
    if docker ps -q -f name=web-interceptor-raspberry &> /dev/null; then
        print_warning "Найден запущенный контейнер web-interceptor-raspberry"
        docker stop web-interceptor-raspberry 2>/dev/null || true
        docker rm -f web-interceptor-raspberry 2>/dev/null || true
        print_success "Контейнер web-interceptor-raspberry остановлен"
    fi
    
    # Остановка всех контейнеров, использующих порт 5000
    CONTAINERS=$(docker ps -q --filter "publish=5000" 2>/dev/null || true)
    if [ -n "$CONTAINERS" ]; then
        print_warning "Найдены контейнеры на порту 5000: $CONTAINERS"
        for container in $CONTAINERS; do
            CONTAINER_NAME=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
            print_info "Остановка контейнера: $CONTAINER_NAME"
            docker stop $container
            docker rm -f $container 2>/dev/null || true
        done
        print_success "Все контейнеры на порту 5000 остановлены"
    fi
    
    # Остановка docker-compose
    print_info "Проверка docker-compose сервисов..."
    if [ -f "../docker-compose.raspberry.yml" ]; then
        cd ..
        docker-compose -f docker-compose.raspberry.yml down 2>/dev/null || true
        cd - > /dev/null
        print_success "Docker Compose сервисы остановлены"
    fi
}

# Остановка Python процессов
stop_python_processes() {
    print_info "Проверка Python процессов на порту 5000..."
    
    # Поиск процессов, использующих порт 5000
    PIDS=$(lsof -ti:5000 2>/dev/null || true)
    
    if [ -n "$PIDS" ]; then
        print_warning "Найдены процессы на порту 5000: $PIDS"
        for pid in $PIDS; do
            PROCESS_INFO=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            print_info "Остановка процесса: $pid ($PROCESS_INFO)"
            kill -TERM $pid 2>/dev/null || kill -KILL $pid 2>/dev/null || true
        done
        
        # Подождать немного
        sleep 2
        
        # Проверить, что процессы остановлены
        REMAINING=$(lsof -ti:5000 2>/dev/null || true)
        if [ -n "$REMAINING" ]; then
            print_warning "Некоторые процессы все еще работают, принудительная остановка..."
            kill -9 $REMAINING 2>/dev/null || true
        fi
        
        print_success "Все процессы на порту 5000 остановлены"
    else
        print_info "Нет процессов на порту 5000"
    fi
}

# Очистка PID файлов
cleanup_pid_files() {
    print_info "Очистка PID файлов..."
    
    rm -f /tmp/web-interceptor-flask.pid 2>/dev/null || true
    rm -f /tmp/web-interceptor-tor.pid 2>/dev/null || true
    rm -f /tmp/web-interceptor-monitor.pid 2>/dev/null || true
    
    print_success "PID файлы очищены"
}

# Проверка порта 5000
check_port() {
    print_info "Финальная проверка порта 5000..."
    
    if lsof -ti:5000 &> /dev/null; then
        print_error "ОШИБКА: Порт 5000 все еще занят!"
        print_info "Информация о процессе:"
        lsof -i:5000 || true
        return 1
    else
        print_success "Порт 5000 свободен!"
        return 0
    fi
}

# Показать статус
show_status() {
    echo
    print_info "Текущий статус системы:"
    echo
    
    # Docker контейнеры
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}Docker контейнеры:${NC}"
        docker ps -a --filter "name=interceptor" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "  Нет контейнеров"
        echo
    fi
    
    # Процессы на порту 5000
    echo -e "${BLUE}Процессы на порту 5000:${NC}"
    if lsof -i:5000 2>/dev/null; then
        echo "  (порт занят)"
    else
        echo "  (порт свободен)"
    fi
    echo
    
    # PID файлы
    echo -e "${BLUE}PID файлы:${NC}"
    for pid_file in /tmp/web-interceptor-*.pid; do
        if [ -f "$pid_file" ]; then
            echo "  $pid_file: $(cat $pid_file 2>/dev/null || echo 'не читается')"
        fi
    done
    [ -f "/tmp/web-interceptor-flask.pid" ] || echo "  (нет PID файлов)"
    echo
}

# Главная функция
main() {
    print_header
    
    # Проверка прав
    if [ "$EUID" -eq 0 ]; then
        print_warning "Запущено с правами root"
    fi
    
    # Выполнение очистки
    stop_docker_containers
    stop_python_processes
    cleanup_pid_files
    
    echo
    if check_port; then
        echo
        print_success "✨ Проблема решена! Порт 5000 свободен"
        echo
        print_info "Теперь можно запустить сервер:"
        echo "  cd raspberry-production"
        echo "  ./raspberry-run.sh start"
        echo
        echo "  или через Docker:"
        echo "  cd .."
        echo "  docker-compose -f docker-compose.raspberry.yml up -d"
        echo
    else
        echo
        print_error "Не удалось освободить порт 5000"
        print_info "Попробуйте запустить с sudo:"
        echo "  sudo ./fix_port_conflict.sh"
        echo
        show_status
        exit 1
    fi
    
    show_status
}

# Запуск
main "$@"

