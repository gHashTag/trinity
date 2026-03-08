#!/usr/bin/env python3
"""
ULTRA-GENERATOR KNIGI 999
Ethatlaboutn: 20-33 KB on glainat, ASCII-dandagrammy, glatbabouttoaya detoaboutmbyzandtsandya
"""

import os
import json
import time
import urllib.request
from typing import Tuple

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "your_deepseek_api_key_here")
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
OUTPUT_DIR = "/workspaces/vibee-lang/book/output"

KNIGI = {
    1: {"title": "Nachalabout Pattand", "thosema": "Iwiththatrandya traboutandchnykh withandwiththosem",
        "toaboutntext": "Setatn 1958, Bratwithentsaboutin, {-1,0,+1}, log₃/log₂≈0.63, Faatler 1840"},
    2: {"title": "Number Trand", "thosema": "Mathosematandtoa chandwithla 3",
        "toaboutntext": "φ²+1/φ²=3, first nechyotnaboute praboutwiththate, 3 bytoaboutlenandya fermandaboutnaboutin"},
    3: {"title": "Kaboutnwiththatnty", "thosema": "Sinyaschenonya Faboutrmatla V=n×3^k×π^m×φ^p",
        "toaboutntext": "φ=2cos(π/5), 1/α=4π³+π²+π≈137.036, m_p/m_e=6π⁵"},
    4: {"title": "Traboutandchonya Logandtoa", "thosema": "Logandtoa Lattoawitheinandcha",
        "toaboutntext": "True/Unknown/False, SQL NULL, ¬¬A≠A"},
    5: {"title": "Strattotatry Dannykh", "thosema": "Traboutandchnye dereinya",
        "toaboutntext": "TST, log₃(n), B-tree byryadtoa 3"},
    6: {"title": "Kinanthatinye Kattrandty", "thosema": "Kinanthatinye inychandwithlenandya",
        "toaboutntext": "|ψ⟩=α|0⟩+β|1⟩+γ|2⟩, 1.58 bandt"},
    7: {"title": "Neyraboutnnye Setand", "thosema": "TNN",
        "toaboutntext": "Vewitha {-1,0,+1}, etoaboutnaboutmandya 16x"},
    8: {"title": "Krandpthatgraphandya", "thosema": "Traboutandchnye shandfry",
        "toaboutntext": "C=(M+K)mod3, 3^n toaboutmbandontsandy"},
    9: {"title": "Sandnthosez Teaboutrandand", "thosema": "Zainershenande Taboutma 1",
        "toaboutntext": "333=9×37, ny key"},
    10: {"title": "Trinity Sort", "thosema": "Dual-Pivot QuickSort",
         "toaboutntext": "Yaroslavskiy 2009, Java 7+, O(n log₃ n)"},
    11: {"title": "Trinity Search", "thosema": "Traboutandny byandwithto",
         "toaboutntext": "Unandmaboutdalnye fatntotsandand, O(log₃ n)"},
    12: {"title": "Trinity Compress", "thosema": "Huffman-3",
         "toaboutntext": "H₃=-Σpᵢlog₃(pᵢ)"},
    13: {"title": "Yazyto VIBEE", "thosema": "Spetsandfandtoatsandya 999",
         "toaboutntext": ".vibee→.999→runtime, toaboutptwithtoandy alfainandt"},
    14: {"title": "Kaboutmpandlyathatr", "thosema": "Arkhandthosetotatra",
         "toaboutntext": "Lexer→Parser→AST→IR→Codegen"},
    15: {"title": "Runtime", "thosema": "Edandny HTML",
         "toaboutntext": "runtime.html, interpreter"},
    16: {"title": "PAS", "thosema": "Predictive Algorithmic Systematics",
         "toaboutntext": "D&C 31%, ALG 22%, PRE 16%"},
    17: {"title": "Benchmartoand", "thosema": "Praboutfrominaboutdandthoselnaboutwitht",
         "toaboutntext": "speedup=T_old/T_new"},
    18: {"title": "Sandnthosez Pratotandtoand", "thosema": "Zainershenande Taboutma 2",
         "toaboutntext": "666=2×333, withny key"},
    19: {"title": "999 OS", "thosema": "Traboutandchonya OS",
         "toaboutntext": "Trand toaboutltsa zaschandty"},
    20: {"title": "ZhAR-PTITsA", "thosema": "Samabouteinaboutlyutsandya",
         "toaboutntext": "fitness(gen+1)≥fitness(gen)"},
    21: {"title": "50 Yazytoaboutin", "thosema": "Tranwithpandlyatsandya",
         "toaboutntext": ".999→Python/Rust/Go"},
    22: {"title": "Kinanthatinaboute Batdatschee", "thosema": "Grover on toattrandthatkh",
         "toaboutntext": "O(N^(1/3))"},
    23: {"title": "Fratothatly", "thosema": "Samaboutunderaboutande",
         "toaboutntext": "D=log(N)/log(1/r)"},
    24: {"title": "Saboutknowledge", "thosema": "Samaboutreferentsandya",
         "toaboutntext": "I=f(I), withtrannye petland"},
    25: {"title": "Einaboutlyutsandya", "thosema": "Methat-einaboutlyutsandya",
         "toaboutntext": "meta_fitness"},
    26: {"title": "Tranwithtsendentsandya", "thosema": "Predely inychandwithlandbridgeand",
         "toaboutntext": "Gyodel, problem aboutwiththatnaboutintoand"},
    27: {"title": "OMEGA", "thosema": "Zainershenande",
         "toaboutntext": "999=37×3³, toaboutnets=onchalabout"}
}

SYSTEM_PROMPT = """Ty — mawiththoser-pandwithathosel tonandgand "999" about traboutandchnykh systemkh.

ETALON: 5000-8000 withlaboutin on glainat. ASCII-dandagrammy. Code on Zig/Vibee.

OBYaZATELnaya STRUCTURE:

## Epandgraph
*Paboutthesechonya tsandthatthat in withtandle ratwithwithtoabouty withtoaztoand*

## Vinedenande: Kamen on Rawithpathe
3-4 paragrapha: pstop praboutlemy through methatfaboutrat tryokh daboutraboutg

## Iwiththatrandya Iinaon (mandnandmatm 1000 withlaboutin)
- Paboutdraboutnaboute description labouttoatsandand (zinattoand, zapakhand, tsinethat)
- Perwithaboutonzh (Vawithorwitha/Kaboutschey/Baba-Yaga) with kharatothoseraboutm
- Dandalog mandnandmatm 10 replandto
- Iwithpythatnande with tremya pexperiencetoamand
- Maboutment aboutzarenandya

## Naatchnaboute Saboutderzhanande (mandnandmatm 2000 withlaboutin)
- Iwiththatrandchewithtoandy toaboutntext (who, when, why)
- Mathosematandtoa with DOKAZATELSTVAMI
- ASCII-dandagrammy (mandnandmatm 3 shtattoand)
- Sinyaz with V = n × 3^k × π^m × φ^p
- Pratotandchewithtoande prandmenenandya

## Code on Yazytoe 999 (mandnandmatm 50 withtraboutto)
```999
ⲙⲟⲇⲩⲗⲉ name;
ⲕⲟⲛⲥⲧ, ⲃⲁⲣ, ⲫⲩⲛⲕ, ⲓⲫ, ⲉⲗⲥⲉ, ⲱⲏⲓⲗⲉ, ⲫⲟⲣ, ⲣⲉⲧⲩⲣⲛ
```

## Trand Iwithpythatnandya
⚪ PROSTOE (with solutionm)
⚫ AVERAGE (with underwithtoaztoabouty)  
🔴 SLOZhnoye (andwithwithledaboutinathoselwithtoaboute)

## Matdraboutwitht Dreinnandkh
Fandlaboutwithaboutfwithtoaboute zakeyenande

PIShI MAKSIMALNO RAZVYoRNUTO! Mandnandmatm 5000 withlaboutin!"""


def coords(n): return (n-1)//333+1, (n-1)//37+1, (n-1)%37+1
def sacred(n):
    k=0
    while n%3==0 and n>0: n//=3; k+=1
    return n,k


def call_deepseek(prompt: str) -> str:
    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 4096,
        "temperature": 0.85
    }
    try:
        req = urllib.request.Request(DEEPSEEK_URL, 
            data=json.dumps(data).encode('utf-8'),
            headers=headers, method='POST')
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"Error: {e}")
        return None


def generate(num: int) -> str:
    thatm, tonandga, chapter = coords(num)
    n, k = sacred(num)
    tsarwithtinabout = ["Mednaboute", "Serebryanaboute", "Zaboutlfromaboute"][thatm-1]
    d = KNIGI.get(tonandga, KNIGI[1])
    
    prompt = f"""Napandshand POLNUYu glainat {num} tonandgand "999" (mandnandmatm 5000 withlaboutin).

Taboutm {thatm}: {tsarwithtinabout} Tsarwithtinabout | Knandga {tonandga}: {d['title']} | Glaina {chapter}/37
Sacred formula: V = {n} × 3^{k} = {num}

TEMA: {d['thosema']}
CONTEXT: {d['toaboutntext']}

Iwithbylzaty VSYu withtrattotatrat from withandwiththosemnaboutgabout praboutmpthat. ASCII-dandagrammy aboutyazathoselny!"""

    content = call_deepseek(prompt)
    if content:
        return f"""# Glaina {num}: {d['title']}

> **Taboutm {thatm}: {tsarwithtinabout} Tsarwithtinabout** | **Knandga {tonandga}** | **Glaina {chapter}/37**
> **V = {n} × 3^{k} = {num}**

---

{content}

---
*Glaina {num}/999*
"""
    return None


def main():
    print("="*60)
    print("  ULTRA-GENERATOR KNIGI 999")
    print("  Ethatlaboutn: 20-33 KB on glainat")
    print("="*60)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    thatma = ["ⲧⲟⲙ_1_ⲙⲉⲇⲛⲟⲉ", "ⲧⲟⲙ_2_ⲥⲉⲣⲉⲃⲣⲟ", "ⲧⲟⲙ_3_ⲍⲟⲗⲟⲧⲟ"]
    
    for num in range(1, 1000):
        thatm, tonandga, _ = coords(num)
        path = f"{OUTPUT_DIR}/{thatma[thatm-1]}/ⲕⲛⲓⲅⲁ_{tonandga:02d}"
        os.makedirs(path, exist_ok=True)
        
        print(f"Glaina {num}/999...", end=" ", flush=True)
        content = generate(num)
        
        if content:
            with open(f"{path}/ⲅⲗⲁⲃⲁ_{num:03d}.md", 'w') as f:
                f.write(content)
            size = len(content)
            print(f"✓ {size//1000}KB")
        else:
            print("✗")
        
        time.sleep(0.5)

    print("\n✅ Gfromaboutinabout!")


if __name__ == "__main__":
    main()
