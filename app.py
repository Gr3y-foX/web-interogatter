#!/usr/bin/env python3
"""
Web Server Interceptor - Простой интерцептор IP адресов
Создан для образовательных целей в области кибербезопасности
"""

from flask import Flask, request, render_template, jsonify, redirect
import datetime
import json
import os
import logging
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
from user_agents import parse
import sqlite3
import threading
import hashlib
import time
import socket
import subprocess
import requests

app = Flask(__name__)

# Создание директорий
REPORTS_DIR = "reports"
LOGS_DIR = "logs"
DATA_DIR = "data"
LOCALES_DIR = "locales"
for directory in [REPORTS_DIR, LOGS_DIR, DATA_DIR]:
    if not os.path.exists(directory):
        os.makedirs(directory)

# Load translations
def load_locale(lang='en'):
    """Load translation file"""
    locale_file = os.path.join(LOCALES_DIR, f'{lang}.json')
    if os.path.exists(locale_file):
        with open(locale_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    # Fallback to English
    locale_file = os.path.join(LOCALES_DIR, 'en.json')
    if os.path.exists(locale_file):
        with open(locale_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def get_locale():
    """Get current locale from request"""
    lang = request.args.get('lang', 'en')
    if lang not in ['en', 'ru']:
        lang = 'en'
    return lang

# Расширенная настройка логирования
def setup_logging():
    """Настройка расширенной системы логирования"""
    # Формат логов
    log_format = logging.Formatter(
        '%(asctime)s | %(levelname)-8s | %(name)s | %(funcName)s:%(lineno)d | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Основной лог файл с ротацией по размеру (10MB, 5 файлов)
    file_handler = RotatingFileHandler(
        f'{LOGS_DIR}/interceptor.log',
        maxBytes=10*1024*1024,
        backupCount=5,
        encoding='utf-8'
    )
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(log_format)
    
    # Лог файл для ошибок
    error_handler = RotatingFileHandler(
        f'{LOGS_DIR}/errors.log',
        maxBytes=10*1024*1024,
        backupCount=5,
        encoding='utf-8'
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(log_format)
    
    # Лог файл с ротацией по времени (ежедневно)
    daily_handler = TimedRotatingFileHandler(
        f'{LOGS_DIR}/daily.log',
        when='midnight',
        interval=1,
        backupCount=30,
        encoding='utf-8'
    )
    daily_handler.setLevel(logging.DEBUG)
    daily_handler.setFormatter(log_format)
    
    # Лог файл для перехватов (только перехваченные запросы)
    intercept_handler = RotatingFileHandler(
        f'{LOGS_DIR}/intercepts.log',
        maxBytes=50*1024*1024,
        backupCount=10,
        encoding='utf-8'
    )
    intercept_handler.setLevel(logging.INFO)
    intercept_format = logging.Formatter(
        '%(asctime)s | IP:%(ip)s | %(method)s %(path)s | %(browser)s | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    intercept_handler.setFormatter(intercept_format)
    
    # Консольный вывод
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_format = logging.Formatter(
        '%(asctime)s | %(levelname)-8s | %(message)s',
        datefmt='%H:%M:%S'
    )
    console_handler.setFormatter(console_format)
    
    # Настройка root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(error_handler)
    root_logger.addHandler(daily_handler)
    root_logger.addHandler(console_handler)
    
    # Специальный logger для перехватов
    intercept_logger = logging.getLogger('intercept')
    intercept_logger.setLevel(logging.INFO)
    intercept_logger.addHandler(intercept_handler)
    intercept_logger.propagate = False
    
    return intercept_logger

# Инициализация логирования
intercept_logger = setup_logging()
logger = logging.getLogger(__name__)

# Получение .onion адреса
def get_onion_address():
    """Получение .onion адреса из Tor hidden service"""
    onion_paths = [
        '/tmp/tor_interceptor/hidden_service/hostname',
        '/var/lib/tor-interceptor/hidden_service/hostname',
        'data/onion_address.txt'
    ]
    
    for path in onion_paths:
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    address = f.read().strip()
                    if address.endswith('.onion'):
                        logger.info(f"Найден .onion адрес: {address}")
                        return address
            except Exception as e:
                logger.warning(f"Ошибка чтения .onion адреса из {path}: {e}")
    
    logger.warning(".onion адрес не найден, используется localhost")
    return None

ONION_ADDRESS = get_onion_address()

def get_local_ip():
    """Получение локального IP адреса"""
    try:
        # Подключение к внешнему адресу для определения локального IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return None

def get_public_ip():
    """Получение публичного IP адреса"""
    try:
        response = requests.get('https://api.ipify.org?format=json', timeout=5)
        return response.json().get('ip')
    except Exception:
        try:
            response = requests.get('https://ifconfig.me/ip', timeout=5)
            return response.text.strip()
        except Exception:
            return None

def get_network_info():
    """Получение информации о сетевых интерфейсах"""
    network_info = {
        'local_ip': get_local_ip(),
        'public_ip': get_public_ip(),
        'hostname': socket.gethostname(),
        'interfaces': []
    }
    
    try:
        # Получение всех сетевых интерфейсов
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            network_info['interfaces'] = result.stdout.strip().split()
    except Exception:
        pass
    
    return network_info

# Инициализация базы данных
def init_db():
    """Инициализация SQLite базы данных для хранения отчетов и логов"""
    db_path = os.path.join(DATA_DIR, 'intercepts.db')
    
    # Обратная совместимость: перенос старой базы данных
    old_db_path = 'intercepts.db'
    if os.path.exists(old_db_path) and not os.path.exists(db_path):
        logger.info(f"Перенос базы данных из {old_db_path} в {db_path}")
        import shutil
        shutil.move(old_db_path, db_path)
    elif os.path.exists(old_db_path) and os.path.exists(db_path):
        # Если обе базы существуют, используем новую, но логируем
        logger.warning(f"Найдены обе базы данных. Используется: {db_path}")
    
    # Создание симлинка для обратной совместимости
    if os.path.exists(db_path) and not os.path.exists(old_db_path):
        try:
            os.symlink(os.path.abspath(db_path), old_db_path)
        except:
            pass  # Игнорируем ошибки создания симлинка
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Таблица перехватов
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS intercepts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            ip_address TEXT NOT NULL,
            user_agent TEXT,
            browser TEXT,
            os TEXT,
            device TEXT,
            referer TEXT,
            accept_language TEXT,
            accept_encoding TEXT,
            headers TEXT,
            request_method TEXT,
            request_path TEXT,
            query_string TEXT,
            content_type TEXT,
            content_length INTEGER,
            host TEXT,
            origin TEXT,
            connection_type TEXT,
            screen_resolution TEXT,
            timezone TEXT,
            cookies TEXT,
            session_id TEXT,
            fingerprint TEXT,
            tor_exit_node TEXT,
            geolocation TEXT
        )
    ''')
    
    # Миграция: добавление недостающих колонок в существующую таблицу
    cursor.execute("PRAGMA table_info(intercepts)")
    existing_columns = [row[1] for row in cursor.fetchall()]
    
    new_columns = {
        'query_string': 'TEXT',
        'content_type': 'TEXT',
        'content_length': 'INTEGER',
        'host': 'TEXT',
        'origin': 'TEXT',
        'connection_type': 'TEXT',
        'screen_resolution': 'TEXT',
        'timezone': 'TEXT',
        'cookies': 'TEXT',
        'session_id': 'TEXT',
        'fingerprint': 'TEXT',
        'tor_exit_node': 'TEXT',
        'geolocation': 'TEXT'
    }
    
    for column_name, column_type in new_columns.items():
        if column_name not in existing_columns:
            try:
                cursor.execute(f"ALTER TABLE intercepts ADD COLUMN {column_name} {column_type}")
                logger.info(f"Добавлена колонка {column_name} в таблицу intercepts")
            except sqlite3.OperationalError as e:
                logger.warning(f"Не удалось добавить колонку {column_name}: {e}")
    
    # Таблица логов
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            level TEXT NOT NULL,
            logger_name TEXT,
            function_name TEXT,
            line_number INTEGER,
            message TEXT,
            ip_address TEXT,
            request_path TEXT,
            exception TEXT
        )
    ''')
    
    # Таблица статистики
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            total_requests INTEGER DEFAULT 0,
            unique_ips INTEGER DEFAULT 0,
            unique_browsers INTEGER DEFAULT 0,
            tor_requests INTEGER DEFAULT 0,
            error_count INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Индексы для быстрого поиска
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_timestamp ON intercepts(timestamp)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_ip ON intercepts(ip_address)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_path ON intercepts(request_path)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level)')
    
    conn.commit()
    conn.close()
    logger.info(f"База данных инициализирована: {db_path}")

def generate_fingerprint(request, user_agent_string):
    """Генерация уникального fingerprint клиента"""
    fingerprint_data = {
        'user_agent': user_agent_string,
        'accept_language': request.headers.get('Accept-Language', ''),
        'accept_encoding': request.headers.get('Accept-Encoding', ''),
        'accept': request.headers.get('Accept', ''),
        'connection': request.headers.get('Connection', ''),
        'upgrade_insecure': request.headers.get('Upgrade-Insecure-Requests', ''),
    }
    fingerprint_string = json.dumps(fingerprint_data, sort_keys=True)
    return hashlib.sha256(fingerprint_string.encode()).hexdigest()[:16]

def get_client_info(request):
    """Расширенное извлечение информации о клиенте из запроса"""
    # Получение IP адреса (учитываем прокси и Tor)
    ip_address = request.environ.get('HTTP_X_FORWARDED_FOR') or request.environ.get('REMOTE_ADDR', 'Unknown')
    
    # Определение, идет ли запрос через Tor
    tor_exit_node = None
    if 'X-Forwarded-For' in request.headers:
        # Tor exit nodes часто имеют специфичные паттерны
        forwarded_ips = request.headers.get('X-Forwarded-For', '').split(',')
        ip_address = forwarded_ips[0].strip()
    
    # Парсинг User-Agent
    user_agent_string = request.headers.get('User-Agent', 'Unknown')
    user_agent = parse(user_agent_string)
    
    # Сбор всех заголовков
    headers = dict(request.headers)
    
    # Извлечение cookies
    cookies = dict(request.cookies) if request.cookies else {}
    
    # Генерация session ID (если нет cookie)
    session_id = cookies.get('session_id') or hashlib.md5(
        f"{ip_address}{user_agent_string}{time.time()}".encode()
    ).hexdigest()[:16]
    
    # Генерация fingerprint
    fingerprint = generate_fingerprint(request, user_agent_string)
    
    # Определение типа подключения
    connection_type = 'Direct'
    if 'X-Forwarded-For' in request.headers:
        connection_type = 'Proxied'
    if request.headers.get('Via'):
        connection_type = 'Via-Proxy'
    
    # Сбор дополнительной информации
    client_info = {
        'timestamp': datetime.datetime.now().isoformat(),
        'ip_address': ip_address,
        'user_agent': user_agent_string,
        'browser': f"{user_agent.browser.family} {user_agent.browser.version_string}".strip(),
        'os': f"{user_agent.os.family} {user_agent.os.version_string}".strip(),
        'device': user_agent.device.family,
        'device_brand': getattr(user_agent.device, 'brand', 'Unknown'),
        'device_model': getattr(user_agent.device, 'model', 'Unknown'),
        'referer': request.headers.get('Referer', 'Direct'),
        'accept_language': request.headers.get('Accept-Language', 'Unknown'),
        'accept_encoding': request.headers.get('Accept-Encoding', 'Unknown'),
        'accept': request.headers.get('Accept', 'Unknown'),
        'headers': headers,
        'request_method': request.method,
        'request_path': request.path,
        'query_string': request.query_string.decode('utf-8') if request.query_string else '',
        'content_type': request.headers.get('Content-Type', ''),
        'content_length': request.headers.get('Content-Length', 0),
        'host': request.headers.get('Host', ''),
        'origin': request.headers.get('Origin', ''),
        'connection_type': connection_type,
        'cookies': cookies,
        'session_id': session_id,
        'fingerprint': fingerprint,
        'tor_exit_node': tor_exit_node,
        'scheme': request.scheme,
        'url': request.url,
        'remote_addr': request.environ.get('REMOTE_ADDR', 'Unknown'),
        'server_name': request.environ.get('SERVER_NAME', 'Unknown'),
        'server_port': request.environ.get('SERVER_PORT', 'Unknown'),
    }
    
    # Попытка определить screen resolution из заголовков (если доступно)
    if 'X-Screen-Resolution' in request.headers:
        client_info['screen_resolution'] = request.headers.get('X-Screen-Resolution')
    elif 'Viewport-Width' in request.headers:
        client_info['screen_resolution'] = f"{request.headers.get('Viewport-Width')}x{request.headers.get('Viewport-Height', 'Unknown')}"
    else:
        client_info['screen_resolution'] = 'Unknown'
    
    # Timezone (если доступно через JavaScript заголовки)
    client_info['timezone'] = request.headers.get('X-Timezone', 'Unknown')
    
    return client_info

def log_to_database(level, message, ip_address=None, request_path=None, exception=None):
    """Сохранение лога в базу данных"""
    try:
        db_path = os.path.join(DATA_DIR, 'intercepts.db')
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Получение информации о вызывающей функции
        import inspect
        frame = inspect.currentframe().f_back
        func_name = frame.f_code.co_name
        line_num = frame.f_lineno
        logger_name = frame.f_globals.get('__name__', 'unknown')
        
        cursor.execute('''
            INSERT INTO logs 
            (timestamp, level, logger_name, function_name, line_number, 
             message, ip_address, request_path, exception)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            datetime.datetime.now().isoformat(),
            level,
            logger_name,
            func_name,
            line_num,
            message,
            ip_address,
            request_path,
            str(exception) if exception else None
        ))
        conn.commit()
        conn.close()
    except Exception as e:
        # Не логируем ошибки логирования, чтобы избежать рекурсии
        pass

def save_intercept(client_info):
    """Расширенное сохранение перехваченной информации в базу данных"""
    try:
        db_path = os.path.join(DATA_DIR, 'intercepts.db')
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO intercepts 
            (timestamp, ip_address, user_agent, browser, os, device, 
             referer, accept_language, accept_encoding, headers, 
             request_method, request_path, query_string, content_type,
             content_length, host, origin, connection_type, screen_resolution,
             timezone, cookies, session_id, fingerprint, tor_exit_node, geolocation)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            client_info['timestamp'],
            client_info['ip_address'],
            client_info['user_agent'],
            client_info['browser'],
            client_info['os'],
            client_info['device'],
            client_info['referer'],
            client_info['accept_language'],
            client_info['accept_encoding'],
            json.dumps(client_info['headers']),
            client_info['request_method'],
            client_info['request_path'],
            client_info['query_string'],
            client_info['content_type'],
            client_info.get('content_length', 0),
            client_info['host'],
            client_info['origin'],
            client_info['connection_type'],
            client_info.get('screen_resolution', 'Unknown'),
            client_info.get('timezone', 'Unknown'),
            json.dumps(client_info['cookies']),
            client_info['session_id'],
            client_info['fingerprint'],
            client_info.get('tor_exit_node'),
            None  # geolocation - можно добавить позже через API
        ))
        intercept_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return intercept_id
        
        # Сохранение в JSON файл
        safe_ip = client_info['ip_address'].replace('.', '_').replace(':', '_')
        filename = f"{REPORTS_DIR}/intercept_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}_{safe_ip}.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(client_info, f, ensure_ascii=False, indent=2)
        
        # Расширенное логирование перехвата
        intercept_logger.info(
            f"Перехвачен запрос",
            extra={
                'ip': client_info['ip_address'],
                'method': client_info['request_method'],
                'path': client_info['request_path'],
                'browser': client_info['browser']
            }
        )
        
        # Логирование в базу данных
        log_to_database(
            'INFO',
            f"Intercept: {client_info['request_method']} {client_info['request_path']} from {client_info['ip_address']}",
            ip_address=client_info['ip_address'],
            request_path=client_info['request_path']
        )
        
        logger.debug(f"Детали перехвата: IP={client_info['ip_address']}, "
                    f"Browser={client_info['browser']}, "
                    f"OS={client_info['os']}, "
                    f"Fingerprint={client_info['fingerprint']}")
        
    except Exception as e:
        error_msg = f"Ошибка сохранения данных: {e}"
        logger.error(error_msg, exc_info=True)
        log_to_database('ERROR', error_msg, exception=e)

# Middleware для логирования всех запросов
@app.before_request
def log_request():
    """Логирование всех входящих запросов"""
    logger.debug(f"Входящий запрос: {request.method} {request.path} от {request.remote_addr}")

@app.after_request
def log_response(response):
    """Логирование ответов"""
    logger.debug(f"Ответ: {response.status_code} для {request.method} {request.path}")
    return response

@app.route('/')
def index():
    """Главная страница - маскировочный сайт или перехват"""
    # Проверяем параметр для выбора режима
    mode = request.args.get('mode', 'mask')  # mask или intercept
    
    if mode == 'mask':
        # Показываем маскировочный сайт
        return render_template('mask_site.html'), 200
    else:
        # Прямой перехват
        client_info = get_client_info(request)
        threading.Thread(target=save_intercept, args=(client_info,)).start()
        return render_template('error.html'), 500

@app.route('/intercept')
def intercept_page():
    """Intercept page - collects data and shows report"""
    client_info = get_client_info(request)
    
    # Save information
    intercept_id = save_intercept(client_info)
    
    lang = get_locale()
    locale = load_locale(lang)
    template_path = f'{lang}/caught_report.html' if lang != 'en' else 'en/caught_report.html'
    
    # Pass data to report template
    return render_template(template_path, 
                         intercept_data=client_info,
                         locale=locale), 200

@app.route('/mask')
def mask_site():
    """Mask site - looks like a regular site"""
    # Collect data even from mask site
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    
    lang = get_locale()
    template_path = f'{lang}/mask_site.html' if lang != 'en' else 'en/mask_site.html'
    
    return render_template(template_path), 200

@app.route('/api/intercept-data')
def get_intercept_data():
    """API для получения данных последнего перехвата (для отчета)"""
    try:
        db_path = os.path.join(DATA_DIR, 'intercepts.db')
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Получаем последний перехват
        cursor.execute('''
            SELECT * FROM intercepts 
            ORDER BY timestamp DESC 
            LIMIT 1
        ''')
        
        report = cursor.fetchone()
        conn.close()
        
        if report:
            report_dict = {
                'id': report[0],
                'timestamp': report[1],
                'ip_address': report[2],
                'user_agent': report[3],
                'browser': report[4],
                'os': report[5],
                'device': report[6],
                'referer': report[7],
                'accept_language': report[8],
                'accept_encoding': report[9],
                'headers': json.loads(report[10]) if report[10] else {},
                'request_method': report[11],
                'request_path': report[12],
                'query_string': report[13] if len(report) > 13 else '',
                'fingerprint': report[22] if len(report) > 22 else '',
                'session_id': report[21] if len(report) > 21 else '',
            }
            return jsonify(report_dict)
        else:
            return jsonify({'error': 'No intercepts found'}), 404
            
    except Exception as e:
        logger.error(f"Ошибка получения данных перехвата: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500

@app.route('/error')
def error_page():
    """Дополнительная страница ошибки"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return render_template('error.html'), 404

@app.route('/admin/reports')
def admin_reports():
    """Административная панель для просмотра отчетов"""
    try:
        db_path = os.path.join(DATA_DIR, 'intercepts.db')
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM intercepts ORDER BY timestamp DESC LIMIT 100')
        reports = cursor.fetchall()
        conn.close()
        
        logger.info(f"Загружено {len(reports)} отчетов для админ панели")
        return render_template('admin.html', reports=reports, onion_address=ONION_ADDRESS)
    except Exception as e:
        error_msg = f"Ошибка загрузки отчетов: {e}"
        logger.error(error_msg, exc_info=True)
        log_to_database('ERROR', error_msg, exception=e)
        return f"Ошибка загрузки отчетов: {e}", 500

@app.route('/admin/api/reports')
def api_reports():
    """API для получения отчетов в JSON формате"""
    try:
        db_path = os.path.join(DATA_DIR, 'intercepts.db')
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM intercepts ORDER BY timestamp DESC LIMIT 50')
        reports = cursor.fetchall()
        conn.close()
        
        # Преобразуем в список словарей (с учетом новых полей)
        report_list = []
        for report in reports:
            report_dict = {
                'id': report[0],
                'timestamp': report[1],
                'ip_address': report[2],
                'user_agent': report[3],
                'browser': report[4],
                'os': report[5],
                'device': report[6],
                'referer': report[7],
                'accept_language': report[8],
                'accept_encoding': report[9],
                'headers': json.loads(report[10]) if report[10] else {},
                'request_method': report[11],
                'request_path': report[12],
                'query_string': report[13] if len(report) > 13 else '',
                'fingerprint': report[22] if len(report) > 22 else '',
                'session_id': report[21] if len(report) > 21 else '',
                'connection_type': report[17] if len(report) > 17 else '',
            }
            report_list.append(report_dict)
        
        logger.info(f"API запрос: возвращено {len(report_list)} отчетов")
        return jsonify({
            'reports': report_list,
            'total': len(report_list),
            'onion_address': ONION_ADDRESS
        })
    except Exception as e:
        error_msg = f"Ошибка API: {e}"
        logger.error(error_msg, exc_info=True)
        log_to_database('ERROR', error_msg, exception=e)
        return jsonify({'error': str(e)}), 500

@app.route('/robots.txt')
def robots():
    """Robots.txt для маскировки"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return "User-agent: *\nDisallow: /", 200, {'Content-Type': 'text/plain'}

@app.route('/favicon.ico')
def favicon():
    """Favicon запрос - также перехватываем"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return "", 404

# Перехват всех остальных путей
# Маршруты для маскировочного сайта
@app.route('/article/<path:article>')
def article_page(article):
    """Страницы статей - перенаправление на перехват"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    # Перенаправление на страницу перехвата
    return redirect('/intercept?ref=article&article=' + article, code=302)

@app.route('/tech')
@app.route('/ai')
@app.route('/security')
@app.route('/about')
@app.route('/popular/<path:popular>')
def category_pages(popular=None):
    """Категории и популярные статьи - перенаправление"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return redirect('/intercept?ref=category', code=302)

@app.route('/privacy')
@app.route('/terms')
def legal_pages():
    """Юридические страницы - перенаправление"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    return redirect('/intercept?ref=legal', code=302)

@app.route('/<path:path>')
def catch_all(path):
    """Перехват всех остальных запросов"""
    client_info = get_client_info(request)
    threading.Thread(target=save_intercept, args=(client_info,)).start()
    
    # Если это запрос на маскировочный сайт, показываем его
    if path in ['', 'index', 'home']:
        return render_template('mask_site.html'), 200
    
    # Иначе показываем страницу перехвата
    return redirect('/intercept?ref=' + path, code=302)

if __name__ == '__main__':
    # Инициализация базы данных
    init_db()
    
    # Попытка получить .onion адрес (если еще не получен)
    current_onion = ONION_ADDRESS
    if not current_onion:
        time.sleep(2)  # Даем время Tor запуститься
        current_onion = get_onion_address()
        # Обновляем глобальную переменную
        globals()['ONION_ADDRESS'] = current_onion
    
    # Получение сетевой информации
    network_info = get_network_info()
    port = int(os.environ.get('FLASK_PORT', 5000))
    
    # Запуск сервера
    print("\n" + "="*60)
    print("🚀 Запуск Web Server Interceptor")
    print("="*60)
    
    print(f"\n🌐 Сетевые адреса:")
    print(f"   - Hostname: {network_info['hostname']}")
    if network_info['local_ip']:
        print(f"   - Локальный IP: {network_info['local_ip']}")
    if network_info['public_ip']:
        print(f"   - Публичный IP: {network_info['public_ip']}")
    if network_info['interfaces']:
        print(f"   - Сетевые интерфейсы: {', '.join(network_info['interfaces'])}")
    
    print(f"\n📊 Административная панель:")
    print(f"   - Localhost:  http://localhost:{port}/admin/reports")
    if network_info['local_ip']:
        print(f"   - Локальная сеть:  http://{network_info['local_ip']}:{port}/admin/reports")
    if network_info['public_ip']:
        print(f"   - Публичный IP:  http://{network_info['public_ip']}:{port}/admin/reports")
    if current_onion:
        print(f"   - Tor (.onion):   http://{current_onion}/admin/reports")
    
    print(f"\n🎭 Маскировочный сайт (entrypoint):")
    print(f"   - Localhost:  http://localhost:{port}/mask")
    if network_info['local_ip']:
        print(f"   - Локальная сеть:  http://{network_info['local_ip']}:{port}/mask")
    if network_info['public_ip']:
        print(f"   - Публичный IP:  http://{network_info['public_ip']}:{port}/mask")
    if current_onion:
        print(f"   - Tor (.onion):   http://{current_onion}/mask")
    
    print(f"\n📊 Страница перехвата (шуточный отчет):")
    print(f"   - Localhost:  http://localhost:{port}/intercept")
    if network_info['local_ip']:
        print(f"   - Локальная сеть:  http://{network_info['local_ip']}:{port}/intercept")
    if network_info['public_ip']:
        print(f"   - Публичный IP:  http://{network_info['public_ip']}:{port}/intercept")
    if current_onion:
        print(f"   - Tor (.onion):   http://{current_onion}/intercept")
    
    print(f"\n📡 Основной сайт:")
    print(f"   - Localhost:  http://localhost:{port}")
    if network_info['local_ip']:
        print(f"   - Локальная сеть:  http://{network_info['local_ip']}:{port}")
    if network_info['public_ip']:
        print(f"   - Публичный IP:  http://{network_info['public_ip']}:{port}")
    if current_onion:
        print(f"   - Tor (.onion):   http://{current_onion}")
    
    print(f"\n🔧 API:")
    print(f"   - Localhost:  http://localhost:{port}/admin/api/reports")
    if network_info['local_ip']:
        print(f"   - Локальная сеть:  http://{network_info['local_ip']}:{port}/admin/api/reports")
    if network_info['public_ip']:
        print(f"   - Публичный IP:  http://{network_info['public_ip']}:{port}/admin/api/reports")
    if current_onion:
        print(f"   - Tor (.onion):   http://{current_onion}/admin/api/reports")
    print(f"\n📁 Логи:")
    print(f"   - Основной:     {LOGS_DIR}/interceptor.log")
    print(f"   - Перехваты:    {LOGS_DIR}/intercepts.log")
    print(f"   - Ошибки:       {LOGS_DIR}/errors.log")
    print(f"   - Ежедневный:   {LOGS_DIR}/daily.log")
    print(f"\n💾 База данных: {DATA_DIR}/intercepts.db")
    print(f"📊 Отчеты: {REPORTS_DIR}/")
    print("="*60 + "\n")
    
    logger.info("Web Server Interceptor запущен")
    if current_onion:
        logger.info(f"Tor Hidden Service доступен: http://{current_onion}")
    else:
        logger.warning("Tor Hidden Service не найден, используется только HTTP")
    
    # Получение порта из переменной окружения или использование по умолчанию
    port = int(os.environ.get('FLASK_PORT', 5000))
    
    logger.info(f"Сервер слушает на 0.0.0.0:{port} (доступен извне)")
    if network_info['public_ip']:
        logger.info(f"Публичный IP: {network_info['public_ip']}")
    if current_onion:
        logger.info(f"Tor Hidden Service: http://{current_onion}")
    
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
