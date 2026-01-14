#!/bin/bash

# Docker Management Script для Web Server Interceptor
# Единый скрипт с автоматическим определением платформы (Kali Linux / Raspberry Pi)
# Упрощенное управление Docker Compose окружением

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Защита от рекурсии: проверяем, был ли скрипт вызван из платформенного скрипта
# Если переменная окружения установлена, значит мы уже в рекурсии
if [ -n "$WEB_INTERCEPTOR_NO_RECURSE" ]; then
    print_error "Обнаружена рекурсия! Платформенный скрипт не должен вызывать корневой скрипт."
    exit 1
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Функции для красивого вывода
print_header() {
    echo -e "${PURPLE}"
    echo "🐳 =============================================="
    echo "   Web Server Interceptor - Docker Edition"
    echo "   Управление контейнерами"
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

# Определение платформы
detect_platform() {
    local platform=""
    local args=("$@")
    
    # Проверка аргументов командной строки
    for i in "${!args[@]}"; do
        if [[ "${args[$i]}" == "--platform"* ]]; then
            if [[ "${args[$i]}" == --platform=* ]]; then
                platform="${args[$i]#*=}"
            elif [[ -n "${args[$i+1]}" ]]; then
                platform="${args[$i+1]}"
            fi
            break
        fi
    done
    
    # Если платформа не указана, определяем автоматически
    if [ -z "$platform" ]; then
        # Проверка на Raspberry Pi
        if [ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
            platform="raspberry"
        elif [ -f /etc/os-release ] && grep -qi "raspbian\|raspberry" /etc/os-release 2>/dev/null; then
            platform="raspberry"
        # Проверка архитектуры ARM
        elif uname -m | grep -qiE "arm|aarch64"; then
            # ARM архитектура - проверяем дальше
            if [ -f /etc/os-release ] && grep -qi "kali" /etc/os-release 2>/dev/null; then
                platform="kali"
            else
                # По умолчанию для ARM - Raspberry
                platform="raspberry"
            fi
        # Проверка на Kali Linux
        elif [ -f /etc/os-release ] && grep -qi "kali" /etc/os-release 2>/dev/null; then
            platform="kali"
        else
            # По умолчанию Kali для x86_64
            platform="kali"
        fi
    fi
    
    echo "$platform"
}

# Получение платформы
PLATFORM=$(detect_platform "$@")

# Удаление аргументов --platform из списка аргументов
ARGS=()
skip_next=false
for arg in "$@"; do
    if [ "$skip_next" = true ]; then
        skip_next=false
        continue
    fi
    if [[ "$arg" == "--platform"* ]]; then
        if [[ "$arg" != --platform=* ]]; then
            skip_next=true
        fi
        continue
    fi
    ARGS+=("$arg")
done

# Определение файлов конфигурации
case "$PLATFORM" in
    "kali")
        COMPOSE_FILE="docker-compose.kali.yml"
        DOCKERFILE="Dockerfile.kali"
        PLATFORM_NAME="Kali Linux"
        CONTAINER_NAME="web-interceptor-kali"
        SERVICE_NAME="web-interceptor"
        ;;
    "raspberry"|"raspberry-pi"|"rpi")
        COMPOSE_FILE="docker-compose.raspberry.yml"
        DOCKERFILE="Dockerfile.raspberry"
        PLATFORM_NAME="Raspberry Pi"
        CONTAINER_NAME="web-interceptor-raspberry"
        SERVICE_NAME="interceptor"
        ;;
    *)
        print_error "Неизвестная платформа: $PLATFORM"
        print_info "Доступные платформы: kali, raspberry"
        exit 1
        ;;
esac

# Проверка Docker и Docker Compose
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        print_info "Установите Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose не установлен"
        print_info "Установите Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Определение команды compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
    else
        COMPOSE_CMD="docker-compose -f $COMPOSE_FILE"
    fi
    
    print_success "Docker и Docker Compose доступны"
}

# Проверка файлов конфигурации
check_config() {
    print_info "Проверка конфигурационных файлов для $PLATFORM_NAME..."
    
    local missing_files=()
    
    [ ! -f "$DOCKERFILE" ] && missing_files+=("$DOCKERFILE")
    [ ! -f "$COMPOSE_FILE" ] && missing_files+=("$COMPOSE_FILE")
    [ ! -f "docker/entrypoint.sh" ] && missing_files+=("docker/entrypoint.sh")
    [ ! -f "docker/torrc" ] && missing_files+=("docker/torrc")
    [ ! -f "requirements.txt" ] && missing_files+=("requirements.txt")
    [ ! -f "app.py" ] && missing_files+=("app.py")
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые файлы:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    print_success "Все конфигурационные файлы найдены"
}

# Создание необходимых директорий
create_directories() {
    print_info "Создание необходимых директорий..."
    
    mkdir -p docker/grafana/{dashboards,datasources} 2>/dev/null || true
    mkdir -p data reports logs
    
    print_success "Директории созданы"
}

# Сборка образов
build_images() {
    print_info "Сборка Docker образов для $PLATFORM_NAME..."
    
    # Включение BuildKit для ускорения сборки
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    local no_cache_flag=""
    if [[ "${ARGS[@]}" =~ "--no-cache" ]]; then
        no_cache_flag="--no-cache"
        print_warning "Сборка без кэша (займет больше времени)"
    fi
    
    $COMPOSE_CMD build $no_cache_flag
    
    print_success "Образы собраны"
}

# Запуск основных сервисов
start_basic() {
    print_info "Запуск основных сервисов для $PLATFORM_NAME..."
    
    # Запускаем основной сервис (Tor встроен в оба контейнера)
    $COMPOSE_CMD up -d "$SERVICE_NAME"
    
    print_success "Основные сервисы запущены"
    sleep 3
    show_urls
}

# Запуск всех сервисов
start_full() {
    print_info "Запуск всех сервисов для $PLATFORM_NAME..."
    
    $COMPOSE_CMD up -d
    
    print_success "Все сервисы запущены"
    sleep 3
    show_urls
}

# Запуск с мониторингом
start_monitoring() {
    print_info "Запуск с системой мониторинга для $PLATFORM_NAME..."
    
    $COMPOSE_CMD --profile monitoring up -d 2>/dev/null || $COMPOSE_CMD up -d
    
    print_success "Сервисы с мониторингом запущены"
    show_urls
    echo
    print_info "📊 Grafana: http://localhost:3000 (admin/interceptor123)"
}

# Остановка сервисов
stop_services() {
    print_info "Остановка сервисов..."
    
    $COMPOSE_CMD down
    
    print_success "Все сервисы остановлены"
}

# Полная очистка
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
    print_info "Статус сервисов ($PLATFORM_NAME):"
    $COMPOSE_CMD ps
    
    echo
    print_info "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || \
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Показ URL адресов
show_urls() {
    local IP_ADDRESS=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo
    print_success "🌐 Доступные сервисы ($PLATFORM_NAME):"
    echo "  📡 Основной сайт:     http://localhost:5000"
    echo "  📡 Основной сайт:     http://$IP_ADDRESS:5000"
    echo "  🔧 Админ панель:      http://localhost:5000/admin/reports"
    echo "  📊 API отчетов:       http://localhost:5000/admin/api/reports"
    echo
    
    # Проверка дополнительных сервисов
    if docker ps | grep -q "sqlite-analyzer"; then
        echo "  🗄️  SQLite Web:       http://localhost:8080"
    fi
    
    if docker ps | grep -q "nginx-interceptor"; then
        echo "  🌐 Nginx прокси:      http://localhost:80"
    fi
    
    echo
    print_info "🧅 Tor SOCKS прокси: 127.0.0.1:9050"
    print_info "🎛️  Tor Control:      127.0.0.1:9051"
    
    # Попытка получить .onion адрес
    if docker exec "$CONTAINER_NAME" test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
        ONION_ADDR=$(docker exec "$CONTAINER_NAME" cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
        print_success "🧅 Hidden Service: http://$ONION_ADDR"
    else
        print_warning "🧅 Hidden Service еще не готов (подождите ~60 секунд)"
    fi
}

# Получение .onion адреса
get_onion() {
    print_info "Получение .onion адреса..."
    
    for i in {1..30}; do
        if docker exec "$CONTAINER_NAME" test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
            ONION_ADDR=$(docker exec "$CONTAINER_NAME" cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
            print_success "🧅 Hidden Service: http://$ONION_ADDR"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    print_warning "Hidden Service адрес еще не готов"
}

# Смена Tor идентичности
new_tor_identity() {
    print_info "Смена Tor идентичности..."
    
    if docker exec "$CONTAINER_NAME" python3 tor_setup.py newip 2>/dev/null; then
        print_success "Tor идентичность изменена"
    else
        print_error "Не удалось изменить Tor идентичность"
    fi
}

# Интерактивная оболочка
shell() {
    local service=${1:-"$SERVICE_NAME"}
    print_info "Запуск интерактивной оболочки в контейнере: $service"
    
    if [ "$service" = "$SERVICE_NAME" ] || [ "$service" = "interceptor" ] || [ "$service" = "web-interceptor" ]; then
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        # Попытка найти контейнер по имени сервиса
        local container=$(docker ps --filter "name=$service" --format "{{.Names}}" | head -1)
        if [ -n "$container" ]; then
            docker exec -it "$container" /bin/bash
        else
            print_error "Сервис $service не найден"
        fi
    fi
}

# Экспорт данных
export_data() {
    print_info "Экспорт данных из контейнера..."
    
    local export_dir="./exported_data_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    
    # Экспорт базы данных
    docker cp "$CONTAINER_NAME:/app/data/intercepts.db" "$export_dir/" 2>/dev/null || true
    
    # Экспорт отчетов
    docker cp "$CONTAINER_NAME:/app/reports/" "$export_dir/" 2>/dev/null || true
    
    # Экспорт логов
    docker cp "$CONTAINER_NAME:/app/logs/" "$export_dir/" 2>/dev/null || true
    
    print_success "Данные экспортированы в: $export_dir"
}

# Обновление образов
update() {
    print_info "Обновление Docker образов..."
    
    $COMPOSE_CMD pull 2>/dev/null || true
    $COMPOSE_CMD build --no-cache
    $COMPOSE_CMD up -d
    
    print_success "Образы обновлены и сервисы перезапущены"
}

# Основная функция
main() {
    print_header
    print_info "Платформа: $PLATFORM_NAME"
    print_info "Используется: $COMPOSE_FILE"
    echo
    
    check_docker
    
    case "${ARGS[0]:-help}" in
        "start"|"up")
            check_config
            create_directories
            start_basic
            ;;
            
        "start-full")
            check_config
            create_directories
            start_full
            ;;
            
        "start-monitoring")
            check_config
            create_directories
            start_monitoring
            ;;
            
        "stop"|"down")
            stop_services
            ;;
            
        "restart")
            stop_services
            sleep 2
            check_config
            create_directories
            start_basic
            ;;
            
        "build")
            check_config
            create_directories
            build_images
            ;;
            
        "status"|"ps")
            show_status
            ;;
            
        "logs")
            show_logs "${ARGS[1]}"
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
            
        "shell")
            shell "${ARGS[1]}"
            ;;
            
        "export")
            export_data
            ;;
            
        "update")
            update
            ;;
            
        "cleanup")
            cleanup
            ;;
            
        "help"|*)
            echo "🐳 Web Server Interceptor - Docker Management"
            echo
            echo "Платформа: $PLATFORM_NAME (автоопределена)"
            echo "Используется: $COMPOSE_FILE"
            echo
            echo "Основные команды:"
            echo "  start, up          - Запуск основных сервисов"
            echo "  start-full         - Запуск всех сервисов"
            echo "  start-monitoring   - Запуск с мониторингом"
            echo "  stop, down         - Остановка сервисов"
            echo "  restart            - Перезапуск сервисов"
            echo "  build              - Сборка образов"
            echo
            echo "Мониторинг:"
            echo "  status, ps         - Статус контейнеров"
            echo "  logs [service]     - Просмотр логов"
            echo "  urls               - Показать URL адреса"
            echo
            echo "Tor управление:"
            echo "  onion              - Получить .onion адрес"
            echo "  newip              - Сменить Tor идентичность"
            echo
            echo "Утилиты:"
            echo "  shell [service]    - Интерактивная оболочка"
            echo "  export             - Экспорт данных"
            echo "  update             - Обновление образов"
            echo "  cleanup            - Полная очистка"
            echo
            echo "Примеры:"
            echo "  ./docker-run.sh start"
            echo "  ./docker-run.sh --platform kali start"
            echo "  ./docker-run.sh --platform raspberry start"
            echo "  ./docker-run.sh logs interceptor"
            echo "  ./docker-run.sh shell"
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 0' INT TERM

# Запуск основной функции
main "$@"
