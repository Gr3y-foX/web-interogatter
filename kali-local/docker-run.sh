#!/bin/bash

# Docker Management Script для Web Server Interceptor
# Упрощенное управление Docker Compose окружением

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
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    print_success "Docker и Docker Compose доступны"
}

# Проверка файлов конфигурации
check_config() {
    print_info "Проверка конфигурационных файлов..."
    
    local missing_files=()
    
    [ ! -f "Dockerfile" ] && missing_files+=("Dockerfile")
    [ ! -f "docker-compose.yml" ] && missing_files+=("docker-compose.yml")
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
    
    mkdir -p docker/grafana/{dashboards,datasources}
    mkdir -p data reports logs
    
    # Создание базовой конфигурации Grafana
    if [ ! -f "docker/grafana/datasources/datasource.yml" ]; then
        cat > docker/grafana/datasources/datasource.yml << EOF
apiVersion: 1
datasources:
  - name: SQLite
    type: frser-sqlite-datasource
    access: proxy
    url: /data/intercepts.db
    isDefault: true
EOF
    fi
    
    print_success "Директории созданы"
}

# Сборка образов
build_images() {
    print_info "Сборка Docker образов..."
    
    $COMPOSE_CMD build --no-cache
    
    print_success "Образы собраны"
}

# Запуск основных сервисов
start_basic() {
    print_info "Запуск основных сервисов..."
    
    $COMPOSE_CMD up -d interceptor tor-relay
    
    print_success "Основные сервисы запущены"
    show_urls
}

# Запуск всех сервисов
start_full() {
    print_info "Запуск всех сервисов..."
    
    $COMPOSE_CMD up -d
    
    print_success "Все сервисы запущены"
    show_urls
}

# Запуск с мониторингом
start_monitoring() {
    print_info "Запуск с системой мониторинга..."
    
    $COMPOSE_CMD --profile monitoring up -d
    
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
    print_info "Статус сервисов:"
    $COMPOSE_CMD ps
    
    echo
    print_info "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Показ URL адресов
show_urls() {
    echo
    print_success "🌐 Доступные сервисы:"
    echo "  📡 Основной сайт:     http://localhost:5000"
    echo "  🔧 Админ панель:      http://localhost:5000/admin/reports"
    echo "  📊 API отчетов:       http://localhost:5000/admin/api/reports"
    echo "  🗄️  SQLite Web:       http://localhost:8080"
    echo "  🌐 Nginx прокси:      http://localhost:80"
    echo "  🔒 HTTPS:             https://localhost:443"
    echo
    print_info "🧅 Tor SOCKS прокси: 127.0.0.1:9050"
    print_info "🎛️  Tor Control:      127.0.0.1:9051"
    
    # Попытка получить .onion адрес
    if docker exec web-interceptor test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
        ONION_ADDR=$(docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
        print_success "🧅 Hidden Service: http://$ONION_ADDR"
    else
        print_warning "🧅 Hidden Service еще не готов (подождите ~60 секунд)"
    fi
}

# Получение .onion адреса
get_onion() {
    print_info "Получение .onion адреса..."
    
    for i in {1..30}; do
        if docker exec web-interceptor test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
            ONION_ADDR=$(docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
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
    
    if docker exec web-interceptor python3 tor_setup.py newip 2>/dev/null; then
        print_success "Tor идентичность изменена"
    else
        print_error "Не удалось изменить Tor идентичность"
    fi
}

# Интерактивная оболочка
shell() {
    local service=${1:-"interceptor"}
    print_info "Запуск интерактивной оболочки в контейнере: $service"
    docker exec -it "web-$service" /bin/bash
}

# Экспорт данных
export_data() {
    print_info "Экспорт данных из контейнера..."
    
    local export_dir="./exported_data_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"
    
    # Экспорт базы данных
    docker cp web-interceptor:/app/data/intercepts.db "$export_dir/"
    
    # Экспорт отчетов
    docker cp web-interceptor:/app/reports/ "$export_dir/"
    
    # Экспорт логов
    docker cp web-interceptor:/app/logs/ "$export_dir/"
    
    print_success "Данные экспортированы в: $export_dir"
}

# Обновление образов
update() {
    print_info "Обновление Docker образов..."
    
    $COMPOSE_CMD pull
    $COMPOSE_CMD build --no-cache
    $COMPOSE_CMD up -d
    
    print_success "Образы обновлены и сервисы перезапущены"
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
            
        "start-monitoring")
            check_docker
            check_config
            create_directories
            start_monitoring
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
            build_images
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
            get_onion
            ;;
            
        "newip")
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
            
        "update")
            check_docker
            update
            ;;
            
        "cleanup")
            check_docker
            cleanup
            ;;
            
        "help"|*)
            echo "🐳 Web Server Interceptor - Docker Management"
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
            echo "  ./docker-run.sh logs interceptor"
            echo "  ./docker-run.sh shell"
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 0' INT TERM

# Запуск основной функции
main "$@"
