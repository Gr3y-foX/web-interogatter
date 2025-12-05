# 🔄 Автоматическое обновление через GitHub Webhook

Это руководство поможет настроить автоматическое обновление проекта на Raspberry Pi после каждого коммита в GitHub.

## 📋 Содержание

1. [Как это работает](#как-это-работает)
2. [Быстрая установка](#быстрая-установка)
3. [Ручная настройка](#ручная-настройка)
4. [Настройка GitHub Webhook](#настройка-github-webhook)
5. [Альтернативные методы](#альтернативные-методы)
6. [Устранение неполадок](#устранение-неполадок)

## 🎯 Как это работает

1. Вы делаете `git push` в GitHub
2. GitHub отправляет webhook запрос на ваш Raspberry Pi
3. Webhook сервер получает уведомление о push
4. Автоматически запускается скрипт обновления:
   - `git pull` для получения новых изменений
   - Перезапуск Docker контейнеров с обновленным кодом
5. Проект обновлен! 🎉

## 🚀 Быстрая установка

### Шаг 1: Установка на Raspberry Pi

```bash
cd ~/web-interogatter/raspberry-production
sudo ./setup_auto_update.sh
```

Скрипт автоматически:
- Установит Flask (если нужно)
- Настроит systemd service
- Сгенерирует секрет для webhook
- Запустит webhook сервер

### Шаг 2: Настройка GitHub Webhook

1. Откройте ваш репозиторий на GitHub
2. Перейдите в **Settings** → **Webhooks** → **Add webhook**
3. Заполните форму:
   - **Payload URL**: `http://ВАШ_IP:9000/webhook`
   - **Content type**: `application/json`
   - **Secret**: (секрет, который показал скрипт установки)
   - **Events**: Выберите "Just the push event"
4. Нажмите **Add webhook**

### Шаг 3: Проверка

Сделайте тестовый коммит:

```bash
git commit --allow-empty -m "Test webhook"
git push
```

Проверьте логи на Raspberry Pi:

```bash
sudo journalctl -u webhook-server -f
tail -f ~/web-interogatter/logs/auto_update.log
```

## 🔧 Ручная настройка

Если автоматическая установка не подходит, выполните шаги вручную:

### 1. Установка зависимостей

```bash
pip3 install flask
```

### 2. Установка прав на скрипты

```bash
chmod +x ~/web-interogatter/raspberry-production/auto_update.sh
chmod +x ~/web-interogatter/raspberry-production/webhook_server.py
```

### 3. Генерация секрета

```bash
openssl rand -hex 32
```

Сохраните полученный секрет.

### 4. Настройка переменных окружения

Создайте файл `.env` или экспортируйте переменные:

```bash
export WEBHOOK_SECRET="ваш_секрет_здесь"
export WEBHOOK_PORT=9000
export GIT_BRANCH=master
```

### 5. Запуск webhook сервера

#### Вариант A: Через systemd (рекомендуется)

Скопируйте и отредактируйте service файл:

```bash
sudo cp ~/web-interogatter/raspberry-production/webhook-server.service /etc/systemd/system/
sudo nano /etc/systemd/system/webhook-server.service
```

Измените:
- `User=` - ваш пользователь
- `WEBHOOK_SECRET=` - ваш секрет
- `WEBHOOK_PORT=` - порт (по умолчанию 9000)
- `GIT_BRANCH=` - ветка для отслеживания

Запустите сервис:

```bash
sudo systemctl daemon-reload
sudo systemctl enable webhook-server
sudo systemctl start webhook-server
sudo systemctl status webhook-server
```

#### Вариант B: Через screen/tmux

```bash
screen -S webhook
cd ~/web-interogatter/raspberry-production
export WEBHOOK_SECRET="ваш_секрет"
export WEBHOOK_PORT=9000
python3 webhook_server.py
# Нажмите Ctrl+A, затем D для отсоединения
```

#### Вариант C: В фоновом режиме

```bash
cd ~/web-interogatter/raspberry-production
nohup python3 webhook_server.py > webhook.log 2>&1 &
```

## 🌐 Настройка GitHub Webhook

### Если Raspberry Pi доступен из интернета

1. Узнайте внешний IP адрес:
   ```bash
   curl ifconfig.me
   ```

2. Настройте проброс портов на роутере (порт 9000)

3. В GitHub укажите: `http://ВАШ_ВНЕШНИЙ_IP:9000/webhook`

### Если Raspberry Pi за NAT (рекомендуется использовать ngrok)

#### Установка ngrok

```bash
# Скачайте ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
tar xvzf ngrok-v3-stable-linux-arm64.tgz
sudo mv ngrok /usr/local/bin/

# Зарегистрируйтесь на ngrok.com и получите authtoken
ngrok config add-authtoken ВАШ_TOKEN
```

#### Запуск ngrok

```bash
ngrok http 9000
```

Скопируйте HTTPS URL (например: `https://abc123.ngrok.io`) и используйте его в GitHub:
- URL: `https://abc123.ngrok.io/webhook`

#### Автозапуск ngrok через systemd

Создайте `/etc/systemd/system/ngrok.service`:

```ini
[Unit]
Description=ngrok tunnel
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/usr/local/bin/ngrok http 9000
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable ngrok
sudo systemctl start ngrok
```

## 🔄 Альтернативные методы

### Метод 1: Cron Job (периодическая проверка)

Если webhook не подходит, можно использовать cron для периодической проверки обновлений:

```bash
# Редактирование crontab
crontab -e

# Добавьте строку (проверка каждые 5 минут)
*/5 * * * * cd ~/web-interogatter && git fetch origin && [ $(git rev-list HEAD...origin/master --count) != 0 ] && ~/web-interogatter/raspberry-production/auto_update.sh
```

### Метод 2: GitHub Actions + SSH

Создайте `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Raspberry Pi

on:
  push:
    branches: [ master ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.RPI_HOST }}
          username: ${{ secrets.RPI_USER }}
          key: ${{ secrets.RPI_SSH_KEY }}
          script: |
            cd ~/web-interogatter
            git pull
            cd raspberry-production
            ./raspberry-run.sh restart
```

## 🛠️ Устранение неполадок

### Webhook не получает запросы

1. **Проверьте, что сервер запущен:**
   ```bash
   sudo systemctl status webhook-server
   ```

2. **Проверьте логи:**
   ```bash
   sudo journalctl -u webhook-server -f
   ```

3. **Проверьте доступность порта:**
   ```bash
   curl http://localhost:9000/health
   ```

4. **Проверьте firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 9000/tcp
   ```

### Обновление не происходит

1. **Проверьте логи обновления:**
   ```bash
   tail -f ~/web-interogatter/logs/auto_update.log
   ```

2. **Проверьте права на скрипт:**
   ```bash
   ls -l ~/web-interogatter/raspberry-production/auto_update.sh
   chmod +x ~/web-interogatter/raspberry-production/auto_update.sh
   ```

3. **Проверьте git репозиторий:**
   ```bash
   cd ~/web-interogatter
   git status
   git remote -v
   ```

### Ошибка "Invalid signature"

1. Убедитесь, что секрет в GitHub совпадает с секретом в systemd service
2. Проверьте переменную окружения:
   ```bash
   sudo systemctl show webhook-server | grep WEBHOOK_SECRET
   ```

### Сервер не перезапускается после обновления

1. Проверьте, что Docker контейнеры запущены:
   ```bash
   docker ps
   ```

2. Проверьте скрипт raspberry-run.sh:
   ```bash
   ~/web-interogatter/raspberry-production/raspberry-run.sh status
   ```

## 📊 Мониторинг

### Просмотр логов webhook сервера

```bash
sudo journalctl -u webhook-server -f
```

### Просмотр логов обновления

```bash
tail -f ~/web-interogatter/logs/auto_update.log
```

### Проверка последних обновлений

```bash
grep "✅" ~/web-interogatter/logs/auto_update.log | tail -10
```

## 🔒 Безопасность

1. **Всегда используйте секрет webhook** - это защищает от несанкционированных запросов
2. **Используйте HTTPS** - если возможно, настройте SSL сертификат
3. **Ограничьте доступ** - настройте firewall, чтобы порт 9000 был доступен только из нужных источников
4. **Регулярно обновляйте** - следите за обновлениями зависимостей

## 📝 Полезные команды

```bash
# Статус webhook сервера
sudo systemctl status webhook-server

# Перезапуск webhook сервера
sudo systemctl restart webhook-server

# Остановка webhook сервера
sudo systemctl stop webhook-server

# Просмотр логов
sudo journalctl -u webhook-server -f

# Ручной запуск обновления
~/web-interogatter/raspberry-production/auto_update.sh

# Проверка здоровья webhook сервера
curl http://localhost:9000/health
```

## 🎉 Готово!

Теперь при каждом `git push` ваш проект на Raspberry Pi будет автоматически обновляться!
