#!/bin/bash

# Web Server Interceptor - Единый скрипт запуска
# Автоматическое определение платформы (Kali Linux / Raspberry Pi)
# Для образовательных целей в области кибербезопасности

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Защита от рекурсии: проверяем, был ли скрипт вызван из платформенного скрипта
# Если переменная окружения установлена, значит мы уже в рекурсии - не вызываем платформенный скрипт снова
if [ -n "$WEB_INTERCEPTOR_NO_RECURSE" ]; then
    # Скрипт был вызван из платформенного скрипта - это рекурсия!
    # Используем платформу из переменной окружения и не вызываем платформенный скрипт
    PLATFORM_FROM_ENV="$WEB_INTERCEPTOR_PLATFORM"
    unset WEB_INTERCEPTOR_NO_RECURSE
    unset WEB_INTERCEPTOR_PLATFORM
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
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
    
    # Проверка аргументов командной строки
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform=*)
                platform="${1#*=}"
                shift
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Если платформа не указана, определяем автоматически
    if [ -z "$platform" ]; then
        # Проверка на Raspberry Pi
        if [ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
            platform="raspberry"
        elif [ -f /etc/os-release ] && grep -qi "raspbian\|raspberry" /etc/os-release 2>/dev/null; then
            platform="raspberry"
        # Проверка на Kali Linux
        elif [ -f /etc/os-release ] && grep -qi "kali" /etc/os-release 2>/dev/null; then
            platform="kali"
        elif [ -f /etc/debian_version ] && uname -m | grep -qi "arm\|aarch64"; then
            # ARM архитектура, но не Raspberry - предполагаем Kali на ARM
            platform="kali"
        else
            # По умолчанию Kali для x86_64
            platform="kali"
        fi
    fi
    
    echo "$platform"
}

# Получение платформы
# Если платформа была передана через переменную окружения (защита от рекурсии), используем её
if [ -n "$PLATFORM_FROM_ENV" ]; then
    PLATFORM="$PLATFORM_FROM_ENV"
else
    PLATFORM=$(detect_platform "$@")
fi

# Удаление аргументов --platform из списка аргументов
ARGS=()
for arg in "$@"; do
    if [[ ! "$arg" =~ ^--platform(=.*)?$ ]]; then
        ARGS+=("$arg")
    fi
done

# Определение пути к скрипту платформы
case "$PLATFORM" in
    "kali")
        PLATFORM_SCRIPT="kali-local/run.sh"
        PLATFORM_NAME="Kali Linux"
        ;;
    "raspberry"|"raspberry-pi"|"rpi")
        PLATFORM_SCRIPT="raspberry-production/raspberry-run.sh"
        PLATFORM_NAME="Raspberry Pi"
        # Для Raspberry Pi используем docker-run.sh, так как там нет обычного run.sh
        if [ ! -f "$PLATFORM_SCRIPT" ] || [ "${ARGS[0]}" = "start" ] || [ -z "${ARGS[0]}" ]; then
            print_warning "Raspberry Pi версия использует Docker. Используйте: ./docker-run.sh --platform raspberry start"
            print_info "Или: ./start-raspberry.sh"
            exit 1
        fi
        ;;
    *)
        print_error "Неизвестная платформа: $PLATFORM"
        print_info "Доступные платформы: kali, raspberry"
        exit 1
        ;;
esac

# Проверка существования скрипта
if [ ! -f "$PLATFORM_SCRIPT" ]; then
    print_error "Скрипт для платформы $PLATFORM_NAME не найден: $PLATFORM_SCRIPT"
    exit 1
fi

# Защита от рекурсии: если платформа была передана через переменную окружения,
# значит мы уже в рекурсии - не вызываем платформенный скрипт снова
if [ -n "$PLATFORM_FROM_ENV" ]; then
    print_error "Обнаружена рекурсия! Платформенный скрипт не должен вызывать корневой скрипт."
    print_info "Платформа: $PLATFORM_FROM_ENV"
    print_info "Выполните платформенный скрипт напрямую: $PLATFORM_SCRIPT"
    exit 1
fi

# Вывод информации
print_info "Платформа: $PLATFORM_NAME"
print_info "Используется скрипт: $PLATFORM_SCRIPT"

# Запуск скрипта платформы
# Устанавливаем флаг, чтобы платформенный скрипт знал, что он был вызван из корневого
export WEB_INTERCEPTOR_NO_RECURSE=1
export WEB_INTERCEPTOR_PLATFORM="$PLATFORM"
exec bash "$PLATFORM_SCRIPT" "${ARGS[@]}"
