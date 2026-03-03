// ═══════════════════════════════════════════════════════════════════════════════
// PERIODIC TABLE DATA — 118 Elements
// Used by SacredChemistryWidget for element lookup and analysis
// ═══════════════════════════════════════════════════════════════════════════════

export interface Element {
  symbol: string;
  name: string;
  number: number;
  mass: number;
  group: number;
  period: number;
  block: string;
  category: string;
  electronegativity?: number;
  ionization_energy?: number;
}

const ELEMENTS: Element[] = [
  { symbol: 'H',  name: 'Hydrogen',      number: 1,   mass: 1.008,     group: 1,  period: 1, block: 's', category: 'nonmetal', electronegativity: 2.20, ionization_energy: 1312.0 },
  { symbol: 'He', name: 'Helium',        number: 2,   mass: 4.0026,    group: 18, period: 1, block: 's', category: 'noble gas', ionization_energy: 2372.3 },
  { symbol: 'Li', name: 'Lithium',       number: 3,   mass: 6.941,     group: 1,  period: 2, block: 's', category: 'alkali metal', electronegativity: 0.98, ionization_energy: 520.2 },
  { symbol: 'Be', name: 'Beryllium',     number: 4,   mass: 9.0122,    group: 2,  period: 2, block: 's', category: 'alkaline earth metal', electronegativity: 1.57, ionization_energy: 899.5 },
  { symbol: 'B',  name: 'Boron',         number: 5,   mass: 10.81,     group: 13, period: 2, block: 'p', category: 'metalloid', electronegativity: 2.04, ionization_energy: 800.6 },
  { symbol: 'C',  name: 'Carbon',        number: 6,   mass: 12.011,    group: 14, period: 2, block: 'p', category: 'nonmetal', electronegativity: 2.55, ionization_energy: 1086.5 },
  { symbol: 'N',  name: 'Nitrogen',      number: 7,   mass: 14.007,    group: 15, period: 2, block: 'p', category: 'nonmetal', electronegativity: 3.04, ionization_energy: 1402.3 },
  { symbol: 'O',  name: 'Oxygen',        number: 8,   mass: 15.999,    group: 16, period: 2, block: 'p', category: 'nonmetal', electronegativity: 3.44, ionization_energy: 1313.9 },
  { symbol: 'F',  name: 'Fluorine',      number: 9,   mass: 18.998,    group: 17, period: 2, block: 'p', category: 'halogen', electronegativity: 3.98, ionization_energy: 1681.0 },
  { symbol: 'Ne', name: 'Neon',          number: 10,  mass: 20.180,    group: 18, period: 2, block: 'p', category: 'noble gas', ionization_energy: 2080.7 },
  { symbol: 'Na', name: 'Sodium',        number: 11,  mass: 22.990,    group: 1,  period: 3, block: 's', category: 'alkali metal', electronegativity: 0.93, ionization_energy: 495.8 },
  { symbol: 'Mg', name: 'Magnesium',     number: 12,  mass: 24.305,    group: 2,  period: 3, block: 's', category: 'alkaline earth metal', electronegativity: 1.31, ionization_energy: 737.7 },
  { symbol: 'Al', name: 'Aluminium',     number: 13,  mass: 26.982,    group: 13, period: 3, block: 'p', category: 'post-transition metal', electronegativity: 1.61, ionization_energy: 577.5 },
  { symbol: 'Si', name: 'Silicon',       number: 14,  mass: 28.086,    group: 14, period: 3, block: 'p', category: 'metalloid', electronegativity: 1.90, ionization_energy: 786.5 },
  { symbol: 'P',  name: 'Phosphorus',    number: 15,  mass: 30.974,    group: 15, period: 3, block: 'p', category: 'nonmetal', electronegativity: 2.19, ionization_energy: 1011.8 },
  { symbol: 'S',  name: 'Sulfur',        number: 16,  mass: 32.06,     group: 16, period: 3, block: 'p', category: 'nonmetal', electronegativity: 2.58, ionization_energy: 999.6 },
  { symbol: 'Cl', name: 'Chlorine',      number: 17,  mass: 35.45,     group: 17, period: 3, block: 'p', category: 'halogen', electronegativity: 3.16, ionization_energy: 1251.2 },
  { symbol: 'Ar', name: 'Argon',         number: 18,  mass: 39.948,    group: 18, period: 3, block: 'p', category: 'noble gas', ionization_energy: 1520.6 },
  { symbol: 'K',  name: 'Potassium',     number: 19,  mass: 39.098,    group: 1,  period: 4, block: 's', category: 'alkali metal', electronegativity: 0.82, ionization_energy: 418.8 },
  { symbol: 'Ca', name: 'Calcium',       number: 20,  mass: 40.078,    group: 2,  period: 4, block: 's', category: 'alkaline earth metal', electronegativity: 1.00, ionization_energy: 589.8 },
  { symbol: 'Sc', name: 'Scandium',      number: 21,  mass: 44.956,    group: 3,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.36, ionization_energy: 633.1 },
  { symbol: 'Ti', name: 'Titanium',      number: 22,  mass: 47.867,    group: 4,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.54, ionization_energy: 658.8 },
  { symbol: 'V',  name: 'Vanadium',      number: 23,  mass: 50.942,    group: 5,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.63, ionization_energy: 650.9 },
  { symbol: 'Cr', name: 'Chromium',      number: 24,  mass: 51.996,    group: 6,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.66, ionization_energy: 652.9 },
  { symbol: 'Mn', name: 'Manganese',     number: 25,  mass: 54.938,    group: 7,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.55, ionization_energy: 717.3 },
  { symbol: 'Fe', name: 'Iron',          number: 26,  mass: 55.845,    group: 8,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.83, ionization_energy: 762.5 },
  { symbol: 'Co', name: 'Cobalt',        number: 27,  mass: 58.933,    group: 9,  period: 4, block: 'd', category: 'transition metal', electronegativity: 1.88, ionization_energy: 760.4 },
  { symbol: 'Ni', name: 'Nickel',        number: 28,  mass: 58.693,    group: 10, period: 4, block: 'd', category: 'transition metal', electronegativity: 1.91, ionization_energy: 737.1 },
  { symbol: 'Cu', name: 'Copper',        number: 29,  mass: 63.546,    group: 11, period: 4, block: 'd', category: 'transition metal', electronegativity: 1.90, ionization_energy: 745.5 },
  { symbol: 'Zn', name: 'Zinc',          number: 30,  mass: 65.38,     group: 12, period: 4, block: 'd', category: 'transition metal', electronegativity: 1.65, ionization_energy: 906.4 },
  { symbol: 'Ga', name: 'Gallium',       number: 31,  mass: 69.723,    group: 13, period: 4, block: 'p', category: 'post-transition metal', electronegativity: 1.81, ionization_energy: 578.8 },
  { symbol: 'Ge', name: 'Germanium',     number: 32,  mass: 72.630,    group: 14, period: 4, block: 'p', category: 'metalloid', electronegativity: 2.01, ionization_energy: 762.2 },
  { symbol: 'As', name: 'Arsenic',       number: 33,  mass: 74.922,    group: 15, period: 4, block: 'p', category: 'metalloid', electronegativity: 2.18, ionization_energy: 947.0 },
  { symbol: 'Se', name: 'Selenium',      number: 34,  mass: 78.971,    group: 16, period: 4, block: 'p', category: 'nonmetal', electronegativity: 2.55, ionization_energy: 941.0 },
  { symbol: 'Br', name: 'Bromine',       number: 35,  mass: 79.904,    group: 17, period: 4, block: 'p', category: 'halogen', electronegativity: 2.96, ionization_energy: 1139.9 },
  { symbol: 'Kr', name: 'Krypton',       number: 36,  mass: 83.798,    group: 18, period: 4, block: 'p', category: 'noble gas', ionization_energy: 1350.8 },
  { symbol: 'Rb', name: 'Rubidium',      number: 37,  mass: 85.468,    group: 1,  period: 5, block: 's', category: 'alkali metal', electronegativity: 0.82, ionization_energy: 403.0 },
  { symbol: 'Sr', name: 'Strontium',     number: 38,  mass: 87.62,     group: 2,  period: 5, block: 's', category: 'alkaline earth metal', electronegativity: 0.95, ionization_energy: 549.5 },
  { symbol: 'Y',  name: 'Yttrium',       number: 39,  mass: 88.906,    group: 3,  period: 5, block: 'd', category: 'transition metal', electronegativity: 1.22, ionization_energy: 600.0 },
  { symbol: 'Zr', name: 'Zirconium',     number: 40,  mass: 91.224,    group: 4,  period: 5, block: 'd', category: 'transition metal', electronegativity: 1.33, ionization_energy: 640.1 },
  { symbol: 'Nb', name: 'Niobium',       number: 41,  mass: 92.906,    group: 5,  period: 5, block: 'd', category: 'transition metal', electronegativity: 1.60, ionization_energy: 652.1 },
  { symbol: 'Mo', name: 'Molybdenum',    number: 42,  mass: 95.95,     group: 6,  period: 5, block: 'd', category: 'transition metal', electronegativity: 2.16, ionization_energy: 684.3 },
  { symbol: 'Tc', name: 'Technetium',    number: 43,  mass: 98.0,      group: 7,  period: 5, block: 'd', category: 'transition metal', electronegativity: 1.90, ionization_energy: 702.0 },
  { symbol: 'Ru', name: 'Ruthenium',     number: 44,  mass: 101.07,    group: 8,  period: 5, block: 'd', category: 'transition metal', electronegativity: 2.20, ionization_energy: 710.2 },
  { symbol: 'Rh', name: 'Rhodium',       number: 45,  mass: 102.91,    group: 9,  period: 5, block: 'd', category: 'transition metal', electronegativity: 2.28, ionization_energy: 719.7 },
  { symbol: 'Pd', name: 'Palladium',     number: 46,  mass: 106.42,    group: 10, period: 5, block: 'd', category: 'transition metal', electronegativity: 2.20, ionization_energy: 804.4 },
  { symbol: 'Ag', name: 'Silver',        number: 47,  mass: 107.87,    group: 11, period: 5, block: 'd', category: 'transition metal', electronegativity: 1.93, ionization_energy: 731.0 },
  { symbol: 'Cd', name: 'Cadmium',       number: 48,  mass: 112.41,    group: 12, period: 5, block: 'd', category: 'transition metal', electronegativity: 1.69, ionization_energy: 867.8 },
  { symbol: 'In', name: 'Indium',        number: 49,  mass: 114.82,    group: 13, period: 5, block: 'p', category: 'post-transition metal', electronegativity: 1.78, ionization_energy: 558.3 },
  { symbol: 'Sn', name: 'Tin',           number: 50,  mass: 118.71,    group: 14, period: 5, block: 'p', category: 'post-transition metal', electronegativity: 1.96, ionization_energy: 708.6 },
  { symbol: 'Sb', name: 'Antimony',      number: 51,  mass: 121.76,    group: 15, period: 5, block: 'p', category: 'metalloid', electronegativity: 2.05, ionization_energy: 834.0 },
  { symbol: 'Te', name: 'Tellurium',     number: 52,  mass: 127.60,    group: 16, period: 5, block: 'p', category: 'metalloid', electronegativity: 2.10, ionization_energy: 869.3 },
  { symbol: 'I',  name: 'Iodine',        number: 53,  mass: 126.90,    group: 17, period: 5, block: 'p', category: 'halogen', electronegativity: 2.66, ionization_energy: 1008.4 },
  { symbol: 'Xe', name: 'Xenon',         number: 54,  mass: 131.29,    group: 18, period: 5, block: 'p', category: 'noble gas', ionization_energy: 1170.4 },
  { symbol: 'Cs', name: 'Caesium',       number: 55,  mass: 132.91,    group: 1,  period: 6, block: 's', category: 'alkali metal', electronegativity: 0.79, ionization_energy: 375.7 },
  { symbol: 'Ba', name: 'Barium',        number: 56,  mass: 137.33,    group: 2,  period: 6, block: 's', category: 'alkaline earth metal', electronegativity: 0.89, ionization_energy: 502.9 },
  { symbol: 'La', name: 'Lanthanum',     number: 57,  mass: 138.91,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.10, ionization_energy: 538.1 },
  { symbol: 'Ce', name: 'Cerium',        number: 58,  mass: 140.12,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.12, ionization_energy: 534.4 },
  { symbol: 'Pr', name: 'Praseodymium',  number: 59,  mass: 140.91,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.13, ionization_energy: 527.0 },
  { symbol: 'Nd', name: 'Neodymium',     number: 60,  mass: 144.24,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.14, ionization_energy: 533.1 },
  { symbol: 'Pm', name: 'Promethium',    number: 61,  mass: 145.0,     group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.13, ionization_energy: 540.0 },
  { symbol: 'Sm', name: 'Samarium',      number: 62,  mass: 150.36,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.17, ionization_energy: 544.5 },
  { symbol: 'Eu', name: 'Europium',      number: 63,  mass: 151.96,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.20, ionization_energy: 547.1 },
  { symbol: 'Gd', name: 'Gadolinium',    number: 64,  mass: 157.25,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.20, ionization_energy: 593.4 },
  { symbol: 'Tb', name: 'Terbium',       number: 65,  mass: 158.93,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.20, ionization_energy: 565.8 },
  { symbol: 'Dy', name: 'Dysprosium',    number: 66,  mass: 162.50,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.22, ionization_energy: 573.0 },
  { symbol: 'Ho', name: 'Holmium',       number: 67,  mass: 164.93,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.23, ionization_energy: 581.0 },
  { symbol: 'Er', name: 'Erbium',        number: 68,  mass: 167.26,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.24, ionization_energy: 589.3 },
  { symbol: 'Tm', name: 'Thulium',       number: 69,  mass: 168.93,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.25, ionization_energy: 596.7 },
  { symbol: 'Yb', name: 'Ytterbium',     number: 70,  mass: 173.05,    group: 3,  period: 6, block: 'f', category: 'lanthanide', electronegativity: 1.10, ionization_energy: 603.4 },
  { symbol: 'Lu', name: 'Lutetium',      number: 71,  mass: 174.97,    group: 3,  period: 6, block: 'd', category: 'lanthanide', electronegativity: 1.27, ionization_energy: 523.5 },
  { symbol: 'Hf', name: 'Hafnium',       number: 72,  mass: 178.49,    group: 4,  period: 6, block: 'd', category: 'transition metal', electronegativity: 1.30, ionization_energy: 658.5 },
  { symbol: 'Ta', name: 'Tantalum',      number: 73,  mass: 180.95,    group: 5,  period: 6, block: 'd', category: 'transition metal', electronegativity: 1.50, ionization_energy: 761.0 },
  { symbol: 'W',  name: 'Tungsten',      number: 74,  mass: 183.84,    group: 6,  period: 6, block: 'd', category: 'transition metal', electronegativity: 2.36, ionization_energy: 770.0 },
  { symbol: 'Re', name: 'Rhenium',       number: 75,  mass: 186.21,    group: 7,  period: 6, block: 'd', category: 'transition metal', electronegativity: 1.90, ionization_energy: 760.0 },
  { symbol: 'Os', name: 'Osmium',        number: 76,  mass: 190.23,    group: 8,  period: 6, block: 'd', category: 'transition metal', electronegativity: 2.20, ionization_energy: 840.0 },
  { symbol: 'Ir', name: 'Iridium',       number: 77,  mass: 192.22,    group: 9,  period: 6, block: 'd', category: 'transition metal', electronegativity: 2.20, ionization_energy: 880.0 },
  { symbol: 'Pt', name: 'Platinum',      number: 78,  mass: 195.08,    group: 10, period: 6, block: 'd', category: 'transition metal', electronegativity: 2.28, ionization_energy: 870.0 },
  { symbol: 'Au', name: 'Gold',          number: 79,  mass: 196.97,    group: 11, period: 6, block: 'd', category: 'transition metal', electronegativity: 2.54, ionization_energy: 890.1 },
  { symbol: 'Hg', name: 'Mercury',       number: 80,  mass: 200.59,    group: 12, period: 6, block: 'd', category: 'transition metal', electronegativity: 2.00, ionization_energy: 1007.1 },
  { symbol: 'Tl', name: 'Thallium',      number: 81,  mass: 204.38,    group: 13, period: 6, block: 'p', category: 'post-transition metal', electronegativity: 1.62, ionization_energy: 589.4 },
  { symbol: 'Pb', name: 'Lead',          number: 82,  mass: 207.2,     group: 14, period: 6, block: 'p', category: 'post-transition metal', electronegativity: 1.87, ionization_energy: 715.6 },
  { symbol: 'Bi', name: 'Bismuth',       number: 83,  mass: 208.98,    group: 15, period: 6, block: 'p', category: 'post-transition metal', electronegativity: 2.02, ionization_energy: 703.0 },
  { symbol: 'Po', name: 'Polonium',      number: 84,  mass: 209.0,     group: 16, period: 6, block: 'p', category: 'post-transition metal', electronegativity: 2.00, ionization_energy: 812.1 },
  { symbol: 'At', name: 'Astatine',      number: 85,  mass: 210.0,     group: 17, period: 6, block: 'p', category: 'halogen', electronegativity: 2.20, ionization_energy: 920.0 },
  { symbol: 'Rn', name: 'Radon',         number: 86,  mass: 222.0,     group: 18, period: 6, block: 'p', category: 'noble gas', ionization_energy: 1037.0 },
  { symbol: 'Fr', name: 'Francium',      number: 87,  mass: 223.0,     group: 1,  period: 7, block: 's', category: 'alkali metal', electronegativity: 0.70, ionization_energy: 380.0 },
  { symbol: 'Ra', name: 'Radium',        number: 88,  mass: 226.0,     group: 2,  period: 7, block: 's', category: 'alkaline earth metal', electronegativity: 0.90, ionization_energy: 509.3 },
  { symbol: 'Ac', name: 'Actinium',      number: 89,  mass: 227.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.10, ionization_energy: 499.0 },
  { symbol: 'Th', name: 'Thorium',       number: 90,  mass: 232.04,    group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 587.0 },
  { symbol: 'Pa', name: 'Protactinium',  number: 91,  mass: 231.04,    group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.50, ionization_energy: 568.0 },
  { symbol: 'U',  name: 'Uranium',       number: 92,  mass: 238.03,    group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.38, ionization_energy: 597.6 },
  { symbol: 'Np', name: 'Neptunium',     number: 93,  mass: 237.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.36, ionization_energy: 604.5 },
  { symbol: 'Pu', name: 'Plutonium',     number: 94,  mass: 244.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.28, ionization_energy: 584.7 },
  { symbol: 'Am', name: 'Americium',     number: 95,  mass: 243.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 578.0 },
  { symbol: 'Cm', name: 'Curium',        number: 96,  mass: 247.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 581.0 },
  { symbol: 'Bk', name: 'Berkelium',     number: 97,  mass: 247.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 601.0 },
  { symbol: 'Cf', name: 'Californium',   number: 98,  mass: 251.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 608.0 },
  { symbol: 'Es', name: 'Einsteinium',   number: 99,  mass: 252.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 619.0 },
  { symbol: 'Fm', name: 'Fermium',       number: 100, mass: 257.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 627.0 },
  { symbol: 'Md', name: 'Mendelevium',   number: 101, mass: 258.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 635.0 },
  { symbol: 'No', name: 'Nobelium',      number: 102, mass: 259.0,     group: 3,  period: 7, block: 'f', category: 'actinide', electronegativity: 1.30, ionization_energy: 642.0 },
  { symbol: 'Lr', name: 'Lawrencium',    number: 103, mass: 266.0,     group: 3,  period: 7, block: 'd', category: 'actinide', electronegativity: 1.30, ionization_energy: 470.0 },
  { symbol: 'Rf', name: 'Rutherfordium', number: 104, mass: 267.0,     group: 4,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Db', name: 'Dubnium',       number: 105, mass: 268.0,     group: 5,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Sg', name: 'Seaborgium',    number: 106, mass: 269.0,     group: 6,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Bh', name: 'Bohrium',       number: 107, mass: 270.0,     group: 7,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Hs', name: 'Hassium',       number: 108, mass: 277.0,     group: 8,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Mt', name: 'Meitnerium',    number: 109, mass: 278.0,     group: 9,  period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Ds', name: 'Darmstadtium',  number: 110, mass: 281.0,     group: 10, period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Rg', name: 'Roentgenium',   number: 111, mass: 282.0,     group: 11, period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Cn', name: 'Copernicium',   number: 112, mass: 285.0,     group: 12, period: 7, block: 'd', category: 'transition metal' },
  { symbol: 'Nh', name: 'Nihonium',      number: 113, mass: 286.0,     group: 13, period: 7, block: 'p', category: 'post-transition metal' },
  { symbol: 'Fl', name: 'Flerovium',     number: 114, mass: 289.0,     group: 14, period: 7, block: 'p', category: 'post-transition metal' },
  { symbol: 'Mc', name: 'Moscovium',     number: 115, mass: 290.0,     group: 15, period: 7, block: 'p', category: 'post-transition metal' },
  { symbol: 'Lv', name: 'Livermorium',   number: 116, mass: 293.0,     group: 16, period: 7, block: 'p', category: 'post-transition metal' },
  { symbol: 'Ts', name: 'Tennessine',    number: 117, mass: 294.0,     group: 17, period: 7, block: 'p', category: 'halogen' },
  { symbol: 'Og', name: 'Oganesson',     number: 118, mass: 294.0,     group: 18, period: 7, block: 'p', category: 'noble gas' },
];

// Index maps for fast lookup
const bySymbol = new Map<string, Element>();
const byNumber = new Map<number, Element>();
for (const el of ELEMENTS) {
  bySymbol.set(el.symbol, el);
  byNumber.set(el.number, el);
}

/** Look up element by symbol (case-sensitive) or atomic number */
export function getElement(query: string): Element | undefined {
  // Try as number
  const num = parseInt(query, 10);
  if (!isNaN(num)) return byNumber.get(num);
  // Try exact symbol match
  const exact = bySymbol.get(query);
  if (exact) return exact;
  // Try case-insensitive name match
  const lower = query.toLowerCase();
  return ELEMENTS.find(e => e.name.toLowerCase() === lower || e.symbol.toLowerCase() === lower);
}

export { ELEMENTS };
