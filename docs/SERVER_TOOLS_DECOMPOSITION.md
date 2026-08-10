# trios-server/tools.rs Декомпозиция

**Created**: 2026-04-19
**Type**: Предложение архитектуры (future work)

---

## Текущее состояние

```
crates/trios-server/ — НЕ СУЩЕСТВУЕТ
```

Модуль `trios-server` ещё не создан. План ниже — архитектурное предложение для создания модуля с использованием существующих TRIOS компонентов.

---

## Проблема

Текущий монолитный подход (если tools.rs был бы создан как единый файл):
- **Одни файл ~9230 байт** со всем dispatch-логикой
- **30+ tool handlers** в одном месте
- **Невозможность масштабирования**: добавление каждого нового домена (golden-float, hdc, physics, sacred, kg, agents, training) увеличивает файл до неуправляемого размера
- **Зависимости смешаны**: FFI (trios-golden-float), HTTP (trios-kg, trios-training), async I/O (fs)

---

## Целевая архитектура

```
crates/trios-server/src/
├── main.rs                          ← MCP server entrypoint
├── mcp.rs                           ← Model Context Protocol
├── security.rs                       ← Auth, encryption
└── tools/                            ← Decoupled tools
    ├── mod.rs                          ← Chain-of-responsibility router
    ├── fs.rs                           ← Filesystem (3 tools)
    ├── git.rs                          ← Core Git (5 tools)
    ├── git_extended.rs                 ← Extended Git (4 tools)
    ├── gitbutler.rs                   ← GitButler (3 tools)
    ├── golden_float.rs                 ← trios-golden-float (4 tools)
    ├── hdc.rs                          ← trios-hdc (4 tools)
    ├── sacred.rs                       ← trios-sacred (4 tools)
    ├── physics.rs                      ← trios-physics (4 tools)
    ├── kg.rs                           ← trios-kg (4 tools)
    ├── agents.rs                       ← trios-agents (4 tools)
    └── training.rs                     ← trios-training (4 tools)
```

---

## Ring-по-кольцевая декомпозиция

### Ring S0: Рефакторинг существующего (если tools.rs есть)
**Ветка**: `feat(server-tools-split)`

| Stage | Действие | Files |
|-------|-----------|--------|
| Stage 1 | Создать `tools/` директорию | `crates/trios-server/src/tools/` |
| Stage 2 | Вынести fs.rs (read/write/list) | `tools/fs.rs` |
| Stage 3 | Вынести git.rs (status/stage/commit/branch) | `tools/git.rs` |
| Stage 4 | Вынести git_extended.rs (log/diff/stash/checkout) | `tools/git_extended.rs` |
| Stage 5 | Вынести gitbutler.rs (branches/push/workspace) | `tools/gitbutler.rs` |
| Stage 6 | Создать mod.rs с chain-of-responsibility | `tools/mod.rs` |
| Stage 7 | Удалить старый tools.rs | DELETE `src/tools.rs` |

**tools/mod.rs** — шаблон:
```rust
use crate::tools::fs;
use crate::tools::git;
use crate::tools::git_extended;
use crate::tools::gitbutler;

pub async fn dispatch(name: &str, input: &Value) -> Result<Value> {
    if let Some(result) = fs::dispatch(name, input).await { return Ok(result); }
    if let Some(result) = git::dispatch(name, input).await { return Ok(result); }
    if let Some(result) = git_extended::dispatch(name, input).await { return Ok(result); }
    if let Some(result) = gitbutler::dispatch(name, input).await { return Ok(result); }
    bail!("unknown tool: {name}");
}
```

---

### Ring S1: `tools/golden_float.rs`

**Зависимость**: `trios-golden-float` (должен быть GREEN)

| Tool | Input | Output |
|------|-------|--------|
| `gf16_encode` | `{"value": f32}` | `{"encoded": i16}` |
| `gf16_decode` | `{"encoded": i16}` | `{"value": f32}` |
| `gf16_compress_weights` | `{"weights": [f32]}` | `{"compressed": [i16], "ratio": f32}` |
| `phi_constant` | `{}` | `{"phi": 1.618...}` |

**Сигнатура dispatch**:
```rust
pub async fn dispatch(name: &str, input: &Value) -> Option<Result<Value>> {
    match name {
        "gf16_encode" => Some(gf16_encode(input)),
        "gf16_decode" => Some(gf16_decode(input)),
        "gf16_compress_weights" => Some(gf16_compress_weights(input)),
        "phi_constant" => Some(Ok(json!({"phi": 1.6180339887498948}))),
        _ => None,
    }
}
```

---

### Ring S2: `tools/hdc.rs`

**Зависимость**: `trios-hdc`

| Tool | Input | Output |
|------|-------|--------|
| `hdc_encode` | `{"data": [f32], "dim": u32}` | `{"hypervector": [i8]}` |
| `hdc_bind` | `{"a": [i8], "b": [i8]}` | `{"bound": [i8]}` |
| `hdc_similarity` | `{"a": [i8], "b": [i8]}` | `{"cosine": f32}` |
| `hdc_search` | `{"query": [i8], "db": [[i8]]}` | `{"matches": [u32]}` |

---

### Ring S3: `tools/sacred.rs`

**Зависимость**: `trios-sacred`

| Tool | Input | Output |
|------|-------|--------|
| `sacred_fibonacci` | `{"n": u32}` | `{"sequence": [u64]}` |
| `sacred_phi_power` | `{"exp": i32}` | `{"value": f64}` |
| `sacred_golden_angle` | `{"n": u32}` | `{"angles": [f64]}` |
| `sacred_spiral_coords` | `{"n": u32, "scale": f32}` | `{"x": [f64], "y": [f64]}` |

---

### Ring S4: `tools/physics.rs`

**Зависимость**: `trios-physics`

| Tool | Input | Output |
|------|-------|--------|
| `physics_constant` | `{"name": str}` | `{"value": f64, "unit": str}` |
| `physics_phi_ratio` | `{"constant": str}` | `{"ratio_to_phi": f64}` |
| `physics_trinity_check` | `{"a": f64, "b": f64}` | `{"is_phi_ratio": bool}` |
| `physics_compute` | `{"formula": str, "params": obj}` | `{"result": f64}` |

---

### Ring S5: `tools/kg.rs`

**Зависимость**: `trios-kg` (HTTP клиент уже реализован)

| Tool | Input | Output |
|------|-------|--------|
| `kg_insert` | `{"subject": str, "predicate": str, "object": str}` | `{"id": str}` |
| `kg_query` | `{"subject": str}` | `{"triples": [...]}` |
| `kg_search` | `{"query": str, "limit": u32}` | `{"results": [...]}` |
| `kg_delete` | `{"id": str}` | `{"deleted": bool}` |

---

### Ring S6: `tools/agents.rs`

**Зависимость**: `trios-agents` + `trios-zig-agents`

| Tool | Input | Output |
|------|-------|--------|
| `agent_spawn` | `{"role": str, "task": str}` | `{"cell_id": str}` |
| `agent_dispatch` | `{"cell_id": str, "message": str}` | `{"result": str}` |
| `agent_status` | `{"cell_id": str}` | `{"status": str, "load": f32}` |
| `agent_list` | `{}` | `{"cells": [...]}` |

---

### Ring S7: `tools/training.rs`

**Зависимость**: `trios-training` (HTTP Railway)

| Tool | Input | Output |
|------|-------|--------|
| `training_start` | `{"config": obj}` | `{"job_id": str}` |
| `training_status` | `{"job_id": str}` | `{"step": u32, "loss": f32, "bpb": f32}` |
| `training_stop` | `{"job_id": str}` | `{"stopped": bool}` |
| `training_results` | `{"job_id": str}` | `{"metrics": obj}` |

---

## Итоговая статистика

| Модуль | Tools | Lines (estimated) |
|--------|-------|-----------------|
| `fs.rs` | 3 | ~150 |
| `git.rs` | 5 | ~250 |
| `git_extended.rs` | 4 | ~200 |
| `gitbutler.rs` | 3 | ~150 |
| `golden_float.rs` | 4 | ~150 |
| `hdc.rs` | 4 | ~200 |
| `sacred.rs` | 4 | ~200 |
| `physics.rs` | 4 | ~200 |
| `kg.rs` | 4 | ~200 |
| `agents.rs` | 4 | ~200 |
| `training.rs` | 4 | ~200 |
| `mod.rs` | 1 (router) | ~50 |
| **ИТОГО** | **43** | ~1950 |

---

## Преимущества декомпозиции

| Аспект | Монолит | Декомпозиция |
|--------|---------|-------------|
| **Обзорность** | 9230 байт, 30+ функций | ~200 строк на модуль, 4-5 функций |
| **Scalability** | Добавить домен = изменить один файл | Добавить модуль = один новый файл |
| **Testing** | Моки для всего dispatch | Моки для отдельных модулей |
| **CI/CD** | Build = rebuild всего | Build = только изменённые модули |
| **Parallel dev** | Lock на файл | Независимая разработка |
| **Зависимости** | Смешаны в одном месте | Чёткое разделение по FFI/HTTP/IO |

---

## Предварительные условия

| Условие | Статус |
|----------|----------|
| `trios-golden-float` GREEN | 📋 |
| `trios-hdc` GREEN | 📋 |
| `trios-physics` GREEN | 📋 |
| `trios-sacred` GREEN | 📋 |
| `trios-kg` GREEN | ✅ |
| `trios-agents` GREEN | ✅ |
| `trios-training` GREEN | ✅ |

---

## Порядок реализации

### Шаг 0: Проверить условия
- [ ] Проверить статус trios-golden-float
- [ ] Проверить статус trios-hdc
- [ ] Проверить статус trios-physics
- [ ] Проверить статус trios-sacred
- [ ] Остановиться на этом этапе если какой-то RED

### Шаг 1: Создать trios-server crate
```bash
cargo new --lib trios-server
mv trios-server crates/
```

### Шаг 2-7: Реализовать Rings S1-S7
- Каждое Ring = отдельный PR
- После каждого Ring: `cargo test -p trios-server`

### Шаг 8: Интеграция с MCP
- [ ] Обновить tool registry в `mcp.rs`
- [ ] Добавить маршрутизацию в main.rs
- [ ] End-to-end тест MCP server

---

## Related Documents

- **ARCHITECTURE_MAP.md**: Обновить после создания trios-server
- **RED_LIST.md**: Убрать блокеры trios-*
- **OPERATIONAL_PLAN.md**: Добавить trios-server создание
