# 🔍 Web Server Interceptor

> **English documentation:** [README_EN.md](README_EN.md) | [docs/en/](docs/en/)

Простой веб-сервер интерцептор для сбора информации о клиентах с анонимизацией через Tor. Создан для образовательных целей в области кибербезопасности.

## 🎯 Возможности

- **🎭 Маскировочный сайт** - Выглядит как обычный новостной сайт, автоматически перенаправляет на перехват
- **📊 Шуточный отчет о перехвате** - Показывает пользователю "отчет о перехвате" в стиле хакера
- **🔄 Автоматическое перенаправление** - Через Tor на сервер перехвата с сохранением всех данных
- **📈 Расширенный сбор данных** - User-Agent, ОС, устройство, язык, cookies, fingerprint, session ID
- **🧅 Анонимизация через Tor** - Проксирование трафика через сеть Tor
- **🌐 Tor Hidden Service (.onion)** - Автоматическое создание и использование .onion адреса
- **📝 Расширенное логирование** - Многоуровневая система логов с ротацией
- **💾 База данных отчетов** - SQLite база для хранения перехваченных данных и логов
- **🔧 Административная панель** - Веб-интерфейс для просмотра отчетов
- **🐳 Docker поддержка** - Полная контейнеризация для легкого развертывания

## 🛠️ Технические детали

### Архитектура
- **Backend**: Python Flask
- **Database**: SQLite
- **Proxy**: Tor (SOCKS5)
- **Frontend**: HTML/CSS/JavaScript

### Собираемая информация
- **Базовая информация:**
  - Timestamp (время запроса)
  - IP адрес клиента
  - User-Agent строка
  - Браузер и версия
  - Операционная система
  - Тип устройства, бренд, модель
  - Реферер
  - Язык браузера
  - HTTP заголовки
  - Метод запроса
  - Запрашиваемый путь
  - Query string

- **Расширенная информация:**
  - Browser fingerprint (уникальный отпечаток)
  - Session ID
  - Cookies
  - Content-Type и Content-Length
  - Host, Origin
  - Тип подключения (Direct/Proxied/Via-Proxy)
  - Screen resolution (если доступно)
  - Timezone (если доступно)
  - Tor exit node информация

### Система логирования
- **interceptor.log** - Основной лог с ротацией по размеру (10MB, 5 файлов)
- **intercepts.log** - Специализированный лог только перехватов (50MB, 10 файлов)
- **errors.log** - Логи ошибок (10MB, 5 файлов)
- **daily.log** - Ежедневные логи с ротацией по времени (30 дней)
- **База данных** - Все логи также сохраняются в SQLite для анализа

## 📋 Требования

### Система
- Linux (предпочтительно Kali Linux)
- Python 3.7+
- Tor
- SQLite3

### Python пакеты
```
Flask==2.3.3
user-agents==2.2.0
requests==2.31.0
stem==1.8.1
PySocks==1.7.1
```

## 📁 Структура проекта

Проект организован в две версии для разных сценариев использования:

### 🐧 `kali-local/` - Версия для Kali Linux (локальный доступ)
- Для локального использования и тестирования
- Минимальная конфигурация безопасности
- Быстрый запуск без дополнительной настройки
- Подходит для изолированной среды (VM)

**См. [kali-local/README.md](kali-local/README.md)**

### 🍓 `raspberry-production/` - Версия для Raspberry Pi (production)
- Для production сервера в открытом интернете
- Усиленная защита (fail2ban, firewall, мониторинг)
- Автоматические обновления и резервное копирование
- Полная настройка безопасности

**См. [raspberry-production/README.md](raspberry-production/README.md)**

## 🚀 Быстрый старт

### Вариант 1: Kali Linux (локальный доступ)

```bash
# Переход в директорию проекта
cd web-server-intercepter/kali-local

# Запуск (без Docker)
./run.sh start

# Или с Docker
./docker-run.sh start
```

### Вариант 2: Raspberry Pi (production)

```bash
# Переход в директорию проекта
cd web-server-intercepter/raspberry-production

# Автоматическая настройка
./setup_raspberry.sh

# Настройка безопасности (требует sudo)
sudo ./setup_security.sh

# Запуск приложения
./raspberry-run.sh start
```

### Вариант 3: Классический запуск (из корня проекта)

```bash
# Переход в директорию проекта
cd web-server-intercepter

# Установка зависимостей и запуск
./run.sh start
```

### 2. Ручная установка
```bash
# Установка Python зависимостей
pip3 install -r requirements.txt

# Установка Tor (Debian/Ubuntu/Kali)
sudo apt update && sudo apt install tor

# Запуск Tor
python3 tor_setup.py start

# Запуск веб-сервера
python3 app.py
```

## 🎮 Использование

### Управление сервисами
```bash
# Запуск всех сервисов
./run.sh start

# Остановка сервисов
./run.sh stop

# Перезапуск
./run.sh restart

# Проверка статуса
./run.sh status

# Просмотр логов
./run.sh logs

# Очистка данных
./run.sh cleanup
```

### Доступ к интерфейсам

#### 🎭 Маскировочный сайт (entrypoint)
- **Localhost**: http://localhost:5000/mask
- **Локальная сеть**: http://[локальный-IP]:5000/mask
- **Публичный IP**: http://[публичный-IP]:5000/mask
- **Tor Hidden Service**: http://[onion-address].onion/mask
  - Выглядит как обычный новостной сайт
  - Автоматически перенаправляет на страницу перехвата

#### 📊 Страница перехвата (шуточный отчет)
- **Localhost**: http://localhost:5000/intercept
- **Локальная сеть**: http://[локальный-IP]:5000/intercept
- **Публичный IP**: http://[публичный-IP]:5000/intercept
- **Tor**: http://[onion-address].onion/intercept
  - Показывает пользователю "отчет о перехвате"
  - Отображает все собранные данные в шуточном формате

#### 🔧 Административная панель
- **Localhost**: http://localhost:5000/admin/reports
- **Локальная сеть**: http://[локальный-IP]:5000/admin/reports
- **Публичный IP**: http://[публичный-IP]:5000/admin/reports
- **Tor**: http://[onion-address].onion/admin/reports
- **API**: http://localhost:5000/admin/api/reports
  - Возвращает JSON с отчетами и .onion адресом

#### Настройка публичного доступа
Для доступа извне (не только localhost):
```bash
# Автоматическая настройка - покажет все доступные адреса
./setup_public_access.sh 5000

# Настройка firewall
sudo ./setup_firewall.sh 5000

# Настройка Tor перенаправления
./setup_tor_redirect.sh
```

**Доступные способы:**
1. **Локальная сеть** - `http://[локальный-IP]:5000/mask`
2. **Публичный IP** - `http://[публичный-IP]:5000/mask` (требует port forwarding)
3. **Tor .onion** - `http://[onion-address].onion/mask` (рекомендуется)

Подробнее см.:
- [PUBLIC_ACCESS.md](PUBLIC_ACCESS.md) - Полная инструкция по публичному доступу
- [EXTERNAL_ACCESS.md](EXTERNAL_ACCESS.md) - Настройка внешнего доступа
- [MASK_AND_REDIRECT.md](MASK_AND_REDIRECT.md) - Маскировочный сайт и перенаправление

### Tor управление
```bash
# Запуск Tor
python3 tor_setup.py start

# Проверка IP
python3 tor_setup.py check

# Смена IP адреса
python3 tor_setup.py newip

# Получить .onion адрес
python3 tor_setup.py hidden

# Остановка Tor
python3 tor_setup.py stop
```

## 📊 Структура проекта

```
web-server-intercepter/
├── app.py                      # Основной Flask сервер
├── tor_setup.py               # Управление Tor
├── requirements.txt           # Python зависимости
├── README.md                  # Основная документация
│
├── kali-local/                # Версия для Kali Linux (локальный доступ)
│   ├── README.md             # Документация для Kali Linux
│   ├── run.sh                # Скрипт запуска (без Docker)
│   ├── docker-run.sh         # Скрипт управления Docker
│   └── setup_tor_redirect.sh # Настройка Tor перенаправления
│
├── raspberry-production/      # Версия для Raspberry Pi (production)
│   ├── README.md             # Документация для Raspberry Pi
│   ├── raspberry-run.sh      # Управление приложением
│   ├── setup_raspberry.sh    # Автоматическая настройка
│   ├── setup_security.sh     # Настройка безопасности
│   ├── setup_production_firewall.sh  # Усиленный firewall
│   └── monitor_security.sh   # Мониторинг безопасности
│
├── templates/                 # HTML шаблоны
│   ├── error.html           # Страница ошибки (ловушка)
│   └── admin.html           # Административная панель
├── reports/                  # JSON отчеты
├── logs/                     # Логи приложения
└── data/                     # Данные (база данных)
```

## 🔒 Безопасность и анонимность

### Tor конфигурация
- SOCKS прокси на порту 9050
- Control порт 9051
- Автоматическое создание скрытого сервиса
- Отключение exit relay для безопасности

### Рекомендации
1. **Используйте только в изолированной среде** (VM)
2. **Регулярно меняйте Tor идентичность**
3. **Не используйте на продакшн серверах**
4. **Соблюдайте законы вашей страны**

## 📈 Мониторинг

### Административная панель
- Статистика перехватов
- Фильтрация по IP, браузеру, дате
- Экспорт в CSV
- Реальное время обновления

### API эндпоинты
```bash
# Получить отчеты в JSON
curl http://localhost:5000/admin/api/reports

# Проверка статуса
curl http://localhost:5000/
```

## 🐛 Отладка

### Проверка логов
```bash
# Основной лог приложения
tail -f logs/interceptor.log

# Лог перехватов
tail -f logs/intercepts.log

# Лог ошибок
tail -f logs/errors.log

# Ежедневный лог
tail -f logs/daily.log

# Логи Tor
tail -f /tmp/tor_interceptor/tor.log

# Логи приложения (через скрипт)
./run.sh logs

# Проверка базы данных
sqlite3 data/intercepts.db "SELECT * FROM intercepts LIMIT 10;"

# Просмотр логов из базы данных
sqlite3 data/intercepts.db "SELECT * FROM logs ORDER BY timestamp DESC LIMIT 20;"
```

### Расширенное логирование
Система логирования включает:
- **Ротация по размеру** - автоматическая очистка старых логов
- **Ротация по времени** - ежедневные логи с хранением 30 дней
- **Многоуровневое логирование** - DEBUG, INFO, WARNING, ERROR
- **Логирование в БД** - все логи сохраняются в SQLite для анализа
- **Структурированные логи** - форматированный вывод с метаданными

### Частые проблемы

#### Tor не запускается
```bash
# Проверка установки
tor --version

# Ручная установка
sudo apt install tor

# Проверка портов
netstat -tuln | grep -E ":(9050|9051)"
```

#### Порт 5000 занят
```bash
# Найти процесс
sudo lsof -i :5000

# Изменить порт в app.py
app.run(host='0.0.0.0', port=8080, debug=False)
```

## 🐳 Docker поддержка

Проект полностью поддерживает Docker для легкого развертывания:

### Быстрый старт с Docker
```bash
# Запуск с Docker Compose
./docker-run.sh start

# Запуск всех сервисов включая мониторинг
./docker-run.sh start-monitoring

# Просмотр статуса
./docker-run.sh status

# Просмотр логов
./docker-run.sh logs interceptor

# Получение .onion адреса
./docker-run.sh onion

# Интерактивная оболочка
./docker-run.sh shell
```

### Docker сервисы
- **interceptor** - Основное приложение
- **tor-relay** - Tor прокси сервер
- **nginx-proxy** - Nginx для маскировки
- **sqlite-web** - Веб-интерфейс для SQLite
- **grafana** - Мониторинг (опционально)

Подробнее см. `docker-compose.yml` и `Dockerfile`.

## 🍓 Версия для Raspberry Pi 4

Проект полностью поддерживает запуск на **Raspberry Pi 4** с оптимизацией для ARM64 архитектуры.

### Быстрый старт на Raspberry Pi

```bash
# Автоматическая настройка
./setup_raspberry.sh

# Запуск основных сервисов (оптимизировано для Raspberry Pi)
./raspberry-run.sh start

# Просмотр статуса
./raspberry-run.sh status

# Мониторинг ресурсов
./raspberry-run.sh monitor
```

### Особенности версии для Raspberry Pi

- ✅ **Оптимизация для ARM64** - специальный Dockerfile для Raspberry Pi
- ✅ **Ограничение ресурсов** - настройки для ограниченной памяти и CPU
- ✅ **Упрощенные сервисы** - минимальная конфигурация для стабильной работы
- ✅ **Автоматическая настройка** - скрипт для быстрой установки
- ✅ **Мониторинг ресурсов** - встроенный мониторинг температуры и памяти

### Требования для Raspberry Pi

- Raspberry Pi 4 (рекомендуется 4GB RAM или больше)
- Raspberry Pi OS (64-bit)
- Docker и Docker Compose
- MicroSD карта минимум 16GB (рекомендуется 32GB+)

### Документация

Подробная инструкция по установке и настройке на Raspberry Pi 4:
- **[RASPBERRY_PI_SETUP.md](RASPBERRY_PI_SETUP.md)** - Полная инструкция по установке

### Файлы для Raspberry Pi

- `Dockerfile.raspberry` - Dockerfile для ARM64
- `docker-compose.raspberry.yml` - Docker Compose конфигурация
- `setup_raspberry.sh` - Скрипт автоматической настройки
- `raspberry-run.sh` - Скрипт управления для Raspberry Pi

## ⚖️ Правовая информация

### ⚠️ ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ
Этот проект создан исключительно для **образовательных целей** в области кибербезопасности. 

### Разрешенное использование:
- ✅ Обучение и изучение веб-безопасности
- ✅ Тестирование собственных систем
- ✅ Академические исследования
- ✅ Демонстрации в контролируемой среде

### Запрещенное использование:
- ❌ Сбор данных без согласия пользователей
- ❌ Нарушение приватности третьих лиц
- ❌ Любая незаконная деятельность
- ❌ Использование против реальных пользователей без разрешения

### Ответственность
Авторы не несут ответственности за неправомерное использование данного ПО. Пользователь несет полную ответственность за соблюдение законов своей юрисдикции.

## 🤝 Вклад в проект

Проект открыт для улучшений и предложений:

1. Fork репозитория
2. Создайте feature branch
3. Внесите изменения
4. Создайте Pull Request

## 📝 Лицензия

Этот проект распространяется под лицензией MIT для образовательных целей.

## 👨‍💻 Автор

Создано для изучения кибербезопасности в учебных целях.

---

**🎓 Образовательный проект по кибербезопасности**  
*Используйте ответственно и в соответствии с законами*
