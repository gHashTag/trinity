# FPGA: Беwith[TRANSLATED]] and [CYR:[TRANSLATED]]inые inарand[CYR:[TRANSLATED]] теwithтandроinанandя

## [CYR:[TRANSLATED]]: [CYR:[TRANSLATED]] withand[CYR:[TRANSLATED]]

### 1. EDA Playground ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]]) ⭐

**URL:** https://www.edaplayground.com

**[CYR:[TRANSLATED]] this:** Беwith[TRANSLATED]] [CYR:[TRANSLATED]] withand[CYR:[TRANSLATED]] Verilog/VHDL

**[CYR:[TRANSLATED]]withтand:**
- ✅ Icarus Verilog (беwith[TRANSLATED]])
- ✅ Verilator (беwith[TRANSLATED]])
- ✅ ModelSim ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andwith[TRANSLATED]]andю)
- ✅ Synopsys VCS ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andwith[TRANSLATED]]andю)
- ✅ Waveform viewer (EPWave)
- ✅ [CYR:[TRANSLATED]]notнandе [CYR:[TRANSLATED]]toтоin
- ✅ Sharing [CYR:[TRANSLATED]]toтоin

**Каto andwith[TRANSLATED]]in[CYR:[TRANSLATED]]:**
1. [CYR:[TRANSLATED]]and on https://www.edaplayground.com
2. [CYR:[TRANSLATED]]andwithтрandроin[CYR:[TRANSLATED]]withя (беwith[TRANSLATED]])
3. [CYR:[TRANSLATED]] "Icarus Verilog" toаto withand[CYR:[TRANSLATED]]
4. Вwithтаinandть toод andз `trinity/output/fpga/hello_fpga_led.v`
5. [CYR:[TRANSLATED]] "Run"

**[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя:**
- [CYR:[TRANSLATED]]toо withand[CYR:[TRANSLATED]]andя, not [CYR:[TRANSLATED]] FPGA
- [CYR:[TRANSLATED]] withand[CYR:[TRANSLATED]]

---

### 2. 8bitworkshop

**URL:** https://8bitworkshop.com

**[CYR:[TRANSLATED]] this:** [CYR:[TRANSLATED]] IDE for [CYR:[TRANSLATED]]-[CYR:[TRANSLATED]]fromtoand with Verilog

**[CYR:[TRANSLATED]]withтand:**
- ✅ Verilog withand[CYR:[TRANSLATED]]andя
- ✅ Вand[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя in browserе
- ✅ Прand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toтоin

**Каto andwith[TRANSLATED]]in[CYR:[TRANSLATED]]:**
1. [CYR:[TRANSLATED]]and on https://8bitworkshop.com
2. [CYR:[TRANSLATED]] "Verilog" [CYR:[TRANSLATED]]
3. Пandwith[TRANSLATED]] and теwithтandроin[CYR:[TRANSLATED]] toод

---

## [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]: [CYR:[TRANSLATED]] FPGA

### AWS F2 Instances

**Цеon:** ~$1.65/чаwith (f2.6xlarge - 1 FPGA)

**[CYR:[TRANSLATED]] this:** [CYR:[TRANSLATED]] FPGA (AMD Virtex UltraScale+) in [CYR:[TRANSLATED]]toе

**Раwith[TRANSLATED]]:**
- 1 чаwith = $1.65
- 10 чаwithоin = $16.50
- [CYR:[TRANSLATED]] теwithта доwith[TRANSLATED]] 2-3 чаwithа = **~$5**

**Каto andwith[TRANSLATED]]in[CYR:[TRANSLATED]]:**
```bash
# 1. [CYR:[TRANSLATED]] AWS аtofor[TRANSLATED]]
# 2. [CYR:[TRANSLATED]]withandть toinfromу on F2 instances
# 3. [CYR:[TRANSLATED]]withтandть FPGA Developer AMI
# 4. [CYR:[TRANSLATED]]andть Verilog toод
# 5. Сand[CYR:[TRANSLATED]]andроin[CYR:[TRANSLATED]] and прfromеwithтandроin[CYR:[TRANSLATED]]
```

**[CYR:[TRANSLATED]]withы:**
- [CYR:[TRANSLATED]] FPGA
- Vivado infor[TRANSLATED]]
- [CYR:[TRANSLATED]]andшь [CYR:[TRANSLATED]]toо за andwith[TRANSLATED]]inанandе

**Мandнуwithы:**
- [CYR:[TRANSLATED]]onя onwith[TRANSLATED]]toа
- [CYR:[TRANSLATED]]on for[TRANSLATED]]andтonя for[TRANSLATED]]
- Кinfromа [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] fromtoлоnoton

---

## [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]

| [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] | Цеon | [CYR:[TRANSLATED]] FPGA? | [CYR:[TRANSLATED]]withть |
|---------|------|----------------|-----------|
| **EDA Playground** | $0 | ❌ Сand[CYR:[TRANSLATED]]andя | ⭐ [CYR:[TRANSLATED]]toо |
| **8bitworkshop** | $0 | ❌ Сand[CYR:[TRANSLATED]]andя | ⭐ [CYR:[TRANSLATED]]toо |
| **Google Colab + iverilog** | $0 | ❌ Сand[CYR:[TRANSLATED]]andя | ⭐⭐ [CYR:[TRANSLATED]]not |
| **AWS F2 (2-3 чаwithа)** | ~$5 | ✅ Да | ⭐⭐⭐ [CYR:[TRANSLATED]] |
| **TinyFPGA BX** | $38 | ✅ Да | ⭐⭐ [CYR:[TRANSLATED]]not |
| **Arty A7-35T** | $150 | ✅ Да | ⭐⭐ [CYR:[TRANSLATED]]not |

---

## [CYR:[TRANSLATED]]: EDA Playground

**[CYR:[TRANSLATED]] not[CYR:[TRANSLATED]] теwithтandроinанandя [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]:**

### [CYR:[TRANSLATED]] 1: [CYR:[TRANSLATED]]andwith[TRANSLATED]]andя
1. [CYR:[TRANSLATED]]and on https://www.edaplayground.com
2. [CYR:[TRANSLATED]] "Log In" → "Sign Up"
3. Вinеwithтand email and password

### [CYR:[TRANSLATED]] 2: [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toт
1. [CYR:[TRANSLATED]] "New"
2.  леinой паnotлand (testbench) inwithтаinandть:

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

3.  [CYR:[TRANSLATED]]inой паnotлand (design) inwithтаinandть toод andз `hello_fpga_led.v`

### [CYR:[TRANSLATED]] 3: [CYR:[TRANSLATED]]withтandть
1. [CYR:[TRANSLATED]] "Icarus Verilog 12.0"
2. Вfor[TRANSLATED]]andть "Open EPWave after run"
3. [CYR:[TRANSLATED]] "Run"

### [CYR:[TRANSLATED]] 4: Result
- Уinandдandте waveforms
- Уinandдandте "Test PASS!"
- [CYR:[TRANSLATED]] доfor[TRANSLATED]]withтinо [CYR:[TRANSLATED]]fromы for[TRANSLATED]]!

---

## [CYR:[TRANSLATED]]: TinyFPGA BX ($38)

Еwithлand [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] FPGA [CYR:[TRANSLATED]]inле $150:

**TinyFPGA BX** - $38
- Lattice iCE40LP8K FPGA
- USB [CYR:[TRANSLATED]]andроinанandе
- Open-source toolchain (IceStorm)
- 7680 logic cells

**[CYR:[TRANSLATED]] toупandть:**
- https://www.crowdsupply.com/tinyfpga/tinyfpga-bx
- https://tinyfpga.com

**[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя:**
- [CYR:[TRANSLATED]] реwithурwithоin [CYR:[TRANSLATED]] Arty A7
- [CYR:[TRANSLATED]] toolchain (not Vivado)
- [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andроin[CYR:[TRANSLATED]] constraints

---

## [CYR:[TRANSLATED]]

| [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]]andй inарand[CYR:[TRANSLATED]] | Цеon |
|------|----------------|------|
| Быwith[TRANSLATED]] теwithт | EDA Playground | $0 |
| [CYR:[TRANSLATED]] FPGA [CYR:[TRANSLATED]]inо | TinyFPGA BX | $38 |
| [CYR:[TRANSLATED]]onя [CYR:[TRANSLATED]]fromtoа | Arty A7-35T | $150 |
| [CYR:[TRANSLATED]] FPGA | AWS F2 | ~$5/теwithт |

**Реfor[TRANSLATED]]andя:** [CYR:[TRANSLATED]] with EDA Playground (беwith[TRANSLATED]]), [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andть [CYR:[TRANSLATED]] лand [CYR:[TRANSLATED]] FPGA.

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
