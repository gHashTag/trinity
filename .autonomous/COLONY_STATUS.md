# COLONY STATUS

> Агрегированное состояние колонии — обновляется Queen/Doctor (L1)
> Last update: 2026-03-25T09:45:00Z

---

## L0 Temple (Sacred Core)

| Слой | Статус | Описание |
|------|--------|----------|
| TTT (src/temple/**) | ✅ PROTECTED | Священный слой, агенты не трогают |
| sacred_math.zig | ✅ OK | φ² + 1/φ² = 3 |
| tri27_core.zig | ✅ OK | TRI-27 ISA, Memory, Opcodes |
| tri_lang_core.zig | ✅ OK | Result, Patterns, Linear, Effects |

**Инвариант**: `zig build temple` всегда компилируется.

---

## L1 Queens (Supervisors)

| Модуль | Статус | Описание |
|--------|--------|----------|
| tri_commands | ✅ OK | Диспетчеризация команд |
| queen_trinity | ✅ OK | Queen UI coordination |
| github_commands | ✅ OK | Git/GitHub integration |
| dev_commands | ✅ OK | Dev workflow (TDGS) |
| doctor | ✅ OK | Health checks + healer |

**Инвариант**: `zig build queens` всегда компилируется.

---

## L2 Workers (Optional)

### Core Workers

| Worker | Статус | Описание |
|--------|--------|----------|
| tri_farm | ✅ OK | Railway training farm (152 workers) |
| tri_cloud | ✅ OK | Cloud orchestration |
| tri_fpga | ✅ OK | FPGA synthesis + UART |

---

### FPGA (L2 Worker: tri_fpga)

| Метрика | Значение |
|---------|----------|
| Компиляция | ✅ Zig 0.15 OK |
| Remote Synth | ⏳ Fly.io SLOW (job queued >2 min) |
| J2 UART XDC | ✅ D26/E26 (Bank 15) — Verified |
| Verilog RTL | ✅ D26/E26 (uart_tx/uart_rx) — Verified |
| Bitstream | ⚠️ СТАРЫЙ (Mar 25 01:13, ДО исправления XDC) |
| nextpnr-xilinx | ❌ Не собран — P&R невозможен |
| Yosys synth | ✅ JSON создан (72 LC) |
| UART Test | ❌ TIMEOUT — ожидает новый bitstream с D26/E26 |

**Fly.io Remote Synth Status:**
- Job ID: `18921a50` — queued >2 min
- Service: Health OK, но synthesis очень медленный
- Причина: Worker спит и нуждается в размывке (~30 сек)

**Проблема диагностирована:**
- XDC обновлён в 23:03, Verilog в 23:11 (Mar 24)
- Bitstream собран в 01:13 (Mar 25) — СТАРЫЙ дизайн с K20/L20
- В FPGA сейчас прошит дизайн с НЕПРАВИЛЬНЫМИ пинами → UART не работает

**Решение:** Собрать nextpnr-xilinx локально (15-30 мин) — больше не зависеть от облака.

**Доступные команды:**
```bash
tri fpga status         # Проверка инструментов и кабеля
tri fpga remote-synth   # Синтез через Fly.io API
tri fpga download-uart-bit  # Скачать .bit с Fly.io
tri fpga build-uart     # Локальный синтез (если есть toolchain)
tri fpga flash-uart     # Прошивка через flash_no_sudo.sh
tri fpga uart-test      # PING/PONG/echo по J2
```

---

### Spec Tools

| Worker | Статус | Описание |
|--------|--------|----------|
| tri_spec_audit | ✅ OK | .tri spec linting |
| tri_spec_apply | ✅ OK | .tri → Zig/Verilog codegen |
| tri_spec_command | ✅ OK | CLI wrapper |

---

## Graceful Degradation

| Build Target | Статус | Описание |
|--------------|--------|----------|
| `zig build temple` | ✅ OK | L0 только (sacred core) |
| `zig build queens` | ✅ OK | L1 (supervisors) |
| `zig build tri` | ✅ OK | L2 (all workers) |

**При сбое worker-а**: L0 + L1 остаются работоспособными, degraded mode показывает альтернативы.

---

## Active Tasks (TDGS)

| Task ID | Фаза | Агент | Прогресс |
|---------|------|-------|----------|
| TDGS-1 | ✅ DONE | — | Все три слоя «guarded» |
| TDGS-2 | 🔄 IN_PROGRESS | agent:coder | L1 Queens migration |
| TDGS-3 | ⏸️ QUEUED | — | L2 Workers graceful degradation |

---

## Health Score

```
Overall: 85/100 (RECOVERING)

L0 (Temple):    ████████████████████ 100/100
L1 (Queens):     ███████████████████░░  90/100
L2 (Workers):    ████████████████░░░░░░  75/100
```

**Блокеры**: FPGA UART communication (needs debug)
**Риски**: UART PING timeout — FPGA не отвечает, нужна диагностика bitstream/пинов/reset
