# Профессиональная FPGA Разработка — Руководство 2026

## Содержание
1. Инструменты и сравнение
2. Лучшие практики (Best Practices)
3. ESP32-FPGA интеграция
4. Как прокачать проект
5. Обучающие ресурсы

---

## 1. Инструменты и сравнение

### Полный стек разработки

```
┌─────────────────────────────────────────────────────────────┐
│                    FPGA Development Stack 2026              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Edit    │  │ Synthesis│  │  Place   │  │  Route   │   │
│  │          │  │          │  │          │  │          │   │
│  │ VS Code  │→ │  Yosys   │→ │ nextpnr  │→ │ nextpnr  │   │
│  │ Vim      │  │  Vivado  │  │  Vivado  │  │  Vivado  │   │
│  │ Sublime  │  │          │  │          │  │          │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                         │                   │
│                                         ↓                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  | Simulate│  | Verify  │  | Debug   │  | Program │   │
│  │          │  │          │  │          │  │          │   │
│  │Verilator│  │  Cocotb  │  │  ILA    │  │ OpenOCD  │   │
│  │ ModelSim │  │   UVM    │  │ ChipScope│  │ Vivado  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Сравнение toolchain

| Инструмент | Статус | Плюсы | Минусы | Когда использовать |
|------------|--------|-------|--------|-------------------|
| **Vivado** | 🔵 Проприетарный | Лучший QoR, полный стек | 50GB+, платный | Производство |
| **Yosys** | 🟢 Open Source | Быстрый, кроссплатформенный | -10% плотности | Open source проекты |
| **nextpnr-xilinx** | 🟡 Экспериментальный | Современный PnR | Xilinx 7-series alpha | Развлечения |
| **Verilator** | 🟢 Open Source | 100x быстрее ModelSim | Только синтаксис | Верификация |

### Рекомендация для вашего проекта

```
┌─────────────────────────────────────────────────────────────┐
│                   Ваша ситуация                             │
├─────────────────────────────────────────────────────────────┤
│ ✓ Есть: QMTECH XC7A100T                                    │
│ ✓ Есть: openXC7 Docker (WORKING!)                          │
│ ✓ Есть: FORGE (Zig) - экспериментальный                    │
│ ✓ Есть: JTAG кабель                                        │
│                                                             │
│ РЕКОМЕНДАЦИЯ:                                              │
│ 1. Используйте openXC7 для production                      │
│ 2. Используйте Verilator для симуляции                     │
│ 3. FORGE только для экспериментов                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Лучшие практики (Best Practices)

### Кодинг стандарты

```systemverilog
// ===== ПРАВИЛЬНО =====
module uart_tx #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0]  tx_data,
    input  logic tx_start,
    output logic tx,
    output logic tx_busy
);

    // Состояния
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state, next_state;

    // Синхронный сброс (предпочтительнее)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Combinatorial логика separately
    always_comb begin
        next_state = state;  // Default
        case (state)
            IDLE: begin
                if (tx_start) next_state = START;
            end
            // ...
        endcase
    end

endmodule
```

### CDC (Clock Domain Crossing)

```systemverilog
// ===== 2-flop synchronizer =====
module sync_2flop (
    input  logic clk_dst,
    input  logic async_sig,
    output logic sync_sig
);
    logic [1:0] sync_reg;

    always_ff @(posedge clk_dst) begin
        sync_reg <= {sync_reg[0], async_sig};
    end

    assign sync_sig = sync_reg[1];
endmodule
```

### Reset стратегия

```systemverilog
// ===== Reset bridge (async -> sync) =====
module reset_bridge (
    input  logic clk,
    input  logic rst_n_async,
    output logic rst_n_sync
);
    logic [2:0] sync_reg;

    always_ff @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            sync_reg <= 3'b000;
        end else begin
            sync_reg <= {sync_reg[1:0], 1'b1};
        end
    end

    assign rst_n_sync = sync_reg[2];
endmodule
```

---

## 3. ESP32-FPGA интеграция

### Рекомендуемые протоколы

| Протокол | Скорость | Сложность | Применение |
|----------|----------|-----------|------------|
| **UART** | 115200 - 921600 baud | ⭐ | Команды, отладка |
| **SPI** | До 80 MHz | ⭐⭐ | Данные, пиксели |
| **I2C** | 400 kHz | ⭐ | Сенсоры |
| **Ethernet** | 100 Mbps | ⭐⭐⭐⭐ | Сеть |

### UART подключение (рекомендуется)

```
ESP32 DIYTZT              FPGA Artix-7
────────────────────────────────────────
GPIO4 (TX) ──────────────> L20 (RX)
GPIO5 (RX) <────────────── K20 (TX)
GND ─────────────────────> GND
```

### Код ESP32 (Arduino)

```cpp
// esp32_fpga_uart.ino
#define RX_PIN 5
#define TX_PIN 4
#define BAUD 115200

HardwareSerial SerialFPGA(1);

void setup() {
    Serial.begin(115200);
    SerialFPGA.begin(BAUD, SERIAL_8N1, RX_PIN, TX_PIN);
    Serial.println("ESP32-FPGA Bridge Ready");
}

void loop() {
    // Relay Serial Monitor to FPGA
    if (Serial.available()) {
        SerialFPGA.write(Serial.read());
    }
    if (SerialFPGA.available()) {
        Serial.write(SerialFPGA.read());
    }
}
```

---

## 4. Как прокачать проект

### Уровень 1: Базовый (текущий)

```
✅ Сделано:
- openXC7 toolchain настроен
- Базовые Verilog модули
- JTAG прошивка
- ESP32 UART мост
```

### Уровень 2: Intermediate (следующие шаги)

```
🔄 TODO:
- [ ] Добавить Verilator для симуляции
- [ ] Создать testbench для всех модулей
- [ ] Implement CDC checking
- [ ] Добавить assertions в код
- [ ] Setup CI/CD для тестов
```

### Уровень 3: Advanced

```
🎯 TODO:
- [ ] Formal verification (SymbiYosys)
- [ ] UVM testbench
- [ ] Integrated Logic Analyzer
- [ ] Performance profiling
- [ ] Documentation generation
```

### Приоритеты

| Приоритет | Задача | Время | Impact |
|-----------|--------|-------|--------|
| 🔥 High | Verilator симуляция | 2 дня | Высокий |
| 🔥 High | Testbench для UART | 1 день | Высокий |
| 🔥 High | ESP32 код + LVGL | 3 дня | Высокий |
| ⚡ Medium | CDC проверка | 2 дня | Средний |
| ⚡ Medium | Assertions | 1 день | Средний |
| 💡 Low | UVM | 1 неделя | Низкий |

---

## 5. Обучающие ресурсы

### Книги

| Книга | Автор | Уровень |
|-------|-------|---------|
| "FPGA Prototyping by Verilog Examples" | Pong P. Chu | Начальный |
| "Advanced FPGA Design" | Steve Kilts | Средний |
| "Computer Architecture: A Quantitative Approach" | Hennessy & Patterson | Продвинутый |

### Онлайн курсы

- **Nandland**: https://www.nandland.com/ (лучший для начинающих)
- **FPGA4Fun**: https://www.fpga4fun.com/
- **ZipCPU**: https://zipcpu.com/ (продвинутый)

### GitHub проекты для изучения

- **LiteX**: SoC builder на Python
- **VexRiscv**: 32-бит RISC-V на Scala/Verilog
- **picorv32**: Маленький RISC-V core
- **serdes**: High-speed serial examples

---

## 6. AliExpress анализ

### Ссылка: https://th.aliexpress.com/item/1005009035385463.html

Вероятно это **ESP32-S3 с LCD дисплеем** или **FPGA плата расширения**.

#### Характеристики типичных плат:

| Компонент | ESP32 Board | FPGA Board |
|-----------|-------------|------------|
| Микроконтроллер | ESP32-WROVER | - |
| FPGA | - | XC7A35T/100T |
| RAM | 8MB PSRAM | DDR3 |
| Flash | 16MB | SPI Flash |
| LCD | 2.4" ST7789 | - |
| Touch | Резистивный | - |
| WiFi | 802.11 b/g/n | - |
| Bluetooth | BLE 4.2/5.0 | - |

#### Что выбрать для вашего проекта:

```
┌─────────────────────────────────────────────────────────────┐
│ ВАШ ВЫБОР                                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 1. ESP32 + LCD (DIYTZT)                                     │
│    ✓ Уже есть                                              │
│    ✓ Отлично подходит для UI                                │
│    ✓ WiFi/Bluetooth для связи                               │
│                                                             │
│ 2. FPGA расширение (если это оно)                           │
│    ⚠️ Проверьте совместимость с XC7A100T                    │
│    ⚠️ Возможно дублирует текущую плату                      │
│                                                             │
│ 3. Комбо плата (ESP32 + FPGA на одной)                     │
│    ✅ Идеально для интеграции                              │
│    ✅ Меньше проводов                                      │
│    ⚠️ Меньше I/O пинов                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Quick Start Checklist

```bash
# 1. Симуляция с Verilator
brew install verilator
cd fpga/openxc7-synth
verilator --Wall uart_bridge.v

# 2. Синтез с openXC7
./synth.sh uart_bridge.v uart_bridge

# 3. Прошивка
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# переподключить кабель
sudo fpga/tools/jtag_program uart_bridge.bit

# 4. ESP32 код
# Открыть Arduino IDE, выбрать "ESP32 Dev Module"
# Загрузить esp32_fpga_uart.ino
# Отправлять команды из Serial Monitor
```

---

## Итог

| Аспект | Рекомендация |
|--------|--------------|
| Toolchain | openXC7 для production |
| Симуляция | Verilator |
| Верификация | Cocotb + assertions |
| ESP32 связь | UART 115200 |
| LCD | LVGL на ESP32 |
| Следующий шаг | Добавить Verilator в проект |

φ² + 1/φ² = 3 = TRINITY
