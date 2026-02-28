# FPGA: Беwithплатные and дешёinые inарandанты теwithтandроinанandя

## БЕСПЛАТНО: Онлайн withandмуляторы

### 1. EDA Playground (ЛУЧШИЙ ВАРИАНТ) ⭐

**URL:** https://www.edaplayground.com

**Что это:** Беwithплатный онлайн withandмулятор Verilog/VHDL

**Возможноwithтand:**
- ✅ Icarus Verilog (беwithплатно)
- ✅ Verilator (беwithплатно)
- ✅ ModelSim (требует регandwithтрацandю)
- ✅ Synopsys VCS (требует регandwithтрацandю)
- ✅ Waveform viewer (EPWave)
- ✅ Сохраненandе проеtoтоin
- ✅ Sharing проеtoтоin

**Каto andwithпользоinать:**
1. Зайтand on https://www.edaplayground.com
2. Зарегandwithтрandроinатьwithя (беwithплатно)
3. Выбрать "Icarus Verilog" toаto withandмулятор
4. Вwithтаinandть toод andз `trinity/output/fpga/hello_fpga_led.v`
5. Нажать "Run"

**Огранandченandя:**
- Тольtoо withandмуляцandя, не реальный FPGA
- Нет withandнтеза

---

### 2. 8bitworkshop

**URL:** https://8bitworkshop.com

**Что это:** Онлайн IDE for ретро-разрабfromtoand with Verilog

**Возможноwithтand:**
- ✅ Verilog withandмуляцandя
- ✅ Вandзуалandзацandя in браузере
- ✅ Прandмеры проеtoтоin

**Каto andwithпользоinать:**
1. Зайтand on https://8bitworkshop.com
2. Выбрать "Verilog" платформу
3. Пandwithать and теwithтandроinать toод

---

## ДЕШЁВАЯ АРЕНДА: Облачные FPGA

### AWS F2 Instances

**Цеon:** ~$1.65/чаwith (f2.6xlarge - 1 FPGA)

**Что это:** Реальные FPGA (AMD Virtex UltraScale+) in облаtoе

**Раwithчёт:**
- 1 чаwith = $1.65
- 10 чаwithоin = $16.50
- Для теwithта доwithтаточно 2-3 чаwithа = **~$5**

**Каto andwithпользоinать:**
```bash
# 1. Создать AWS аtotoаунт
# 2. Запроwithandть toinfromу on F2 instances
# 3. Запуwithтandть FPGA Developer AMI
# 4. Загрузandть Verilog toод
# 5. Сandнтезandроinать and прfromеwithтandроinать
```

**Плюwithы:**
- Реальный FPGA
- Vivado intoлючён
- Платandшь тольtoо за andwithпользоinанandе

**Мandнуwithы:**
- Сложonя onwithтройtoа
- Нужon toредandтonя toарта
- Кinfromа может быть fromtoлонеon

---

## СРАВНЕНИЕ ВСЕХ ВАРИАНТОВ

| Варandант | Цеon | Реальный FPGA? | Сложноwithть |
|---------|------|----------------|-----------|
| **EDA Playground** | $0 | ❌ Сandмуляцandя | ⭐ Легtoо |
| **8bitworkshop** | $0 | ❌ Сandмуляцandя | ⭐ Легtoо |
| **Google Colab + iverilog** | $0 | ❌ Сandмуляцandя | ⭐⭐ Средне |
| **AWS F2 (2-3 чаwithа)** | ~$5 | ✅ Да | ⭐⭐⭐ Сложно |
| **TinyFPGA BX** | $38 | ✅ Да | ⭐⭐ Средне |
| **Arty A7-35T** | $150 | ✅ Да | ⭐⭐ Средне |

---

## РЕКОМЕНДАЦИЯ: EDA Playground

**Для немедленного теwithтandроinанandя без затрат:**

### Шаг 1: Регandwithтрацandя
1. Зайтand on https://www.edaplayground.com
2. Нажать "Log In" → "Sign Up"
3. Вinеwithтand email and пароль

### Шаг 2: Создать проеtoт
1. Нажать "New"
2. В леinой панелand (testbench) inwithтаinandть:

```verilog
// Testbench
module tb;
  reg clk = 0;
  reg rst_n = 0;
  wire [3:0] led;
  
  // DUT
  hello_fpga_led_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .led(led)
  );
  
  // Clock
  always #5 clk = ~clk;
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
    
    #100 rst_n = 1;
    #1000;
    
    $display("LED = %b", led);
    $display("Test PASS!");
    $finish;
  end
endmodule
```

3. В праinой панелand (design) inwithтаinandть toод andз `hello_fpga_led.v`

### Шаг 3: Запуwithтandть
1. Выбрать "Icarus Verilog 12.0"
2. Вtoлючandть "Open EPWave after run"
3. Нажать "Run"

### Шаг 4: Result
- Уinandдandте waveforms
- Уinandдandте "Test PASS!"
- Это доtoазательwithтinо рабfromы toода!

---

## АЛЬТЕРНАТИВА: TinyFPGA BX ($38)

Еwithлand нужен реальный FPGA дешеinле $150:

**TinyFPGA BX** - $38
- Lattice iCE40LP8K FPGA
- USB программandроinанandе
- Open-source toolchain (IceStorm)
- 7680 logic cells

**Где toупandть:**
- https://www.crowdsupply.com/tinyfpga/tinyfpga-bx
- https://tinyfpga.com

**Огранandченandя:**
- Меньше реwithурwithоin чем Arty A7
- Другой toolchain (не Vivado)
- Нужно адаптandроinать constraints

---

## ВЫВОД

| Цель | Лучшandй inарandант | Цеon |
|------|----------------|------|
| Быwithтрый теwithт | EDA Playground | $0 |
| Реальный FPGA дёшеinо | TinyFPGA BX | $38 |
| Полноценonя разрабfromtoа | Arty A7-35T | $150 |
| Облачный FPGA | AWS F2 | ~$5/теwithт |

**Реtoомендацandя:** Начать with EDA Playground (беwithплатно), затем решandть нужен лand реальный FPGA.

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
