#!/bin/bash

# Скрипт проверки всех файлов Docker конфигурации

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Проверка файлов Docker конфигурации"
echo "========================================"
echo ""

check_file() {
    local file=$1
    local required=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $file"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}❌${NC} $file (КРИТИЧНО)"
            return 1
        else
            echo -e "${YELLOW}⚠️${NC} $file (опционально)"
            return 0
        fi
    fi
}

check_dir() {
    local dir=$1
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $dir/ ($(ls -1 $dir 2>/dev/null | wc -l | xargs) файлов)"
        return 0
    else
        echo -e "${YELLOW}⚠️${NC} $dir/ (будет создана)"
        mkdir -p "$dir" 2>/dev/null || true
        return 0
    fi
}

echo "📁 Основные файлы:"
check_file "Dockerfile" "required"
check_file ".dockerignore" "required"
check_file "docker-compose.yml" "optional"
check_file "docker-compose.optimized.yml" "required"
check_file "docker-build-and-run.sh" "required"

echo ""
echo "📁 Директория docker/:"
check_file "docker/entrypoint.sh" "required"
check_file "docker/torrc" "required"
check_file "docker/nginx.conf" "optional"

echo ""
echo "📁 Приложение:"
check_file "app.py" "required"
check_file "tor_setup.py" "required"
check_file "requirements.txt" "required"

echo ""
echo "📁 Директории с данными:"
check_dir "data"
check_dir "reports"
check_dir "logs"
check_dir "templates"
check_dir "locales"

echo ""
echo "📁 Документация:"
check_file "README.md" "required"
check_file "DOCKER_OPTIMIZED_GUIDE.md" "optional"
check_file "CHANGELOG_DOCKER.md" "optional"
check_file "QUICK_DOCKER_START.md" "optional"

echo ""
echo "========================================"

# Проверка прав доступа
echo ""
echo "🔐 Проверка прав доступа:"

if [ -f "docker-build-and-run.sh" ]; then
    if [ -x "docker-build-and-run.sh" ]; then
        echo -e "${GREEN}✅${NC} docker-build-and-run.sh исполняемый"
    else
        echo -e "${YELLOW}⚠️${NC} docker-build-and-run.sh не исполняемый (исправляем...)"
        chmod +x docker-build-and-run.sh
        echo -e "${GREEN}✅${NC} Права исправлены"
    fi
fi

if [ -f "docker/entrypoint.sh" ]; then
    if [ -x "docker/entrypoint.sh" ]; then
        echo -e "${GREEN}✅${NC} docker/entrypoint.sh исполняемый"
    else
        echo -e "${YELLOW}⚠️${NC} docker/entrypoint.sh не исполняемый (исправляем...)"
        chmod +x docker/entrypoint.sh
        echo -e "${GREEN}✅${NC} Права исправлены"
    fi
fi

echo ""
echo "🐳 Проверка Docker:"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅${NC} Docker установлен: $(docker --version)"
    
    if docker ps &> /dev/null; then
        echo -e "${GREEN}✅${NC} Docker daemon запущен"
    else
        echo -e "${RED}❌${NC} Docker daemon не запущен"
        echo "   Запустите Docker Desktop или OrbStack"
    fi
else
    echo -e "${RED}❌${NC} Docker не установлен"
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✅${NC} Docker Compose установлен: $(docker compose version)"
    else
        echo -e "${GREEN}✅${NC} Docker Compose установлен: $(docker-compose --version)"
    fi
else
    echo -e "${RED}❌${NC} Docker Compose не установлен"
fi

echo ""
echo "========================================"
echo "✨ Проверка завершена!"
echo ""
echo "📚 Следующие шаги:"
echo "   1. Запустите Docker daemon (если не запущен)"
echo "   2. Выполните: ./docker-build-and-run.sh"
echo "   3. Откройте: http://localhost:5000"
echo ""
echo "📖 Документация:"
echo "   - QUICK_DOCKER_START.md - Быстрый старт"
echo "   - DOCKER_OPTIMIZED_GUIDE.md - Полное руководство"
echo ""
