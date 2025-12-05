#!/bin/bash

# Скрипт управления Web Server Interceptor для Raspberry Pi 4
# Оптимизированная версия docker-run.sh для Raspberry Pi

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
PURPLE='\033[0;35m'
NC='\033[0m'

# Определение команды compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose -f $PROJECT_ROOT/docker-compose.raspberry.yml"
else
    COMPOSE_CMD="docker-compose -f $PROJECT_ROOT/docker-compose.raspberry.yml"
fi

# Функции для красивого вывода
print_header() {
    echo -e "${PURPLE}"
    echo "🍓 =============================================="
    echo "   Web Server Interceptor - Raspberry Pi Edition"
    echo "   Управление контейнерами для Raspberry Pi 4"
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

# Проверка Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        print_info "Запустите: ./setup_raspberry.sh"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker не запущен или нет прав доступа"
        print_info "Запустите: sudo systemctl start docker"
        print_info "Или добавьте пользователя в группу docker: sudo usermod -aG docker $USER"
        exit 1
    fi
    
    print_success "Docker доступен"
}

# Проверка файлов конфигурации
check_config() {
    if [ ! -f "docker-compose.raspberry.yml" ]; then
        print_error "Файл docker-compose.raspberry.yml не найден"
        exit 1
    fi
    
    if [ ! -f "Dockerfile.raspberry" ]; then
        print_error "Файл Dockerfile.raspberry не найден"
        exit 1
    fi
}

# Создание необходимых директорий
create_directories() {
    mkdir -p data reports logs
    mkdir -p docker/grafana/{dashboards,datasources} 2>/dev/null || true
}

# Сборка образов
build_images() {
    print_info "Сборка Docker образов для Raspberry Pi..."
    
    # Включение BuildKit для ускорения сборки
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    # Опция для использования кэша (быстрее) или без кэша (чистая сборка)
    local no_cache_flag=""
    if [ "${2:-}" = "--no-cache" ]; then
        no_cache_flag="--no-cache"
        print_warning "Сборка без кэша (займет больше времени)"
    else
        print_info "Использование кэша для ускорения сборки"
    fi
    
    $COMPOSE_CMD build $no_cache_flag
    
    print_success "Образы собраны"
}

# Запуск основных сервисов (рекомендуется для Raspberry Pi)
start_basic() {
    print_info "Запуск основных сервисов (оптимизировано для Raspberry Pi)..."
    
    $COMPOSE_CMD up -d interceptor tor-relay
    
    print_success "Основные сервисы запущены"
    sleep 5
    show_urls
}

# Запуск всех сервисов
start_full() {
    print_info "Запуск всех сервисов..."
    
    $COMPOSE_CMD up -d
    
    print_success "Все сервисы запущены"
    sleep 5
    show_urls
}

# Запуск с дополнительными сервисами
start_with_profile() {
    local profile=$1
    print_info "Запуск с профилем: $profile"
    
    $COMPOSE_CMD --profile "$profile" up -d
    
    print_success "Сервисы запущены с профилем: $profile"
    sleep 5
    show_urls
}

# Остановка сервисов
stop_services() {
    print_info "Остановка сервисов..."
    
    $COMPOSE_CMD down
    
    print_success "Все сервисы остановлены"
}

# Показ логов
show_logs() {
    local service=${1:-""}
    
    if [ -z "$service" ]; then
        print_info "Показ логов всех сервисов..."
        $COMPOSE_CMD logs -f --tail=50
    else
        print_info "Показ логов сервиса: $service"
        $COMPOSE_CMD logs -f --tail=50 "$service"
    fi
}

# Показ статуса
show_status() {
    print_info "Статус сервисов:"
    $COMPOSE_CMD ps
    
    echo
    print_info "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || \
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo
    print_info "Использование диска:"
    df -h / | tail -1
}

# Показ URL адресов
show_urls() {
    local IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    echo
    print_success "🌐 Доступные сервисы:"
    echo "  📡 Основной сайт:     http://localhost:5000"
    echo "  📡 Основной сайт:     http://$IP_ADDRESS:5000"
    echo "  🔧 Админ панель:      http://localhost:5000/admin/reports"
    echo "  📊 API отчетов:       http://localhost:5000/admin/api/reports"
    echo
    
    # Проверка дополнительных сервисов
    if docker ps | grep -q sqlite-analyzer-raspberry; then
        echo "  🗄️  SQLite Web:       http://localhost:8080"
    fi
    
    if docker ps | grep -q nginx-interceptor-raspberry; then
        echo "  🌐 Nginx прокси:      http://localhost:80"
    fi
    
    echo
    print_info "🧅 Tor SOCKS прокси: 127.0.0.1:9050"
    print_info "🎛️  Tor Control:      127.0.0.1:9051"
    
    # Попытка получить .onion адрес
    if docker exec web-interceptor-raspberry test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
        ONION_ADDR=$(docker exec web-interceptor-raspberry cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
        print_success "🧅 Hidden Service: http://$ONION_ADDR"
    else
        print_warning "🧅 Hidden Service еще не готов (подождите ~60-90 секунд)"
        print_info "   Выполните: ./raspberry-run.sh onion"
    fi
}

# Получение .onion адреса
get_onion() {
    print_info "Получение .onion адреса..."
    
    for i in {1..45}; do
        if docker exec web-interceptor-raspberry test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
            ONION_ADDR=$(docker exec web-interceptor-raspberry cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
            print_success "🧅 Hidden Service: http://$ONION_ADDR"
            echo "$ONION_ADDR" > data/onion_address.txt
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    print_warning "Hidden Service адрес еще не готов"
    print_info "Tor может потребовать больше времени на Raspberry Pi"
    print_info "Попробуйте позже: ./raspberry-run.sh onion"
}

# Смена Tor идентичности
new_tor_identity() {
    print_info "Смена Tor идентичности..."
    
    if docker exec web-interceptor-raspberry python3 tor_setup.py newip 2>/dev/null; then
        print_success "Tor идентичность изменена"
    else
        print_error "Не удалось изменить Tor идентичность"
    fi
}

# Интерактивная оболочка
shell() {
    local service=${1:-"interceptor"}
    print_info "Запуск интерактивной оболочки в контейнере: $service"
    
    if [ "$service" = "interceptor" ]; then
        docker exec -it web-interceptor-raspberry /bin/bash
    else
        print_error "Сервис $service не найден"
    fi
}

# Экспорт данных
export_data() {
    print_info "Экспорт данных из контейнера..."
    
    local export_dir="./exported_data_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    
    # Экспорт базы данных
    if docker exec web-interceptor-raspberry test -f /app/data/intercepts.db 2>/dev/null; then
        docker cp web-interceptor-raspberry:/app/data/intercepts.db "$export_dir/" 2>/dev/null || true
    fi
    
    # Экспорт отчетов
    docker cp web-interceptor-raspberry:/app/reports/ "$export_dir/" 2>/dev/null || true
    
    # Экспорт логов
    docker cp web-interceptor-raspberry:/app/logs/ "$export_dir/" 2>/dev/null || true
    
    print_success "Данные экспортированы в: $export_dir"
}

# Мониторинг ресурсов
monitor_resources() {
    print_info "Мониторинг ресурсов Raspberry Pi..."
    
    echo
    print_info "Температура CPU:"
    if command -v vcgencmd &> /dev/null; then
        vcgencmd measure_temp
    else
        echo "vcgencmd не доступен"
    fi
    
    echo
    print_info "Использование памяти:"
    free -h
    
    echo
    print_info "Использование диска:"
    df -h /
    
    echo
    print_info "Статус Docker контейнеров:"
    docker stats --no-stream
}

# Очистка
cleanup() {
    print_warning "Полная очистка Docker окружения..."
    read -p "Удалить все контейнеры, образы и данные? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $COMPOSE_CMD down -v --rmi all --remove-orphans
        docker system prune -a -f
        print_success "Очистка завершена"
    else
        print_info "Очистка отменена"
    fi
}

# Основная функция
main() {
    print_header
    
    case "${1:-help}" in
        "start"|"up")
            check_docker
            check_config
            create_directories
            start_basic
            ;;
            
        "start-full")
            check_docker
            check_config
            create_directories
            start_full
            ;;
            
        "start-nginx")
            check_docker
            check_config
            create_directories
            start_with_profile "nginx"
            ;;
            
        "start-tools")
            check_docker
            check_config
            create_directories
            start_with_profile "tools"
            ;;
            
        "stop"|"down")
            check_docker
            stop_services
            ;;
            
        "restart")
            check_docker
            stop_services
            sleep 2
            start_basic
            ;;
            
        "build")
            check_docker
            check_config
            create_directories
            build_images "$@"
            ;;
            
        "build-no-cache")
            check_docker
            check_config
            create_directories
            build_images "$@" "--no-cache"
            ;;
            
        "fix-build")
            print_info "Запуск скрипта исправления проблем сборки..."
            if [ -f "$SCRIPT_DIR/fix_docker_build.sh" ]; then
                bash "$SCRIPT_DIR/fix_docker_build.sh"
            else
                print_error "Скрипт fix_docker_build.sh не найден"
            fi
            ;;
            
        "status"|"ps")
            check_docker
            show_status
            ;;
            
        "logs")
            check_docker
            show_logs "${2}"
            ;;
            
        "urls")
            show_urls
            ;;
            
        "onion")
            check_docker
            get_onion
            ;;
            
        "newip")
            check_docker
            new_tor_identity
            ;;
            
        "shell")
            check_docker
            shell "${2}"
            ;;
            
        "export")
            check_docker
            export_data
            ;;
            
        "monitor")
            monitor_resources
            ;;
            
        "cleanup")
            check_docker
            cleanup
            ;;
            
        "help"|*)
            echo "🍓 Web Server Interceptor - Raspberry Pi Management"
            echo
            echo "Основные команды:"
            echo "  start, up          - Запуск основных сервисов (рекомендуется)"
            echo "  start-full         - Запуск всех сервисов"
            echo "  start-nginx        - Запуск с Nginx прокси"
            echo "  start-tools        - Запуск с SQLite Web"
            echo "  stop, down         - Остановка сервисов"
            echo "  restart            - Перезапуск сервисов"
            echo "  build              - Сборка образов (с кэшем)"
            echo "  build-no-cache     - Сборка образов без кэша"
            echo "  fix-build          - Исправить проблемы сборки"
            echo
            echo "Мониторинг:"
            echo "  status, ps         - Статус контейнеров"
            echo "  logs [service]     - Просмотр логов"
            echo "  urls               - Показать URL адреса"
            echo "  monitor            - Мониторинг ресурсов Raspberry Pi"
            echo
            echo "Tor управление:"
            echo "  onion              - Получить .onion адрес"
            echo "  newip              - Сменить Tor идентичность"
            echo
            echo "Утилиты:"
            echo "  shell [service]    - Интерактивная оболочка"
            echo "  export             - Экспорт данных"
            echo "  cleanup            - Полная очистка"
            echo
            echo "Примеры:"
            echo "  ./raspberry-run.sh start"
            echo "  ./raspberry-run.sh logs interceptor"
            echo "  ./raspberry-run.sh monitor"
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 0' INT TERM

# Запуск основной функции
main "$@"

