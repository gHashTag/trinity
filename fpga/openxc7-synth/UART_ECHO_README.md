# UART Echo — FPGA + FT232RL Тест

## Схема подключения (QMTech XC7A100T)

```
FT232RL        →        FPGA XC7A100T
─────────────────────────────────────────
GND (черный)   →  J2 pin 1
RXD (зелёный)   →  J2 pin 5  → L20 (FPGA TX)
TXD (белый)     →  J2 pin 6  → K20 (FPGA RX)
─────────────────────────────────────────
Xilinx JTAG      →  JTAG header (VCC, GND, TCK, TDO, TDI, TMS)
```

## Рекомендуемый рабочий файл

**Используйте `uart_echo_top.v` + `uart_echo.xdc`**

Этот файл уже содержит исправленную логику:
- ✅ Правильная обработка START бита
- ✅ Проверка START бита на LOW (line 56-59)
- ✅ LSB-first прием данных
- ✅ Explicit idle HIGH состояние
- ✅ Echo логика с PONG ответом

## Синтез (Yosys + NextPNR)

```bash
cd fpga/openxc7-synth
yosys -p synth_xilinx -d no_iobuf -d srl_low_flop \
      uart_echo_top.v -o uart_echo_top.json

nextpnr-xilinx --chipdb /opt/prjxray-db/artix7/device.db \
      --json uart_echo_top.json \
      --xdc uart_echo.xdc \
      --fmax 50 \
      --write uart_echo_top_routed.json \
      --write-bitstream uart_echo_top.bit

# Или используя Yosys напрямую
yosys -p synth_xilinx -d no_iobuf \
      uart_echo_top.v -o uart_echo_top.edif
```

## Прошивка через JTAG

```bash
# 1. Инициализировать JTAG кабель (обязательно!)
sudo fxload -v -t fx2 -d 03fd:0013 -i xusb_xp2.hex

# 2. Прошить битстрим
sudo ./jtag_program uart_echo_top.bit

# Или использовать openFPGALoader
openFPGALoader --cable xpc --bit uart_echo_top.bit
```

## Тест UART (Python)

```bash
cd fpga
python3 test_uart_echo.py
```

Тест проверит:
- Поиск FT232RL устройства
- Отправку байтов (A, 0x55, 0xAA, "Hello", 0x00, 0xFF)
- Ожидание эхо ответа
- Статистику PASS/FAIL

## Монитор UART (опционально)

```bash
cd fpga/uart_monitor
python3 uart_monitor.py /dev/cu.usbserial-* --baudrate 115200
```

Интерактивный монитор с:
- HEX/ASCII отображением
- Отправкой данных
- Статистикой

## Диагностика проблем

### 1. Нет ответа (0x00/тишина)

**Проверьте:**
- [ ] JTAG прошивка прошла успешно?
- [ ] FT232RL подключен правильно (цвета)?
- [ ] Правильный порт выбран (`python3 test_uart_echo.py`)?

**Действия:**
- Подтяните и воткните провода
- Попробуйте другой USB порт
- Проверьте LED на плате (должна мигать при приёме)

### 2. Получаете мусор

**Возможные причины:**
- Скорость не совпадает (115200)
- Дробы/эмуляция при подключении

**Действия:**
- Отключите FT232RL при прошивке
- Перезагрузите плату (питание)

### 3. LED не мигает

**Проблема:** FPGA не прошита или неправильные пины

**Действия:**
- Перепрошить с `jtag_program`
- Проверить `.xdc` (L20 = TX, K20 = RX)

## Версии файлов

| Файл | Статус |
|-------|---------|
| `uart_echo_top.v` | ✅ Исправлен (рекомендуется) |
| `uart_bridge_fixed.v` | ⚠️  Возможны баги (нет tx_busy) |
| `uart_bridge_v2.v` | 🆕 Новая версия с tx_busy |

## Следующие шаги (если uart_echo не работает)

1. Симуляция в Icarus Verilog
2. Проверить pin mapping в constraint файле
3. Использовать осциллограф на пинах L20/K20
4. Проверить FT232RL с loopback (TX → RX напрямую)
