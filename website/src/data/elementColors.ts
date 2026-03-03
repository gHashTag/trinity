// ═══════════════════════════════════════════════════════════════════════════════
// CPK COLOR SCHEME + ATOMIC RADII for 3D Molecule Rendering
// ═══════════════════════════════════════════════════════════════════════════════

/** CPK coloring convention for elements */
export const ELEMENT_COLORS: Record<string, string> = {
  H:  '#FFFFFF', He: '#D9FFFF', Li: '#CC80FF', Be: '#C2FF00',
  B:  '#FFB5B5', C:  '#909090', N:  '#3050F8', O:  '#FF0D0D',
  F:  '#90E050', Ne: '#B3E3F5', Na: '#AB5CF2', Mg: '#8AFF00',
  Al: '#BFA6A6', Si: '#F0C8A0', P:  '#FF8000', S:  '#FFFF30',
  Cl: '#1FF01F', Ar: '#80D1E3', K:  '#8F40D4', Ca: '#3DFF00',
  Sc: '#E6E6E6', Ti: '#BFC2C7', V:  '#A6A6AB', Cr: '#8A99C7',
  Mn: '#9C7AC7', Fe: '#E06633', Co: '#F090A0', Ni: '#50D050',
  Cu: '#C88033', Zn: '#7D80B0', Ga: '#C28F8F', Ge: '#668F8F',
  As: '#BD80E3', Se: '#FFA100', Br: '#A62929', Kr: '#5CB8D1',
  Rb: '#702EB0', Sr: '#00FF00', Y:  '#94FFFF', Zr: '#94E0E0',
  Nb: '#73C2C9', Mo: '#54B5B5', Tc: '#3B9E9E', Ru: '#248F8F',
  Rh: '#0A7D8C', Pd: '#006985', Ag: '#C0C0C0', Cd: '#FFD98F',
  In: '#A67573', Sn: '#668080', Sb: '#9E63B5', Te: '#D47A00',
  I:  '#940094', Xe: '#429EB0', Cs: '#57178F', Ba: '#00C900',
  La: '#70D4FF', Ce: '#FFFFC7', Pr: '#D9FFC7', Nd: '#C7FFC7',
  Pm: '#A3FFC7', Sm: '#8FFFC7', Eu: '#61FFC7', Gd: '#45FFC7',
  Tb: '#30FFC7', Dy: '#1FFFC7', Ho: '#00FF9C', Er: '#00E675',
  Tm: '#00D452', Yb: '#00BF38', Lu: '#00AB24', Hf: '#4DC2FF',
  Ta: '#4DA6FF', W:  '#2194D6', Re: '#267DAB', Os: '#266696',
  Ir: '#175487', Pt: '#D0D0E0', Au: '#FFD123', Hg: '#B8B8D0',
  Tl: '#A6544D', Pb: '#575961', Bi: '#9E4FB5', Po: '#AB5C00',
  At: '#754F45', Rn: '#428296', Fr: '#420066', Ra: '#007D00',
  Ac: '#70ABFA', Th: '#00BAFF', Pa: '#00A1FF', U:  '#008FFF',
  Np: '#0080FF', Pu: '#006BFF', Am: '#545CF2', Cm: '#785CE3',
};

/** Van der Waals radii in angstroms, scaled for 3D display */
export const ELEMENT_RADII: Record<string, number> = {
  H: 0.25, He: 0.31, Li: 0.45, Be: 0.35, B: 0.35, C: 0.40,
  N: 0.38, O: 0.35, F: 0.33, Ne: 0.38, Na: 0.50, Mg: 0.45,
  Al: 0.43, Si: 0.42, P: 0.40, S: 0.40, Cl: 0.39, Ar: 0.42,
  K: 0.55, Ca: 0.50, Fe: 0.45, Cu: 0.42, Zn: 0.42, Br: 0.42,
  Ag: 0.45, I: 0.45, Au: 0.45, Pt: 0.45, U: 0.50,
};

/** Get color for element (fallback to gray) */
export function getElementColor(symbol: string): string {
  return ELEMENT_COLORS[symbol] || '#808080';
}

/** Get radius for element (fallback to 0.35) */
export function getElementRadius(symbol: string): number {
  return ELEMENT_RADII[symbol] || 0.35;
}
