#!/usr/bin/env python3
"""
Скрипт миграции базы данных для добавления новых колонок
"""

import sqlite3
import os

DATA_DIR = "data"
DB_PATH = os.path.join(DATA_DIR, 'intercepts.db')

# Обратная совместимость
old_db_path = 'intercepts.db'
if os.path.exists(old_db_path) and not os.path.exists(DB_PATH):
    import shutil
    shutil.move(old_db_path, DB_PATH)
    print(f"✅ База данных перенесена из {old_db_path} в {DB_PATH}")

if not os.path.exists(DB_PATH):
    print(f"❌ База данных не найдена: {DB_PATH}")
    print("   База будет создана при следующем запуске приложения")
    exit(0)

print(f"📊 Миграция базы данных: {DB_PATH}")

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Проверка существующих колонок
cursor.execute("PRAGMA table_info(intercepts)")
existing_columns = [row[1] for row in cursor.fetchall()]

print(f"   Найдено колонок: {len(existing_columns)}")

# Новые колонки для добавления
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

added_count = 0
for column_name, column_type in new_columns.items():
    if column_name not in existing_columns:
        try:
            cursor.execute(f"ALTER TABLE intercepts ADD COLUMN {column_name} {column_type}")
            print(f"   ✅ Добавлена колонка: {column_name}")
            added_count += 1
        except sqlite3.OperationalError as e:
            print(f"   ❌ Ошибка добавления {column_name}: {e}")
    else:
        print(f"   ✓ Колонка уже существует: {column_name}")

conn.commit()
conn.close()

if added_count > 0:
    print(f"\n✅ Миграция завершена. Добавлено колонок: {added_count}")
else:
    print(f"\n✅ База данных уже актуальна. Все колонки на месте.")

print(f"\n💡 Теперь можно перезапустить сервер: ./run.sh start")
