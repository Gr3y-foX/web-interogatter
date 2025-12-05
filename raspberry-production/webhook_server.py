#!/usr/bin/env python3
"""
GitHub Webhook Server для автоматического обновления проекта
Слушает webhook события от GitHub и запускает обновление
"""

import hmac
import hashlib
import json
import subprocess
import logging
import os
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Настройка логирования
LOG_DIR = os.path.expanduser("~/web-interogatter/logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'webhook_server.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Конфигурация
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', '')
WEBHOOK_PORT = int(os.environ.get('WEBHOOK_PORT', '9000'))
UPDATE_SCRIPT = os.path.expanduser('~/web-interogatter/raspberry-production/auto_update.sh')
BRANCH = os.environ.get('GIT_BRANCH', 'master')

# Проверка секрета webhook (рекомендуется для безопасности)
def verify_signature(payload_body, signature_header):
    """Проверка подписи webhook от GitHub"""
    if not WEBHOOK_SECRET:
        logger.warning("WEBHOOK_SECRET не установлен, проверка подписи пропущена")
        return True
    
    if not signature_header:
        return False
    
    # GitHub отправляет подпись в формате "sha256=..."
    if not signature_header.startswith('sha256='):
        return False
    
    expected_signature = signature_header.split('=')[1]
    
    # Создание HMAC подписи
    mac = hmac.new(
        WEBHOOK_SECRET.encode('utf-8'),
        msg=payload_body,
        digestmod=hashlib.sha256
    )
    calculated_signature = mac.hexdigest()
    
    # Безопасное сравнение
    return hmac.compare_digest(calculated_signature, expected_signature)


def run_update_script():
    """Запуск скрипта обновления"""
    try:
        logger.info("Запуск скрипта обновления...")
        
        # Проверка существования скрипта
        if not os.path.exists(UPDATE_SCRIPT):
            logger.error(f"Скрипт обновления не найден: {UPDATE_SCRIPT}")
            return False, "Скрипт обновления не найден"
        
        # Установка прав на выполнение
        os.chmod(UPDATE_SCRIPT, 0o755)
        
        # Запуск скрипта
        result = subprocess.run(
            ['/bin/bash', UPDATE_SCRIPT],
            capture_output=True,
            text=True,
            timeout=300  # 5 минут таймаут
        )
        
        if result.returncode == 0:
            logger.info("Обновление выполнено успешно")
            logger.info(f"Вывод: {result.stdout}")
            return True, result.stdout
        else:
            logger.error(f"Ошибка при обновлении: {result.stderr}")
            return False, result.stderr
            
    except subprocess.TimeoutExpired:
        logger.error("Таймаут при выполнении скрипта обновления")
        return False, "Таймаут при выполнении"
    except Exception as e:
        logger.error(f"Исключение при запуске скрипта: {str(e)}")
        return False, str(e)


@app.route('/webhook', methods=['POST'])
def webhook():
    """Обработка webhook запроса от GitHub"""
    try:
        # Получение заголовков
        signature = request.headers.get('X-Hub-Signature-256', '')
        event_type = request.headers.get('X-GitHub-Event', '')
        
        # Получение тела запроса
        payload_body = request.get_data()
        payload = request.get_json()
        
        logger.info(f"Получен webhook: {event_type}")
        
        # Проверка подписи
        if not verify_signature(payload_body, signature):
            logger.warning("Неверная подпись webhook")
            return jsonify({'error': 'Invalid signature'}), 401
        
        # Обработка только push событий
        if event_type != 'push':
            logger.info(f"Событие {event_type} проигнорировано (ожидается push)")
            return jsonify({'message': f'Event {event_type} ignored'}), 200
        
        # Проверка ветки
        ref = payload.get('ref', '')
        if not ref.endswith(f'/{BRANCH}'):
            logger.info(f"Push в ветку {ref} проигнорирован (ожидается {BRANCH})")
            return jsonify({'message': f'Branch {ref} ignored'}), 200
        
        # Информация о коммите
        commits = payload.get('commits', [])
        commit_count = len(commits)
        commit_messages = [c.get('message', '')[:50] for c in commits[:3]]
        
        logger.info(f"Обнаружен push в ветку {BRANCH} с {commit_count} коммитом(ами)")
        logger.info(f"Коммиты: {', '.join(commit_messages)}")
        
        # Запуск обновления
        success, message = run_update_script()
        
        if success:
            return jsonify({
                'status': 'success',
                'message': 'Update completed successfully',
                'commits': commit_count,
                'branch': BRANCH
            }), 200
        else:
            return jsonify({
                'status': 'error',
                'message': 'Update failed',
                'error': message
            }), 500
            
    except Exception as e:
        logger.error(f"Ошибка при обработке webhook: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Проверка здоровья сервера"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'branch': BRANCH,
        'script': UPDATE_SCRIPT
    }), 200


@app.route('/', methods=['GET'])
def index():
    """Главная страница"""
    return jsonify({
        'service': 'GitHub Webhook Server',
        'version': '1.0',
        'endpoints': {
            'webhook': '/webhook (POST)',
            'health': '/health (GET)'
        }
    }), 200


if __name__ == '__main__':
    logger.info("=" * 50)
    logger.info("GitHub Webhook Server запущен")
    logger.info(f"Порт: {WEBHOOK_PORT}")
    logger.info(f"Ветка: {BRANCH}")
    logger.info(f"Скрипт обновления: {UPDATE_SCRIPT}")
    logger.info(f"Секрет: {'Установлен' if WEBHOOK_SECRET else 'Не установлен (небезопасно!)'}")
    logger.info("=" * 50)
    
    # Запуск Flask сервера
    app.run(
        host='0.0.0.0',
        port=WEBHOOK_PORT,
        debug=False
    )
