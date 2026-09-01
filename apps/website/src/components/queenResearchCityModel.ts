export type ResearchState =
  | "researched"
  | "researching"
  | "available"
  | "locked";

export interface CityResearchNode {
  id: string;
  label: string;
  layer: string;
  maturity: "shipped" | "partial" | "blocked" | "planned" | "unknown";
  state: ResearchState;
  evidence: string;
}

export interface CityResearchEdge {
  from: string;
  to: string;
}

export interface CityPosition {
  x: number;
  y: number;
  z: number;
  height: number;
  layerIndex: number;
}

export interface CityRoute {
  edge: CityResearchEdge;
  from: CityPosition;
  to: CityPosition;
}

export interface ResearchCityModel {
  available: boolean;
  layers: string[];
  positions: Map<string, CityPosition>;
  routes: CityRoute[];
}

const STATE_HEIGHTS: Record<ResearchState, number> = {
  researched: 1.5,
  researching: 2.25,
  available: 1.8,
  locked: 0.9,
};

const RESEARCH_STATES = new Set<ResearchState>([
  "researched",
  "researching",
  "available",
  "locked",
]);
const MATURITIES = new Set<CityResearchNode["maturity"]>([
  "shipped",
  "partial",
  "blocked",
  "planned",
  "unknown",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isCityResearchNode(value: unknown): value is CityResearchNode {
  return (
    isRecord(value) &&
    isNonEmptyString(value.id) &&
    isNonEmptyString(value.label) &&
    isNonEmptyString(value.layer) &&
    isNonEmptyString(value.evidence) &&
    typeof value.state === "string" &&
    RESEARCH_STATES.has(value.state as ResearchState) &&
    typeof value.maturity === "string" &&
    MATURITIES.has(value.maturity as CityResearchNode["maturity"])
  );
}

function isCityResearchEdge(value: unknown): value is CityResearchEdge {
  return (
    isRecord(value) &&
    isNonEmptyString(value.from) &&
    isNonEmptyString(value.to)
  );
}

function unavailableModel(): ResearchCityModel {
  return {
    available: false,
    layers: [],
    positions: new Map(),
    routes: [],
  };
}

export function buildResearchCityModel(
  researchNodes: CityResearchNode[],
  researchEdges: CityResearchEdge[],
  researchLayers: string[],
  error: string | null,
): ResearchCityModel {
  if (
    error !== null ||
    !Array.isArray(researchNodes) ||
    !researchNodes.length ||
    !researchNodes.every(isCityResearchNode) ||
    !Array.isArray(researchEdges) ||
    !researchEdges.every(isCityResearchEdge) ||
    !Array.isArray(researchLayers) ||
    !researchLayers.every(isNonEmptyString)
  ) {
    return unavailableModel();
  }

  const layers = [...new Set(researchLayers)];
  researchNodes.forEach((node) => {
    if (!layers.includes(node.layer)) layers.push(node.layer);
  });
  if (!layers.length) return unavailableModel();

  const positions = new Map<string, CityPosition>();
  layers.forEach((layer, layerIndex) => {
    const districtNodes = researchNodes.filter((node) => node.layer === layer);
    const radius = 3.4 + layerIndex * 2.15;
    const offset =
      (layerIndex % 2) * (Math.PI / Math.max(1, districtNodes.length));

    districtNodes.forEach((node, nodeIndex) => {
      const angle =
        (nodeIndex / Math.max(1, districtNodes.length)) * Math.PI * 2 + offset;
      const height = STATE_HEIGHTS[node.state];
      positions.set(node.id, {
        x: Math.cos(angle) * radius,
        y: height / 2,
        z: Math.sin(angle) * radius,
        height,
        layerIndex,
      });
    });
  });

  if (positions.size !== researchNodes.length) return unavailableModel();

  const routes: CityRoute[] = [];
  for (const edge of researchEdges) {
    const from = positions.get(edge.from);
    const to = positions.get(edge.to);
    if (!from || !to) return unavailableModel();
    routes.push({ edge, from, to });
  }

  return { available: true, layers, positions, routes };
}

export function motionModeFromPreference(prefersReducedMotion: boolean) {
  return prefersReducedMotion ? "static" : "interactive";
}
