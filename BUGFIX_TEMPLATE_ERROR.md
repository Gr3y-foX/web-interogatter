# 🐛 Bugfix: Template Error 500 - RESOLVED

## Дата: 29.01.2026

### Проблема

При переходе с маскировочного сайта на страницу перехвата (`/intercept`) возникала ошибка **500 Internal Server Error**.

### Симптомы

```
GET /intercept?ref=mask_site HTTP/1.1" 500
jinja2.exceptions.TemplateNotFound: en/caught_report.html
```

### Анализ

1. **Структура templates в контейнере:**
   ```
   /app/templates/
   ├── admin.html
   ├── caught_report.html       ✅ Основной шаблон
   ├── error.html
   ├── mask_site.html
   ├── en/
   │   └── mask_site.html       ✅ Есть
   └── ru/
       ├── admin.html
       ├── caught_report.html   ✅ Есть
       ├── error.html
       └── mask_site.html
   ```

2. **Проблемный код (app.py:584):**
   ```python
   template_path = f'{lang}/caught_report.html' if lang != 'en' else 'en/caught_report.html'
   ```
   
   **Проблема:** Для английского языка код пытался использовать `en/caught_report.html`, но этого файла не существует.

### Решение

**Файл:** `app.py`, строка 584

**Изменено:**
```python
# До исправления:
template_path = f'{lang}/caught_report.html' if lang != 'en' else 'en/caught_report.html'

# После исправления:
template_path = f'{lang}/caught_report.html' if lang == 'ru' else 'caught_report.html'
```

**Логика после исправления:**
- `lang == 'ru'` → используется `ru/caught_report.html`
- `lang == 'en'` (или любой другой) → используется `caught_report.html` (основной шаблон)

### Тестирование

```bash
# Тест 1: Главная страница
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:5000/
# ✅ Status: 200

# Тест 2: Маскировочный сайт
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:5000/mask
# ✅ Status: 200

# Тест 3: Страница перехвата (ИСПРАВЛЕНО!)
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:5000/intercept
# ✅ Status: 200

# Тест 4: Админ панель
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:5000/admin/reports
# ✅ Status: 200
```

### Проверка содержимого

```bash
curl -s http://localhost:5000/intercept | grep -o "<title>.*</title>"
# ✅ <title>⚠️ Обнаружена подозрительная активность</title>
```

### Альтернативные решения (не использованы)

1. **Создать файл `templates/en/caught_report.html`**
   - ❌ Дублирование кода
   - ❌ Требует поддержки двух копий шаблона

2. **Использовать try/except для fallback**
   - ❌ Менее эффективно
   - ❌ Скрывает реальную проблему

3. **Выбранное решение:** Изменить логику выбора шаблона
   - ✅ Простое и понятное
   - ✅ Нет дублирования кода
   - ✅ Основной шаблон работает для всех языков кроме русского

### Статус

✅ **ИСПРАВЛЕНО И ПРОТЕСТИРОВАНО**

- Образ Docker пересобран с исправлением
- Все маршруты работают корректно
- Ошибок 500 больше нет

### Связанные файлы

- `app.py` - исправлен маршрут `/intercept`
- `templates/caught_report.html` - основной шаблон (используется по умолчанию)
- `templates/ru/caught_report.html` - русская версия шаблона
- `Dockerfile` - пересобран образ с исправлением

### Commit

```bash
git add app.py
git commit -m "Fix: Template error 500 on /intercept - use default template for English"
```

---

**Автор:** Docker Optimization Team  
**Дата:** 29.01.2026  
**Статус:** ✅ Resolved
