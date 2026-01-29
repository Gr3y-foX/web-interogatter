# =============================================================================
# Web Server Interceptor - Production Docker Image
# Оптимизирован для безопасности и кросс-платформенности
# =============================================================================

# Stage 1: Builder - установка зависимостей
FROM python:3.11-slim-bullseye AS builder

# Установка системных зависимостей для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Создание виртуального окружения
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копирование и установка Python зависимостей
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# =============================================================================
# Stage 2: Runtime - финальный образ
FROM python:3.11-slim-bullseye

# Метаданные образа
LABEL maintainer="cybersecurity-student" \
      description="Web Server Interceptor for educational cybersecurity purposes" \
      version="2.0" \
      security.level="hardened"

# Аргументы сборки
ARG APP_USER=interceptor
ARG APP_UID=1000
ARG APP_GID=1000

# Установка runtime зависимостей (минимальный набор)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tor \
    curl \
    netcat-traditional \
    sqlite3 \
    procps \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Создание пользователя и групп с явным UID/GID для совместимости
RUN groupadd -g ${APP_GID} ${APP_USER} 2>/dev/null || groupmod -n ${APP_USER} $(getent group ${APP_GID} | cut -d: -f1) && \
    useradd -m -u ${APP_UID} -g ${APP_GID} -s /bin/bash ${APP_USER} && \
    usermod -aG debian-tor ${APP_USER}

# Создание структуры директорий с правильными правами
RUN mkdir -p \
    /app/templates \
    /app/locales \
    /app/data \
    /app/reports \
    /app/logs \
    /var/lib/tor-interceptor/hidden_service \
    /var/log/tor-interceptor && \
    chown -R ${APP_USER}:${APP_USER} /app && \
    chown -R ${APP_USER}:debian-tor /var/lib/tor-interceptor && \
    chown -R ${APP_USER}:debian-tor /var/log/tor-interceptor && \
    chmod 750 /var/lib/tor-interceptor /var/log/tor-interceptor && \
    chmod 700 /var/lib/tor-interceptor/hidden_service

# Копирование виртуального окружения из builder stage
COPY --from=builder --chown=${APP_USER}:${APP_USER} /opt/venv /opt/venv

# Установка рабочей директории
WORKDIR /app

# Копирование приложения с правильными правами (важно: сначала все файлы, потом chown)
COPY --chown=${APP_USER}:${APP_USER} app.py tor_setup.py ./
COPY --chown=${APP_USER}:${APP_USER} templates/ templates/
COPY --chown=${APP_USER}:${APP_USER} locales/ locales/
COPY --chown=${APP_USER}:${APP_USER} README.md ./

# Копирование и настройка Tor конфигурации
COPY --chown=root:root docker/torrc /etc/tor/torrc-interceptor
RUN chmod 644 /etc/tor/torrc-interceptor

# Копирование и настройка entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown root:root /usr/local/bin/entrypoint.sh

# Переключение на непривилегированного пользователя
USER ${APP_USER}

# Переменные окружения
ENV PATH="/opt/venv/bin:$PATH" \
    FLASK_APP=app.py \
    FLASK_ENV=production \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    TOR_DATA_DIR=/var/lib/tor-interceptor \
    APP_USER=${APP_USER}

# Открытие портов
EXPOSE 5000 9050 9051

# Health check (увеличен start-period для Tor)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

# Volumes для персистентности данных
VOLUME ["/app/data", "/app/reports", "/app/logs", "/var/lib/tor-interceptor"]

# Запуск приложения
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
