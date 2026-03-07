# Полное руководство по подключениям и WiFi для Trinity FPGA

## Часть 1: Куда подключать DSlogic Plus?

### Точки подключения на FPGA плате

```
┌─────────────────────────────────────────────────────────────────────┐
│              QMTECH XC7A100TFGG676 - Точки подключения             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    FPGA Chip (BGA676)                        │  │
│  │                                                               │  │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │  │
│  │   │ Bank 0  │  │ Bank 14 │  │ Bank 34 │  │ Bank 35 │← ESP32 │  │
│  │   │  (3.3V) │  │  (3.3V) │  │  (3.3V) │  │  (3.3V) │         │  │
│  │   └─────────┘  └─────────┘  └─────────┘  └─────────┘        │  │
│  │                                                               │  │
│  │   Всего: ~300+ пользовательских пинов!                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  PLS-EXT разъём (если есть)                                  │   │
│  │  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐                  │   │
│  │  │GND│VCC│IO1│IO2│IO3│IO4│IO5│IO6│IO7│IO8│ ...              │   │
│  │  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 16 каналов — на что хватит?

| Канал | Сигнал | Описание |
|-------|--------|----------|
| CH0 | ESP32_TX → FPGA_RX | UART данные |
| CH1 | FPGA_TX → ESP32_RX | UART данные |
| CH2 | ESP32_SCLK | SPI clock |
| CH3 | ESP32_MOSI | SPI данные → FPGA |
| CH4 | ESP32_MISO | SPI данные → ESP32 |
| CH5 | ESP32_CS | SPI chip select |
| CH6 | FPGA_CLK | 50 MHz системный клок |
| CH7 | LED output | Статус LED |
| CH8 | VSA_result[0] | Результат VSA |
| CH9 | VSA_result[1] | Результат VSA |
| CH10 | state[0] | FSM состояние |
| CH11 | state[1] | FSM состояние |
| CH12 | trigger_out | Триггер для осциллографа |
| CH13 | spare | Запас |
| CH14 | spare | Запас |
| CH15 | spare | Запас |

### Как физически подключаться

**Метод 1: Pogo Pin тестовые точки**
```
        ┌─────┐
        │  ○  │ ← Pogo pin прижимается к пину
        └─────┘
           │
           │ ← Пружинный зонд
           │
        ┌───┴───┐
        │ DSlogic│
        └───────┘
```

**Метод 2: Test clips (крокодилы)**
```
FPGA Pin ──[🔧 крокодил]─── Wire ──── DSlogic CH0
```

**Метод 3: Монтажные провода**
```
FPGA Pin ──┐
           │ ← Dupont провод (male-to-female)
DSlogic ───┘
```

---

## Часть 2: WiFi на FPGA

### Варианты подключения WiFi

```
┌─────────────────────────────────────────────────────────────────────┐
│                      WiFi Опции для FPGA                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Вариант 1: ESP32 как мост (РЕКОМЕНДУЕТСЯ)                          │
│  ┌─────────┐    UART/SPI    ┌─────────┐    Ethernet/WiFi        │  │
│  │ ESP32   │ ←────────────→ │  FPGA   │ ←───────────────────────│  │
│  │ + WiFi  │                │         │                         │  │
│  └─────────┘                └─────────┘                         │  │
│       │                                                           │  │
│       └─── WiFi AP → Пользователи подключаются                    │  │
│                                                                     │
│  Вариант 2: Ethernet PHY + WiFi Router                             │
│  ┌─────────┐    RGMII      ┌─────────┐    ┌──────────┐          │  │
│  │  FPGA   │ ←────────────→│ Ethernet│ ←→│ WiFi AP  │          │  │
│  └─────────┘               │   PHY   │    └──────────┘          │  │
│                             └─────────┘                           │  │
│                                                                     │
│  Вариант 3: ESP32 WROVER с Ethernet                                │
│  ┌─────────┐    SPI         ┌─────────┐    ┌──────────┐          │  │
│  │ESP32-WRO│ ←────────────→ │  FPGA   │    │ Ethernet │          │  │
│  │+WiFi+Eth│                │         │    │ + WiFi   │          │  │
│  └─────────┘                └─────────┘    └──────────┘          │  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### РЕКОМЕНДАЦИЯ: ESP32 как WiFi мост

**Почему это лучший вариант:**

| Плюс | Объяснение |
|------|------------|
| ✅ Простой | Уже есть UART мост |
| ✅ Дёшево | ESP32 стоит ~$5 |
| � | WiFi + Bluetooth |
| ✅ HTTPS | ESP32 поддерживает TLS |
| ✅ Лёгкий UI | Web интерфейс |
| ✅ OTA | Обновление по воздуху |

---

## Часть 3: Архитектура системы для пользователей

```
┌─────────────────────────────────────────────────────────────────────┐
│               Trinity FPGA System - User Experience                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                         ПОЛЬЗОВАТЕЛЬ                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │   Web UI    │  │ Mobile App  │  │   CLI Tool  │         │   │
│  │  │  (Browser)  │  │  (iOS/Android)│  │  (Python)   │         │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │   │
│  └─────────┼─────────────────┼─────────────────┼────────────────┘   │
│            │                 │                 │                    │
│            └─────────────────┼─────────────────┘                    │
│                              │                                      │
│                         WiFi/Ethernet                              │
│                              │                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    ESP32 Gateway                               │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │ │
│  │  │   WiFi AP   │    │  Web Server │    │   REST API  │       │ │
│  │  │   (mDNS)    │    │  (Port 80)  │    │  (Port 8080)│       │ │
│  │  └─────────────┘    └──────┬──────┘    └──────┬──────┘       │ │
│  │                            │                   │               │ │
│  │  ┌──────────────────────────────────────────────────────┐     │ │
│  │  │            Protocol Bridge (UART/SPI)                │     │ │
│  │  └────────────────────┬───────────────────────────────┘     │ │
│  └───────────────────────┼──────────────────────────────────────┘ │
│                            │ UART/SPI                              │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Trinity FPGA                               │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │ │
│  │  │   VSA Core  │    │   Control   │    │  Interface  │       │ │
│  │  │  (Compute)  │    │   Logic     │    │   Bridge    │       │ │
│  │  └─────────────┘    └──────┬──────┘    └─────────────┘       │ │
│  └───────────────────────────────┼───────────────────────────────┘ │
│                                  │                                  │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Results/Output                             │ │
│  │  • LED indication                                              │ │
│  │  • 7-segment display (опц.)                                    │ │
│  │  • HDMI/Video output (опц.)                                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Часть 4: Как пользователи будут работать

### Сценарий 1: Web UI (самый простой)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Пользователь открывает браузер:                                  │
│                                                                     │
│  1. Подключиться к WiFi: "Trinity-FPGA"                           │
│  2. Перейти на: http://trinity.local  (или 192.168.4.1)           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Trinity Control Panel                    │   │
│  │  ╔═════════════════════════════════════════════════════════╗ │   │
│  │  ║  Status:                                               ║ │   │
│  │  ║    ○ FPGA: Running                                     ║ │   │
│  │  ║    ○ VSA: Active (157 MOPS)                            ║ │   │
│  │  ║    ○ Temperature: 42°C                                  ║ │   │
│  │  ║                                                         ║ │   │
│  │  ║  Controls:                                              ║ │   │
│  │  ║    [LED ON]  [LED OFF]  [BLINK]                         ║ │   │
│  │  ║                                                         ║ │   │
│  │  ║  VSA Operations:                                        ║ │   │
│  │  ║    Vector: [__________________________________]        ║ │   │
│  │  ║    Search: [______________________] [SEARCH]           ║ │   │
│  │  ║                                                         ║ │   │
│  │  ║  Results:                                               ║ │   │
│  │  ║    1. item_123.vsa   similarity: 0.95                  ║ │   │
│  │  ║    2. item_456.vsa   similarity: 0.87                  ║ │   │
│  │  ║                                                         ║ │   │
│  │  ║  [Upload]  [Download]  [Settings]                      ║ │   │
│  │  ╚═════════════════════════════════════════════════════════╝ │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Сценарий 2: Mobile App

```
┌─────────────────────────────────────────────────────────────────────┐
│  Trinity Mobile App (iOS/Android)                                  │
│                                                                     │
│  ┌───────────────────────────────────────────┐                     │
│  │  ┌─────────────────────────────────────┐  │                     │
│  │  │         TRINITY                     │  │                     │
│  │  │    φ² + 1/φ² = 3                    │  │                     │
│  │  ├─────────────────────────────────────┤  │                     │
│  │  │                                     │  │                     │
│  │  │  Status: ● Running                  │  │                     │
│  │  │  MOPS:   157                         │  │                     │
│  │  │  Temp:   42°C                         │  │                     │
│  │  │                                     │  │                     │
│  │  │  ┌─────┐ ┌─────┐ ┌─────┐            │  │                     │
│  │  │  │ LED │ │VSA  │ │CFG  │            │  │                     │
│  │  │  │ ON  │ │RUN  │ │     │            │  │                     │
│  │  │  └─────┘ └─────┘ └─────┘            │  │                     │
│  │  │                                     │  │                     │
│  │  │  Results:                            │  │                     │
│  │  │  □ item_123 (95%)                    │  │                     │
│  │  │  □ item_456 (87%)                    │  │                     │
│  │  │                                     │  │                     │
│  │  └─────────────────────────────────────┘  │                     │
│  └───────────────────────────────────────────┘                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Сценарий 3: CLI Tool

```
$ trinity-cli --host trinity.local status

Trinity FPGA Status
════════════════════
FPGA:      XC7A100T
Status:    Running
MOPS:      157
Temp:      42°C
Uptime:    2d 4h 32m

$ trinity-cli vsa search --vector "hello world"
Searching...
  ✓ item_123.vsa (similarity: 0.95)
  ✓ item_456.vsa (similarity: 0.87)
  ✓ item_789.vsa (similarity: 0.76)

$ trinity-cli led --blink
OK: LED blinking enabled
```

---

## Часть 5: Реализация WiFi моста на ESP32

### ESP32 код (WebSocket сервер)

```cpp
// esp32_wifi_bridge.ino
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// WiFi credentials
const char* ssid = "Trinity-FPGA";
const char* password = "trinity2026";

WebServer server(80);
WebSocketsServer webSocket = WebSocketsServer(81);

HardwareSerial FPGASerial(1);

// WebSocket event handler
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload,
                    size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            Serial.printf("[%u] Disconnected!\n", num);
            break;

        case WStype_CONNECTED:
            Serial.printf("[%u] Connected!\n", num);
            break;

        case WStype_TEXT:
            // Получить команду от Web UI
            Serial.printf("[%u] Command: %s\n", num, payload);

            // Отправить в FPGA
            if (strcmp((char*)payload, "PING") == 0) {
                FPGASerial.write(0x03);
            } else if (strcmp((char*)payload, "LED_ON") == 0) {
                FPGASerial.write(0x10);
            } else if (strcmp((char*)payload, "LED_OFF") == 0) {
                FPGASerial.write(0x11);
            }
            break;
    }
}

void setup() {
    Serial.begin(115200);
    FPGASerial.begin(115200, SERIAL_8N1, 5, 4); // RX=5, TX=4

    // WiFi AP mode
    WiFi.softAP(ssid, password);
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);

    // WebSocket server
    webSocket.begin();
    webSocket.onEvent(webSocketEvent);

    // HTTP server для Web UI
    server.on("/", []() {
        server.send(200, "text/html", getWebPage());
    });

    server.begin();
    Serial.println("HTTP server started");
}

void loop() {
    webSocket.loop();
    server.handleClient();

    // Ретранслировать FPGA ответы в WebSocket
    if (FPGASerial.available()) {
        uint8_t data = FPGASerial.read();
        char msg[32];
        sprintf(msg, "{\"fpga_response\": \"0x%02X\"}", data);
        webSocket.broadcastTXT(msg);
    }
}

String getWebPage() {
    return R"(
    <!DOCTYPE html>
    <html>
    <head>
        <title>Trinity Control</title>
        <style>
            body { font-family: Arial; padding: 20px; }
            .btn { padding: 10px 20px; margin: 5px; cursor: pointer; }
            .green { background: #4CAF50; color: white; }
            .red { background: #f44336; color: white; }
        </style>
    </head>
    <body>
        <h1>Trinity FPGA Control</h1>
        <div>
            <button class="btn green" onclick="send('LED_ON')">LED ON</button>
            <button class="btn red" onclick="send('LED_OFF')">LED OFF</button>
            <button class="btn" onclick="send('PING')">PING</button>
        </div>
        <div id="log"></div>
        <script>
            var ws = new WebSocket('ws://' + window.location.hostname + ':81/');
            ws.onmessage = function(event) {
                var data = JSON.parse(event.data);
                document.getElementById('log').innerHTML +=
                    '<p>FPGA: ' + data.fpga_response + '</p>';
            };
            function send(cmd) {
                ws.send(cmd);
            }
        </script>
    </body>
    </html>
    )";
}
```

---

## Часть 6: Общая архитектура

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ПОЛНАЯ АРХИТЕКТУРА                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Пользователи                                                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                        │
│  │ Browser  │  │ Mobile   │  │  CLI     │                        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                        │
│       │             │             │                               │
│       └─────────────┼─────────────┘                               │
│                     │                                              │
│                  WiFi/Ethernet                                     │
│                     │                                              │
│       ┌─────────────┴─────────────┐                               │
│       │      ESP32 Gateway        │                               │
│       │  ┌─────────────────────┐  │                               │
│       │  │  WebSocket Server  │  │                               │
│       │  │  HTTP Server       │  │                               │
│       │  │  REST API          │  │                               │
│       │  │  mDNS (trinity.local)│                               │
│       │  └─────────┬───────────┘  │                               │
│       │            │ UART/SPI     │                               │
│       └────────────┼──────────────┘                               │
│                    │                                              │
│       ┌────────────┴─────────────┐                               │
│       │    Trinity FPGA          │                               │
│       │  ┌─────────────────────┐  │                               │
│       │  │   UART/SPI Bridge   │  │                               │
│       │  ├─────────────────────┤  │                               │
│       │  │   VSA Compute Core  │  │                               │
│       │  ├─────────────────────┤  │                               │
│       │  │   Control Logic     │  │                               │
│       │  └─────────────────────┘  │                               │
│       └──────────────────────────┘                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Часть 7: План реализации

### Шаг 1: Базовый UART мост (сейчас)
```
ESP32 ←UART→ FPGA
```

### Шаг 2: Добавить WiFi AP
```
User → WiFi → ESP32 ←UART→ FPGA
```

### Шаг 3: Web UI
```
User → Browser → WiFi → ESP32 ←UART→ FPGA
```

### Шаг 4: Mobile App
```
User → App → WiFi → ESP32 ←UART→ FPGA
```

### Шаг 5: Облачная интеграция (опц.)
```
User → App → Cloud → WiFi → ESP32 ←UART→ FPGA
```

---

## Часть 8: Как пользователи подключаются

### Первичная настройка (один раз)

```
1. Включить устройство
2. Подключиться к WiFi: "Trinity-FPGA"
3. Открыть браузер: http://192.168.4.1
4. Настроить:
   - Имя устройства
   - Домашний WiFi (для bridge режима)
   - Пароль администратора
5. Готово!
```

### Ежедневное использование

```
1. Включить устройство (автоподключение к домашнему WiFi)
2. Открыть: http://trinity.local
3. Работать!
```

---

## Итог

| Вопрос | Ответ |
|--------|-------|
| **Куда подключать DSlogic?** | ~300 пинов на FPGA, 16 каналов хватит для всего |
| **Как WiFi на FPGA?** | Через ESP32 мост (проще и дешевле) |
| **Как с компьютера?** | Web UI (browser) или Mobile App |
| **Как пользователям?** | Простой интерфейс, никаких технических знаний |

φ² + 1/φ² = 3 = TRINITY
