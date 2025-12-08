#!/bin/bash

# Скрипт сборки и запуска единого Docker контейнера для Kali Linux
# Собирает все в один образ и запускает сервер

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "🐧 =============================================="
    echo "   Web Server Interceptor - Kali Linux"
    echo "   Сборка и запуск единого Docker контейнера"
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

# Проверка Docker/Podman
check_docker() {
    # Проверка наличия Podman
    if command -v podman &> /dev/null && docker info 2>&1 | grep -q "podman"; then
        print_info "Обнаружен Podman (Docker-совместимый)"
        USE_PODMAN=true
        
        # Проверка работы Podman
        if ! docker info &> /dev/null; then
            print_error "Podman не запущен или нет прав доступа"
            print_info "Попробуйте запустить Podman socket:"
            print_info "  systemctl --user start podman.socket"
            print_info "  или"
            print_info "  podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &"
            print_info ""
            print_info "Альтернативно, установите Docker:"
            print_info "  sudo apt update && sudo apt install -y docker.io docker-compose"
            print_info "  sudo systemctl start docker"
            print_info "  sudo usermod -aG docker $USER"
            exit 1
        fi
        
        print_success "Podman доступен"
        return 0
    fi
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        print_info "Установите Docker:"
        print_info "  sudo apt update && sudo apt install -y docker.io docker-compose"
        print_info "  sudo systemctl start docker"
        print_info "  sudo usermod -aG docker $USER"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker не запущен или нет прав доступа"
        print_info "Запустите: sudo systemctl start docker"
        print_info "Или добавьте пользователя в группу docker: sudo usermod -aG docker $USER"
        print_info ""
        print_info "Если используете Podman, запустите:"
        print_info "  systemctl --user start podman.socket"
        exit 1
    fi
    
    print_success "Docker доступен"
}

# Проверка Docker Compose
check_compose() {
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose доступен"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        print_success "Docker Compose доступен"
    else
        print_error "Docker Compose не установлен"
        print_info "Установите Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# Проверка файлов
check_files() {
    print_info "Проверка необходимых файлов..."
    
    local missing_files=()
    
    [ ! -f "Dockerfile.kali" ] && missing_files+=("Dockerfile.kali")
    [ ! -f "docker-compose.kali.yml" ] && missing_files+=("docker-compose.kali.yml")
    [ ! -f "requirements.txt" ] && missing_files+=("requirements.txt")
    [ ! -f "app.py" ] && missing_files+=("app.py")
    [ ! -f "docker/entrypoint.sh" ] && missing_files+=("docker/entrypoint.sh")
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые файлы:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    print_success "Все файлы найдены"
}

# Сборка образа
build_image() {
    print_info "Сборка Docker образа..."
    
    if [ "$1" == "--no-cache" ]; then
        print_info "Сборка без кэша..."
        $COMPOSE_CMD -f docker-compose.kali.yml build --no-cache
    else
        $COMPOSE_CMD -f docker-compose.kali.yml build
    fi
    
    print_success "Образ собран"
}

# Запуск контейнера
start_container() {
    print_info "Запуск контейнера..."
    
    $COMPOSE_CMD -f docker-compose.kali.yml up -d
    
    print_success "Контейнер запущен"
    
    # Ожидание запуска
    print_info "Ожидание запуска сервисов..."
    sleep 10
    
    # Проверка статуса
    if docker ps | grep -q "web-interceptor-kali"; then
        print_success "Контейнер работает"
    else
        print_error "Контейнер не запущен"
        print_info "Проверьте логи: docker logs web-interceptor-kali"
        exit 1
    fi
}

# Остановка контейнера
stop_container() {
    print_info "Остановка контейнера..."
    
    $COMPOSE_CMD -f docker-compose.kali.yml down
    
    print_success "Контейнер остановлен"
}

# Показ статуса
show_status() {
    print_info "Статус контейнера:"
    $COMPOSE_CMD -f docker-compose.kali.yml ps
    
    echo
    print_info "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" web-interceptor-kali 2>/dev/null || \
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" web-interceptor-kali
}

# Показ логов
show_logs() {
    print_info "Логи контейнера:"
    $COMPOSE_CMD -f docker-compose.kali.yml logs -f --tail=50
}

# Показ URL
show_urls() {
    echo
    print_success "🌐 Доступные сервисы:"
    echo "  📡 Основной сайт:     http://localhost:5000"
    echo "  🔧 Админ панель:      http://localhost:5000/admin/reports"
    echo "  📊 API отчетов:       http://localhost:5000/admin/api/reports"
    echo
    print_info "🧅 Tor SOCKS прокси: 127.0.0.1:9050"
    print_info "🎛️  Tor Control:      127.0.0.1:9051"
    
    # Попытка получить .onion адрес
    if docker exec web-interceptor-kali test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
        ONION_ADDR=$(docker exec web-interceptor-kali cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
        print_success "🧅 Hidden Service: http://$ONION_ADDR"
    else
        print_warning "🧅 Hidden Service еще не готов (подождите ~60 секунд)"
    fi
    echo
}

# Получение .onion адреса
get_onion() {
    print_info "Получение .onion адреса..."
    
    for i in {1..30}; do
        if docker exec web-interceptor-kali test -f /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null; then
            ONION_ADDR=$(docker exec web-interceptor-kali cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null)
            print_success "🧅 Hidden Service: http://$ONION_ADDR"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    print_warning "Hidden Service адрес еще не готов"
}

# Интерактивная оболочка
shell() {
    print_info "Запуск интерактивной оболочки в контейнере"
    docker exec -it web-interceptor-kali /bin/bash
}

# Очистка
cleanup() {
    print_warning "Полная очистка Docker окружения..."
    read -p "Удалить все контейнеры, образы и данные? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $COMPOSE_CMD -f docker-compose.kali.yml down -v --rmi all --remove-orphans
        docker system prune -a -f
        print_success "Очистка завершена"
    else
        print_info "Очистка отменена"
    fi
}

# Основная функция
main() {
    print_header
    
    case "${1:-build-and-run}" in
        "build")
            check_docker
            check_compose
            check_files
            build_image "${2}"
            ;;
            
        "build-and-run"|"start")
            check_docker
            check_compose
            check_files
            build_image
            start_container
            sleep 5
            show_urls
            ;;
            
        "run"|"up")
            check_docker
            check_compose
            start_container
            sleep 5
            show_urls
            ;;
            
        "stop"|"down")
            check_docker
            check_compose
            stop_container
            ;;
            
        "restart")
            check_docker
            check_compose
            stop_container
            sleep 2
            start_container
            sleep 5
            show_urls
            ;;
            
        "status"|"ps")
            check_docker
            check_compose
            show_status
            ;;
            
        "logs")
            check_docker
            check_compose
            show_logs
            ;;
            
        "urls")
            show_urls
            ;;
            
        "onion")
            check_docker
            get_onion
            ;;
            
        "shell")
            check_docker
            shell
            ;;
            
        "cleanup")
            check_docker
            check_compose
            cleanup
            ;;
            
        "help"|*)
            echo "🐧 Web Server Interceptor - Kali Linux Docker Management"
            echo
            echo "Команды:"
            echo "  build              - Собрать Docker образ"
            echo "  build-and-run      - Собрать и запустить (по умолчанию)"
            echo "  start, run, up     - Запустить контейнер"
            echo "  stop, down         - Остановить контейнер"
            echo "  restart            - Перезапустить контейнер"
            echo "  status, ps         - Статус контейнера"
            echo "  logs               - Просмотр логов"
            echo "  urls               - Показать URL адреса"
            echo "  onion              - Получить .onion адрес"
            echo "  shell              - Интерактивная оболочка"
            echo "  cleanup            - Полная очистка"
            echo
            echo "Примеры:"
            echo "  ./docker-build-and-run.sh build-and-run"
            echo "  ./docker-build-and-run.sh build --no-cache"
            echo "  ./docker-build-and-run.sh logs"
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 0' INT TERM

# Запуск
main "$@"

