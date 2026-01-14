#!/bin/bash

# Docker Management Script для Web Server Interceptor - Kali Linux
# Wrapper для основного скрипта из корня проекта
# Для обратной совместимости

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Вызов корневого docker-run.sh с указанием платформы
# Примечание: корневой docker-run.sh не вызывает платформенные скрипты обратно,
# поэтому рекурсии здесь нет. Это просто обертка для удобства.
exec ./docker-run.sh --platform kali "$@"
