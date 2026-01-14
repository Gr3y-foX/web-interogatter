# Решение проблемы с отсутствующими зависимостями

## Проблема
```
❌ Отсутствуют зависимости: stem (pip)
```

## Быстрое решение

### Вариант 1: Автоматический скрипт (рекомендуется)

На **Raspberry Pi** выполните:

```bash
cd /path/to/web-server-intercepter/raspberry-production
chmod +x install_dependencies.sh
./install_dependencies.sh
```

Скрипт автоматически:
- ✅ Обновит pip
- ✅ Установит системные зависимости (tor, python3-dev и т.д.)
- ✅ Установит все Python пакеты из requirements.txt

---

### Вариант 2: Ручная установка

**Шаг 1:** Обновите систему и установите базовые зависимости:

```bash
sudo apt-get update
sudo apt-get install -y python3-pip python3-dev tor build-essential libssl-dev libffi-dev
```

**Шаг 2:** Установите Python пакеты:

```bash
cd /path/to/web-server-intercepter

# Попробуйте обычную установку:
pip3 install -r requirements.txt

# Если не работает, используйте флаг --break-system-packages:
pip3 install --break-system-packages -r requirements.txt
```

---

### Вариант 3: Только stem

Если нужна только библиотека stem:

```bash
pip3 install stem
# или
pip3 install --break-system-packages stem
```

---

## Проверка установки

После установки проверьте, что зависимости установлены:

```bash
python3 -c "import flask; print('Flask: OK')"
python3 -c "import stem; print('Stem: OK')"
python3 -c "import requests; print('Requests: OK')"
```

Все должно вывести "OK".

---

## Запуск приложения

После успешной установки зависимостей:

```bash
cd raspberry-production
./raspberry-run.sh start
```

---

## Примечание для Raspberry Pi OS

На новых версиях Raspberry Pi OS может быть включена защита `externally-managed-environment`. 

Это **нормально** использовать флаг `--break-system-packages` для специализированных проектов вроде этого, так как:
- Проект изолирован
- Не конфликтует с системными пакетами
- Raspberry Pi часто используется для dedicated проектов

---

## Альтернатива: Virtual Environment (для продвинутых)

Если хотите более чистое решение:

```bash
cd /path/to/web-server-intercepter
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Внимание:** При использовании venv нужно будет модифицировать `raspberry-run.sh` для активации окружения.

