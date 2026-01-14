#!/bin/bash

# Скрипт автоматического обновления проекта из Git
# Вызывается webhook сервером при получении push события от GitHub

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Логирование
LOG_FILE="$HOME/web-interogatter/logs/auto_update.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "ℹ️  $1"
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "✅ $1"
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    log "⚠️  $1"
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "❌ $1"
    echo -e "${RED}❌ $1${NC}"
}

# Переменные
PROJECT_DIR="$HOME/web-interogatter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RASPBERRY_RUN_SCRIPT="$PROJECT_DIR/raspberry-production/raspberry-run.sh"

# Проверка существования директории проекта
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "Директория проекта не найдена: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

# Проверка git репозитория
if [ ! -d ".git" ]; then
    log_error "Директория не является git репозиторием"
    exit 1
fi

log_info "Начало автоматического обновления..."

# Получение текущей ветки
CURRENT_BRANCH=$(git branch --show-current)
log_info "Текущая ветка: $CURRENT_BRANCH"

# Сохранение текущего коммита
OLD_COMMIT=$(git rev-parse HEAD)
log_info "Текущий коммит: ${OLD_COMMIT:0:7}"

# Получение обновлений
log_info "Получение обновлений из GitHub..."
git fetch origin "$CURRENT_BRANCH" || {
    log_error "Не удалось получить обновления из git"
    exit 1
}

# Проверка наличия новых коммитов
NEW_COMMIT=$(git rev-parse "origin/$CURRENT_BRANCH")
if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
    log_info "Новых обновлений нет"
    exit 0
fi

log_info "Найден новый коммит: ${NEW_COMMIT:0:7}"

# Сохранение локальных изменений (если есть)
if ! git diff --quiet || ! git diff --cached --quiet; then
    log_warning "Обнаружены локальные изменения, сохранение в stash..."
    git stash save "Auto-stash before update $(date +%Y%m%d_%H%M%S)" || {
        log_error "Не удалось сохранить локальные изменения"
        exit 1
    }
    log_success "Локальные изменения сохранены в stash"
fi

# Обновление кода
log_info "Применение обновлений..."
if git pull origin "$CURRENT_BRANCH"; then
    log_success "Код обновлен успешно"
else
    log_error "Не удалось применить обновления"
    exit 1
fi

# Показ изменений
log_info "Изменения:"
git log --oneline "$OLD_COMMIT..$NEW_COMMIT" | head -10 | while read line; do
    log_info "  $line"
done

# Проверка, запущен ли сервер
SERVER_RUNNING=false
if docker ps 2>/dev/null | grep -q "web-interceptor-raspberry"; then
    SERVER_RUNNING=true
    log_info "Сервер запущен, требуется перезапуск"
fi

# Перезапуск сервера (если запущен)
if [ "$SERVER_RUNNING" = true ]; then
    log_info "Перезапуск сервера..."
    
    if [ -f "$RASPBERRY_RUN_SCRIPT" ]; then
        cd "$PROJECT_DIR/raspberry-production"
        
        # Остановка
        log_info "Остановка сервера..."
        "$RASPBERRY_RUN_SCRIPT" stop || log_warning "Не удалось остановить сервер"
        
        sleep 2
        
        # Запуск
        log_info "Запуск сервера с обновленным кодом..."
        "$RASPBERRY_RUN_SCRIPT" start || {
            log_error "Не удалось запустить сервер"
            log_warning "Попробуйте запустить вручную: cd $PROJECT_DIR/raspberry-production && ./raspberry-run.sh start"
            exit 1
        }
        
        log_success "Сервер перезапущен успешно"
    else
        log_warning "Скрипт raspberry-run.sh не найден, перезапуск пропущен"
    fi
else
    log_info "Сервер не запущен, перезапуск не требуется"
fi

log_success "Автоматическое обновление завершено успешно!"
log_info "Старый коммит: ${OLD_COMMIT:0:7}"
log_info "Новый коммит: ${NEW_COMMIT:0:7}"

exit 0
