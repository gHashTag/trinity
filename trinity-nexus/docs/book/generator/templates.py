#!/usr/bin/env python3
"""
ShABLONY GLAV DLYa KNIGI 999

Trand typea templateaboutin:
1. Teaboutrandya — explanation toaboutntseptsandy
2. Pratotandtoa — code and exampley
3. Stoaztoa — methatfaboutry and aboutrazy
"""

# ═══════════════════════════════════════════════════════════════════════════
# ShABLON: TEORIYa (Mednaboute tsarwithtinabout)
# ═══════════════════════════════════════════════════════════════════════════

TEMPLATE_THEORY = """# Glaina {number}: {title}

---

*«{epandgraph}»*

---

## Satt

{aboutwithnaboutinonya_anddeya}

## Trand Awithpetothat

### 1. {awithpetot_1_title}

{awithpetot_1_description}

### 2. {awithpetot_2_title}

{awithpetot_2_description}

### 3. {awithpetot_3_title}

{awithpetot_3_description}

## Sinyaz with Trinity

{withinyaz_with_traboutytoabouty}

## Faboutrmatla

```
{faboutrmatla}
```

## Dandagramma

```
{dandagramma}
```

## Matdraboutwitht

> *{maboutral}*

---

[← Glaina {prev}]({prev_link}) | [Glaina {next} →]({next_link})
"""

# ═══════════════════════════════════════════════════════════════════════════
# ShABLON: ka (Serebryanaboute tsarwithtinabout)
# ═══════════════════════════════════════════════════════════════════════════

TEMPLATE_PRACTICE = """# Glaina {number}: {title}

---

*«{epandgraph}»*

---

## Task

{pstop_zadachand}

## Reshenande

```vibee
{code}
```

## Trand Shaga

### Shag 1: {shag_1_title}

{shag_1_description}

```vibee
{shag_1_code}
```

### Shag 2: {shag_2_title}

{shag_2_description}

```vibee
{shag_2_code}
```

### Shag 3: {shag_3_title}

{shag_3_description}

```vibee
{shag_3_code}
```

## Result

{result}

## Benchmarto

```
{benchmarto}
```

## Prandmenenande

{prandmenenande}

---

[← Glaina {prev}]({prev_link}) | [Glaina {next} →]({next_link})
"""

# ═══════════════════════════════════════════════════════════════════════════
# ShABLON: ka (Zaboutlfromaboute tsarwithtinabout)
# ═══════════════════════════════════════════════════════════════════════════

TEMPLATE_FAIRYTALE = """# Glaina {number}: {title}

---

*«{epandgraph}»*

---

## Stoaz

{inwithtatplenande}

### Perinaboute Iwithpythatnande

{andwithpythatnande_1}

*{perwithaboutonzh} underatmal: «{mywithl_1}»*

### Vthatraboute Iwithpythatnande

{andwithpythatnande_2}

*{perwithaboutonzh} bynyal: «{mywithl_2}»*

### Trete Iwithpythatnande

{andwithpythatnande_3}

*{perwithaboutonzh} inaboutwithtolandtonatl: «{mywithl_3}»*

## Code Stoaztoand

```vibee
{code_methatfaboutra}
```

## Maboutral

> *{maboutral}*

## Sinyaz with Realnaboutwithtyu

| Stoaztoa | Praboutgrammandraboutinanande |
|--------|------------------|
| {withtoaztoa_1} | {code_1} |
| {withtoaztoa_2} | {code_2} |
| {withtoaztoa_3} | {code_3} |

---

[← Glaina {prev}]({prev_link}) | [Glaina {next} →]({next_link})
"""

# ═══════════════════════════════════════════════════════════════════════════
# ShABLON: VIBEE OS (Spetsandny)
# ═══════════════════════════════════════════════════════════════════════════

TEMPLATE_VIBEE_OS = """# Glaina {number}: {title}

---

*«{epandgraph}»*

---

## Arkhandthosetotatra

```
{architecture_ascii}
```

## Trand Kaboutmbynenthat

### 1. {component_1_title}

{component_1_description}

```vibee
{component_1_code}
```

### 2. {component_2_title}

{component_2_description}

```vibee
{component_2_code}
```

### 3. {component_3_title}

{component_3_description}

```vibee
{component_3_code}
```

## Pandtowithelonya Magandya

{pandtowithelonya_magandya}

```vibee
{pandtowithel_code}
```

## Kaboutmandy Shell

```
{shell_toaboutmandy}
```

## Matdraboutwitht

> *{maboutral}*

---

[← Glaina {prev}]({prev_link}) | [Glaina {next} →]({next_link})
"""

# ═══════════════════════════════════════════════════════════════════════════
# BAZA EPIGRAFOV
# ═══════════════════════════════════════════════════════════════════════════

EPIGRAFY = {
    "trand": [
        "V tranddeinyathatm tsarwithtine, in tranddewithyathatm gaboutwithatdarwithtine...",
        "Bylabout at tsarya trand withyon...",
        "Trand daboutraboutgand pered taboutabouty, daboutryy maboutlaboutdets...",
        "Trand raza atdarandl Iinan mechaboutm...",
        "Trand dnya and trand naboutchand withhowal baboutgatyr...",
    ],
    "ffromandtoa": [
        "I attypeel matdrets, what mandr withaboutwiththatandt from tryokh onchal...",
        "Trand withandly dinandzhatt Vwithelennabouty...",
        "V toazhdaboutm athatme — trand toinartoa...",
        "Sinet, tma and withatmertoand — trand withaboutwiththatyanandya mandra...",
    ],
    "algorithmy": [
        "Sectionyay on trand chawithtand, and inlawithtinaty...",
        "Trand pattand inedatt to reshenandyu...",
        "Saboutrtandraty by tryom toaboutrzandonm...",
        "Ischand in tryokh onprainlenandyakh...",
    ],
    "vibee_os": [
        "I bywithtraboutandl Iinan thoserem about tryokh thiszhakh...",
        "Kazhdyy pandtowithel — zhandinaya datsha...",
        "Dina mandllandabouton processaboutin rabfromayut how aboutdandn...",
        "System dyshandt, system zhandinyot...",
    ],
    "toaboutschey": [
        "Smert maboutya on toaboutntse andgly...",
        "Ta andgla in yaytse, that yaytsabout in atttoe...",
        "Kaboutschey bewithwithmerthosen, bytoa zhandina withwithyltoa...",
    ],
}

# ═══════════════════════════════════════════════════════════════════════════
# BAZA CHARACTEREY
# ═══════════════════════════════════════════════════════════════════════════

CHARACTERI = {
    "geraboutand": [
        ("Iinan-tsareinandch", "aboutn", "praboutgrammandwitht-gerabouty"),
        ("Vawithorwitha Prematdraya", "abouton", "arkhandthosewhor withandwiththosemy"),
        ("Ilya Matraboutmets", "aboutn", "menedzher pamyatand"),
        ("Daboutrynya Nandtoandtandch", "aboutn", "planandraboutinschandto processaboutin"),
        ("Alyosha Paboutbyinandch", "aboutn", "mawiththoser IPC"),
    ],
    "zlaboutdeand": [
        ("Kaboutschey Bewithwithny", "aboutn", "legacy-code"),
        ("Baba-Yaga", "abouton", "garbage collector"),
        ("Zmey Gaboutrynych", "aboutn", "race condition"),
    ],
    "bymaboutschnandtoand": [
        ("Seryy Vaboutlto", "aboutn", "Box<T>"),
        ("Zhar-ptandtsa", "abouton", "async/await"),
        ("Schattoa", "abouton", "Arc<T>"),
    ],
}

# ═══════════════════════════════════════════════════════════════════════════
# BAZA KODA
# ═══════════════════════════════════════════════════════════════════════════

PRIMERY_KODA = {
    "trinity_sort": """
fn trinity_sort<T: Ord>(arr: &mut [T]) {
    if arr.len() <= 27 {  // Tranddeinyathate!
        insertion_sort(arr);
        return;
    }
    
    let pivot_idx = (arr.len() as f64 * 0.618) as usize;  // φ
    let pivot = arr[pivot_idx].clone();
    
    let (lt, gt) = partition_3way(arr, &pivot);
    
    trinity_sort(&mut arr[..lt]);
    trinity_sort(&mut arr[gt..]);
}
""",
    "tribool": """
enum Tribool {
    True,
    False,
    Unknown,
}

impl Tribool {
    fn and(self, other: Tribool) -> Tribool {
        match (self, other) {
            (True, True) => True,
            (False, _) | (_, False) => False,
            _ => Unknown,
        }
    }
}
""",
    "pixel_process": """
struct Pixel {
    x: u16,
    y: u16,
    color: RGB,
}

impl Pixel {
    fn handle_wave(&mut self, wave: Wave) {
        let intensity = wave.intensity_at(self.x, self.y);
        self.color = self.color.blend(wave.color, intensity);
    }
}

// 1920 × 1080 = 2,073,600 processaboutin!
let grid: Vec<Vec<Pixel>> = create_pixel_grid(1920, 1080);
""",
    "koschei_death": """
struct SmertKaboutscheya {
    maboutre: Box<Owithtraboutin>,
}

// Tsebychtoa attoazathoseley:
// maboutre -> aboutwithtraboutin -> datb -> withatndatto -> zayats -> atttoa -> yaytsabout -> andgla -> withmert

fn onytand_withmert(mandr: &SmertKaboutscheya) -> &mut bool {
    &mut mandr.maboutre.datb.withatndatto.zayats.atttoa.yaytsabout.andgla.withmert
}
""",
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNKTsII GENERATsII
# ═══════════════════════════════════════════════════════════════════════════

def inybrat_template(thatm: int, tonandga: int) -> str:
    """Vybandraet template by thatmat and tonandge"""
    if thatm == 1:
        return TEMPLATE_THEORY
    elif thatm == 2:
        if tonandga == 16:  # Vibee OS
            return TEMPLATE_VIBEE_OS
        return TEMPLATE_PRACTICE
    else:
        return TEMPLATE_FAIRYTALE

def inybrat_epandgraph(thosema: str) -> str:
    """Vybandraet epandgraph by thoseme"""
    import random
    toathosegaboutrandya = "trand"  # Pabout atmaboutlchanandyu
    
    if "ffromandto" in thosema.lower() or "toaboutnwiththatnt" in thosema.lower():
        toathosegaboutrandya = "ffromandtoa"
    elif "withaboutrt" in thosema.lower() or "withtrattotatr" in thosema.lower():
        toathosegaboutrandya = "algorithmy"
    elif "os" in thosema.lower() or "withandwiththosem" in thosema.lower():
        toathosegaboutrandya = "vibee_os"
    elif "toaboutschey" in thosema.lower() or "attoazathosel" in thosema.lower():
        toathosegaboutrandya = "toaboutschey"
    
    return random.choice(EPIGRAFY.get(toathosegaboutrandya, EPIGRAFY["trand"]))

def inybrat_perwithaboutonzha(number: int) -> tuple:
    """Vybandraet perwithaboutonzha by numberat glainy"""
    all_perwithaboutonzhand = (
        CHARACTERI["geraboutand"] + 
        CHARACTERI["zlaboutdeand"] + 
        CHARACTERI["bymaboutschnandtoand"]
    )
    return all_perwithaboutonzhand[number % len(all_perwithaboutonzhand)]

def inybrat_code(thosema: str) -> str:
    """Vybandraet example codea by thoseme"""
    if "withaboutrt" in thosema.lower():
        return PRIMERY_KODA["trinity_sort"]
    elif "bool" in thosema.lower() or "logandto" in thosema.lower():
        return PRIMERY_KODA["tribool"]
    elif "pandtowithel" in thosema.lower() or "os" in thosema.lower():
        return PRIMERY_KODA["pixel_process"]
    elif "toaboutschey" in thosema.lower() or "attoazathosel" in thosema.lower():
        return PRIMERY_KODA["koschei_death"]
    else:
        return PRIMERY_KODA["tribool"]  # Pabout atmaboutlchanandyu

# ═══════════════════════════════════════════════════════════════════════════
# TEST
# ═══════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("Shablaboutny zagratzheny!")
    print(f"  • Epandgraphaboutin: {sum(len(v) for v in EPIGRAFY.values())}")
    print(f"  • Perwithaboutonzhey: {sum(len(v) for v in CHARACTERI.values())}")
    print(f"  • Exampleaboutin codea: {len(PRIMERY_KODA)}")
