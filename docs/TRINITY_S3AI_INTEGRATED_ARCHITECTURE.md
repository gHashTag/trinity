# Trinity S³AI — Интегрированная архитектура Trinity

> **Единый документ для всей системы Trinity**: от нейроанатомических карт до FPGA выполнения
>
> **Связующие уровни**: Science → Language/VM → Hardware — BDD → Tests
> **Цель**: Показать, как каждый уровень использует результаты следующего уровня

---

## 🧠 Level 1: Научные Рамки (Science Framework)

### Текущая документация
- **Trinity S³AI Architecture** — `docs/trinity_s3ai_architecture.md`
- **Связные карты мозга** — см. `docs/trinity_s3ai_brain_maps.md` (если есть, иначе создать по аналогиям)
- **Связь с Sacred Formula** — `φ² + 1/φ² = 3` задаёт пропорции

### Ближайшие спецификации
- **Hippocampus (Angular Gyrus)** — пространственные вычисления
- **Orbitofrontal Cortex** — сенсомоторная интеграция и принятие решений
- **Amygdala** — эмоциональная обработка и детекция угроз

---

## 📝 Level 2: Язык и VM (Tri + TRI-27)

### Tri — Текнарный Язык
- **Спецификация** — `specs/tri/lang-ref/language_spec.md`
- **Компилятор** — tric (VIBEE Codegen)
- **AST** — `.tri` → Zig/Verilog
- **Типы** — Trit, GF16, TF3
- **Интерфейсы** — для интеграции с FPGA

### TRI-27 ISA
- **CPU State** — 27 тритных регистра (t0-t26) + 3 float (f0-f2)
- **Opcodes** — 27 опкодов (arithmetic, logic, control, тернарный, sacred)
- **Формат** — `.tbin` файлы (см. ниже)
- **Исполнители** — tri-emu (CLI), tri-hw (FPGA)

#### Связи с Level 1
- **Neuro модули** → TRI-27 байткод для:
  - Связные операции (VSA, bind, bundle, dot)
  - Свящённые вычисления (Sacred ALU: φ_const, pi_const, e_const)
  - Тернарные операции (DOT, BIND, BUNDLE2, BUNDLE3)
  - Контроль потоки (вызовы, условия, события)

- **Научные рамки** → .tri файлы используют научную терминологию:
  - `intraparietal_sulcus` — Working Memory
  - `angulargyrus` — Semantic Reasoning
  - `fusiform_gyrus` — Sensory Integration
  - `orbital_frontal_cortex` — Executive Function
  - `amygdala` — Emotional Processing

---

## ⚡ Level 3: FPGA/Hardware

### Sacred ALU — φ-Математическое Ядро
- **Модуль** — `fpga/openxc7-synth/sacred_alu.v`
- **Состав**:
  - φ-арифметика (golden angles, φ^n, φ × π)
  - π-тригонометрия (π-константы)
  - e-экспонента (e^n, decay)
  - GF16/TF3 — квантованный форматы для тернарных весов
  - Тернарные квантования (трёхмерный, bind, bundle, dot)

### TMU — Ternary Matrix Unit
- **Модуль** — `fpga/openxc7-synth/hslm_ternary_mac.v`
- **Состав**:
  - K×K матрицы (хранение весов)
  - Dot product pipeline (векторное/конволюционное умножение)
  - Bind/bundle операции (интеграция с VSA)
  - Ternарный формат (хранение 3-тритов в байт)

### FPGA Bitstream Pipeline
```
.tri spec → Zig код → Verilog → .bit
↓
tric (VIBEE codegen)  ← .tri компилятор
↓
Yosys synthesis → .blif → .net → .pcf → .bit
↓
openxc7 synthesis → .bitstream → .bit файл
```

#### Связи с Level 2
- **TRI-27 ISA** → аппаратное исполнение инструкций
- **Sacred ALU** → аппаратная поддержка математики
- **TMU** → аппаратная обработка векторов

---

## 🧪 Level 4: BDD — Поведение и Тестирование

### Поведение (Behavior-Driven Development)
**Спецификации BDD для:**
- `docs/docs/adr/003-sacred-constants-unified.md`
- `docs/docs/adr/001-vibee-compiler.md`
- `docs/docs/adr/002-ternary-presentation.md`
- `docs/internal/agents.md`

#### Ближайшие спецификации
- **Behavior** — `docs/docs/internal/ACTIONS.md` (словарный формат поведения)
- **Grammar** — `specs/tri/lang-ref/grammar.tri` (уже есть)
- **Types** — `specs/tri/lang-ref/types.tri` (уже есть)
- **Tokens** — `specs/tri/lang-ref/tokens.tri` (уже есть)

#### Использование BDD
```zig
// .tri файл для мозга "intraparietal_sulcus" зоны
module {
    // Использует VSA модуль для состояния
    // Вызывает Sacred ALU операции для φ-вычислений
}

// Синтез TRI-27 ISA опкодов для математики
const sacred_alu_phi_const = try executeSacredOp(SACRED.PHI_CONST);
const sacred_alu_pi_const = try executeSacredOp(SACRED.PI_CONST);
```

// Исполняет FPGA операции для инференса
try sacred_alu_dot = executeSacredOp(SACRED.DOT, &a, &b);
try sacred_alu_fadd = executeSacredOp(SACRED.FADD, &a, &b);
```

```

#### Тестовые примеры
```zig
// Пример 1: PHI-константа в нейро-зоне
fn initBrainZone(name: []const u8, size: u32) !void {
    // Выделяем векторное состояние для зоны "intraparietal_sulcus"
    // На практике это будет вызывать sacred_alu_phi_const из TRI-27
}

// Пример 2: Связь двух зон
fn bindZones(zoneA: VSAState, zoneB: VSAState) !void {
    // Использует sacred_alu_bind для ассоциации
    const similarity = sacred_alu_cosine_similarity(zoneA, zoneB);
    // Если similarity > 0.8, зоны связаны
}

// Пример 3: Исполнение через TMU
fn executeThroughTernary(input: []Trit) !void {
    // Используем TMU модуль для обработки вектора
    // Связываем через Sacred ALU для φ-вычислений
}

// Пример 4: Условное ветвление
fn processDecision(condition: BrainContext) bool !void {
    // Использует decision-making из "orbital_frontal_cortex"
    // Возвращает true/false на основе нескольких входов
    // Если true → продолжаем, если false → альтернативный путь
}
```

---

## 🔗 Поток Данных Между Уровнями

```
┌────────────────────────────────────┐
│ Level 1: Научные рамки (Science)               │
│  - intraparietal_sulcus (Working Memory)         │
│   - angulargyrus (Reasoning)               │
│   - fusiform_gyrus (Sensory)             │
│   - orbital_frontal (Decision)        │
│   - amygdala (Emotion)                 │
├─────────────────────────────────────┤
│            │ Связь через .tri файлы        │
│            │      TRI-27 байткод (VM + ISA) │
│            └─────────────────────────────────────┘
                          │
                          │ аппаратно FPGA для инференса │
                          └─────────────────────────────────────┘
                                      │ Sacred ALU: φ-математика │
                                      │ TMU: тернарная матрица  │
                                      └─────────────────────────────────────┘
                          ↓
│                   Проверяем состояние                │
│                   BDD тесты (behaviour)  │
└─────────────────────────────────────────────┘
```

---

## 📚 Использование

### Разработка .tri файла для нейро-зоны

```bash
# 1. Создаём .tri файл для "intraparietal_sulcus" зоны
tri create brain_zone --name intraparietal_sulcus \
    --weights 16384 --connections 4096 \
    --trit27-ops "DOT, BIND, BUNDLE2" \
    --output zone.bin

# 2. Выполняем .tri файл на FPGA
tri compile brain_zone --name intraparietal_sulcus \
    --target fpga \
    --sacred_alu_ops "PHI_CONST, PI_CONST, E_CONST" \
    --output intraparietal_sulcus.bin

# 3. Запускаем эмуляцию
tri run brain_zone --name intraparietal_sulcus \
    --weights zone.bin \
    --backend tri27emu
```

### Разработка TRI-27 программы

```zig
// TRI-27 программа для нейро-вычислений
const std = @import("std");
const vm = @import("trinity/tri27/emu");
const sacred_alu = @import("fpga/sacred_alu");

pub fn runNeuralInference() !void {
    // 1. Инициализируем TRI-27 CPU
    var cpu = try vm.CPU.init();

    // 2. Загружаем веса из нейро-зоны
    try vm.loadFpgaWeights(&cpu, "intraparietal_sulcus.bin");

    // 3. Выполняем вычисления через Sacred ALU
    try sacred_alu.setMode(.phi_computation);

    // 4. Выполняем векторные операции
    try vm.executeOpcodes(&[
        .opcode = .DOT,
        .a = &weights,
        .b = &weights,
    .result = &cpu.regs[0],
    ]);

    // 5. Принятие решений через Amygdala
    const decision = try amygdala.evaluate(inputs: &cpu.regs);
    if (decision.go) {
        // Продолжаем дальше по выбранному пути
    try vm.executeOpcodes(&[
            .opcode = .HALT,
            .target = "fusiform_gyrus_zone",
        .input = inputs,
        ]);
    } else {
        // Альтернативный путь (например, логирование)
        try vm.executeOpcodes(&[
            .opcode = .JZ,
            .target = "log_decision",
            .reason = "amygdala_said_no",
            ]);
    }
    }
}
```

### Формат .tbin (для TRI-27)

```zig
// .tbin формат для TRI-27
pub const TBINHeader = extern struct {
    magic: [4]u8 = .{'t', 'r', 'i', 'n'}, // "TRI27"
    version: u8 = 1,
    section_count: u8 = 0,
    code_size: u32 = 0,
    data_size: u32 = 0,
};

pub const TBISection = extern struct {
    section_type: u8, // 1: Code, 2: Constants, 3: Data, 4: BSS
    offset: u32,
    size: u32,
};

pub const TBINCodeSection = extern struct {
    opcodes: []u8,
};
```

// Функции для создания .tbin файлов
fn createTBin(program: []const TBIInstruction) ![]u8 {
    // Заголовок (magic, version, секции, размеры)
    var header: TBINHeader = ...;

    // Конвертируем в bytearray
    var code = std.ArrayList(u8).init(allocator);

    // Пишем опкоды
    for (instruction) &program) {
        try code.append(serializeInstruction(instruction));
    }

    // Вычисляем смещения
    header.code_size = code.items.len;
    header.data_size = calculateDataSize(program);

    // Формируем bytearray
    return code.toOwnedSlice();
}

fn calculateDataSize(program: []const TBIInstruction) u32 {
    var size: u32 = 0;
    for (instruction) &program) {
        size += estimateInstructionSize(instruction);
    }
    return size;
}
```

---

## � Примеры Использования

### Пример 1: Простое вычисление с Sacred ALU
```zig
// Вычисление φ² через Sacred ALU
const sacred_alu = @import("fpga/sacred_alu");

fn main() !void {
    const phi_result = try sacred_alu.phi_pow();

    // φ_result содержит f-регистр с результатом φ^10
    try std.debug.print("φ^10 = {d:.6}\n", .{phi_result});
}
}
```

### Пример 2: Полноценная сеть через TMU
```zig
// Полноценная нейро сеть с 3 слоями:
// 1. intraparietal_sulcus — Working Memory (VSA)
// 2. fusiform_gyrus — Semantic Reasoning (текст)
// 3. orbital_frontal_cortex — Executive Decision

// Связь через .tri файлы
trinity config:
  modules:
    - intraparietal_sulcus: VSA + Sacred ALU
    - fusiform_gyrus: Parser
    - orbital_frontal_cortex: Decision
    - amygdala: Emotion

// Поток данных
Working Memory → VSA → Sacred ALU → Orbital → Amygdala → Decision → Output
```

---

## 📊 Модель Использования

```zig
// Единая система Trinity S³AI работает по 3 уровням:

1. **НАУЧНЫЕ РАМКИ** (уровень 1)
   - intraparietal_sulcus: хранит состояние
   - fusiform_gyrus: выполняет вычисления
   - orbital_cortex: принимает решения
   - amygdala проверяет угрозы

2. **ЯЗЫК И ISA** (уровень 2)
   - .tri компилятор создаёт TRI-27 байткод
   - tri-emu исполняет байткод
   - tri-hw исполняет на FPGA

3. **АППАРАТУРА** (уровень 3)
   - Sacred ALU исполняет φ-математику
   - TMU исполняет тернарные операции
   - FPGA загружает битстрим и исполняет

4. **ПОВЕДЕНИЕ** (уровень 4)
   - BDD спецификации описывают поведение
   - Все изменения валидируются через BDD тесты
```

---

## 🔗 Консиструкции

### Функциональный стиль (требование из контракта)
- ✅ Только функции верхнего уровня
- ✅ Только `struct` и `enum` (нет классов)
- ✅ Только `match` для ветвлений (нет виртуального dispatch)
- ✅ Неизменяемые значения по умолчанию
- ✅ Модульность через файлы/модули (module tri.vsa_ops, etc.)

### Жёсткий запрет
- ❌ Никаких `class`, `object`, `this`, `super`, `interface`
- ❌ Никаких методов, привязанных к типам
- ❌ Никакого наследования и виртуальных таблиц
- ❌ Никаких исключений и throw/try-catch
- ❌ Никаких скрытого состояния (global mutable, this)

### Enforcement
- **Parser**: Detects and отклоняет любые .tri файлы с запрещёнными конструкциями
- **Linter**: Отклоняет любые попытки ввести императив
- **Formatter**: Автоматически исправляет всё к функциональному стилю
- **VM Core**: Проверяет, что все VM используют консолидированное VM-ядро

---

## 📖

Для более информации:
- **Architecture**: `docs/trinity_s3ai_architecture.md` — 3-уровневая архитектура
- **Language**: `specs/tri/lang-ref/language_spec.md` — спецификация Tri
- **Hardware**: `fpga/README.md` — FPGA синтез
- **BDD Docs**: `docs/docs/adr/*` — спецификации поведения

---

**Ключевой инсайт**: Все спецификации используют единое φ-структуру.
**От нейро-карт до FPGA — единый поток через функциональный Tri язык.**
