#!/usr/bin/env python3
"""
Утилита для просмотра логов Web Server Interceptor
"""

import sqlite3
import os
import sys
from datetime import datetime, timedelta
import json

DATA_DIR = "data"
LOGS_DIR = "logs"
DB_PATH = os.path.join(DATA_DIR, 'intercepts.db')

def print_header(text):
    """Красивый вывод заголовка"""
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def view_recent_intercepts(limit=20):
    """Просмотр последних перехватов"""
    if not os.path.exists(DB_PATH):
        print("❌ База данных не найдена")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT timestamp, ip_address, request_method, request_path, 
               browser, os, fingerprint
        FROM intercepts 
        ORDER BY timestamp DESC 
        LIMIT ?
    ''', (limit,))
    
    intercepts = cursor.fetchall()
    conn.close()
    
    print_header(f"Последние {len(intercepts)} перехватов")
    
    for i, intercept in enumerate(intercepts, 1):
        timestamp, ip, method, path, browser, os_info, fingerprint = intercept
        print(f"\n{i}. {timestamp}")
        print(f"   IP: {ip}")
        print(f"   {method} {path}")
        print(f"   Browser: {browser}")
        print(f"   OS: {os_info}")
        print(f"   Fingerprint: {fingerprint[:16]}...")

def view_statistics():
    """Просмотр статистики"""
    if not os.path.exists(DB_PATH):
        print("❌ База данных не найдена")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Общая статистика
    cursor.execute('SELECT COUNT(*) FROM intercepts')
    total = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(DISTINCT ip_address) FROM intercepts')
    unique_ips = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(DISTINCT fingerprint) FROM intercepts')
    unique_fingerprints = cursor.fetchone()[0]
    
    # Статистика за сегодня
    today = datetime.now().date().isoformat()
    cursor.execute('SELECT COUNT(*) FROM intercepts WHERE DATE(timestamp) = ?', (today,))
    today_count = cursor.fetchone()[0]
    
    # Топ IP адресов
    cursor.execute('''
        SELECT ip_address, COUNT(*) as count 
        FROM intercepts 
        GROUP BY ip_address 
        ORDER BY count DESC 
        LIMIT 10
    ''')
    top_ips = cursor.fetchall()
    
    # Топ браузеров
    cursor.execute('''
        SELECT browser, COUNT(*) as count 
        FROM intercepts 
        WHERE browser IS NOT NULL 
        GROUP BY browser 
        ORDER BY count DESC 
        LIMIT 10
    ''')
    top_browsers = cursor.fetchall()
    
    conn.close()
    
    print_header("Статистика")
    print(f"\n📊 Общая статистика:")
    print(f"   Всего перехватов: {total}")
    print(f"   Уникальных IP: {unique_ips}")
    print(f"   Уникальных fingerprint: {unique_fingerprints}")
    print(f"   Перехватов сегодня: {today_count}")
    
    print(f"\n🔝 Топ-10 IP адресов:")
    for ip, count in top_ips:
        print(f"   {ip:20s} - {count:4d} запросов")
    
    print(f"\n🌐 Топ-10 браузеров:")
    for browser, count in top_browsers:
        browser_short = browser[:50] + "..." if len(browser) > 50 else browser
        print(f"   {browser_short:50s} - {count:4d}")

def view_logs_from_db(level=None, limit=50):
    """Просмотр логов из базы данных"""
    if not os.path.exists(DB_PATH):
        print("❌ База данных не найдена")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    if level:
        cursor.execute('''
            SELECT timestamp, level, logger_name, function_name, 
                   message, ip_address, request_path
            FROM logs 
            WHERE level = ?
            ORDER BY timestamp DESC 
            LIMIT ?
        ''', (level.upper(), limit))
    else:
        cursor.execute('''
            SELECT timestamp, level, logger_name, function_name, 
                   message, ip_address, request_path
            FROM logs 
            ORDER BY timestamp DESC 
            LIMIT ?
        ''', (limit,))
    
    logs = cursor.fetchall()
    conn.close()
    
    level_text = f" ({level.upper()})" if level else ""
    print_header(f"Последние {len(logs)} логов{level_text}")
    
    for log in logs:
        timestamp, level, logger_name, func_name, message, ip, path = log
        print(f"\n[{level}] {timestamp}")
        print(f"   {logger_name}.{func_name}")
        print(f"   {message}")
        if ip:
            print(f"   IP: {ip}")
        if path:
            print(f"   Path: {path}")

def view_file_logs(log_type='interceptor', lines=50):
    """Просмотр логов из файлов"""
    log_files = {
        'interceptor': f'{LOGS_DIR}/interceptor.log',
        'intercepts': f'{LOGS_DIR}/intercepts.log',
        'errors': f'{LOGS_DIR}/errors.log',
        'daily': f'{LOGS_DIR}/daily.log'
    }
    
    log_file = log_files.get(log_type)
    if not log_file or not os.path.exists(log_file):
        print(f"❌ Лог файл не найден: {log_file}")
        return
    
    print_header(f"Последние {lines} строк из {log_type}.log")
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            all_lines = f.readlines()
            for line in all_lines[-lines:]:
                print(line.rstrip())
    except Exception as e:
        print(f"❌ Ошибка чтения файла: {e}")

def get_onion_address():
    """Получение .onion адреса"""
    onion_paths = [
        'data/onion_address.txt',
        '/tmp/tor_interceptor/hidden_service/hostname',
        '/var/lib/tor-interceptor/hidden_service/hostname'
    ]
    
    for path in onion_paths:
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    address = f.read().strip()
                    if address.endswith('.onion'):
                        return address
            except:
                continue
    return None

def main():
    """Основная функция"""
    if len(sys.argv) < 2:
        print("""
📋 Утилита просмотра логов Web Server Interceptor

Использование:
  python3 view_logs.py intercepts [limit]    - Последние перехваты
  python3 view_logs.py stats                 - Статистика
  python3 view_logs.py logs [level] [limit]  - Логи из БД (level: INFO, ERROR, DEBUG)
  python3 view_logs.py file [type] [lines]   - Логи из файлов
  python3 view_logs.py onion                 - Показать .onion адрес

Типы файлов логов:
  interceptor  - Основной лог
  intercepts   - Лог перехватов
  errors       - Лог ошибок
  daily        - Ежедневный лог

Примеры:
  python3 view_logs.py intercepts 50
  python3 view_logs.py logs ERROR 20
  python3 view_logs.py file errors 100
  python3 view_logs.py stats
        """)
        return
    
    command = sys.argv[1].lower()
    
    if command == 'intercepts':
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 20
        view_recent_intercepts(limit)
    
    elif command == 'stats':
        view_statistics()
    
    elif command == 'logs':
        level = sys.argv[2] if len(sys.argv) > 2 else None
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 50
        view_logs_from_db(level, limit)
    
    elif command == 'file':
        log_type = sys.argv[2] if len(sys.argv) > 2 else 'interceptor'
        lines = int(sys.argv[3]) if len(sys.argv) > 3 else 50
        view_file_logs(log_type, lines)
    
    elif command == 'onion':
        address = get_onion_address()
        if address:
            print_header(".onion адрес")
            print(f"\n🧅 Hidden Service: http://{address}")
            print(f"\nДоступные URL:")
            print(f"   Основной сайт: http://{address}")
            print(f"   Админ панель: http://{address}/admin/reports")
            print(f"   API: http://{address}/admin/api/reports")
        else:
            print("❌ .onion адрес не найден")
            print("   Убедитесь, что Tor запущен и hidden service создан")
    
    else:
        print(f"❌ Неизвестная команда: {command}")

if __name__ == '__main__':
    main()
