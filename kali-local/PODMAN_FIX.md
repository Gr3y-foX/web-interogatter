# Исправление проблемы с Podman

## Проблема

При запуске `./docker-build-and-run.sh` возникает ошибка:
```
Cannot connect to the Docker daemon at unix:///run/user/1000/podman/podman.sock. 
Is the docker daemon running?
```

Это означает, что ваша система использует **Podman** вместо Docker, и Podman service не запущен.

## Быстрое решение

### Вариант 1: Автоматический запуск Podman (рекомендуется)

```bash
cd /media/psf/vpn/web-server-intercepter/kali-local
./start-podman.sh
```

Затем снова запустите:
```bash
./docker-build-and-run.sh build-and-run
```

### Вариант 2: Ручной запуск через systemd

```bash
# Запуск Podman socket
systemctl --user start podman.socket

# Включение автозапуска (опционально)
systemctl --user enable podman.socket

# Проверка статуса
systemctl --user status podman.socket
```

### Вариант 3: Прямой запуск Podman service

```bash
# Запуск в фоне
podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &

# Или с сохранением PID
podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock > /tmp/podman.log 2>&1 &
echo $! > /tmp/podman.pid
```

### Вариант 4: Установка Docker (альтернатива)

Если вы предпочитаете использовать Docker вместо Podman:

```bash
# Установка Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Выход и повторный вход для применения изменений группы
# Или выполните: newgrp docker
```

## Проверка работы

После запуска Podman, проверьте:

```bash
# Проверка Podman
podman info

# Или через Docker CLI (если настроен alias)
docker info
```

## Автозапуск Podman при входе в систему

Чтобы Podman запускался автоматически:

```bash
# Создание systemd user service
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/podman.service << 'EOF'
[Unit]
Description=Podman API Service
Requires=podman.socket
After=podman.socket

[Service]
Type=simple
ExecStart=/usr/bin/podman system service --time=0 unix:///run/user/%U/podman/podman.sock
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Включение автозапуска
systemctl --user enable podman.socket
systemctl --user enable podman.service
systemctl --user start podman.socket
systemctl --user start podman.service
```

## Дополнительная информация

- Podman - это Docker-совместимый контейнеризатор, который не требует root-прав
- Podman может работать в rootless режиме (без sudo)
- Docker CLI команды работают с Podman через alias или podman-docker пакет

## Устранение неполадок

### Podman socket не создается

```bash
# Проверка прав доступа
ls -la /run/user/$(id -u)/podman/

# Создание директории вручную
mkdir -p /run/user/$(id -u)/podman
chmod 700 /run/user/$(id -u)/podman
```

### Ошибка "permission denied"

```bash
# Проверка групп пользователя
groups

# Если нужно, добавьте пользователя в группу podman
sudo usermod -aG podman $USER
```

### Проверка логов

```bash
# Логи systemd
journalctl --user -u podman.socket -f

# Логи Podman service
journalctl --user -u podman.service -f
```






