#!/bin/bash

# =============================================================================
# Docker Build and Run Script для Web Server Interceptor
# Автоматизированная сборка и запуск с проверками
# =============================================================================

set -e

# Цвета для вывода
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

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        exit 1
    fi
    
    # Проверка Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose не установлен"
        exit 1
    fi
    
    # Определение команды docker-compose
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    log_success "Все зависимости установлены"
}

# Создание необходимых директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p data reports logs
    
    # Установка правильных прав
    chmod 755 data reports logs
    
    log_success "Директории созданы"
}

# Очистка старых образов и контейнеров
cleanup_old() {
    log_info "Очистка старых контейнеров и образов..."
    
    # Остановка и удаление старых контейнеров
    docker stop web-interceptor 2>/dev/null || true
    docker rm web-interceptor 2>/dev/null || true
    
    # Удаление старых образов (опционально)
    # docker rmi web-interceptor:latest 2>/dev/null || true
    
    log_success "Очистка завершена"
}

# Сборка образа
build_image() {
    log_info "Сборка Docker образа..."
    
    local BUILD_ARGS=""
    
    # Определение платформы
    case "$(uname -m)" in
        x86_64|amd64)
            BUILD_ARGS="--platform linux/amd64"
            log_info "Платформа: linux/amd64"
            ;;
        arm64|aarch64)
            BUILD_ARGS="--platform linux/arm64"
            log_info "Платформа: linux/arm64"
            ;;
        armv7l)
            BUILD_ARGS="--platform linux/arm/v7"
            log_info "Платформа: linux/arm/v7"
            ;;
        *)
            log_warning "Неизвестная платформа: $(uname -m), используем auto-detect"
            BUILD_ARGS=""
            ;;
    esac
    
    # Сборка образа
    docker build $BUILD_ARGS \
        --tag web-interceptor:latest \
        --tag web-interceptor:$(date +%Y%m%d-%H%M%S) \
        --build-arg APP_USER=interceptor \
        --build-arg APP_UID=$(id -u) \
        --build-arg APP_GID=$(id -g) \
        .
    
    log_success "Образ собран успешно"
}

# Запуск контейнера
start_container() {
    log_info "Запуск контейнера..."
    
    # Использование оптимизированного compose файла
    local COMPOSE_FILE="docker-compose.optimized.yml"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_warning "Файл $COMPOSE_FILE не найден, использую docker-compose.yml"
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # Запуск через docker-compose
    $DOCKER_COMPOSE -f $COMPOSE_FILE up -d
    
    log_success "Контейнер запущен"
}

# Проверка работы контейнера
check_health() {
    log_info "Проверка работоспособности контейнера..."
    
    # Ожидание запуска
    sleep 10
    
    # Проверка статуса контейнера
    if ! docker ps | grep -q web-interceptor; then
        log_error "Контейнер не запущен"
        log_info "Просмотр логов:"
        docker logs web-interceptor --tail 50
        exit 1
    fi
    
    # Проверка доступности Flask
    for i in {1..30}; do
        if curl -f http://localhost:5000/ >/dev/null 2>&1; then
            log_success "Flask приложение доступно"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Flask приложение недоступно после 30 попыток"
            log_info "Просмотр логов:"
            docker logs web-interceptor --tail 50
            exit 1
        fi
        sleep 2
    done
    
    log_success "Контейнер работает корректно"
}

# Получение .onion адреса
get_onion_address() {
    log_info "Получение .onion адреса..."
    
    # Ожидание создания hidden service
    for i in {1..60}; do
        ONION=$(docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname 2>/dev/null || echo "")
        if [ -n "$ONION" ]; then
            log_success "Tor Hidden Service: http://$ONION"
            return 0
        fi
        sleep 2
    done
    
    log_warning ".onion адрес пока не готов (это нормально, может занять несколько минут)"
}

# Вывод информации о доступе
show_access_info() {
    log_success "==================================="
    log_success "Web Server Interceptor запущен!"
    log_success "==================================="
    echo ""
    echo "📊 Доступные интерфейсы:"
    echo "   - Главная страница:     http://localhost:5000"
    echo "   - Админ панель:         http://localhost:5000/admin/reports"
    echo "   - Маскировочный сайт:   http://localhost:5000/mask"
    echo "   - Страница перехвата:   http://localhost:5000/intercept"
    echo ""
    echo "🔧 Управление:"
    echo "   - Просмотр логов:       docker logs -f web-interceptor"
    echo "   - Остановка:            docker stop web-interceptor"
    echo "   - Перезапуск:           docker restart web-interceptor"
    echo "   - Войти в контейнер:    docker exec -it web-interceptor /bin/bash"
    echo ""
    echo "📁 Данные:"
    echo "   - База данных:          ./data/intercepts.db"
    echo "   - Отчеты:               ./reports/"
    echo "   - Логи:                 ./logs/"
    echo ""
    get_onion_address
    echo ""
}

# Главная функция
main() {
    log_info "🚀 Запуск сборки и развертывания Web Server Interceptor"
    echo ""
    
    check_dependencies
    create_directories
    cleanup_old
    build_image
    start_container
    check_health
    show_access_info
    
    log_success "Готово! 🎉"
}

# Запуск
main "$@"
