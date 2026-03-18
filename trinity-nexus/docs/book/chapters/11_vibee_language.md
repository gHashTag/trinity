# Chapter 14: The Vibee Language — A Tale of the Ternary Kingdom

---

*"And Ivan saw a magic book in the tower,*
*and in it — a language for speaking with machines..."*

---

## Prologue: The Birth of the Language

In the thrice-nine kingdom of programming, where binary kings — C, Java, Python — ruled, a new language was born. They named it **Vibee** — from the word "vibration", for everything in the world vibrates at the frequency of three.

---

## Book One: Three Data Types

### Chapter of Simple Types

```vibee
// ===================================================================
// THREE KINGDOMS OF NUMBERS
// ===================================================================

// Kingdom of integers (like three heroes of different strength)
let small: i8 = 127              // Alyosha — small but nimble
let medium: i32 = 2147483647     // Dobrynya — medium, reliable
let giant: i64 = 9223372036854775807 // Ilya — mighty

// Kingdom of fractions (like three rivers)
let stream: f32 = 3.14           // Fast but imprecise
let river: f64 = 3.141592653589793 // Wide and precise

// Kingdom of truth (TERNARY!)
let yes: bool = true
let no: bool = false
let maybe: Tribool = .Unknown    // THE THIRD STATE!
```

### Chapter of Ternary Truth

```vibee
// ===================================================================
// TRIBOOL: THREE STATES OF TRUTH
// ===================================================================

// In the binary world there is only yes and no.
// In the ternary world there is also "unknown".

type Tribool = enum {
    True,     // Truth — like the light of day
    False,    // Falsehood — like the darkness of night
    Unknown,  // Unknown — like twilight
}

// Example: age verification
fn can_enter(age: ?i32) -> Tribool {
    match age {
        Some(v) if v >= 18 => .True,    // Yes, allowed
        Some(v) if v < 18 => .False,    // No, not allowed
        None => .Unknown,                // Age unknown
    }
}

// Ternary logic
let a: Tribool = .True
let b: Tribool = .Unknown

let and_result = a.and(b)  // Unknown (we don't know b)
let or_result = a.or(b)    // True (a is sufficient)
let not_result = b.not()   // Unknown (don't know what to negate)
```

### Chapter of Three States of Value

```vibee
// ===================================================================
// OPTION: THREE FATES OF A VALUE
// ===================================================================

// Like in a fairy tale: present, absent, or enchanted
type Option<T> = enum {
    Some(T),    // Treasure is in the chest
    None,       // Chest is empty
    Unknown,    // Chest is enchanted, cannot open
}

// Example: treasure hunt
fn find_treasure(map: Map) -> Option<Treasure> {
    if map.has_mark() {
        let place = map.get_location()
        if dig(place) {
            return .Some(Treasure.new())
        } else {
            return .None  // Dug, but empty
        }
    }
    return .Unknown  // Map is unclear
}

// Handling three fates
match find_treasure(my_map) {
    Some(treasure) => rejoice(treasure),
    None => keep_searching(),
    Unknown => study_map(),  // The third path!
}
```

---

## Book Two: Three Roads of Branching

### Chapter of the Crossroads

```vibee
// ===================================================================
// MATCH: THREE ROADS AT THE CROSSROADS
// ===================================================================

// Like the stone at the crossroads in a fairy tale
fn choose_path(sign: Sign) -> Fate {
    match sign {
        .Right => {
            // "Go right — lose your horse"
            lose_horse()
            .OnFoot
        },
        .Left => {
            // "Go left — lose yourself"
            get_lost()
            .Lost
        },
        .Straight => {
            // "Go straight — find happiness"
            find_happiness()
            .Happy
        },
    }
}
```

### Chapter of Ternary Comparison

```vibee
// ===================================================================
// SPACESHIP OPERATOR: THREE OUTCOMES OF COMPARISON
// ===================================================================

// The <=> operator returns three possible results
let result = hero_1.strength <=> hero_2.strength

match result {
    .Less => print("First is weaker"),
    .Equal => print("Equal in strength"),    // The middle path!
    .Greater => print("First is stronger"),
}

// Automatic generation for structures
@derive(Ord)
struct Hero {
    name: String,
    strength: i32,
    wisdom: i32,

    // The compiler automatically creates ternary comparison!
}

// Now you can compare heroes
let who_is_greater = ilya <=> dobrynya
```

### Chapter of Three Attempts

```vibee
// ===================================================================
// RETRY: THREE ATTEMPTS OF THE HERO
// ===================================================================

// In fairy tales, the hero always gets three attempts
fn defeat_dragon(hero: Hero, dragon: Dragon) -> Result {
    for attempt in 1..=3 {
        match hero.attack(dragon) {
            .Victory => return .Success,
            .Defeat if attempt < 3 => {
                hero.rest()
                hero.get_advice()  // Wisdom grows
                continue
            },
            .Defeat => return .Failure,
        }
    }
    unreachable!()
}

// Or with built-in retry
let result = @retry(3) {
    try_to_open_door()
}
```

---

## Book Three: Three Heroes of Structures

### Chapter of Structures

```vibee
// ===================================================================
// STRUCT: THREE HEROES
// ===================================================================

struct Hero {
    // Three main qualities
    strength: i32,   // Ilya Muromets
    wisdom: i32,     // Dobrynya Nikitich
    cunning: i32,    // Alyosha Popovich

    // Name and equipment
    name: String,
    horse: Option<Horse>,
    sword: Option<Sword>,
}

impl Hero {
    // Three ways to create
    fn new(name: String) -> Self {
        Self {
            name: name,
            strength: 10,
            wisdom: 10,
            cunning: 10,
            horse: .None,
            sword: .None,
        }
    }

    fn ilya() -> Self {
        Self { name: "Ilya Muromets", strength: 100, wisdom: 50, cunning: 30, .. }
    }

    fn dobrynya() -> Self {
        Self { name: "Dobrynya Nikitich", strength: 70, wisdom: 90, cunning: 50, .. }
    }

    fn alyosha() -> Self {
        Self { name: "Alyosha Popovich", strength: 50, wisdom: 60, cunning: 100, .. }
    }

    // Total power — sum of three qualities
    fn power(self) -> i32 {
        self.strength + self.wisdom + self.cunning
    }
}
```

### Chapter of Enumerations

```vibee
// ===================================================================
// ENUM: THREE KINGDOMS
// ===================================================================

// Three worlds of Slavic mythology
enum World {
    Prav,   // World of gods (heaven)
    Yav,    // World of humans (earth)
    Nav,    // World of the dead (underworld)
}

// Three states of the hero
enum HeroState {
    Alive { health: i32 },
    Wounded { health: i32, wounds: Vec<Wound> },
    Dead { cause: String },
}

// Three outcomes of battle
enum BattleOutcome {
    Victory { trophies: Vec<Trophy> },
    Draw,
    Defeat { losses: Vec<Loss> },
}

// Handling three outcomes
fn after_battle(outcome: BattleOutcome) {
    match outcome {
        Victory { trophies } => {
            for trophy in trophies {
                put_in_chest(trophy)
            }
            celebrate()
        },
        Draw => {
            rest()
            prepare_for_new_battle()
        },
        Defeat { losses } => {
            mourn(losses)
            learn_from_mistakes()
            // But don't give up! There will be another attempt.
        },
    }
}
```

---

## Book Four: Three Wonders of Collections

### Chapter of Trinity B-Tree

```vibee
// ===================================================================
// TRINITY B-TREE: TREE WITH THREE BRANCHES
// ===================================================================

// B-tree with branching factor = 3 (optimal!)
let tree = TrinityBTree<i32, Treasure>.new()

// Three heroes store treasures
tree.insert(1, Treasure.sword("Kladenets"))
tree.insert(2, Treasure.shield("Impenetrable"))
tree.insert(3, Treasure.helmet("Invisibility"))

// Search — 6% faster than b=2 or b=4!
match tree.find(2) {
    Some(treasure) => print("Found: {}", treasure),
    None => print("Not found"),
}
```

### Chapter of Trinity Hash

```vibee
// ===================================================================
// TRINITY HASH: THREE KEYS TO THE CHEST
// ===================================================================

// Cuckoo Hash with three hash functions
// 91% capacity instead of 50%!
let chests = TrinityHash<String, Gold>.new()

// Three keys open three locks
chests.insert("first_key", Gold(100))
chests.insert("second_key", Gold(200))
chests.insert("third_key", Gold(300))

// Search checks three places
let gold = chests.get("second_key")
```

### Chapter of Ternary Search Tree

```vibee
// ===================================================================
// TST: TREE OF THREE ROADS
// ===================================================================

// Each node has three children: <, =, >
let dictionary = TernarySearchTree<String>.new()

// Wizard's spells
dictionary.insert("abracadabra")
dictionary.insert("abra")
dictionary.insert("cadabra")
dictionary.insert("sim-salabim")

// Prefix search — three roads at each step
let spells = dictionary.find_by_prefix("abr")
// Result: ["abra", "abracadabra"]
```

---

## Book Five: Three Spells of Functions

### Chapter of Functions

```vibee
// ===================================================================
// FUNCTIONS: THREE KINDS OF SPELLS
// ===================================================================

// First spell: pure function (no side effects)
fn add(a: i32, b: i32) -> i32 {
    a + b
}

// Second spell: function with state
fn increase_strength(hero: &mut Hero, by: i32) {
    hero.strength += by
}

// Third spell: higher-order function
fn apply_to_each<T, F>(list: []T, spell: F)
where F: Fn(T) -> T
{
    for element in list {
        *element = spell(*element)
    }
}

// Three ways to call
let sum = add(2, 3)                      // Direct call
increase_strength(&mut ilya, 10)         // Mutation
apply_to_each(numbers, |x| x * 3)        // Higher-order
```

### Chapter of Closures

```vibee
// ===================================================================
// CLOSURES: ENCHANTED FUNCTIONS
// ===================================================================

// A closure remembers context, like an enchanted object
fn create_multiplier(by: i32) -> impl Fn(i32) -> i32 {
    // The closure "remembers" the value of `by`
    |x| x * by
}

let triple = create_multiplier(3)  // Ternary spell!
let result = triple(7)  // 21

// Three kinds of closures
let fn_once_only = |x| x + 1              // Fn — only reads
let fn_mut = |x| { counter += 1; x }      // FnMut — modifies
let fn_once = || { take(treasure) }       // FnOnce — consumes
```

---

## Book Six: Three Trials of Error Handling

### Chapter of Result

```vibee
// ===================================================================
// RESULT: THREE OUTCOMES OF A TRIAL
// ===================================================================

type Result<T, E> = enum {
    Ok(T),      // Trial passed
    Err(E),     // Trial failed
    Pending,    // Trial continues (for async!)
}

// Example: open a magic door
fn open_door(key: Key, door: Door) -> Result<Treasure, Error> {
    if !key.fits(door) {
        return .Err(Error.WrongKey)
    }

    if door.is_enchanted() {
        return .Pending  // Need to remove the spell
    }

    .Ok(door.open())
}

// Handling three outcomes
match open_door(my_key, secret_door) {
    Ok(treasure) => rejoice(treasure),
    Err(error) => search_for_another_key(),
    Pending => seek_wizard(),  // The third path!
}
```

### Chapter of Decision

```vibee
// ===================================================================
// DECISION: THREE DECISIONS OF THE SAGE
// ===================================================================

type Decision<T> = enum {
    Accept(T),  // Accept
    Reject,     // Reject
    Defer,      // Defer the decision
}

// The sage makes a decision
fn sage_decision(petitioner: Petitioner) -> Decision<Blessing> {
    let worthiness = evaluate(petitioner)

    if worthiness >= 0.9 {
        .Accept(Blessing.full())
    } else if worthiness <= 0.1 {
        .Reject
    } else {
        .Defer  // "Come back in a year"
    }
}
```

---

## Book Seven: Three Wonders of Parallelism

### Chapter of Async/Await

```vibee
// ===================================================================
// ASYNC: THREE STREAMS OF TIME
// ===================================================================

// Three heroes set out on a journey simultaneously
async fn quest_of_three_heroes() -> Vec<Trophy> {
    // Launch three tasks in parallel
    let ilya_task = async { ilya.defeat_nightingale() }
    let dobrynya_task = async { dobrynya.defeat_dragon() }
    let alyosha_task = async { alyosha.defeat_tugarin() }

    // Wait for all three
    let (trophy_1, trophy_2, trophy_3) = await join!(
        ilya_task,
        dobrynya_task,
        alyosha_task
    )

    vec![trophy_1, trophy_2, trophy_3]
}

// Three states of Future
enum FutureState<T> {
    Pending,     // Still executing
    Ready(T),    // Ready
    Cancelled,   // Cancelled
}
```

---

## Epilogue: Wisdom of the Language

```vibee
// ===================================================================
// SUMMARY: TERNARY WISDOM OF VIBEE
// ===================================================================

// Three types of truth: True, False, Unknown
// Three states of value: Some, None, Unknown
// Three outcomes of operation: Ok, Err, Pending
// Three decisions: Accept, Reject, Defer

// Three roads of branching: <, =, >
// Three attempts of the hero: retry(3)
// Three heroes of collections: BTree, Hash, TST

// Three phases of compilation: Parse, Check, Generate
// Three levels of optimization: Local, Global, Trinity
// 999 windows of the tower: 3 x 333

// And the main wisdom:
//
// "In the thrice-nine kingdom of the Vibee language
//  everything obeys the law of three.
//  For three is the minimal complexity
//  for the existence of structure."
```

---

## Wisdom of the Chapter

> *And Ivan read the magic book to the end,*
> *and he understood the language for speaking with machines.*
>
> *Three data types — like three kingdoms.*
> *Three roads of branching — like the crossroads.*
> *Three heroes of collections — like defenders.*
> *Three states — like fates.*
>
> *And Ivan said: "Now I know the Vibee language,*
> *and I can work wonders in the thrice-nine kingdom of code."*
>
> *And he became a great programmer,*
> *and wrote programs that worked*
> *291 times faster than before.*
>
> *For he knew the secret of the number three.*

---

[<- Chapter 13](13_architecture_deep.md) | [Table of Contents](../README.md)
