# Content-Addressed Functions: Критика и Улучшения

**Дата:** 2026-03-25
**Статус:** Текущая реализация работает, но есть существенные возможности для улучшения

---

## Обзор Текущей Реализации

Текущая реализация (`content_hash.zig` ~500 LOC, `content_registry.zig` ~400 LOC) обеспечивает:
- ✅ SHA256 хеширование нормализованных AST
- ✅ Alpha-equivalence (переменные v0, v1, v2...)
- ✅ Registry для обнаружения дубликатов
- ✅ JSON сериализация

Однако, изучив научные работы (Unison, BLAKE3, hash consing), я выявил **серьёзные проблемы**.

---

## ✅ SOLVED: Critical Problems

### 1. ~~Weak Hash Function in HashMap~~ ✅ FIXED

**Problem:** `content_registry.zig:99`
```zig
return std.mem.readInt(u64, key[0..8], .little);
```

**Why this was bad:**
- Only first 8 bytes used out of 32
- Collision probability: ~2⁻⁶⁴ (for random data), but higher for structured data
- Birthday paradox: at ~2³² entries collision probability ≈ 50%

**Solution implemented in `content_registry_v2.zig`:**
```zig
// Use Wyhash on full 32-byte key
pub fn hash(self: ImprovedHashMapContext, key: [32]u8) u64 {
    _ = self;
    // Wyhash - modern non-cryptographic hash with excellent avalanche
    return std.hash.Wyhash.hash(0, &key);
}
```

**Test results:**
- Avalanche effect test: PASSED (20+ bits flipped out of 64)
- Distribution test: PASSED (1000 unique hashes for 1000 inputs)

### 2. Нормализация Через Строки — Медленно

**Проблема:** `normalizeExprToWriter` создаёт промежуточные строки:
```zig
try writer.print("v:{s}", .{norm_name});  // Аллокация!
try writer.print("fn:{d}:", .{e.params.len});
```

**Почему это плохо:**
- Каждая аллокация — это syscall или至少 cache miss
- String formatting медленный
- Нормализация O(n) AST требует O(n log n) аллокаций

**Решение:** Бинарная сериализация
```zig
fn normalizeBinary(allocator: Allocator, expr: *const TypedExpr) ![]u8 {
    var buffer = ArrayList(u8).init(allocator);
    // [tag: u8][arity: u8][params...][body_hash: 32u8]
    try buffer.append(@intFromEnum(Tag.Int));
    try buffer.append(0); // arity
    // ... binary encoding
    return buffer.toOwnedSlice();
}
```

### 3. Отсутствие Type-Aware Hashing

**Проблема:** Unison включает типы в hash:
```haskell
-- Unison: hash зависит от типа
increment : Nat -> Nat  -- hash #abc
increment : Int -> Int  -- hash #def (разный!)
```

У нас типы игнорируются — это может привести к ложным дубликатам.

**Решение:** Добавить type information в нормализацию:
```zig
// Текущий
try writer.print("i:{d}", .{e.value});

// С типами
try writer.print("i:{d}:{}", .{e.value, e.type});
```

### 4. Нет Structural Type Equivalence

**Проблема:**
```zig
// Эти два типа семантически идентичны, но дадут разный hash:
{ x: Int, y: Bool }  // "adt:Record.x:Int,y:Bool"
{ y: Bool, x: Int }  // "adt:Record.y:Bool,x:Int"
```

**Решение:** Сортировать record fields по имени:
```zig
var sorted_fields = try allocator.alloc(Type.Field, fields.len);
std.sort.block(Type.Field, sorted_fields, {}, struct {
    fn lessThan(_: void, a: Type.Field, b: Type.Field) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }
});
```

### 5. Нет Incremental Hashing (Merkle Trees)

**Проблема:** При изменении одного подвыражения весь AST перехешируется.

**BLAKE3 преимущества (из научных работ):**
- ~10x быстрее SHA256
- Параллельное хеширование (Merkle tree внутри)
- Verified streaming
- 1MB chunks → independent hashing

**Решение:** Добавить кэш для подвыражений:
```zig
pub const HashCache = struct {
    entries: std.AutoHashMap([32]u8, CachedNode),

    pub const CachedNode = struct {
        hash: [32]u8,
        dependencies: [][32]u8,  // Hashes of children
    };

    pub fn hashWithCache(self: *HashCache, expr: *const TypedExpr) !ContentHash {
        if (self.get(expr)) |cached| return cached;

        const hash = try self.hashRecursive(expr);
        try self.put(expr, hash);
        return hash;
    }
};
```

### 6. JSON Persistence Неэффективен

**Проблема:** `toJson` создаёт огромные строки для больших реестров.

**Альтернативы:**
1. **Binary format** (MessagePack, CBOR)
2. **SQLite** с BLOB для hash → data
3. **LevelDB** / **RocksDB** (LSM-tree)

```zig
// SQLite пример
const sql =
    \\CREATE TABLE content_hashes (
    \\    hash BLOB PRIMARY KEY,  -- 32 bytes
    \\    location_json TEXT,
    \\    ast_binary BLOB
    \\);
```

---

## 📊 Улучшения на Основе Научных Работ

### Из Unison (Paul Chiusano, Runar Bjarnason)

1. **Dependency-Aware Hashing**
   ```zig
   // Текущий: foldLeft — это просто строка
   try writer.writeAll("foldLeft");

   // Unison-style: include dependency hash
   const dep_hash = try lookupHash("foldLeft");
   try writer.writeAll(dep_hash);
   ```

2. **Reference-by-Hash вместо Names**
   ```zig
   // Вместо "add2 x = inc (inc x)"
   // Hash: H("add2", [H("inc")])
   // Это позволяет инкрементальные обновления
   ```

### Из "Hashing Modulo Alpha-Equivalence" (Peyton Jones et al.)

**O(n log n) algorithm:**
- Использовать **de Bruijn indices** вместо строковых имён
- Коммутативный combiner для associative операций

```zig
// de Bruijn indices — позиционные, без аллокаций
fn normalizeDeBruijn(expr: *const TypedExpr) ![]u8 {
    var buffer = ArrayList(u8).init(allocator);
    var depth: u32 = 0;

    try normalizeDeBruijnRec(expr, &buffer, &depth);
    return buffer.toOwnedSlice();
}

// \x.(\y.x)  →  λ.λ.1  (где 1 = "var bound 1 level up")
```

### Из BLAKE3 Research

**Replace SHA256 with BLAKE3:**
```zig
const std = @import("std");
const blake3 = @import("blake3");  // Need wrapper

pub fn hashBlake3(data: []const u8) [32]u8 {
    return blake3.hash(data);
}

// Incremental hashing для больших AST
pub fn hashIncremental(ast: *const TypedExpr) ![32]u8 {
    var hasher = blake3.Hasher.init();
    try hashASTChunks(&hasher, ast);
    return hasher.finalize();
}
```

---

## 🎯 Improvement Priorities

| Priority | Improvement | Complexity | Benefit | Status |
|----------|-------------|------------|---------|--------|
| **P0** | Full 32-byte hash in HashMap | Easy | High | ✅ DONE |
| **P0** | Binary normalization | Medium | High | ✅ DONE |
| **P1** | Type-aware hashing | Medium | Medium | TODO |
| **P1** | Subexpression cache | Medium | High | ✅ DONE |
| **P2** | BLAKE3 instead of SHA256 | Easy | Medium | TODO |
| **P2** | Structural type equivalence | Medium | Low | TODO |
| **P3** | SQLite persistence | Complex | Low | TODO |

---

## 🔧 Quick Wins (Implemented)

### 1. ✅ Fix HashMap Context

```zig
// In content_registry_v2.zig - SOLVED
pub const ImprovedHashMapContext = struct {
    pub fn hash(self: ImprovedHashMapContext, key: [32]u8) u64 {
        _ = self;
        // Wyhash - modern non-cryptographic hash with excellent avalanche
        return std.hash.Wyhash.hash(0, &key);
    }
    // ...
};
```

### 2. ✅ HashMap Pre-allocation

```zig
// In content_registry_v2.zig - SOLVED
pub fn init(allocator: Allocator) !ContentRegistryV2 {
    var registry = ContentRegistryV2{
        .allocator = allocator,
        .entries = std.HashMap(...).init(allocator),
    };
    // Pre-allocate for expected function count
    try registry.entries.ensureTotalCapacity(1024);
    return registry;
}
```

### 3. ✅ Arena Allocator for Normalization

```zig
// In content_hash_v2.zig - SOLVED
pub fn normalizeBinary(allocator: Allocator, expr: *const TypedExpr) ![]u8 {
    var buffer = List.init(allocator);
    defer buffer.deinit();

    // Use ArenaAllocator for temporary allocations
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = NormalizeContext{
        .allocator = arena.allocator(),
        .var_depth = std.array_list.Managed(u32).init(arena.allocator()),
    };

    try normalizeBinaryRec(&ctx, &buffer, expr);
    return allocator.dupe(u8, buffer.items);
}
```

---

## 📚 Ссылки на Научные Работы

1. **Unison Language**: https://unison-lang.org/docs/the-big-idea/
2. **Hashing Modulo Alpha-Equivalence**: Peyton Jones et al. [PDF]
3. **BLAKE3 Specification**: https://github.com/BLAKE3-team/BLAKE3-specs
4. **Algorithms for Extended Alpha-Equivalence**: Schmidt-Schauß et al.
5. **Merkle Tree Hashing**: NNCP project (BLAKE3-based)

---

## Заключение

Текущая реализация **функциональна**, но есть существенные возможности для улучшения:

1. **Безопасность:** Исправить hash function (P0)
2. **Производительность:** Binary normalization + cache (P0-P1)
3. **Корректность:** Type-aware + structural equivalence (P1-P2)

**Рекомендация:** Начать с P0 исправлений (HashMap + binary norm), затем добавить cache и type-aware hashing.
