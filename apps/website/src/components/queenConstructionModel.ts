import {
  buildResearchCityModel,
  type CityResearchEdge,
  type CityResearchNode,
} from "./queenResearchCityModel";

export type ConstructionStage =
  | "complete"
  | "assembling"
  | "blueprint"
  | "sealed";

export interface ConstructionStructure {
  id: string;
  label: string;
  layer: string;
  stage: ConstructionStage;
  dependenciesReady: number;
  dependenciesTotal: number;
}

export interface ConstructionRoute {
  from: string;
  to: string;
  state: "energized" | "assembling" | "dormant";
}

export interface ConstructionPlan {
  available: boolean;
  structures: ConstructionStructure[];
  routes: ConstructionRoute[];
  summary: Record<ConstructionStage, number>;
}

const EMPTY_SUMMARY: Record<ConstructionStage, number> = {
  complete: 0,
  assembling: 0,
  blueprint: 0,
  sealed: 0,
};

function unavailablePlan(): ConstructionPlan {
  return {
    available: false,
    structures: [],
    routes: [],
    summary: { ...EMPTY_SUMMARY },
  };
}

function stageFromState(
  state: CityResearchNode["state"],
): ConstructionStage {
  if (state === "researched") return "complete";
  if (state === "researching") return "assembling";
  if (state === "available") return "blueprint";
  return "sealed";
}

export function buildConstructionPlan(
  researchNodes: CityResearchNode[],
  researchEdges: CityResearchEdge[],
  error: string | null,
): ConstructionPlan {
  const city = buildResearchCityModel(researchNodes, researchEdges, [], error);
  if (!city.available) return unavailablePlan();

  const stageById = new Map(
    researchNodes.map((node) => [node.id, stageFromState(node.state)]),
  );
  const incoming = new Map<string, string[]>();
  researchEdges.forEach((edge) => {
    incoming.set(edge.to, [...(incoming.get(edge.to) ?? []), edge.from]);
  });

  const structures = researchNodes.map((node) => {
    const dependencies = incoming.get(node.id) ?? [];
    return {
      id: node.id,
      label: node.label,
      layer: node.layer,
      stage: stageById.get(node.id) ?? "sealed",
      dependenciesReady: dependencies.filter(
        (id) => stageById.get(id) === "complete",
      ).length,
      dependenciesTotal: dependencies.length,
    } satisfies ConstructionStructure;
  });
  const routes = researchEdges.map((edge) => {
    const sourceStage = stageById.get(edge.from);
    return {
      from: edge.from,
      to: edge.to,
      state:
        sourceStage === "complete"
          ? "energized"
          : sourceStage === "assembling"
            ? "assembling"
            : "dormant",
    } satisfies ConstructionRoute;
  });
  const summary = { ...EMPTY_SUMMARY };
  structures.forEach((structure) => {
    summary[structure.stage] += 1;
  });

  return { available: true, structures, routes, summary };
}
