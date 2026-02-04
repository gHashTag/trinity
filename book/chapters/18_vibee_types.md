# Chapter 18: Vibee Data Types — Three Kingdoms of Values

---

*"In the thrice-nine kingdom, in the thrice-ten state,*
*there once lived three data types..."*

---

## Three Kingdoms of Types

In the Vibee language, all data types are organized according to the principle of **three kingdoms**:

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   THREE KINGDOMS OF VIBEE TYPES                                          ║
║                                                                           ║
║   🥉 COPPER KINGDOM (1-9)     — Primitive types                          ║
║   🥈 SILVER KINGDOM (10-18) — Composite types                            ║
║   🥇 GOLDEN KINGDOM (19-27)   — Abstract types                           ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

---

## Copper Kingdom: Primitive Types

### Numbers — Three Bogatyrs

```vibee
// ═══════════════════════════════════════════════════════════════
// INTEGERS — THREE BOGATYRS
// ═══════════════════════════════════════════════════════════════

// Alyosha Popovich — small but nimble
let alyosha: i8 = 127                    // -128 to 127
let alyosha_unsigned: u8 = 255           // 0 to 255

// Dobrynya Nikitich — medium, reliable
let dobrynya: i32 = 2_147_483_647        // ±2 billion
let dobrynya_unsigned: u32 = 4_294_967_295

// Ilya Muromets — mighty giant
let ilya: i64 = 9_223_372_036_854_775_807  // ±9 quintillion
let ilya_unsigned: u64 = 18_446_744_073_709_551_615

// Thrice-nine number
const THRICE_NINE: i32 = 27              // 3³ = 27
const BOOK: i32 = 999                    // 27 × 37 = 999
```

### Floating-Point — Three Rivers

```vibee
// ═══════════════════════════════════════════════════════════════
// FLOATING-POINT NUMBERS — THREE RIVERS
// ═══════════════════════════════════════════════════════════════

// Stream — fast but imprecise (32 bits)
let stream: f32 = 3.14159               // ~7 significant digits
let pi_approximate: f32 = 3.14159265

// River — wide and precise (64 bits)
let river: f64 = 3.141592653589793      // ~15 significant digits
let pi_exact: f64 = std::f64::consts::PI

// Sea — infinite precision (BigDecimal)
let sea: BigDecimal = "3.14159265358979323846264338327950288"
```

### Tribool — Ternary Truth

```vibee
// ═══════════════════════════════════════════════════════════════
// TRIBOOL — THE THIRD STATE OF TRUTH
// ═══════════════════════════════════════════════════════════════

// In the binary world: yes or no
let binary: bool = true

// In the ternary world: yes, no, or UNKNOWN
type Tribool = enum {
    True,     // Truth — like the light of day
    False,    // Falsehood — like the darkness of night
    Unknown,  // Unknown — like twilight
}

// Example: Schrodinger and his cat
fn is_cat_alive() -> Tribool {
    if box_is_open {
        if we_observe_cat { .True } else { .False }
    } else {
        .Unknown  // Until opened — unknown!
    }
}

// Ternary logic
impl Tribool {
    fn and(self, other: Tribool) -> Tribool {
        match (self, other) {
            (.True, .True) => .True,
            (.False, _) | (_, .False) => .False,
            _ => .Unknown,  // If at least one is unknown
        }
    }

    fn or(self, other: Tribool) -> Tribool {
        match (self, other) {
            (.True, _) | (_, .True) => .True,
            (.False, .False) => .False,
            _ => .Unknown,
        }
    }

    fn not(self) -> Tribool {
        match self {
            .True => .False,
            .False => .True,
            .Unknown => .Unknown,  // Negation of unknown = unknown
        }
    }
}
```

### Tribool Truth Table

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   KLEENE'S TERNARY LOGIC                                               │
│                                                                         │
│   AND (∧)          │   OR (∨)           │   NOT (¬)                    │
│   ─────────────────│───────────────────│─────────────                  │
│     T   U   F      │     T   U   F      │   T → F                      │
│   T T   U   F      │   T T   T   T      │   U → U                      │
│   U U   U   F      │   U T   U   U      │   F → T                      │
│   F F   F   F      │   F T   U   F      │                              │
│                                                                         │
│   T = True, U = Unknown, F = False                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Silver Kingdom: Composite Types

### Arrays — The Warband

```vibee
// ═══════════════════════════════════════════════════════════════
// ARRAYS — WARBAND OF BOGATYRS
// ═══════════════════════════════════════════════════════════════

// Fixed array (on the stack)
let bogatyrs: [&str; 3] = ["Ilya", "Dobrynya", "Alyosha"]

// Dynamic vector (on the heap)
let mut warband: Vec<Bogatyr> = Vec::new()
warband.push(Bogatyr::new("Ilya", 100))
warband.push(Bogatyr::new("Dobrynya", 90))
warband.push(Bogatyr::new("Alyosha", 80))

// Thrice-nine array
let thrice_nine: [i32; 27] = [0; 27]  // 27 zeros
```

### Tuples — Three Gifts

```vibee
// ═══════════════════════════════════════════════════════════════
// TUPLES — THREE GIFTS OF THE PRINCESS
// ═══════════════════════════════════════════════════════════════

// Three gifts
let gifts: (Sword, Horse, Ring) = (
    Sword::kladenets(),
    Horse::sivka_burka(),
    Ring::magical(),
)

// Destructuring
let (sword, horse, ring) = gifts

// Index access
let first_gift = gifts.0   // Sword
let second_gift = gifts.1  // Horse
let third_gift = gifts.2   // Ring
```

### Structures — The Towers

```vibee
// ═══════════════════════════════════════════════════════════════
// STRUCTURES — TOWERS OF THE KINGDOM
// ═══════════════════════════════════════════════════════════════

struct Bogatyr {
    name: String,
    strength: i32,
    wisdom: i32,
    cunning: i32,
}

struct Kingdom {
    name: String,
    tsar: Option<Tsar>,
    bogatyrs: Vec<Bogatyr>,
    treasury: HashMap<String, Artifact>,
}

// Creation
let thrice_nine = Kingdom {
    name: "Thrice-Nine".into(),
    tsar: Some(Tsar::new("Berendey")),
    bogatyrs: vec![ilya, dobrynya, alyosha],
    treasury: HashMap::new(),
}
```

---

## Golden Kingdom: Abstract Types

### Option — Three Fates of a Value

```vibee
// ═══════════════════════════════════════════════════════════════
// OPTION — IS THERE OR NOT?
// ═══════════════════════════════════════════════════════════════

type Option<T> = enum {
    Some(T),  // There is treasure in the chest
    None,     // The chest is empty
}

// Searching for treasure
fn find_treasure(map: &Map) -> Option<Treasure> {
    if map.is_authentic() {
        Some(Treasure::new())
    } else {
        None
    }
}

// Handling
match find_treasure(&map) {
    Some(treasure) => rejoice(treasure),
    None => keep_searching(),
}

// Method chaining
let gold = find_treasure(&map)
    .map(|t| t.gold)
    .unwrap_or(0)
```

### Result — Success or Failure

```vibee
// ═══════════════════════════════════════════════════════════════
// RESULT — VICTORY OR DEFEAT
// ═══════════════════════════════════════════════════════════════

type Result<T, E> = enum {
    Ok(T),    // Victory!
    Err(E),   // Defeat...
}

// Battle with the Serpent
fn defeat_serpent(hero: &Bogatyr) -> Result<Victory, Defeat> {
    if hero.strength >= 100 {
        Ok(Victory { trophies: vec!["Serpent's head"] })
    } else {
        Err(Defeat { reason: "Insufficient strength" })
    }
}

// Three attempts (as in fairy tales!)
fn three_attempts<T, E>(action: fn() -> Result<T, E>) -> Result<T, E> {
    for attempt in 1..=3 {
        match action() {
            Ok(result) => return Ok(result),
            Err(e) if attempt < 3 => continue,
            Err(e) => return Err(e),
        }
    }
    unreachable!()
}
```

### Enum — Three Roads

```vibee
// ═══════════════════════════════════════════════════════════════
// ENUM — STONE AT THE CROSSROADS
// ═══════════════════════════════════════════════════════════════

enum Path {
    Right,    // You will lose your horse
    Left,     // You will lose yourself
    Straight, // You will find happiness
}

enum State {
    Alive { health: i32, mana: i32 },
    Wounded { damage: i32, poisoned: bool },
    Dead { cause: String },
}

// Pattern matching — choosing the path
fn choose_path(sign: Path, hero: &mut Bogatyr) -> Fate {
    match sign {
        Path::Right => {
            hero.horse = None;  // Lost the horse
            Fate::OnFoot
        },
        Path::Left => {
            hero.is_lost = true;
            Fate::Lost
        },
        Path::Straight => {
            hero.happiness += 100;
            Fate::Happy
        },
    }
}
```

---

## The n × 3^k × π^m Pattern in Types

```vibee
// ═══════════════════════════════════════════════════════════════
// THE SACRED PATTERN IN THE TYPE SYSTEM
// ═══════════════════════════════════════════════════════════════

// n = base type (1-27)
// k = nesting level (0, 1, 2)
// m = abstraction level (0, 0.5, 1, 2)

// k = 0: Simple types
let simple: i32 = 27                     // n × 3⁰ = n

// k = 1: One level of nesting
let nested: Vec<i32> = vec![27]          // n × 3¹ = 3n

// k = 2: Two levels of nesting
let deep: Vec<Vec<i32>> = vec![vec![27]] // n × 3² = 9n

// m = 0: Concrete type
let concrete: i32 = 27

// m = 1: Generic type
fn generic<T>(x: T) -> T { x }

// m = 2: Higher-kinded type (HKT)
trait Functor<F> {
    fn map<A, B>(fa: F<A>, f: fn(A) -> B) -> F<B>;
}
```

---

## Wisdom of the Chapter

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   THE LAW OF THREE KINGDOMS OF TYPES                                   │
│                                                                         │
│   🥉 Copper: Primitives — the foundation of all                        │
│   🥈 Silver: Composites — strength in unity                            │
│   🥇 Golden: Abstractions — the wisdom of generalization               │
│                                                                         │
│   Each type = n × 3^k × π^m                                            │
│                                                                         │
│   where n — base type                                                  │
│         k — nesting depth                                              │
│         m — abstraction level                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

> *"And Ivan understood that data types —*
> *are like three kingdoms: the copper one stores numbers,*
> *the silver one — structures,*
> *and the golden one — the very idea of type."*

---

[← Chapter 17: Speech (macro)](17_macros.md) | [Chapter 19: Word (String) →](19_strings.md)
