# 🎯 Примеры использования Web Server Interceptor

## 🚀 Сценарии запуска

### Сценарий 1: Базовый запуск в Kali Linux

```bash
# 1. Обновление системы
sudo apt update && sudo apt upgrade -y

# 2. Переход в директорию проекта
cd /path/to/web-server-intercepter

# 3. Запуск с автоматической установкой
./run.sh start

# 4. Проверка статуса
./run.sh status
```

### Сценарий 2: Ручная настройка

```bash
# 1. Установка зависимостей Python
pip3 install --user -r requirements.txt

# 2. Установка Tor
sudo apt install tor

# 3. Запуск Tor с кастомной конфигурацией
python3 tor_setup.py start

# 4. В новом терминале - запуск Flask сервера
python3 app.py

# 5. Проверка IP через Tor
python3 tor_setup.py check
```

## 🎭 Тестовые сценарии

### Тест 1: Проверка перехвата IP

```bash
# Терминал 1: Запуск сервера
./run.sh start

# Терминал 2: Тестовые запросы
curl http://localhost:5000
curl http://localhost:5000/test-page
curl http://localhost:5000/robots.txt

# Проверка результатов
curl http://localhost:5000/admin/api/reports | jq
```

### Тест 2: Проверка анонимности через Tor

```bash
# 1. Запуск с Tor
python3 tor_setup.py start

# 2. Проверка реального IP
curl https://httpbin.org/ip

# 3. Проверка IP через Tor
curl --socks5 127.0.0.1:9050 https://httpbin.org/ip

# 4. Смена IP и повторная проверка
python3 tor_setup.py newip
curl --socks5 127.0.0.1:9050 https://httpbin.org/ip
```

### Тест 3: Скрытый сервис (.onion)

```bash
# 1. Запуск и получение .onion адреса
./run.sh start
python3 tor_setup.py hidden

# 2. Доступ через Tor Browser или curl
# curl --socks5 127.0.0.1:9050 http://[your-onion-address].onion

# 3. Проверка перехватов
curl http://localhost:5000/admin/reports
```

## 📊 Анализ собранных данных

### Просмотр в SQLite

```bash
# Подключение к базе данных
sqlite3 intercepts.db

# Базовые запросы
.tables
.schema intercepts

# Статистика по IP
SELECT ip_address, COUNT(*) as visits 
FROM intercepts 
GROUP BY ip_address 
ORDER BY visits DESC;

# Статистика по браузерам
SELECT browser, COUNT(*) as count 
FROM intercepts 
WHERE browser IS NOT NULL 
GROUP BY browser 
ORDER BY count DESC;

# Активность по времени
SELECT DATE(timestamp) as date, COUNT(*) as visits 
FROM intercepts 
GROUP BY DATE(timestamp) 
ORDER BY date DESC;

# Поиск подозрительной активности
SELECT * FROM intercepts 
WHERE ip_address IN (
    SELECT ip_address FROM intercepts 
    GROUP BY ip_address 
    HAVING COUNT(*) > 10
) ORDER BY timestamp DESC;
```

### Экспорт данных

```bash
# Экспорт в CSV
sqlite3 -header -csv intercepts.db "SELECT * FROM intercepts;" > export.csv

# Экспорт в JSON через API
curl http://localhost:5000/admin/api/reports > export.json

# Фильтрация данных
sqlite3 -header -csv intercepts.db \
"SELECT timestamp, ip_address, browser, os 
FROM intercepts 
WHERE DATE(timestamp) = DATE('now');" > today.csv
```

## 🔧 Расширенная конфигурация

### Настройка для production

```python
# app.py - добавить в конец файла
if __name__ == '__main__':
    import logging
    from logging.handlers import RotatingFileHandler
    
    # Настройка логирования
    if not app.debug:
        file_handler = RotatingFileHandler('logs/interceptor.log', 
                                         maxBytes=10240, backupCount=10)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)
        app.logger.setLevel(logging.INFO)
        app.logger.info('Interceptor startup')
    
    # Запуск с Gunicorn (для production)
    # gunicorn --bind 0.0.0.0:5000 --workers 4 app:app
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
```

### Дополнительные Tor настройки

```bash
# Создание кастомного torrc
cat > /tmp/tor_interceptor/torrc << EOF
# Расширенная конфигурация Tor
SocksPort 9050
ControlPort 9051
HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C

# Скрытый сервис
HiddenServiceDir /tmp/tor_interceptor/hidden_service/
HiddenServicePort 80 127.0.0.1:5000
HiddenServiceVersion 3

# Безопасность
ExitPolicy reject *:*
ExitRelay 0
PublishServerDescriptor 0

# Производительность
NumCPUs 2
MaxCircuitDirtiness 300
NewCircuitPeriod 15
MaxClientCircuitsPending 16

# Дополнительные настройки
StrictNodes 1
ExcludeExitNodes {us},{ca},{au},{nz},{gb},{??}
EOF
```

## 🛡️ Безопасность и маскировка

### Имитация реального сайта

```python
# Добавить в app.py новые роуты для маскировки
@app.route('/login')
def fake_login():
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return render_template('login.html'), 200

@app.route('/contact')
def fake_contact():
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return render_template('contact.html'), 200

@app.route('/api/status')
def fake_api():
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return jsonify({"status": "error", "message": "Service temporarily unavailable"}), 503
```

### Дополнительные заголовки для маскировки

```python
# Добавить в app.py
@app.after_request
def add_security_headers(response):
    # Имитация Apache сервера
    response.headers['Server'] = 'Apache/2.4.41 (Ubuntu)'
    response.headers['X-Powered-By'] = 'PHP/7.4.3'
    
    # Стандартные заголовки безопасности
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    return response
```

## 📈 Мониторинг и алерты

### Простая система алертов

```python
# alerts.py - создать новый файл
import sqlite3
import smtplib
from datetime import datetime, timedelta

def check_suspicious_activity():
    """Проверка подозрительной активности"""
    conn = sqlite3.connect('intercepts.db')
    cursor = conn.cursor()
    
    # Много запросов с одного IP за последний час
    one_hour_ago = datetime.now() - timedelta(hours=1)
    cursor.execute("""
        SELECT ip_address, COUNT(*) as count 
        FROM intercepts 
        WHERE timestamp > ? 
        GROUP BY ip_address 
        HAVING count > 20
    """, (one_hour_ago.isoformat(),))
    
    suspicious_ips = cursor.fetchall()
    conn.close()
    
    if suspicious_ips:
        print(f"⚠️ Подозрительная активность обнаружена:")
        for ip, count in suspicious_ips:
            print(f"  IP {ip}: {count} запросов за час")
    
    return suspicious_ips

# Запуск проверки каждые 10 минут
# while True:
#     check_suspicious_activity()
#     time.sleep(600)
```

### Dashboard для мониторинга

```html
<!-- Добавить в admin.html -->
<div class="dashboard-metrics">
    <div class="metric-card">
        <h3>Активность за час</h3>
        <canvas id="hourly-chart"></canvas>
    </div>
    <div class="metric-card">
        <h3>География IP</h3>
        <div id="geo-stats"></div>
    </div>
    <div class="metric-card">
        <h3>User Agents</h3>
        <div id="ua-stats"></div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
// Код для графиков и статистики
</script>
```

## 🔄 Автоматизация

### Systemd сервис (для постоянной работы)

```bash
# Создание systemd сервиса
sudo tee /etc/systemd/system/web-interceptor.service << EOF
[Unit]
Description=Web Server Interceptor
After=network.target

[Service]
Type=forking
User=nobody
Group=nogroup
WorkingDirectory=/path/to/web-server-intercepter
ExecStart=/path/to/web-server-intercepter/run.sh start
ExecStop=/path/to/web-server-intercepter/run.sh stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Активация сервиса
sudo systemctl enable web-interceptor
sudo systemctl start web-interceptor
sudo systemctl status web-interceptor
```

### Cron задачи для обслуживания

```bash
# Добавить в crontab
crontab -e

# Очистка старых логов каждый день в 2:00
0 2 * * * find /path/to/web-server-intercepter/logs -name "*.log" -mtime +7 -delete

# Смена Tor идентичности каждые 30 минут
*/30 * * * * cd /path/to/web-server-intercepter && python3 tor_setup.py newip

# Резервное копирование базы данных каждый день в 3:00
0 3 * * * cp /path/to/web-server-intercepter/intercepts.db /backup/intercepts_$(date +\%Y\%m\%d).db
```

## 🎓 Образовательные упражнения

### Упражнение 1: Анализ трафика
1. Запустите interceptor
2. Сделайте 20-30 различных запросов
3. Проанализируйте собранные данные
4. Найдите закономерности в User-Agent строках

### Упражнение 2: Тестирование анонимности
1. Запустите без Tor - запишите IP
2. Запустите с Tor - сравните IP
3. Поменяйте Tor идентичность 5 раз
4. Проверьте, меняется ли IP каждый раз

### Упражнение 3: Создание отчета
1. Соберите данные за 24 часа
2. Создайте CSV отчет
3. Постройте графики активности
4. Определите самые популярные браузеры

---

*Помните: используйте только в образовательных целях и в соответствии с законами!*
