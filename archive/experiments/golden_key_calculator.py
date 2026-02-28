#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    ZOLOTOY KLYuCh: INTERAKTIVNYY KALKULYaTOR                   ║
║                           φ² + 1/φ² = 3                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Avtor: Dmitrii Vasilev
Proekt: VIBEE / 999 OS
Versiya: 2.0

Etot kalkulyator pozvolyaet:
1. Proverit Zolotoy Klyuch (φ² + 1/φ² = 3)
2. Vychislit lyubuyu fizicheskuyu konstantu cherez formulu V = n × 3^k × π^m × φ^p × e^q
3. Nayti formulu dlya proizvolnogo chisla
4. Proverit vse izvestnye formuly
5. Statisticheskiy analiz

Zapusk:
    python3 golden_key_calculator.py

Ili import kak modul:
    from golden_key_calculator import GoldenKeyCalculator
    calc = GoldenKeyCalculator()
    calc.verify_golden_key()
"""

import math
import itertools
from typing import Tuple, List, Dict, Optional
from dataclasses import dataclass
import json

# ============================================
# FUNDAMENTALNYE KONSTANTY
# ============================================

PHI = (1 + math.sqrt(5)) / 2  # Zolotoe sechenie φ = 1.6180339887...
PI = math.pi                   # π = 3.1415926535...
E = math.e                     # e = 2.7182818284...
GOLDEN_KEY = 3                 # φ² + 1/φ² = 3

# ============================================
# BAZA FIZIChESKIKh KONSTANT
# ============================================

PHYSICAL_CONSTANTS = {
    # Matematicheskie konstanty
    "delta_feigenbaum": {
        "name": "Postoyannaya Feygenbauma δ",
        "value": 4.669201609102990,
        "uncertainty": 0.000000000000001,
        "source": "Matematicheskaya konstanta",
        "category": "math"
    },
    "alpha_feigenbaum": {
        "name": "Postoyannaya Feygenbauma α",
        "value": 2.502907875095892,
        "uncertainty": 0.000000000000001,
        "source": "Matematicheskaya konstanta",
        "category": "math"
    },
    
    # Elektroslabye konstanty
    "sin2_theta_W": {
        "name": "sin²θ_W (ugol Vaynberga)",
        "value": 0.23121,
        "uncertainty": 0.00004,
        "source": "PDG 2024",
        "category": "electroweak"
    },
    "fine_structure_inverse": {
        "name": "1/α (postoyannaya tonkoy struktury)",
        "value": 137.035999177,
        "uncertainty": 0.000000021,
        "source": "CODATA 2018",
        "category": "electroweak"
    },
    
    # Massy chastits
    "proton_electron_ratio": {
        "name": "m_p/m_e (otnoshenie mass)",
        "value": 1836.15267343,
        "uncertainty": 0.00000011,
        "source": "CODATA 2018",
        "category": "masses"
    },
    "neutron_electron_ratio": {
        "name": "m_n/m_e",
        "value": 1838.68366173,
        "uncertainty": 0.00000089,
        "source": "CODATA 2018",
        "category": "masses"
    },
    
    # Neytrinnoe smeshivanie
    "sin2_theta_12": {
        "name": "sin²θ₁₂ (solnechnoe smeshivanie)",
        "value": 0.307,
        "uncertainty": 0.013,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    "sin2_theta_23": {
        "name": "sin²θ₂₃ (atmosfernoe smeshivanie)",
        "value": 0.546,
        "uncertainty": 0.021,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    "sin2_theta_13": {
        "name": "sin²θ₁₃ (reaktornoe smeshivanie)",
        "value": 0.0220,
        "uncertainty": 0.0007,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    
    # Formula Koide
    "koide_K": {
        "name": "Parametr Koide K",
        "value": 0.666661,
        "uncertainty": 0.000001,
        "source": "PDG 2024 (vychisleno iz mass leptonov)",
        "category": "koide"
    },
    
    # Kosmologiya
    "dark_energy_ratio": {
        "name": "Ω_Λ/Ω_m (tyomnaya energiya/materiya)",
        "value": 2.1746,
        "uncertainty": 0.05,
        "source": "Planck 2020",
        "category": "cosmology"
    },
    
    # Petlevaya kvantovaya gravitatsiya
    "barbero_immirzi": {
        "name": "γ (parametr Barbero-Immirtsi)",
        "value": 0.2375,
        "uncertainty": 0.0001,
        "source": "LQG teoriya",
        "category": "lqg"
    },
    
    # Fraktalnye razmernosti
    "sierpinski_dimension": {
        "name": "D (treugolnik Serpinskogo)",
        "value": 1.5849625007211563,
        "uncertainty": 0.0000000000000001,
        "source": "Matematicheskaya konstanta",
        "category": "fractal"
    },
    "menger_dimension": {
        "name": "D (gubka Mengera)",
        "value": 2.7268330278608417,
        "uncertainty": 0.0000000000000001,
        "source": "Matematicheskaya konstanta",
        "category": "fractal"
    },
}

# ============================================
# IZVESTNYE FORMULY
# ============================================

KNOWN_FORMULAS = {
    "delta_feigenbaum": {"n": 1, "k": 6, "m": -7, "p": 2, "q": 2},
    "alpha_feigenbaum": {"n": 46, "k": 7, "m": -8, "p": -3, "q": 0},
    "sin2_theta_W": {"n": 274, "k": -5, "m": -3, "p": 8, "q": -2},
    "proton_electron_ratio": {"n": 6, "k": 0, "m": 5, "p": 0, "q": 0},
    "fine_structure_inverse": {"n": 4, "k": 0, "m": 3, "p": 0, "q": 0},  # 4π³ + π² + π (priblizhenie)
    "sin2_theta_12": {"n": 97, "k": -7, "m": 0, "p": 4, "q": 0},
    "barbero_immirzi": {"n": 98, "k": 0, "m": -4, "p": -3, "q": 0},
}


@dataclass
class FormulaResult:
    """Rezultat vychisleniya formuly."""
    n: int
    k: int
    m: int
    p: int
    q: int
    calculated: float
    target: float
    error_percent: float
    formula_str: str


class GoldenKeyCalculator:
    """Kalkulyator Zolotogo Klyucha."""
    
    def __init__(self):
        self.phi = PHI
        self.pi = PI
        self.e = E
        self.golden_key = GOLDEN_KEY
        self.constants = PHYSICAL_CONSTANTS
        self.known_formulas = KNOWN_FORMULAS
    
    # ============================================
    # OSNOVNYE FUNKTsII
    # ============================================
    
    def verify_golden_key(self) -> Tuple[float, bool]:
        """
        Proveryaet tsentralnoe tozhdestvo: φ² + 1/φ² = 3
        
        Returns:
            Tuple[float, bool]: (vychislennoe znachenie, tochno li ravno 3)
        """
        phi_squared = self.phi ** 2
        inv_phi_squared = 1 / (self.phi ** 2)
        result = phi_squared + inv_phi_squared
        
        is_exact = abs(result - 3.0) < 1e-14
        
        print("=" * 60)
        print("ZOLOTOY KLYuCh: φ² + 1/φ² = 3")
        print("=" * 60)
        print(f"φ = {self.phi:.15f}")
        print(f"φ² = {phi_squared:.15f}")
        print(f"1/φ² = {inv_phi_squared:.15f}")
        print(f"φ² + 1/φ² = {result:.15f}")
        print(f"Otklonenie ot 3: {abs(result - 3.0):.2e}")
        print(f"Rezultat: {'✅ TOChNO RAVNO 3!' if is_exact else '❌ Oshibka!'}")
        print()
        
        return result, is_exact
    
    def calculate_formula(self, n: int, k: int, m: int, p: int, q: int) -> float:
        """
        Vychislyaet V = n × 3^k × π^m × φ^p × e^q
        
        Args:
            n: tseloe chislo (1-300)
            k: stepen 3 (-10 to +10)
            m: stepen π (-10 to +10)
            p: stepen φ (-10 to +10)
            q: stepen e (-3 to +3)
        
        Returns:
            float: vychislennoe znachenie
        """
        return n * (3 ** k) * (self.pi ** m) * (self.phi ** p) * (self.e ** q)
    
    def formula_to_string(self, n: int, k: int, m: int, p: int, q: int) -> str:
        """Preobrazuet parametry formuly v stroku."""
        parts = []
        if n != 1:
            parts.append(str(n))
        if k != 0:
            parts.append(f"3^{k}" if k != 1 else "3")
        if m != 0:
            parts.append(f"π^{m}" if m != 1 else "π")
        if p != 0:
            parts.append(f"φ^{p}" if p != 1 else "φ")
        if q != 0:
            parts.append(f"e^{q}" if q != 1 else "e")
        
        return " × ".join(parts) if parts else "1"
    
    def find_formula(self, target: float, 
                     n_range: Tuple[int, int] = (1, 300),
                     k_range: Tuple[int, int] = (-10, 10),
                     m_range: Tuple[int, int] = (-10, 10),
                     p_range: Tuple[int, int] = (-10, 10),
                     q_range: Tuple[int, int] = (-3, 3),
                     max_error: float = 0.01,
                     max_results: int = 10) -> List[FormulaResult]:
        """
        Ischet formulu dlya zadannogo chisla.
        
        Args:
            target: tselevoe znachenie
            n_range: diapazon n
            k_range: diapazon k
            m_range: diapazon m
            p_range: diapazon p
            q_range: diapazon q
            max_error: maksimalnaya oshibka v protsentakh
            max_results: maksimalnoe kolichestvo rezultatov
        
        Returns:
            List[FormulaResult]: spisok naydennykh formul
        """
        results = []
        
        for n in range(n_range[0], n_range[1] + 1):
            for k in range(k_range[0], k_range[1] + 1):
                for m in range(m_range[0], m_range[1] + 1):
                    for p in range(p_range[0], p_range[1] + 1):
                        for q in range(q_range[0], q_range[1] + 1):
                            calculated = self.calculate_formula(n, k, m, p, q)
                            
                            if calculated <= 0:
                                continue
                            
                            error = abs(calculated - target) / target * 100
                            
                            if error <= max_error:
                                results.append(FormulaResult(
                                    n=n, k=k, m=m, p=p, q=q,
                                    calculated=calculated,
                                    target=target,
                                    error_percent=error,
                                    formula_str=self.formula_to_string(n, k, m, p, q)
                                ))
        
        # Sortiruem po oshibke
        results.sort(key=lambda x: x.error_percent)
        
        return results[:max_results]
    
    def verify_all_constants(self) -> Dict[str, Dict]:
        """
        Proveryaet vse izvestnye formuly.
        
        Returns:
            Dict: rezultaty proverki
        """
        print("=" * 60)
        print("PROVERKA VSEKh IZVESTNYKh FORMUL")
        print("=" * 60)
        
        results = {}
        
        for key, formula in self.known_formulas.items():
            if key not in self.constants:
                continue
            
            const = self.constants[key]
            calculated = self.calculate_formula(**formula)
            error = abs(calculated - const["value"]) / const["value"] * 100
            
            status = "✅" if error < 0.01 else "⚠️" if error < 1 else "❌"
            
            results[key] = {
                "name": const["name"],
                "real": const["value"],
                "calculated": calculated,
                "error_percent": error,
                "formula": self.formula_to_string(**formula),
                "status": status
            }
            
            print(f"\n{const['name']}")
            print(f"  Realnoe: {const['value']}")
            print(f"  Formula: {self.formula_to_string(**formula)}")
            print(f"  Vychisleno: {calculated:.10f}")
            print(f"  Oshibka: {error:.7f}% {status}")
        
        print()
        return results
    
    def verify_koide_formula(self) -> Tuple[float, float]:
        """
        Detalnaya proverka formuly Koide.
        
        Returns:
            Tuple[float, float]: (K, oshibka v protsentakh)
        """
        # Massy leptonov (MeV, PDG 2024)
        m_e = 0.51099895000
        m_mu = 105.6583755
        m_tau = 1776.86
        
        numerator = m_e + m_mu + m_tau
        denominator = (math.sqrt(m_e) + math.sqrt(m_mu) + math.sqrt(m_tau)) ** 2
        K = numerator / denominator
        
        K_theory = 2/3
        error = abs(K - K_theory) / K_theory * 100
        
        print("=" * 60)
        print("FORMULA KOIDE")
        print("=" * 60)
        print(f"Massy leptonov (MeV):")
        print(f"  m_e = {m_e}")
        print(f"  m_μ = {m_mu}")
        print(f"  m_τ = {m_tau}")
        print()
        print(f"K = (m_e + m_μ + m_τ) / (√m_e + √m_μ + √m_τ)²")
        print(f"K = {K:.10f}")
        print(f"2/3 = {K_theory:.10f}")
        print(f"Oshibka: {error:.5f}%")
        print()
        
        return K, error
    
    def statistical_analysis(self) -> Dict:
        """
        Statisticheskiy analiz veroyatnosti sluchaynogo sovpadeniya.
        
        Returns:
            Dict: rezultaty analiza
        """
        print("=" * 60)
        print("STATISTIChESKIY ANALIZ")
        print("=" * 60)
        
        # Parametry poiska
        n_range = 300
        k_range = 21
        m_range = 21
        p_range = 21
        q_range = 7
        
        total_combinations = n_range * k_range * m_range * p_range * q_range
        
        print(f"Prostranstvo poiska: {total_combinations:,} kombinatsiy")
        
        # Veroyatnost sluchaynogo sovpadeniya
        precision = 0.0001  # 0.01%
        p_single = precision * 2
        
        n_constants = len(self.known_formulas)
        p_all = p_single ** n_constants
        
        p_corrected = p_all * total_combinations
        
        print(f"Veroyatnost sluchaynogo sovpadeniya:")
        print(f"  Dlya odnoy konstanty (0.01%): {p_single:.2e}")
        print(f"  Dlya {n_constants} konstant: {p_all:.2e}")
        print(f"  S uchyotom mnozhestvennogo testirovaniya: {p_corrected:.2e}")
        print()
        
        return {
            "total_combinations": total_combinations,
            "n_constants": n_constants,
            "p_single": p_single,
            "p_all": p_all,
            "p_corrected": p_corrected
        }
    
    # ============================================
    # INTERAKTIVNYY REZhIM
    # ============================================
    
    def interactive_mode(self):
        """Zapuskaet interaktivnyy rezhim."""
        print()
        print("╔" + "═" * 58 + "╗")
        print("║" + " ZOLOTOY KLYuCh: INTERAKTIVNYY KALKULYaTOR ".center(58) + "║")
        print("║" + " φ² + 1/φ² = 3 ".center(58) + "║")
        print("╚" + "═" * 58 + "╝")
        print()
        
        while True:
            print("Vyberite deystvie:")
            print("  1. Proverit Zolotoy Klyuch (φ² + 1/φ² = 3)")
            print("  2. Vychislit formulu V = n × 3^k × π^m × φ^p × e^q")
            print("  3. Nayti formulu dlya chisla")
            print("  4. Proverit vse izvestnye formuly")
            print("  5. Proverit formulu Koide")
            print("  6. Statisticheskiy analiz")
            print("  7. Pokazat vse konstanty")
            print("  0. Vykhod")
            print()
            
            try:
                choice = input("Vash vybor: ").strip()
            except EOFError:
                break
            
            if choice == "0":
                print("Do svidaniya!")
                break
            elif choice == "1":
                self.verify_golden_key()
            elif choice == "2":
                self._interactive_calculate()
            elif choice == "3":
                self._interactive_find()
            elif choice == "4":
                self.verify_all_constants()
            elif choice == "5":
                self.verify_koide_formula()
            elif choice == "6":
                self.statistical_analysis()
            elif choice == "7":
                self._show_all_constants()
            else:
                print("Nevernyy vybor. Poprobuyte snova.")
            
            print()
    
    def _interactive_calculate(self):
        """Interaktivnoe vychislenie formuly."""
        print("\nVvedite parametry formuly V = n × 3^k × π^m × φ^p × e^q:")
        try:
            n = int(input("  n (1-300): "))
            k = int(input("  k (-10 to +10): "))
            m = int(input("  m (-10 to +10): "))
            p = int(input("  p (-10 to +10): "))
            q = int(input("  q (-3 to +3): "))
            
            result = self.calculate_formula(n, k, m, p, q)
            formula_str = self.formula_to_string(n, k, m, p, q)
            
            print(f"\nFormula: {formula_str}")
            print(f"Rezultat: {result}")
        except ValueError:
            print("Oshibka: vvedite tselye chisla.")
    
    def _interactive_find(self):
        """Interaktivnyy poisk formuly."""
        print("\nVvedite chislo dlya poiska formuly:")
        try:
            target = float(input("  Chislo: "))
            max_error = float(input("  Maksimalnaya oshibka (%, po umolchaniyu 0.01): ") or "0.01")
            
            print(f"\nIschu formuly dlya {target} s oshibkoy < {max_error}%...")
            results = self.find_formula(target, max_error=max_error)
            
            if results:
                print(f"\nNaydeno {len(results)} formul:")
                for i, r in enumerate(results, 1):
                    print(f"  {i}. {r.formula_str} = {r.calculated:.10f} (oshibka: {r.error_percent:.7f}%)")
            else:
                print("Formuly ne naydeny. Poprobuyte uvelichit maksimalnuyu oshibku.")
        except ValueError:
            print("Oshibka: vvedite chislo.")
    
    def _show_all_constants(self):
        """Pokazyvaet vse konstanty."""
        print("\n" + "=" * 60)
        print("VSE FIZIChESKIE KONSTANTY")
        print("=" * 60)
        
        categories = {}
        for key, const in self.constants.items():
            cat = const.get("category", "other")
            if cat not in categories:
                categories[cat] = []
            categories[cat].append((key, const))
        
        for cat, items in categories.items():
            print(f"\n{cat.upper()}:")
            for key, const in items:
                print(f"  {const['name']}: {const['value']} ± {const['uncertainty']}")
                print(f"    Istochnik: {const['source']}")


def main():
    """Glavnaya funktsiya."""
    calc = GoldenKeyCalculator()
    
    # Proveryaem, zapuschen li skript interaktivno
    import sys
    if sys.stdin.isatty():
        calc.interactive_mode()
    else:
        # Neinteraktivnyy rezhim — zapuskaem vse proverki
        calc.verify_golden_key()
        calc.verify_all_constants()
        calc.verify_koide_formula()
        calc.statistical_analysis()


if __name__ == "__main__":
    main()
