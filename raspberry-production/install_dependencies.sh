#!/bin/bash

# Быстрая установка зависимостей для Raspberry Pi
# Решение проблемы с отсутствующим stem

set -e

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🍓 Установка зависимостей для Web Server Interceptor${NC}"
echo

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Проверка наличия requirements.txt
if [ ! -f "requirements.txt" ]; then
    echo -e "${RED}❌ Файл requirements.txt не найден${NC}"
    exit 1
fi

# Обновление pip (пропускаем, если не получается из-за системного пакета)
echo -e "${BLUE}ℹ️  Проверка pip...${NC}"
if python3 -m pip --version &>/dev/null; then
    echo -e "${GREEN}✅ pip доступен${NC}"
else
    echo -e "${RED}❌ pip не найден${NC}"
    exit 1
fi

# Установка системных зависимостей
echo -e "${BLUE}ℹ️  Установка системных зависимостей...${NC}"
sudo apt-get update
sudo apt-get install -y \
    python3-pip \
    python3-dev \
    tor \
    build-essential \
    libssl-dev \
    libffi-dev

# Установка Python зависимостей
echo -e "${BLUE}ℹ️  Установка Python пакетов из requirements.txt...${NC}"

# Попытка установки без флагов
if python3 -m pip install -r requirements.txt 2>/dev/null; then
    echo -e "${GREEN}✅ Зависимости установлены успешно${NC}"
# Если не получилось, используем --break-system-packages и --ignore-installed
elif python3 -m pip install --break-system-packages --ignore-installed -r requirements.txt; then
    echo -e "${GREEN}✅ Зависимости установлены с флагом --break-system-packages${NC}"
else
    # Последняя попытка с force-reinstall
    echo -e "${BLUE}ℹ️  Попытка принудительной переустановки...${NC}"
    if python3 -m pip install --break-system-packages --upgrade --force-reinstall --no-deps -r requirements.txt; then
        echo -e "${GREEN}✅ Зависимости установлены с принудительной переустановкой${NC}"
    else
        echo -e "${RED}❌ Не удалось установить зависимости${NC}"
        exit 1
    fi
fi

echo
echo -e "${GREEN}✅ Все зависимости установлены!${NC}"
echo
echo -e "${BLUE}Теперь запустите:${NC}"
echo "  cd $PROJECT_ROOT/raspberry-production"
echo "  ./raspberry-run.sh start"
echo

