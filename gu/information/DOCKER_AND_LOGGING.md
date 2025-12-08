# 🐳 Docker и Расширенное Логирование

## 🚀 Быстрый старт с Docker

### Установка и запуск
```bash
# 1. Убедитесь, что Docker установлен
docker --version
docker-compose --version

# 2. Запуск всех сервисов
./docker-run.sh start

# 3. Проверка статуса
./docker-run.sh status

# 4. Получение .onion адреса
./docker-run.sh onion
```

### Доступ к сервисам
После запуска доступны:
- **HTTP**: http://localhost:5000
- **Tor Hidden Service**: http://[onion-address].onion (отображается при запуске)
- **Админ панель**: http://localhost:5000/admin/reports
- **SQLite Web**: http://localhost:8080
- **Nginx прокси**: http://localhost:80

## 📊 Расширенное логирование

### Структура логов

```
logs/
├── interceptor.log    # Основной лог (ротация 10MB, 5 файлов)
├── intercepts.log     # Лог перехватов (ротация 50MB, 10 файлов)
├── errors.log         # Лог ошибок (ротация 10MB, 5 файлов)
└── daily.log          # Ежедневные логи (ротация по времени, 30 дней)
```

### Просмотр логов

#### Через утилиту
```bash
# Последние перехваты
python3 view_logs.py intercepts 50

# Статистика
python3 view_logs.py stats

# Логи из базы данных
python3 view_logs.py logs ERROR 20

# Логи из файлов
python3 view_logs.py file errors 100

# .onion адрес
python3 view_logs.py onion
```

#### Напрямую из файлов
```bash
# Основной лог
tail -f logs/interceptor.log

# Лог перехватов
tail -f logs/intercepts.log

# Лог ошибок
tail -f logs/errors.log

# Ежедневный лог
tail -f logs/daily.log
```

#### Из базы данных
```bash
# Все логи
sqlite3 data/intercepts.db "SELECT * FROM logs ORDER BY timestamp DESC LIMIT 20;"

# Только ошибки
sqlite3 data/intercepts.db "SELECT * FROM logs WHERE level='ERROR' ORDER BY timestamp DESC;"

# Логи за сегодня
sqlite3 data/intercepts.db "SELECT * FROM logs WHERE DATE(timestamp) = DATE('now');"
```

## 🧅 Работа с .onion адресом

### Автоматическое получение
.onion адрес автоматически:
1. Генерируется при запуске Tor
2. Сохраняется в `data/onion_address.txt`
3. Отображается при запуске сервера
4. Доступен через API: `/admin/api/reports`

### Ручное получение
```bash
# Через tor_setup.py
python3 tor_setup.py hidden

# Через docker
./docker-run.sh onion

# Через утилиту логов
python3 view_logs.py onion

# Напрямую из файла
cat data/onion_address.txt
```

### Использование .onion адреса
```bash
# Доступ через Tor Browser
# Просто откройте: http://[onion-address].onion

# Через curl (требует Tor)
curl --socks5 127.0.0.1:9050 http://[onion-address].onion

# Проверка доступности
curl --socks5 127.0.0.1:9050 http://[onion-address].onion/admin/api/reports
```

## 📈 Расширенная информация о клиентах

### Собираемые данные

#### Базовая информация
- IP адрес
- User-Agent
- Браузер и версия
- Операционная система
- Тип устройства

#### Расширенная информация
- **Fingerprint** - Уникальный отпечаток браузера
- **Session ID** - Идентификатор сессии
- **Cookies** - Все cookies клиента
- **Screen Resolution** - Разрешение экрана (если доступно)
- **Timezone** - Часовой пояс (если доступно)
- **Connection Type** - Тип подключения (Direct/Proxied/Via-Proxy)
- **Query String** - Параметры запроса
- **Content-Type/Length** - Метаданные запроса
- **Host/Origin** - Заголовки хоста

### Просмотр расширенных данных

```bash
# Из базы данных
sqlite3 data/intercepts.db "SELECT fingerprint, session_id, cookies FROM intercepts LIMIT 10;"

# Через API
curl http://localhost:5000/admin/api/reports | jq '.reports[0]'

# Через утилиту
python3 view_logs.py intercepts 10
```

## 🔍 Анализ данных

### Статистика по fingerprint
```sql
SELECT fingerprint, COUNT(*) as count 
FROM intercepts 
GROUP BY fingerprint 
ORDER BY count DESC 
LIMIT 10;
```

### Поиск повторных посещений
```sql
SELECT ip_address, fingerprint, COUNT(*) as visits
FROM intercepts
GROUP BY ip_address, fingerprint
HAVING visits > 1
ORDER BY visits DESC;
```

### Анализ браузеров
```sql
SELECT browser, COUNT(*) as count,
       COUNT(DISTINCT ip_address) as unique_ips,
       COUNT(DISTINCT fingerprint) as unique_fingerprints
FROM intercepts
GROUP BY browser
ORDER BY count DESC;
```

### Временная статистика
```sql
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as requests,
    COUNT(DISTINCT ip_address) as unique_ips,
    COUNT(DISTINCT fingerprint) as unique_fingerprints
FROM intercepts
GROUP BY DATE(timestamp)
ORDER BY date DESC
LIMIT 30;
```

## 🐳 Docker команды

### Основные команды
```bash
./docker-run.sh start          # Запуск основных сервисов
./docker-run.sh start-full     # Запуск всех сервисов
./docker-run.sh start-monitoring  # С мониторингом
./docker-run.sh stop           # Остановка
./docker-run.sh restart        # Перезапуск
./docker-run.sh status         # Статус
./docker-run.sh logs [service] # Логи
```

### Tor управление
```bash
./docker-run.sh onion          # Получить .onion адрес
./docker-run.sh newip          # Сменить Tor идентичность
```

### Утилиты
```bash
./docker-run.sh shell          # Интерактивная оболочка
./docker-run.sh export         # Экспорт данных
./docker-run.sh cleanup        # Очистка
```

## 🔧 Настройка логирования

### Изменение уровня логирования
В `app.py` измените:
```python
root_logger.setLevel(logging.DEBUG)  # DEBUG, INFO, WARNING, ERROR
```

### Изменение размера ротации
В `app.py` измените параметры:
```python
RotatingFileHandler(
    f'{LOGS_DIR}/interceptor.log',
    maxBytes=10*1024*1024,  # Размер в байтах
    backupCount=5,          # Количество файлов
)
```

### Отключение логирования в БД
Закомментируйте вызовы `log_to_database()` в `app.py`

## 📝 Примеры использования

### Мониторинг в реальном времени
```bash
# Просмотр перехватов в реальном времени
watch -n 1 'python3 view_logs.py intercepts 5'

# Мониторинг ошибок
tail -f logs/errors.log

# Статистика каждые 10 секунд
watch -n 10 'python3 view_logs.py stats'
```

### Экспорт данных
```bash
# Экспорт в CSV
sqlite3 -header -csv data/intercepts.db "SELECT * FROM intercepts;" > export.csv

# Экспорт через API
curl http://localhost:5000/admin/api/reports > reports.json

# Экспорт логов
sqlite3 -header -csv data/intercepts.db "SELECT * FROM logs;" > logs.csv
```

### Автоматизация
```bash
# Cron задача для ежедневной статистики
0 0 * * * cd /path/to/project && python3 view_logs.py stats >> daily_stats.txt

# Мониторинг ошибок
*/5 * * * * cd /path/to/project && tail -n 100 logs/errors.log | grep ERROR | mail -s "Interceptor Errors" admin@example.com
```

---

*Для дополнительной информации см. основной README.md*
