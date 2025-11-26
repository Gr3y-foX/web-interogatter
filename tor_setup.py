#!/usr/bin/env python3
"""
Tor Proxy Setup - Настройка анонимизации трафика через Tor
Для образовательных целей в области кибербезопасности
"""

import os
import sys
import subprocess
import time
import requests
from stem import Signal
from stem.control import Controller
import configparser

class TorManager:
    def __init__(self, tor_port=9050, control_port=9051):
        self.tor_port = tor_port
        self.control_port = control_port
        self.tor_process = None
        
    def check_tor_installation(self):
        """Проверка установки Tor"""
        try:
            result = subprocess.run(['tor', '--version'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print("✅ Tor установлен:", result.stdout.split('\n')[0])
                return True
            else:
                print("❌ Tor не найден")
                return False
        except FileNotFoundError:
            print("❌ Tor не установлен")
            return False
    
    def install_tor_debian(self):
        """Установка Tor на Debian/Ubuntu/Kali"""
        print("🔧 Установка Tor на Debian/Ubuntu/Kali...")
        try:
            subprocess.run(['sudo', 'apt', 'update'], check=True)
            subprocess.run(['sudo', 'apt', 'install', '-y', 'tor'], check=True)
            print("✅ Tor успешно установлен")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Ошибка установки Tor: {e}")
            return False
    
    def create_tor_config(self):
        """Создание конфигурационного файла для Tor"""
        config_content = f"""
# Tor Configuration for Web Server Interceptor
# Порт для SOCKS прокси
SocksPort {self.tor_port}

# Порт для управления
ControlPort {self.control_port}

# Пароль для управления (хешированный)
HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C

# Директория данных
DataDirectory /tmp/tor_interceptor

# Логирование
Log notice file /tmp/tor_interceptor/tor.log

# Дополнительные настройки безопасности
ExitPolicy reject *:*
ExitRelay 0
PublishServerDescriptor 0

# Настройки для скрытого сервиса (опционально)
HiddenServiceDir /tmp/tor_interceptor/hidden_service/
HiddenServicePort 80 127.0.0.1:5000

# Настройки производительности
NumCPUs 2
MaxCircuitDirtiness 600
NewCircuitPeriod 30
MaxClientCircuitsPending 32
"""
        
        os.makedirs('/tmp/tor_interceptor', exist_ok=True)
        
        with open('/tmp/tor_interceptor/torrc', 'w') as f:
            f.write(config_content)
        
        print("✅ Конфигурация Tor создана: /tmp/tor_interceptor/torrc")
    
    def start_tor(self):
        """Запуск Tor с кастомной конфигурацией"""
        if not self.check_tor_installation():
            if sys.platform.startswith('linux'):
                self.install_tor_debian()
            else:
                print("❌ Пожалуйста, установите Tor вручную")
                return False
        
        self.create_tor_config()
        
        try:
            print("🚀 Запуск Tor...")
            self.tor_process = subprocess.Popen([
                'tor', '-f', '/tmp/tor_interceptor/torrc'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Ждем запуска Tor
            time.sleep(10)
            
            if self.tor_process.poll() is None:
                print("✅ Tor успешно запущен")
                print(f"📡 SOCKS прокси: 127.0.0.1:{self.tor_port}")
                print(f"🎛️  Управление: 127.0.0.1:{self.control_port}")
                return True
            else:
                print("❌ Ошибка запуска Tor")
                return False
                
        except Exception as e:
            print(f"❌ Ошибка запуска Tor: {e}")
            return False
    
    def stop_tor(self):
        """Остановка Tor"""
        if self.tor_process:
            print("🛑 Остановка Tor...")
            self.tor_process.terminate()
            self.tor_process.wait()
            print("✅ Tor остановлен")
    
    def get_new_identity(self):
        """Получение нового IP адреса через Tor"""
        try:
            with Controller.from_port(port=self.control_port) as controller:
                controller.authenticate(password="interceptor_password")
                controller.signal(Signal.NEWNYM)
                print("🔄 Получен новый IP адрес")
                time.sleep(5)  # Ждем смены IP
                return True
        except Exception as e:
            print(f"❌ Ошибка смены IP: {e}")
            return False
    
    def check_ip(self):
        """Проверка текущего IP адреса"""
        proxies = {
            'http': f'socks5://127.0.0.1:{self.tor_port}',
            'https': f'socks5://127.0.0.1:{self.tor_port}'
        }
        
        try:
            # Проверка IP без прокси
            response = requests.get('https://httpbin.org/ip', timeout=10)
            real_ip = response.json()['origin']
            print(f"🌐 Реальный IP: {real_ip}")
            
            # Проверка IP через Tor
            response = requests.get('https://httpbin.org/ip', 
                                  proxies=proxies, timeout=30)
            tor_ip = response.json()['origin']
            print(f"🧅 IP через Tor: {tor_ip}")
            
            if real_ip != tor_ip:
                print("✅ Tor работает корректно!")
                return True
            else:
                print("❌ Tor не работает или не используется")
                return False
                
        except Exception as e:
            print(f"❌ Ошибка проверки IP: {e}")
            return False
    
    def get_hidden_service_address(self):
        """Получение адреса скрытого сервиса"""
        hostname_paths = [
            '/tmp/tor_interceptor/hidden_service/hostname',
            '/var/lib/tor-interceptor/hidden_service/hostname',
            'data/onion_address.txt'
        ]
        
        for hostname_file in hostname_paths:
            try:
                if os.path.exists(hostname_file):
                    with open(hostname_file, 'r') as f:
                        address = f.read().strip()
                    if address.endswith('.onion'):
                        print(f"🧅 Адрес скрытого сервиса: {address}")
                        
                        # Сохранение адреса в data директорию для app.py
                        os.makedirs('data', exist_ok=True)
                        with open('data/onion_address.txt', 'w') as f:
                            f.write(address)
                        
                        return address
            except Exception as e:
                continue
        
        print("⏳ Скрытый сервис еще не готов, подождите...")
        return None

def main():
    """Основная функция для управления Tor"""
    tor_manager = TorManager()
    
    if len(sys.argv) < 2:
        print("""
🧅 Tor Manager для Web Server Interceptor

Использование:
  python3 tor_setup.py start    - Запустить Tor
  python3 tor_setup.py stop     - Остановить Tor
  python3 tor_setup.py check    - Проверить IP
  python3 tor_setup.py newip    - Получить новый IP
  python3 tor_setup.py hidden   - Показать адрес скрытого сервиса
  python3 tor_setup.py install  - Установить Tor (только Linux)
""")
        return
    
    command = sys.argv[1].lower()
    
    if command == 'start':
        tor_manager.start_tor()
        time.sleep(5)
        tor_manager.check_ip()
        
        # Показываем адрес скрытого сервиса
        for i in range(6):  # Пытаемся 6 раз с интервалом в 10 секунд
            address = tor_manager.get_hidden_service_address()
            if address:
                break
            time.sleep(10)
    
    elif command == 'stop':
        tor_manager.stop_tor()
    
    elif command == 'check':
        tor_manager.check_ip()
    
    elif command == 'newip':
        tor_manager.get_new_identity()
        time.sleep(5)
        tor_manager.check_ip()
    
    elif command == 'hidden':
        tor_manager.get_hidden_service_address()
    
    elif command == 'install':
        if sys.platform.startswith('linux'):
            tor_manager.install_tor_debian()
        else:
            print("❌ Автоматическая установка доступна только на Linux")
    
    else:
        print(f"❌ Неизвестная команда: {command}")

if __name__ == '__main__':
    main()
