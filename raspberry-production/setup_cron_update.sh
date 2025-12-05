#!/bin/bash

# Скрипт настройки автоматического обновления через Cron
# Альтернатива webhook для случаев, когда webhook недоступен

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
    echo "⏰ =============================================="
    echo "   Настройка автоматического обновления"
    echo "   Через Cron (периодическая проверка)"
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

print_header

# Переменные
PROJECT_DIR="$HOME/web-interogatter"
UPDATE_SCRIPT="$PROJECT_DIR/raspberry-production/auto_update.sh"

# Проверка существования проекта
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Директория проекта не найдена: $PROJECT_DIR"
    print_info "Сначала запустите install_and_run.sh"
    exit 1
fi

# Проверка скрипта обновления
if [ ! -f "$UPDATE_SCRIPT" ]; then
    print_error "Скрипт обновления не найден: $UPDATE_SCRIPT"
    exit 1
fi

# Установка прав на выполнение
chmod +x "$UPDATE_SCRIPT"
print_success "Права на скрипт установлены"

# Запрос интервала проверки
echo
print_info "Настройка интервала проверки обновлений"
echo "Выберите интервал:"
echo "  1) Каждые 5 минут"
echo "  2) Каждые 10 минут"
echo "  3) Каждые 15 минут"
echo "  4) Каждый час"
echo "  5) Каждые 6 часов"
echo "  6) Каждые 12 часов"
echo "  7) Раз в день (в полночь)"
echo "  8) Вручную указать (cron формат)"
read -p "Ваш выбор (1-8): " INTERVAL_CHOICE

case $INTERVAL_CHOICE in
    1)
        CRON_SCHEDULE="*/5 * * * *"
        INTERVAL_DESC="каждые 5 минут"
        ;;
    2)
        CRON_SCHEDULE="*/10 * * * *"
        INTERVAL_DESC="каждые 10 минут"
        ;;
    3)
        CRON_SCHEDULE="*/15 * * * *"
        INTERVAL_DESC="каждые 15 минут"
        ;;
    4)
        CRON_SCHEDULE="0 * * * *"
        INTERVAL_DESC="каждый час"
        ;;
    5)
        CRON_SCHEDULE="0 */6 * * *"
        INTERVAL_DESC="каждые 6 часов"
        ;;
    6)
        CRON_SCHEDULE="0 */12 * * *"
        INTERVAL_DESC="каждые 12 часов"
        ;;
    7)
        CRON_SCHEDULE="0 0 * * *"
        INTERVAL_DESC="раз в день (в полночь)"
        ;;
    8)
        read -p "Введите cron расписание (например: '*/30 * * * *'): " CRON_SCHEDULE
        INTERVAL_DESC="по указанному расписанию"
        ;;
    *)
        print_error "Неверный выбор"
        exit 1
        ;;
esac

# Запрос ветки
read -p "Ветка для отслеживания (по умолчанию master): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-master}

# Создание скрипта для cron
CRON_SCRIPT="$PROJECT_DIR/raspberry-production/cron_update.sh"
cat > "$CRON_SCRIPT" << EOF
#!/bin/bash
# Автоматическое обновление через cron
# Создано: $(date)

cd "$PROJECT_DIR" || exit 1

# Проверка наличия новых коммитов
git fetch origin "$GIT_BRANCH" > /dev/null 2>&1 || exit 1

# Сравнение коммитов
LOCAL=\$(git rev-parse HEAD)
REMOTE=\$(git rev-parse "origin/$GIT_BRANCH")

if [ "\$LOCAL" != "\$REMOTE" ]; then
    # Есть обновления, запускаем скрипт обновления
    "$UPDATE_SCRIPT" >> "$PROJECT_DIR/logs/cron_update.log" 2>&1
fi
EOF

chmod +x "$CRON_SCRIPT"
print_success "Cron скрипт создан: $CRON_SCRIPT"

# Добавление в crontab
print_info "Добавление задачи в crontab..."

# Получение текущего crontab
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

# Проверка, не добавлена ли уже задача
if echo "$CURRENT_CRON" | grep -q "$CRON_SCRIPT"; then
    print_warning "Задача уже существует в crontab"
    read -p "Заменить существующую задачу? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Удаление старой задачи
        CURRENT_CRON=$(echo "$CURRENT_CRON" | grep -v "$CRON_SCRIPT")
    else
        print_info "Отменено"
        exit 0
    fi
fi

# Добавление новой задачи
NEW_CRON_LINE="$CRON_SCHEDULE $CRON_SCRIPT"
(crontab -l 2>/dev/null | grep -v "$CRON_SCRIPT"; echo "$NEW_CRON_LINE") | crontab -

print_success "Задача добавлена в crontab"

# Вывод информации
echo
print_success "Настройка завершена!"
echo
print_info "Информация о настройке:"
echo "  Интервал проверки: $INTERVAL_DESC"
echo "  Cron расписание: $CRON_SCHEDULE"
echo "  Ветка: $GIT_BRANCH"
echo "  Скрипт: $CRON_SCRIPT"
echo
print_info "Управление:"
echo "  crontab -l                    # Просмотр задач cron"
echo "  crontab -e                    # Редактирование задач cron"
echo "  tail -f $PROJECT_DIR/logs/cron_update.log  # Логи обновлений"
echo
print_warning "Примечание:"
echo "  - Обновления будут проверяться $INTERVAL_DESC"
echo "  - Если обновлений нет, скрипт не будет выполняться"
echo "  - Логи сохраняются в: $PROJECT_DIR/logs/cron_update.log"
echo
print_info "Для удаления задачи из cron:"
echo "  crontab -e"
echo "  (удалите строку с $CRON_SCRIPT)"
echo
