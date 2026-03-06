# Подключение ESP32 к FPGA Artix-7

## Что лучше подходит?

| Интерфейс | Сложность | Скорость | Для чего подходит | Рейтинг |
|-----------|-----------|----------|-------------------|---------|
| **UART** | ⭐ Простой | ~1 Mbps | Команды, лог, отладка | ✅ **ЛУЧШИЙ ДЛЯ НАЧАЛА** |
| **SPI** | ⭐⭐ Средний | ~50 Mbps | Данные, пиксели | ⚡ Быстро |
| **I2C** | ⭐ Простой | ~400 kHz | Сенсоры, настройки | 🔧 Для периферии |
| **GPIO** | ⭐ Простейший | - | Кнопки, LED | 💡 Управление |

**РЕКОМЕНДАЦИЯ**: Начните с **UART** — самый простой и надёжный вариант.

---

## Вариант 1: UART (Рекомендуемый)

### Схема подключения

```
┌─────────────────────┐              ┌─────────────────────┐
│                     │              │                     │
│   ESP32 DIYTZT      │              │   FPGA Artix-7      │
│                     │              │   QMTECH XC7A100T   │
│                     │              │                     │
│  GPIO4 (TX) ────────┼──────────────┼──> L20 (UART_RX)   │
│                     │              │                     │
│  GPIO5 (RX) <───────┼──────────────┼── K20 (UART_TX)    │
│                     │              │                     │
│  GND ───────────────┼──────────────┼── GND (ВАЖНО!)     │
│                     │              │                     │
│  3.3V ──────────────┼──(опция)────┼── 3.3V (если нужно)│
│                     │              │                     │
└─────────────────────┘              └─────────────────────┘
```

### Пины ESP32 DIYTZT

| ESP32 Пин | Название | Куда подключить | Примечание |
|-----------|----------|-----------------|------------|
| GPIO4 | TX | FPGA Pin L20 | ESP32 передаёт |
| GPIO5 | RX | FPGA Pin K20 | ESP32 принимает |
| GND | GND | FPGA GND | **ОБЯЗАТЕЛЬНО!** |
| 3V3 | 3.3V | - | Не подключать (есть свой) |
| 5V | 5V | - | Не подключать |

### Пины FPGA (FGG676)

| FPGA Пин | Банк | Название | Куда подключить |
|----------|------|----------|-----------------|
| L20 | 35 | IO_L1N_N0_A14_35 | ESP32 TX |
| K20 | 35 | IO_L1P_P0_A13_35 | ESP32 RX |
| GND | - | GND | ESP32 GND |

### Провода

Используйте:
- **DuPont провода** (Female-Female) — самый простой вариант
- Или **монтажные провода** с паяльником

---

## Вариант 2: SPI (Для высоких скоростей)

### Схема подключения

```
ESP32                    FPGA
────────────────────────────────────────
GPIO14 (SCLK) ─────────> J21 (SPI_SCK)
GPIO12 (MISO) <───────── H21 (SPI_MISO)
GPIO13 (MOSI) ─────────> G22 (SPI_MOSI)
GPIO15 (CS) ───────────> F22 (SPI_CS)
GND ───────────────────> GND
```

**Когда использовать**: Когда нужно передавать много данных (например, пиксели для LCD).

---

## Вариант 3: I2C (Для сенсоров)

### Схема подключения

```
ESP32                    FPGA
────────────────────────────────────────
GPIO21 (SDA) ────────>── I2C_SDA (с резистором 4.7k)
GPIO22 (SCL) ────────>── I2C_SCL (с резистором 4.7k)
GND ───────────────────> GND
```

**Примечание**: Нужны подтягивающие резисторы 4.7kΩ на SDA и SCL.

---

## Физическое подключение (пошагово)

### Способ 1: DuPont провода (проще всего)

1. Возьмите 3 Duport провода (Female-Female)
2. Соедините:
   - **Чёрный**: GND → GND
   - **Белый**: GPIO4 → Pin L20
   - **Синий**: GPIO5 → Pin K20
3. Проверьте соединения (мультиметром или визуально)

### Способ 2: PLS-EXT платка (профессионально)

QMTech предоставляет расширительную плату с разъёмами:

```
PLS-EXT Connector:
┌────────────────────────────┐
│  GND  VCC  IO1  IO2  IO3   │
│   ↑    ↑    ↑    ↑    ↑    │
└────────────────────────────┘
```

Подключите ESP32 к этим пинам.

---

## Проверка соединений

### 1. Проверка GND (обязательно!)

```bash
# Мультиметром: прозвоните GND ESP32 и GND FPGA
# Должно быть ~0 Ом
```

### 2. Проверка уровней напряжения

- ESP32: **3.3V логика** ✓
- FPGA: **3.3V логика** (LVCMOS33) ✓
- **Совместимы напрямую!** (не нужны конвертеры)

### 3. Осмотр пинов

| Проверка | Как |
|----------|-----|
| Короткое замыкание | Мультиметр: VCC-GND не должны звониться |
| Правильный пин | Схемота FPGA + маркировка на плате |
| Плохой контакт | Покачайте провод |

---

## Сбор и прошивка FPGA

### 1. Синтезировать дизайн

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Создать упрощённый XDC (только для uart_bridge)
cat > uart_bridge.xdc << 'EOF'
# Clock
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
EOF

# Синтез с openXC7
docker run --rm --platform linux/amd64 \
    -v "$(pwd):/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top uart_bridge; \
              write_json uart_bridge.json" \
    uart_bridge.v

# nextpnr + fasm2frames + xc7frames2bit
./synth.sh uart_bridge.v uart_bridge
```

### 2. Прошить FPGA

```bash
# Загрузить прошивку кабеля
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex

# Переподключить кабель (подождать 2 секунды)

# Прошить битстрим
sudo fpga/tools/jtag_program uart_bridge.bit
```

---

## ESP32 код (Arduino)

```cpp
// esp32_uart_fpga.ino
// Подключение:
//   ESP32 GPIO4 (TX) -> FPGA L20 (RX)
//   ESP32 GPIO5 (RX) <- FPGA K20 (TX)
//   ESP32 GND       -> FPGA GND

#define RX_PIN 5
#define TX_PIN 4
#define BAUD_RATE 115200

// Команды FPGA
#define CMD_PING      0x03
#define CMD_LED_ON    0x10
#define CMD_LED_OFF   0x11
#define CMD_LED_BLINK 0x12

// Ответы FPGA
#define RESP_PONG     0x83
#define RESP_OK       0xFF
#define RESP_ACK      0xAA

HardwareSerial SerialFPGA(1); // Использовать UART1

void setup() {
    Serial.begin(115200);
    SerialFPGA.begin(BAUD_RATE, SERIAL_8N1, RX_PIN, TX_PIN);

    Serial.println("=== ESP32 <-> FPGA UART Bridge ===");
    Serial.println("Commands: p=ping, o=on, f=off, b=blink");
}

void loop() {
    // Проверка команд из Serial Monitor
    if (Serial.available()) {
        char cmd = Serial.read();

        switch (cmd) {
            case 'p': // PING
                Serial.print("Sending PING... ");
                SerialFPGA.write(CMD_PING);
                break;

            case 'o': // LED ON
                Serial.print("Turning LED ON... ");
                SerialFPGA.write(CMD_LED_ON);
                break;

            case 'f': // LED OFF
                Serial.print("Turning LED OFF... ");
                SerialFPGA.write(CMD_LED_OFF);
                break;

            case 'b': // LED BLINK
                Serial.print("Blinking LED... ");
                SerialFPGA.write(CMD_LED_BLINK);
                break;

            default:
                Serial.println("Unknown command");
                break;
        }

        // Ждём ответа от FPGA
        delay(100);
        if (SerialFPGA.available()) {
            uint8_t resp = SerialFPGA.read();
            Serial.print("Response: 0x");
            Serial.println(resp, HEX);
        } else {
            Serial.println("No response");
        }
    }

    // Ретранслировать данные из FPGA в Serial Monitor
    if (SerialFPGA.available()) {
        uint8_t data = SerialFPGA.read();
        Serial.print("FPGA: 0x");
        Serial.println(data, HEX);
    }
}
```

### Загрузка в ESP32

1. Откройте Arduino IDE
2. Выберите плату: **ESP32 Dev Module**
3. Выберите порт: `/dev/cu.usbserial-*` (или COMx на Windows)
4. Загрузите скетч
5. Откройте Serial Monitor (115200 baud)
6. Отправляйте команды: `p`, `o`, `f`, `b`

---

## Тестирование

### Тест 1: Проверка связи

```bash
# В Arduino IDE Serial Monitor отправьте:
p
# Должно вернуться: Response: 0x83
```

### Тест 2: Управление LED

```bash
o  # LED включится
f  # LED выключится
b  # LED начнёт мигать
```

### Тест 3: Осциллограф

Проверьте сигналы TX/RX осциллографом:
- Скорость: 115200 baud
- Бит: 8N1 (8 data bits, No parity, 1 stop bit)
- Уровни: 0V = лог. 0, 3.3V = лог. 1

---

## Схема пинов FPGA (полная)

### Bank 35 (используется для UART)

```
Pin  | Name          | ESP32 Connection
-----|---------------|------------------
L20  | IO_L1N_N0_A14 | UART_RX (GPIO4 TX)
K20  | IO_L1P_P0_A13 | UART_TX (GPIO5 RX)
M22  | IO_L2N_N1_A16 | Debug[0] (опц.)
N21  | IO_L2P_P1_A17 | Debug[1] (опц.)
N20  | IO_L3N_N2_A20 | Debug[2] (опц.)
P22  | IO_L3P_P2_A21 | Debug[3] (опц.)
```

### Расположение пинов на FPGA

```
        ┌───────────────────────┐
        │                       │
        │   [FGG676 BGA]        │
        │                       │
        │  K20 L20  <- UART     │
        │   │   │               │
        └───┴───┴───────────────┘
```

---

## Поиск проблем

| Проблема | Причина | Решение |
|----------|---------|---------|
| Нет ответа от FPGA | GND не подключен | Соедините GND! |
| Нет ответа от FPGA | Неправильные пины | Проверьте XDC файл |
| ESP32 перезагружается | Питание | Не используйте 5V от FPGA |
| Мусор в Serial Monitor | Скорость не совпадает | Проверьте BAUD_RATE |
| LED не работает | Синтез прошёл с ошибками | Проверьте логи синтеза |

---

## Следующие шаги

1. **VSA вычисления**: FPGA вычисляет VSA, ESP32 отображает на LCD
2. **WiFi мост**: ESP32 пересылает данные через WiFi в компьютер
3. **LVGL интерфейс**: Красивый UI на ESP32 для управления FPGA

φ² + 1/φ² = 3 = TRINITY
