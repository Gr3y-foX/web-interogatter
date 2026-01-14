from flask import Flask, request
import subprocess
import hmac
import hashlib
import os

app = Flask(__name__)

# ВАЖНО: Замените на свои значения!
WEBHOOK_SECRET = "ваш_секрет_из_github"  
REPO_PATH = "/home/main/git-update/web-interogatter"  # Ваш путь

def verify_signature(payload, signature):
    """Проверяет подпись от GitHub для безопасности"""
    if not signature:
        print("⚠️ Отсутствует заголовок X-Hub-Signature-256")
        return False
    
    try:
        sha_name, signature = signature.split('=')
        if sha_name != 'sha256':
            print(f"⚠️ Неподдерживаемый алгоритм подписи: {sha_name}")
            return False
    except ValueError:
        print(f"⚠️ Неверный формат подписи: {signature}")
        return False
    
    if WEBHOOK_SECRET == "ваш_секрет_из_github":
        print("⚠️ ВНИМАНИЕ: WEBHOOK_SECRET не установлен! Установите настоящий secret из GitHub!")
        # Все равно проверяем, но с дефолтным значением подпись не пройдет
    
    mac = hmac.new(WEBHOOK_SECRET.encode(), msg=payload, digestmod=hashlib.sha256)
    return hmac.compare_digest(mac.hexdigest(), signature)

@app.route('/webhook', methods=['POST'])
def webhook():
    # Получаем тип события из заголовка
    event_type = request.headers.get('X-GitHub-Event')
    print(f"📬 Получено событие типа: {event_type}")
    
    # Получаем подпись из заголовка
    signature = request.headers.get('X-Hub-Signature-256')
    
    # Сохраняем payload ДО проверки подписи (чтобы можно было потом использовать request.json)
    payload = request.data
    
    # Проверяем подпись
    if not verify_signature(payload, signature):
        print("⚠️ Неверная подпись! Возможная атака!")
        print(f"   Полученная подпись: {signature}")
        return 'Invalid signature', 403
    
    # Парсим данные от GitHub
    try:
        data = request.json
        if data is None:
            print("❌ ОШИБКА: Не удалось распарсить JSON из запроса")
            return 'Invalid JSON', 400
    except Exception as e:
        print(f"❌ ОШИБКА при парсинге JSON: {e}")
        return 'Invalid JSON', 400
    
    # Проверяем, что это push event
    if event_type != 'push':
        print(f"ℹ️ Игнорируем событие типа '{event_type}' (ожидаем 'push')")
        return 'Event ignored', 200
    
    # Проверяем наличие необходимых полей
    if not data or 'ref' not in data:
        print(f"⚠️ Отсутствует поле 'ref' в данных события")
        print(f"   Доступные поля: {list(data.keys()) if data else 'None'}")
        return 'Invalid push event', 400
    
    branch = data['ref'].split('/')[-1]
    repo_name = data.get('repository', {}).get('name', 'unknown')
    pusher = data.get('pusher', {}).get('name', 'unknown')
    
    print(f"✅ Получен push от {pusher} в репозиторий {repo_name}, ветка {branch}")
    
    # Проверяем существование директории
    if not os.path.exists(REPO_PATH):
        print(f"❌ ОШИБКА: Директория {REPO_PATH} не существует!")
        return 'Repo path not found', 500
    
    if not os.path.exists(os.path.join(REPO_PATH, '.git')):
        print(f"❌ ОШИБКА: {REPO_PATH} не является git-репозиторием!")
        return 'Not a git repo', 500
    
    # Выполняем git pull с подробным выводом
    try:
        print(f"🔄 Выполняю git pull в {REPO_PATH}...")
        print(f"   Команда: git pull origin {branch}")
        
        result = subprocess.run(
            ['git', 'pull', 'origin', branch],
            cwd=REPO_PATH,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # Выводим результат
        if result.returncode == 0:
            print(f"📥 Git pull выполнен успешно:")
            print(f"   STDOUT: {result.stdout}")
            if result.stderr:
                print(f"   STDERR: {result.stderr}")
            return 'OK - Pull successful', 200
        else:
            print(f"❌ Git pull завершился с ошибкой (код {result.returncode}):")
            print(f"   STDOUT: {result.stdout}")
            print(f"   STDERR: {result.stderr}")
            return f'Git pull failed: {result.stderr}', 500
                
    except subprocess.TimeoutExpired:
        error_msg = "⏱️ Таймаут при выполнении git pull!"
        print(error_msg)
        return error_msg, 500
    except Exception as e:
        error_msg = f"❌ Ошибка при git pull: {e}"
        print(error_msg)
        return error_msg, 500

@app.route('/', methods=['GET'])
def index():
    return 'Webhook server is running!', 200

if __name__ == '__main__':
    print(f"🚀 Запуск webhook сервера...")
    print(f"📂 Путь к репозиторию: {REPO_PATH}")
    print(f"🔐 Webhook secret установлен: {'Да' if WEBHOOK_SECRET != 'ваш_секрет_из_github' else 'НЕТ (УСТАНОВИТЕ!)'}")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
