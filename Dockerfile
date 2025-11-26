# Web Server Interceptor - Docker Container
# Базовый образ с Python и необходимыми утилитами
FROM python:3.11-slim-bullseye

# Метаданные
LABEL maintainer="cybersecurity-student"
LABEL description="Web Server Interceptor for educational cybersecurity purposes"
LABEL version="1.0"

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    tor \
    curl \
    netcat \
    sqlite3 \
    procps \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя для безопасности (не root)
RUN useradd -m -u 1000 interceptor && \
    usermod -aG debian-tor interceptor

# Установка рабочей директории
WORKDIR /app

# Копирование файлов зависимостей
COPY requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY app.py .
COPY tor_setup.py .
COPY templates/ templates/
COPY *.md .

# Создание необходимых директорий
RUN mkdir -p /app/reports /app/logs /app/data && \
    chown -R interceptor:interceptor /app

# Создание директорий для Tor
RUN mkdir -p /var/lib/tor-interceptor /var/log/tor-interceptor && \
    chown -R interceptor:debian-tor /var/lib/tor-interceptor && \
    chown -R interceptor:debian-tor /var/log/tor-interceptor && \
    chmod 750 /var/lib/tor-interceptor /var/log/tor-interceptor

# Копирование конфигурации Tor
COPY docker/torrc /etc/tor/torrc-interceptor

# Переключение на непривилегированного пользователя
USER interceptor

# Создание entrypoint скрипта
COPY docker/entrypoint.sh /app/entrypoint.sh
USER root
RUN chmod +x /app/entrypoint.sh
USER interceptor

# Открытие портов
EXPOSE 5000 9050 9051

# Переменные окружения
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONPATH=/app
ENV TOR_DATA_DIR=/var/lib/tor-interceptor

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

# Volumes для персистентности данных
VOLUME ["/app/data", "/app/reports", "/app/logs", "/var/lib/tor-interceptor"]

# Запуск приложения
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["start"]
