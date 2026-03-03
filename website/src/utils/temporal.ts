// ═══════════════════════════════════════════════════════════════════════════════
// TEMPORAL KINETICS — φ-Time curves for reaction animations
// Used by TemporalMoleculeViewer for animating reactions over sacred time
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948;
const PHI_SQ = PHI * PHI;       // 2.618 — creation acceleration
const INV_PHI_SQ = 1 / PHI_SQ;  // 0.382 — destruction deceleration
const PHI_FOUR = PHI_SQ * PHI_SQ; // 6.854 — temporal asymmetry

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

export interface AtomState {
  element: string;
  position: [number, number, number];
  visible: boolean;  // for atoms that appear/disappear
}

export interface BondState {
  from: number;  // atom index
  to: number;    // atom index
  order: 1 | 2 | 3;
  strength: number; // 0 = broken, 1 = formed, in-between = forming/breaking
}

export interface TemporalFrame {
  atoms: AtomState[];
  bonds: BondState[];
  time: number; // 0-1
  label: string; // e.g., "Reactants", "Transition State", "Products"
}

export interface ReactionAnimation {
  reactants: TemporalFrame;
  products: TemporalFrame;
  transitionState?: TemporalFrame; // optional intermediate state
  duration: number; // animation duration in seconds
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-TIME EASING FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * φ-Time easing for bond formation (creation).
 * Uses φ² curve: bonds form rapidly then stabilize.
 * Input t: 0-1, Output: eased 0-1
 */
export function phiTimeFormation(t: number): number {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  // φ²-accelerated curve: fast start, smooth finish
  return 1 - Math.pow(1 - t, PHI_SQ);
}

/**
 * φ-Time easing for bond breaking (destruction).
 * Uses 1/φ² curve: bonds break slowly then snap.
 * Input t: 0-1, Output: eased 0-1
 */
export function phiTimeBreaking(t: number): number {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  // 1/φ²-decelerated curve: slow start, snap finish
  return Math.pow(t, INV_PHI_SQ);
}

/**
 * Combined φ-time curve for reactions.
 * 0 → 0.382 (1/φ²): bond breaking phase
 * 0.382 → 0.618 (φ⁻¹): transition state
 * 0.618 → 1 (φ): bond formation phase
 */
export function phiTimeReaction(t: number): number {
  if (t <= INV_PHI_SQ) {
    // Breaking phase: remap 0-0.382 to 0-1
    return phiTimeBreaking(t / INV_PHI_SQ) * 0.382;
  } else if (t >= 1 - INV_PHI_SQ) {
    // Formation phase: remap 0.618-1 to 0-1
    const formationStart = 1 - INV_PHI_SQ;
    return formationStart + phiTimeFormation((t - formationStart) / INV_PHI_SQ) * INV_PHI_SQ;
  } else {
    // Linear through transition state
    return t;
  }
}

/**
 * Get the phase name for a given time position.
 */
export function getTemporalPhase(t: number): 'breaking' | 'transition' | 'forming' | 'complete' {
  if (t < INV_PHI_SQ) return 'breaking';
  if (t < 1 - INV_PHI_SQ) return 'transition';
  if (t < 1) return 'forming';
  return 'complete';
}

/**
 * Calculate golden spiral point for timeline visualization.
 */
export function goldenSpiralPoint(t: number, scale: number = 1): [number, number] {
  const angle = t * Math.PI * 2 * PHI; // φ-scaled angle
  const radius = scale * Math.sqrt(t) * PHI;
  return [
    radius * Math.cos(angle),
    radius * Math.sin(angle)
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERPOLATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Interpolate between two atom states.
 */
export function interpolateAtom(from: AtomState, to: AtomState, t: number): AtomState {
  const easedT = phiTimeReaction(t);
  return {
    element: to.element, // element doesn't change
    position: [
      from.position[0] + (to.position[0] - from.position[0]) * easedT,
      from.position[1] + (to.position[1] - from.position[1]) * easedT,
      from.position[2] + (to.position[2] - from.position[2]) * easedT,
    ],
    visible: t < 0.5 ? from.visible : to.visible,
  };
}

/**
 * Interpolate bond strength based on breaking/forming phase.
 */
export function interpolateBondStrength(
  fromStrength: number,
  toStrength: number,
  t: number,
  phase: 'breaking' | 'forming'
): number {
  if (phase === 'breaking') {
    // Use breaking curve
    const eased = phiTimeBreaking(t);
    return fromStrength + (toStrength - fromStrength) * eased;
  } else {
    // Use formation curve
    const eased = phiTimeFormation(t);
    return fromStrength + (toStrength - fromStrength) * eased;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECTION MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Map atoms from reactants to products.
 * Simple heuristic: match by element and proximity.
 */
export function mapReactantAtoms(
  reactants: AtomState[],
  products: AtomState[]
): Map<number, number> {
  const mapping = new Map<number, number>();
  const used = new Set<number>();

  for (let i = 0; i < reactants.length; i++) {
    const rAtom = reactants[i];
    let bestMatch = -1;
    let bestDist = Infinity;

    for (let j = 0; j < products.length; j++) {
      if (used.has(j)) continue;
      const pAtom = products[j];
      if (pAtom.element !== rAtom.element) continue;

      // Calculate distance
      const dx = rAtom.position[0] - pAtom.position[0];
      const dy = rAtom.position[1] - pAtom.position[1];
      const dz = rAtom.position[2] - pAtom.position[2];
      const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);

      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = j;
      }
    }

    if (bestMatch >= 0) {
      mapping.set(i, bestMatch);
      used.add(bestMatch);
    }
  }

  return mapping;
}

/**
 * Create interpolated frame at time t.
 */
export function createInterpolatedFrame(
  reactants: TemporalFrame,
  products: TemporalFrame,
  t: number,
  atomMapping?: Map<number, number>
): TemporalFrame {
  const phase = getTemporalPhase(t);
  const atoms: AtomState[] = [];
  const bonds: BondState[] = [];

  // Interpolate atoms
  const mapping = atomMapping || mapReactantAtoms(reactants.atoms, products.atoms);

  for (let i = 0; i < reactants.atoms.length; i++) {
    const rAtom = reactants.atoms[i];
    const targetIdx = mapping.get(i);

    if (targetIdx !== undefined) {
      const pAtom = products.atoms[targetIdx];
      atoms.push(interpolateAtom(rAtom, pAtom, t));
    } else {
      // Atom disappears (reactant consumed)
      atoms.push({
        ...rAtom,
        visible: t < INV_PHI_SQ, // Fade out during breaking phase
      });
    }
  }

  // Add new atoms that appear in products
  for (let j = 0; j < products.atoms.length; j++) {
    if (!Array.from(mapping.values()).includes(j)) {
      const pAtom = products.atoms[j];
      atoms.push({
        ...pAtom,
        visible: t > 1 - INV_PHI_SQ, // Fade in during formation phase
      });
    }
  }

  // Interpolate bonds
  // Start with reactant bonds, fade them out during breaking
  for (const bond of reactants.bonds) {
    const strength = t < INV_PHI_SQ
      ? interpolateBondStrength(1, 0, t / INV_PHI_SQ, 'breaking')
      : 0;
    bonds.push({ ...bond, strength });
  }

  // Add product bonds, fade them in during formation
  for (const bond of products.bonds) {
    const strength = t > 1 - INV_PHI_SQ
      ? interpolateBondStrength(0, 1, (t - (1 - INV_PHI_SQ)) / INV_PHI_SQ, 'forming')
      : 0;
    bonds.push({ ...bond, strength });
  }

  // Determine label
  let label = reactants.label;
  if (t > 0.45 && t < 0.55) label = 'Transition State';
  if (t > 0.9) label = products.label;

  return { atoms, bonds, time: t, label };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MARKERS
// ═══════════════════════════════════════════════════════════════════════════════

export const SACRED_TIME_MARKERS = [
  { t: 0, label: 'Start', symbol: '○' },
  { t: INV_PHI_SQ, label: 'Breaking Complete', symbol: '∅' },
  { t: 0.5, label: 'Transition State', symbol: '⧫' },
  { t: 1 - INV_PHI_SQ, label: 'Formation Begins', symbol: '→' },
  { t: 1, label: 'Complete', symbol: '●' },
];
