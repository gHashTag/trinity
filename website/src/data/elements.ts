// ============================================================================
// PERIODIC TABLE DATA — 118 Elements
// Source: src/sacred/chemistry.zig PERIODIC_TABLE
// ============================================================================

export interface Element {
  symbol: string;
  name: string;
  number: number;
  mass: number;
  electronegativity: number | null;
  ionization_energy: number | null;
  group: number;
  period: number;
}

export const ELEMENTS: Element[] = [
  { symbol: 'H',  name: 'Hydrogen',      number: 1,   mass: 1.008,    electronegativity: 2.20, ionization_energy: 13.598,  group: 1,  period: 1 },
  { symbol: 'He', name: 'Helium',        number: 2,   mass: 4.003,    electronegativity: null, ionization_energy: 24.587,  group: 18, period: 1 },
  { symbol: 'Li', name: 'Lithium',       number: 3,   mass: 6.941,    electronegativity: 0.98, ionization_energy: 5.392,   group: 1,  period: 2 },
  { symbol: 'Be', name: 'Beryllium',     number: 4,   mass: 9.012,    electronegativity: 1.57, ionization_energy: 9.323,   group: 2,  period: 2 },
  { symbol: 'B',  name: 'Boron',         number: 5,   mass: 10.81,    electronegativity: 2.04, ionization_energy: 8.298,   group: 13, period: 2 },
  { symbol: 'C',  name: 'Carbon',        number: 6,   mass: 12.011,   electronegativity: 2.55, ionization_energy: 11.260,  group: 14, period: 2 },
  { symbol: 'N',  name: 'Nitrogen',      number: 7,   mass: 14.007,   electronegativity: 3.04, ionization_energy: 14.534,  group: 15, period: 2 },
  { symbol: 'O',  name: 'Oxygen',        number: 8,   mass: 15.999,   electronegativity: 3.44, ionization_energy: 13.618,  group: 16, period: 2 },
  { symbol: 'F',  name: 'Fluorine',      number: 9,   mass: 18.998,   electronegativity: 3.98, ionization_energy: 17.423,  group: 17, period: 2 },
  { symbol: 'Ne', name: 'Neon',          number: 10,  mass: 20.180,   electronegativity: null, ionization_energy: 21.565,  group: 18, period: 2 },
  { symbol: 'Na', name: 'Sodium',        number: 11,  mass: 22.990,   electronegativity: 0.93, ionization_energy: 5.139,   group: 1,  period: 3 },
  { symbol: 'Mg', name: 'Magnesium',     number: 12,  mass: 24.305,   electronegativity: 1.31, ionization_energy: 7.646,   group: 2,  period: 3 },
  { symbol: 'Al', name: 'Aluminium',     number: 13,  mass: 26.982,   electronegativity: 1.61, ionization_energy: 5.986,   group: 13, period: 3 },
  { symbol: 'Si', name: 'Silicon',       number: 14,  mass: 28.086,   electronegativity: 1.90, ionization_energy: 8.152,   group: 14, period: 3 },
  { symbol: 'P',  name: 'Phosphorus',    number: 15,  mass: 30.974,   electronegativity: 2.19, ionization_energy: 10.487,  group: 15, period: 3 },
  { symbol: 'S',  name: 'Sulfur',        number: 16,  mass: 32.06,    electronegativity: 2.58, ionization_energy: 10.360,  group: 16, period: 3 },
  { symbol: 'Cl', name: 'Chlorine',      number: 17,  mass: 35.45,    electronegativity: 3.16, ionization_energy: 12.968,  group: 17, period: 3 },
  { symbol: 'Ar', name: 'Argon',         number: 18,  mass: 39.948,   electronegativity: null, ionization_energy: 15.760,  group: 18, period: 3 },
  { symbol: 'K',  name: 'Potassium',     number: 19,  mass: 39.098,   electronegativity: 0.82, ionization_energy: 4.3407,  group: 1,  period: 4 },
  { symbol: 'Ca', name: 'Calcium',       number: 20,  mass: 40.078,   electronegativity: 1.00, ionization_energy: 6.1132,  group: 2,  period: 4 },
  { symbol: 'Sc', name: 'Scandium',      number: 21,  mass: 44.956,   electronegativity: 1.36, ionization_energy: 6.5615,  group: 3,  period: 4 },
  { symbol: 'Ti', name: 'Titanium',      number: 22,  mass: 47.867,   electronegativity: 1.54, ionization_energy: 6.8281,  group: 4,  period: 4 },
  { symbol: 'V',  name: 'Vanadium',      number: 23,  mass: 50.942,   electronegativity: 1.63, ionization_energy: 6.7463,  group: 5,  period: 4 },
  { symbol: 'Cr', name: 'Chromium',      number: 24,  mass: 51.996,   electronegativity: 1.66, ionization_energy: 6.7665,  group: 6,  period: 4 },
  { symbol: 'Mn', name: 'Manganese',     number: 25,  mass: 54.938,   electronegativity: 1.55, ionization_energy: 7.4340,  group: 7,  period: 4 },
  { symbol: 'Fe', name: 'Iron',          number: 26,  mass: 55.845,   electronegativity: 1.83, ionization_energy: 7.9024,  group: 8,  period: 4 },
  { symbol: 'Co', name: 'Cobalt',        number: 27,  mass: 58.933,   electronegativity: 1.88, ionization_energy: 7.8810,  group: 9,  period: 4 },
  { symbol: 'Ni', name: 'Nickel',        number: 28,  mass: 58.693,   electronegativity: 1.91, ionization_energy: 7.6398,  group: 10, period: 4 },
  { symbol: 'Cu', name: 'Copper',        number: 29,  mass: 63.546,   electronegativity: 1.90, ionization_energy: 7.7264,  group: 11, period: 4 },
  { symbol: 'Zn', name: 'Zinc',          number: 30,  mass: 65.38,    electronegativity: 1.65, ionization_energy: 9.3942,  group: 12, period: 4 },
  { symbol: 'Ga', name: 'Gallium',       number: 31,  mass: 69.723,   electronegativity: 1.81, ionization_energy: 5.9993,  group: 13, period: 4 },
  { symbol: 'Ge', name: 'Germanium',     number: 32,  mass: 72.630,   electronegativity: 2.01, ionization_energy: 7.8994,  group: 14, period: 4 },
  { symbol: 'As', name: 'Arsenic',       number: 33,  mass: 74.922,   electronegativity: 2.18, ionization_energy: 9.7886,  group: 15, period: 4 },
  { symbol: 'Se', name: 'Selenium',      number: 34,  mass: 78.971,   electronegativity: 2.55, ionization_energy: 9.752,   group: 16, period: 4 },
  { symbol: 'Br', name: 'Bromine',       number: 35,  mass: 79.904,   electronegativity: 2.96, ionization_energy: 11.8138, group: 17, period: 4 },
  { symbol: 'Kr', name: 'Krypton',       number: 36,  mass: 83.798,   electronegativity: 3.00, ionization_energy: 14.000,  group: 18, period: 4 },
  { symbol: 'Rb', name: 'Rubidium',      number: 37,  mass: 85.468,   electronegativity: 0.82, ionization_energy: 4.1771,  group: 1,  period: 5 },
  { symbol: 'Sr', name: 'Strontium',     number: 38,  mass: 87.62,    electronegativity: 0.95, ionization_energy: 5.6949,  group: 2,  period: 5 },
  { symbol: 'Y',  name: 'Yttrium',       number: 39,  mass: 88.906,   electronegativity: 1.22, ionization_energy: 6.2173,  group: 3,  period: 5 },
  { symbol: 'Zr', name: 'Zirconium',     number: 40,  mass: 91.224,   electronegativity: 1.33, ionization_energy: 6.6339,  group: 4,  period: 5 },
  { symbol: 'Nb', name: 'Niobium',       number: 41,  mass: 92.906,   electronegativity: 1.6,  ionization_energy: 6.7589,  group: 5,  period: 5 },
  { symbol: 'Mo', name: 'Molybdenum',    number: 42,  mass: 95.95,    electronegativity: 2.16, ionization_energy: 7.0924,  group: 6,  period: 5 },
  { symbol: 'Tc', name: 'Technetium',    number: 43,  mass: 98.0,     electronegativity: 1.9,  ionization_energy: 7.28,    group: 7,  period: 5 },
  { symbol: 'Ru', name: 'Ruthenium',     number: 44,  mass: 101.07,   electronegativity: 2.2,  ionization_energy: 7.3605,  group: 8,  period: 5 },
  { symbol: 'Rh', name: 'Rhodium',       number: 45,  mass: 102.91,   electronegativity: 2.28, ionization_energy: 7.4589,  group: 9,  period: 5 },
  { symbol: 'Pd', name: 'Palladium',     number: 46,  mass: 106.42,   electronegativity: 2.20, ionization_energy: 8.3369,  group: 10, period: 5 },
  { symbol: 'Ag', name: 'Silver',        number: 47,  mass: 107.868,  electronegativity: 1.93, ionization_energy: 7.5762,  group: 11, period: 5 },
  { symbol: 'Cd', name: 'Cadmium',       number: 48,  mass: 112.41,   electronegativity: 1.69, ionization_energy: 8.9938,  group: 12, period: 5 },
  { symbol: 'In', name: 'Indium',        number: 49,  mass: 114.82,   electronegativity: 1.78, ionization_energy: 5.7864,  group: 13, period: 5 },
  { symbol: 'Sn', name: 'Tin',           number: 50,  mass: 118.71,   electronegativity: 1.96, ionization_energy: 7.3439,  group: 14, period: 5 },
  { symbol: 'Sb', name: 'Antimony',      number: 51,  mass: 121.76,   electronegativity: 2.05, ionization_energy: 8.6084,  group: 15, period: 5 },
  { symbol: 'Te', name: 'Tellurium',     number: 52,  mass: 127.60,   electronegativity: 2.1,  ionization_energy: 9.009,   group: 16, period: 5 },
  { symbol: 'I',  name: 'Iodine',        number: 53,  mass: 126.904,  electronegativity: 2.66, ionization_energy: 10.4513, group: 17, period: 5 },
  { symbol: 'Xe', name: 'Xenon',         number: 54,  mass: 131.293,  electronegativity: 2.6,  ionization_energy: 12.1298, group: 18, period: 5 },
  { symbol: 'Cs', name: 'Caesium',       number: 55,  mass: 132.91,   electronegativity: 0.79, ionization_energy: 3.8939,  group: 1,  period: 6 },
  { symbol: 'Ba', name: 'Barium',        number: 56,  mass: 137.33,   electronegativity: 0.89, ionization_energy: 5.2117,  group: 2,  period: 6 },
  { symbol: 'La', name: 'Lanthanum',     number: 57,  mass: 138.91,   electronegativity: 1.10, ionization_energy: 5.5770,  group: 3,  period: 6 },
  { symbol: 'Ce', name: 'Cerium',        number: 58,  mass: 140.12,   electronegativity: 1.12, ionization_energy: 5.5387,  group: 3,  period: 6 },
  { symbol: 'Pr', name: 'Praseodymium',  number: 59,  mass: 140.91,   electronegativity: 1.13, ionization_energy: 5.473,   group: 3,  period: 6 },
  { symbol: 'Nd', name: 'Neodymium',     number: 60,  mass: 144.24,   electronegativity: 1.14, ionization_energy: 5.5250,  group: 3,  period: 6 },
  { symbol: 'Pm', name: 'Promethium',    number: 61,  mass: 145.0,    electronegativity: 1.13, ionization_energy: 5.582,   group: 3,  period: 6 },
  { symbol: 'Sm', name: 'Samarium',      number: 62,  mass: 150.36,   electronegativity: 1.17, ionization_energy: 5.6437,  group: 3,  period: 6 },
  { symbol: 'Eu', name: 'Europium',      number: 63,  mass: 151.96,   electronegativity: 1.2,  ionization_energy: 5.6704,  group: 3,  period: 6 },
  { symbol: 'Gd', name: 'Gadolinium',    number: 64,  mass: 157.25,   electronegativity: 1.20, ionization_energy: 6.1498,  group: 3,  period: 6 },
  { symbol: 'Tb', name: 'Terbium',       number: 65,  mass: 158.93,   electronegativity: 1.2,  ionization_energy: 5.8638,  group: 3,  period: 6 },
  { symbol: 'Dy', name: 'Dysprosium',    number: 66,  mass: 162.50,   electronegativity: 1.22, ionization_energy: 5.9389,  group: 3,  period: 6 },
  { symbol: 'Ho', name: 'Holmium',       number: 67,  mass: 164.93,   electronegativity: 1.23, ionization_energy: 6.0215,  group: 3,  period: 6 },
  { symbol: 'Er', name: 'Erbium',        number: 68,  mass: 167.26,   electronegativity: 1.24, ionization_energy: 6.1077,  group: 3,  period: 6 },
  { symbol: 'Tm', name: 'Thulium',       number: 69,  mass: 168.93,   electronegativity: 1.25, ionization_energy: 6.1843,  group: 3,  period: 6 },
  { symbol: 'Yb', name: 'Ytterbium',     number: 70,  mass: 173.05,   electronegativity: 1.1,  ionization_energy: 6.2542,  group: 3,  period: 6 },
  { symbol: 'Lu', name: 'Lutetium',      number: 71,  mass: 174.97,   electronegativity: 1.27, ionization_energy: 5.4259,  group: 3,  period: 6 },
  { symbol: 'Hf', name: 'Hafnium',       number: 72,  mass: 178.49,   electronegativity: 1.3,  ionization_energy: 6.8251,  group: 4,  period: 6 },
  { symbol: 'Ta', name: 'Tantalum',      number: 73,  mass: 180.95,   electronegativity: 1.5,  ionization_energy: 7.5496,  group: 5,  period: 6 },
  { symbol: 'W',  name: 'Tungsten',      number: 74,  mass: 183.84,   electronegativity: 2.36, ionization_energy: 7.8640,  group: 6,  period: 6 },
  { symbol: 'Re', name: 'Rhenium',       number: 75,  mass: 186.21,   electronegativity: 1.9,  ionization_energy: 7.8837,  group: 7,  period: 6 },
  { symbol: 'Os', name: 'Osmium',        number: 76,  mass: 190.23,   electronegativity: 2.2,  ionization_energy: 8.4382,  group: 8,  period: 6 },
  { symbol: 'Ir', name: 'Iridium',       number: 77,  mass: 192.22,   electronegativity: 2.20, ionization_energy: 8.9670,  group: 9,  period: 6 },
  { symbol: 'Pt', name: 'Platinum',      number: 78,  mass: 195.08,   electronegativity: 2.28, ionization_energy: 8.9587,  group: 10, period: 6 },
  { symbol: 'Au', name: 'Gold',          number: 79,  mass: 196.967,  electronegativity: 2.54, ionization_energy: 9.2255,  group: 11, period: 6 },
  { symbol: 'Hg', name: 'Mercury',       number: 80,  mass: 200.592,  electronegativity: 2.00, ionization_energy: 10.4375, group: 12, period: 6 },
  { symbol: 'Tl', name: 'Thallium',      number: 81,  mass: 204.38,   electronegativity: 1.62, ionization_energy: 6.1082,  group: 13, period: 6 },
  { symbol: 'Pb', name: 'Lead',          number: 82,  mass: 207.2,    electronegativity: 2.33, ionization_energy: 7.4167,  group: 14, period: 6 },
  { symbol: 'Bi', name: 'Bismuth',       number: 83,  mass: 208.98,   electronegativity: 2.02, ionization_energy: 7.2855,  group: 15, period: 6 },
  { symbol: 'Po', name: 'Polonium',      number: 84,  mass: 209.0,    electronegativity: 2.0,  ionization_energy: 8.414,   group: 16, period: 6 },
  { symbol: 'At', name: 'Astatine',      number: 85,  mass: 210.0,    electronegativity: 2.2,  ionization_energy: 8.86,    group: 17, period: 6 },
  { symbol: 'Rn', name: 'Radon',         number: 86,  mass: 222.0,    electronegativity: 2.2,  ionization_energy: 10.7485, group: 18, period: 6 },
  { symbol: 'Fr', name: 'Francium',      number: 87,  mass: 223.0,    electronegativity: 0.7,  ionization_energy: 4.0727,  group: 1,  period: 7 },
  { symbol: 'Ra', name: 'Radium',        number: 88,  mass: 226.0,    electronegativity: 0.9,  ionization_energy: 5.2784,  group: 2,  period: 7 },
  { symbol: 'Ac', name: 'Actinium',      number: 89,  mass: 227.0,    electronegativity: 1.1,  ionization_energy: 5.17,    group: 3,  period: 7 },
  { symbol: 'Th', name: 'Thorium',       number: 90,  mass: 232.04,   electronegativity: 1.3,  ionization_energy: 6.3067,  group: 3,  period: 7 },
  { symbol: 'Pa', name: 'Protactinium',  number: 91,  mass: 231.04,   electronegativity: 1.5,  ionization_energy: 5.89,    group: 3,  period: 7 },
  { symbol: 'U',  name: 'Uranium',       number: 92,  mass: 238.029,  electronegativity: 1.38, ionization_energy: 6.1941,  group: 3,  period: 7 },
  { symbol: 'Np', name: 'Neptunium',     number: 93,  mass: 237.0,    electronegativity: 1.36, ionization_energy: 6.2657,  group: 3,  period: 7 },
  { symbol: 'Pu', name: 'Plutonium',     number: 94,  mass: 244.0,    electronegativity: 1.28, ionization_energy: 6.026,   group: 3,  period: 7 },
  { symbol: 'Am', name: 'Americium',     number: 95,  mass: 243.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Cm', name: 'Curium',        number: 96,  mass: 247.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Bk', name: 'Berkelium',     number: 97,  mass: 247.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Cf', name: 'Californium',   number: 98,  mass: 251.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Es', name: 'Einsteinium',   number: 99,  mass: 252.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Fm', name: 'Fermium',       number: 100, mass: 257.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Md', name: 'Mendelevium',   number: 101, mass: 258.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'No', name: 'Nobelium',      number: 102, mass: 259.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Lr', name: 'Lawrencium',    number: 103, mass: 266.0,    electronegativity: null, ionization_energy: null,    group: 3,  period: 7 },
  { symbol: 'Rf', name: 'Rutherfordium', number: 104, mass: 267.0,    electronegativity: null, ionization_energy: null,    group: 4,  period: 7 },
  { symbol: 'Db', name: 'Dubnium',       number: 105, mass: 268.0,    electronegativity: null, ionization_energy: null,    group: 5,  period: 7 },
  { symbol: 'Sg', name: 'Seaborgium',    number: 106, mass: 269.0,    electronegativity: null, ionization_energy: null,    group: 6,  period: 7 },
  { symbol: 'Bh', name: 'Bohrium',       number: 107, mass: 270.0,    electronegativity: null, ionization_energy: null,    group: 7,  period: 7 },
  { symbol: 'Hs', name: 'Hassium',       number: 108, mass: 277.0,    electronegativity: null, ionization_energy: null,    group: 8,  period: 7 },
  { symbol: 'Mt', name: 'Meitnerium',    number: 109, mass: 278.0,    electronegativity: null, ionization_energy: null,    group: 9,  period: 7 },
  { symbol: 'Ds', name: 'Darmstadtium',  number: 110, mass: 281.0,    electronegativity: null, ionization_energy: null,    group: 10, period: 7 },
  { symbol: 'Rg', name: 'Roentgenium',   number: 111, mass: 282.0,    electronegativity: null, ionization_energy: null,    group: 11, period: 7 },
  { symbol: 'Cn', name: 'Copernicium',   number: 112, mass: 285.0,    electronegativity: null, ionization_energy: null,    group: 12, period: 7 },
  { symbol: 'Nh', name: 'Nihonium',      number: 113, mass: 286.0,    electronegativity: null, ionization_energy: null,    group: 13, period: 7 },
  { symbol: 'Fl', name: 'Flerovium',     number: 114, mass: 289.0,    electronegativity: null, ionization_energy: null,    group: 14, period: 7 },
  { symbol: 'Mc', name: 'Moscovium',     number: 115, mass: 290.0,    electronegativity: null, ionization_energy: null,    group: 15, period: 7 },
  { symbol: 'Lv', name: 'Livermorium',   number: 116, mass: 293.0,    electronegativity: null, ionization_energy: null,    group: 16, period: 7 },
  { symbol: 'Ts', name: 'Tennessine',    number: 117, mass: 294.0,    electronegativity: null, ionization_energy: null,    group: 17, period: 7 },
  { symbol: 'Og', name: 'Oganesson',     number: 118, mass: 294.0,    electronegativity: null, ionization_energy: null,    group: 18, period: 7 },
];

const elementsBySymbol = new Map<string, Element>();
const elementsByNumber = new Map<number, Element>();
for (const el of ELEMENTS) {
  elementsBySymbol.set(el.symbol.toLowerCase(), el);
  elementsByNumber.set(el.number, el);
}

export function getElement(query: string): Element | null {
  const num = parseInt(query);
  if (!isNaN(num)) return elementsByNumber.get(num) ?? null;
  return elementsBySymbol.get(query.toLowerCase()) ?? null;
}
