# 🚀 Быстрый старт Docker (5 минут)

## Перед запуском

**1. Запустите Docker daemon:**
   - **macOS:** Запустите Docker Desktop или OrbStack
   - **Linux:** `sudo systemctl start docker`
   - **Windows:** Запустите Docker Desktop

**2. Проверьте Docker:**
```bash
docker --version
docker-compose --version
```

## Запуск (3 простых шага)

### Шаг 1: Автоматическая сборка и запуск
```bash
cd /Users/phenix/Projects/web-server-intercepter
./docker-build-and-run.sh
```

### Шаг 2: Дождитесь завершения
Скрипт автоматически:
- ✅ Проверит зависимости
- ✅ Создаст необходимые директории
- ✅ Соберет оптимизированный Docker образ (~2-3 минуты)
- ✅ Запустит контейнер
- ✅ Проверит работоспособность
- ✅ Выведет информацию о доступе

### Шаг 3: Откройте в браузере
```
http://localhost:5000
```

## Альтернативный запуск (ручной)

Если автоматический скрипт не работает:

```bash
# 1. Создание директорий
mkdir -p data reports logs

# 2. Сборка образа
docker build -t web-interceptor:latest .

# 3. Запуск контейнера
docker-compose -f docker-compose.optimized.yml up -d

# 4. Проверка логов
docker logs -f web-interceptor
```

## Проверка работы

### Быстрая проверка
```bash
# Проверка Flask
curl http://localhost:5000/

# Проверка контейнера
docker ps | grep web-interceptor

# Просмотр логов
docker logs web-interceptor --tail 20
```

### Получение .onion адреса
```bash
# Подождите 1-2 минуты после запуска, затем:
docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname
```

## Доступные интерфейсы

После запуска доступны:

- **Главная страница:** http://localhost:5000
- **Админ панель:** http://localhost:5000/admin/reports
- **Маскировочный сайт:** http://localhost:5000/mask
- **Страница перехвата:** http://localhost:5000/intercept

## Управление

```bash
# Остановка
docker stop web-interceptor

# Запуск снова
docker start web-interceptor

# Перезапуск
docker restart web-interceptor

# Просмотр логов
docker logs -f web-interceptor

# Полная остановка и удаление
docker-compose -f docker-compose.optimized.yml down
```

## Проблемы?

### Docker daemon не запущен
```
ERROR: Cannot connect to the Docker daemon
```
**Решение:** Запустите Docker Desktop или OrbStack

### Порт 5000 занят
```
Error starting userland proxy: listen tcp4 0.0.0.0:5000: bind: address already in use
```
**Решение:** Остановите процесс на порту 5000 или измените порт в docker-compose

### Tor не запускается
Просмотрите логи:
```bash
docker logs web-interceptor | grep -A 10 "ERROR"
docker exec web-interceptor cat /app/logs/tor.log
```

## Полная документация

- **DOCKER_OPTIMIZED_GUIDE.md** - Детальное руководство
- **CHANGELOG_DOCKER.md** - Список изменений
- **README.md** - Основная документация

---

**Готово! 🎉**

Теперь ваш Web Server Interceptor работает в Docker контейнере с оптимальными настройками безопасности.
