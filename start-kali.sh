#!/bin/bash

# Быстрый запуск для Kali Linux
# Wrapper скрипт для docker-run.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

exec ./docker-run.sh --platform kali "$@"

