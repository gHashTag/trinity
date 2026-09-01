import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { QueenFactory } from "../components/QueenFactory";
import {
  verifyHardwareEnvelope,
  type VerifiedHardwareRegistry,
} from "../components/queenHardwareRegistry";
import { TrinityLogo } from "../components/TrinityLogo";
import { useI18n } from "../i18n/context";
import "./Queen.css";

const DEFAULT_QUEEN_API =
  "https://trios-agent-server-production.up.railway.app";
const QUEEN_API = (
  (import.meta.env.VITE_QUEEN_API as string | undefined) ?? DEFAULT_QUEEN_API
).replace(/\/+$/, "");
const LIVE_POLL_MS = 5_000;
const ACTIVITY_POLL_MS = 2_000;
const PINNED_QUEEN_HARDWARE_PUBLIC_KEY =
  "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA/K7txBmCOUwA3k3L03lHlM77TH45r7qfw7XscBGNXmQ=\n-----END PUBLIC KEY-----\n";

type ResearchState = "researched" | "researching" | "available" | "locked";

interface ResearchNode {
  id: string;
  label: string;
  layer: string;
  maturity: "shipped" | "partial" | "blocked" | "planned" | "unknown";
  state: ResearchState;
  evidence: string;
  blockedBy?: string;
  note?: string;
  prerequisites: string[];
  unlocks: string[];
}

interface ResearchGraph {
  nodes: ResearchNode[];
  edges: Array<{ from: string; to: string }>;
  layers: string[];
  summary: {
    total: number;
    researched: number;
    researching: number;
    available: number;
    locked: number;
    percentage: number;
  };
  runtime: { status: "live" | "offline" };
  workers: {
    capacity: number;
    active: number;
    idle: number;
    utilization: number;
    slots: Array<{ slot: number; state: "busy" | "idle" }>;
  };
  agentBootstrap: {
    version: string;
    mode: string;
    protocol: string;
    endpoints: Record<string, string>;
    repositories: string[];
    skills: string[];
    adaptation: { read: string[]; write: string };
  };
}

interface QueenStatus {
  status: "ok";
  scheduler: {
    enabled: boolean;
    intervalSeconds: number;
  };
  lastTick: {
    decidedAt: string;
    allowed: boolean;
    refusal: string | null;
    skippedCount: number;
  } | null;
  dispatches: {
    total: number;
    finished: number;
    running: number;
    latest: {
      issue: number;
      dispatchedAt: string;
      finishedAt: string | null;
      outcome: string | null;
    } | null;
  };
}

interface QueenBoard {
  repo: string;
  columns: Array<{ key: string; title: string; blurb: string }>;
  cards: Array<{
    number: number;
    title: string;
    column: string;
    criteria?: number;
    needs?: string[];
  }>;
  pulse: {
    rounds: number;
    bees: number;
    verdicts: number;
    lastRoundAt: string | null;
    roundSeconds: number | null;
  };
}

const FALLBACK_COLUMNS = [
  { key: "backlog", title: "backlog", blurb: "" },
  { key: "blocked", title: "blocked", blurb: "" },
  { key: "running", title: "running", blurb: "" },
  { key: "review", title: "in review", blurb: "" },
  { key: "done", title: "done", blurb: "" },
  { key: "dropped", title: "dropped", blurb: "" },
];

interface QueenActivityEvent {
  id: string;
  kind:
    | "dispatch"
    | "progress"
    | "tool"
    | "result"
    | "usage"
    | "error"
    | "finished"
    | "review";
  issue: number | null;
  title: string;
  at: string;
  state: string | null;
}

interface QueenActivity {
  cursor: number;
  events: QueenActivityEvent[];
}

type LoadState =
  | { kind: "loading"; data: null; error: null }
  | { kind: "ready"; data: QueenStatus; error: null }
  | { kind: "error"; data: QueenStatus | null; error: string };

const COPY = {
  en: {
    back: "TRINITY",
    eyebrow: "AUTONOMOUS SUPERVISOR / PRODUCTION",
    title: "Queen turns specifications into verified work.",
    lede: "One decision-maker. Isolated Bees. Every refusal and completion leaves evidence.",
    live: "LIVE BACKEND",
    unavailable: "BACKEND UNAVAILABLE",
    checking: "CHECKING BACKEND",
    scheduler: "Scheduler",
    every: "every",
    lastDecision: "Last decision",
    dispatches: "Completed Bees",
    active: "Running now",
    decision: "LATEST QUEEN DECISION",
    chose: "A new Bee may start.",
    stoodDown: "No Bee started — policy stood down.",
    noDecision: "No recorded decision yet.",
    reasons: "explicit skip reasons",
    queueMeaning:
      "The supervisor is alive. The current queue has no eligible specification.",
    path: "FROM INTENT TO EVIDENCE",
    spec: "SPEC",
    specCopy: "Boundary, scenarios, requirements and success criteria.",
    queen: "QUEEN",
    queenCopy: "Checks collisions, state and policy before delegation.",
    bee: "BEE",
    beeCopy: "Works in isolation and returns a reviewable result.",
    latest: "LATEST COMPLETED DISPATCH",
    issue: "Issue",
    outcome: "Outcome",
    finished: "Finished",
    provenance: "LIVE / RAILWAY / POSTGRES / QUEEND",
    refresh: "refreshes every 5 seconds",
    source: "Open operational view",
    board: "REALTIME KANBAN",
    boardTitle: "The whole swarm, in one place.",
    boardCopy:
      "Public GitHub work mapped to the Queen’s own states. Operational secrets stay private.",
    kanbanView: "KANBAN",
    mapView: "MISSION MAP",
    factoryView: "FACTORY",
    kanbanHint: "Operational columns",
    mapHint: "Strategic lifecycle sectors",
    factoryHint: "Live engineering production",
    factoryFlow: "ISSUE → SPEC → BEE → REVIEW → EVIDENCE",
    factoryThroughput: "Live utilization",
    factoryQueueDensity: "queue density peak",
    factoryWorkerBays: "Bee hangars",
    factoryIdle: "idle",
    factoryStation: "station",
    factoryModules: "modules",
    factoryOffline: "factory telemetry offline",
    factoryOpenIssue: "OPEN REAL MODULE",
    factorySelectedModule: "SELECTED PRODUCTION MODULE",
    factoryLiveContract:
      "Every station, module and Bee bay below is backed by the live Queen ledger.",
    cityTitle: "RESEARCH CITADEL",
    cityCopy:
      "A living city compiled from the canonical technology graph. Laboratories are research nodes; energy routes are dependencies.",
    cityDistricts: "research districts",
    cityLaboratories: "real laboratories",
    citySelected: "SELECTED LABORATORY",
    cityEvidence: "Evidence",
    cityOffline: "Research graph unavailable — no city was synthesized.",
    cityBuildTitle: "CONSTRUCTION PROTOCOL",
    cityComplete: "complete",
    cityAssembling: "assembling",
    cityBlueprint: "blueprints",
    citySealed: "sealed",
    cityDependencies: "dependencies ready",
    foundryTitle: "SIGNED FPGA FOUNDRY",
    foundryVerified: "Registry signature verified. Structures below represent signed public evidence.",
    foundryUnavailable: "Hardware registry unavailable — no FPGA structures rendered.",
    foundryTotal: "verified devices",
    foundryOnline: "online now",
    foundryProgrammed: "programmed",
    foundryKey: "signing key",
    mapLegend:
      "The routes show Queen lifecycle movement; only the Technology Tree below claims prerequisite links.",
    sector: "sector",
    rounds: "rounds / 24h",
    beesStarted: "Bees started",
    verdicts: "verdicts",
    empty: "Nothing here",
    criteria: "criteria",
    missing: "needs",
    command: "LIVE COMMAND ROOM",
    commandTitle: "Queen reviews the swarm herself.",
    commandCopy:
      "The screen follows the real supervisor cycle: selection, isolated execution, self-review, Queen verdict and acceptance.",
    nextRound: "next Queen round",
    reviewing: "waiting for Queen review",
    executing: "executing now",
    noBees:
      "No Bee is executing right now. Queen remains online and keeps the queue under policy.",
    reviewQueue: "Queen review queue",
    activity: "LIVE BEE ACTIVITY",
    activityRate: "2 second pulse",
    noActivity: "Waiting for the next recorded Bee event.",
    synchronized: "synced every 5 seconds",
    selfReview: "SELF-REVIEW",
    selfReviewCopy:
      "The Bee runs checks and inspects its own diff before handoff.",
    verdict: "QUEEN VERDICT",
    verdictCopy:
      "Queen judges the evidence, rejects weak work and accepts only a passing result.",
    merge: "ACCEPT / MERGE",
    mergeCopy: "Approved work enters the repository with an auditable trail.",
    tech: "TECHNOLOGY TREE",
    techTitle: "Research opens the next capabilities.",
    techCopy:
      "This is the existing TRINITY research graph. Select a technology to see its prerequisites and what it unlocks next.",
    researched: "researched",
    researching: "researching",
    available: "available next",
    locked: "locked",
    prerequisites: "Prerequisites",
    unlocks: "Unlocks next",
    noPrerequisites: "Available from the start",
    terminalNode: "Final technology in this branch",
    overallResearch: "overall research",
    activeResearch: "active research",
    nextAvailable: "available next",
    evidence: "Evidence",
    graphLive: "LIVE EVIDENCE GRAPH",
    graphOffline: "RESEARCH GRAPH OFFLINE",
    graphLoading: "Synchronizing the canonical TRINITY graph…",
    workerPool: "A2A RESEARCH WORKERS",
    workerPoolCopy: "Each paid slot can carry one isolated Bee without sharing a rate limit.",
    slotsBusy: "slots busy",
    copyAgent: "COPY TO AGENT",
    copiedAgent: "BOOTSTRAP COPIED",
    copyAgentTitle: "Connect an agent to TRINITY research and development.",
    copyAgentCopy:
      "Copies the public A2A bootstrap, graph endpoints, repositories, evidence skills and adaptation rules. No secret or mutation authority is included.",
    copyFailed: "COPY FAILED",
    nodeMaturity: "Repository maturity",
  },
  ru: {
    back: "TRINITY",
    eyebrow: "АВТОНОМНЫЙ НАДЗОР / PRODUCTION",
    title: "Queen превращает спецификации в проверяемую работу.",
    lede: "Один центр решений. Изолированные Bees. Каждый отказ и завершение оставляют доказательства.",
    live: "BACKEND РАБОТАЕТ",
    unavailable: "BACKEND НЕДОСТУПЕН",
    checking: "ПРОВЕРЯЮ BACKEND",
    scheduler: "Планировщик",
    every: "каждые",
    lastDecision: "Последнее решение",
    dispatches: "Завершено Bees",
    active: "Сейчас работают",
    decision: "ПОСЛЕДНЕЕ РЕШЕНИЕ QUEEN",
    chose: "Новая Bee может быть запущена.",
    stoodDown: "Bee не запущена — политика остановила делегирование.",
    noDecision: "Решений пока не записано.",
    reasons: "явных причин пропуска",
    queueMeaning:
      "Королева работает. В текущей очереди нет допустимой спецификации.",
    path: "ОТ НАМЕРЕНИЯ К ДОКАЗАТЕЛЬСТВУ",
    spec: "SPEC",
    specCopy: "Граница, сценарии, требования и критерии успеха.",
    queen: "QUEEN",
    queenCopy: "Проверяет конфликты, состояние и политику до делегирования.",
    bee: "BEE",
    beeCopy: "Работает изолированно и возвращает результат на проверку.",
    latest: "ПОСЛЕДНИЙ ЗАВЕРШЁННЫЙ DISPATCH",
    issue: "Задача",
    outcome: "Исход",
    finished: "Завершено",
    provenance: "LIVE / RAILWAY / POSTGRES / QUEEND",
    refresh: "обновление каждые 5 секунд",
    source: "Открытый operational view",
    board: "REALTIME KANBAN",
    boardTitle: "Весь рой — в одном месте.",
    boardCopy:
      "Публичные GitHub-задачи в реальных состояниях Queen. Внутренние данные остаются закрытыми.",
    kanbanView: "КАНБАН",
    mapView: "КАРТА МИССИЙ",
    factoryView: "ФАБРИКА",
    kanbanHint: "Операционные колонки",
    mapHint: "Стратегические сектора цикла",
    factoryHint: "Живое инженерное производство",
    factoryFlow: "ISSUE → SPEC → BEE → REVIEW → EVIDENCE",
    factoryThroughput: "Живая загрузка",
    factoryQueueDensity: "пик плотности очереди",
    factoryWorkerBays: "Ангары Bees",
    factoryIdle: "свободно",
    factoryStation: "станция",
    factoryModules: "модулей",
    factoryOffline: "телеметрия фабрики недоступна",
    factoryOpenIssue: "ОТКРЫТЬ РЕАЛЬНЫЙ МОДУЛЬ",
    factorySelectedModule: "ВЫБРАННЫЙ ПРОИЗВОДСТВЕННЫЙ МОДУЛЬ",
    factoryLiveContract:
      "Каждая станция, модуль и ангар Bee ниже подтверждены живым реестром Queen.",
    cityTitle: "ИССЛЕДОВАТЕЛЬСКАЯ ЦИТАДЕЛЬ",
    cityCopy:
      "Живой город собран из канонического графа технологий. Лаборатории — узлы исследований, энергомаршруты — зависимости.",
    cityDistricts: "районов исследований",
    cityLaboratories: "реальных лабораторий",
    citySelected: "ВЫБРАННАЯ ЛАБОРАТОРИЯ",
    cityEvidence: "Доказательство",
    cityOffline: "Граф исследований недоступен — город не синтезирован.",
    cityBuildTitle: "ПРОТОКОЛ СТРОИТЕЛЬСТВА",
    cityComplete: "построено",
    cityAssembling: "строится",
    cityBlueprint: "чертежи",
    citySealed: "запечатано",
    cityDependencies: "зависимостей готово",
    foundryTitle: "ПОДПИСАННАЯ FPGA-ВЕРФЬ",
    foundryVerified: "Подпись реестра проверена. Сооружения показывают только подписанные публичные факты.",
    foundryUnavailable: "Реестр оборудования недоступен — FPGA-сооружения не отображаются.",
    foundryTotal: "проверено устройств",
    foundryOnline: "онлайн сейчас",
    foundryProgrammed: "запрограммировано",
    foundryKey: "ключ подписи",
    mapLegend:
      "Маршруты показывают движение по циклу Queen; реальные зависимости есть только в Дереве технологий ниже.",
    sector: "сектор",
    rounds: "циклов / 24ч",
    beesStarted: "Bees запущено",
    verdicts: "вердиктов",
    empty: "Здесь пусто",
    criteria: "критерия",
    missing: "нужно",
    command: "ЖИВОЙ КОМАНДНЫЙ ЦЕНТР",
    commandTitle: "Королева сама ревьюит работу роя.",
    commandCopy:
      "Экран следует реальному циклу надзирателя: выбор, изолированное выполнение, саморевью, вердикт Королевы и приёмка.",
    nextRound: "следующий цикл Queen",
    reviewing: "ждут ревью Королевы",
    executing: "выполняются сейчас",
    noBees:
      "Сейчас ни одна Bee не выполняет задачу. Queen остаётся онлайн и контролирует очередь по политике.",
    reviewQueue: "очередь ревью Queen",
    activity: "ЖИВЫЕ СОБЫТИЯ BEES",
    activityRate: "пульс каждые 2 секунды",
    noActivity: "Ждём следующее записанное событие Bee.",
    synchronized: "синхронизация каждые 5 секунд",
    selfReview: "САМОРЕВЬЮ",
    selfReviewCopy:
      "Bee запускает проверки и изучает собственный diff до передачи результата.",
    verdict: "ВЕРДИКТ QUEEN",
    verdictCopy:
      "Королева судит доказательства, отклоняет слабую работу и принимает только прошедший результат.",
    merge: "ПРИЁМКА / MERGE",
    mergeCopy:
      "Одобренная работа попадает в репозиторий с полным следом доказательств.",
    tech: "ДЕРЕВО ТЕХНОЛОГИЙ",
    techTitle: "Исследования открывают следующие возможности.",
    techCopy:
      "Это существующий граф исследований TRINITY. Выберите технологию, чтобы увидеть зависимости и что она откроет дальше.",
    researched: "исследовано",
    researching: "изучается",
    available: "доступно дальше",
    locked: "заблокировано",
    prerequisites: "Зависимости",
    unlocks: "Откроет дальше",
    noPrerequisites: "Доступно с начала",
    terminalNode: "Финальная технология ветки",
    overallResearch: "исследовано всего",
    activeResearch: "активных исследований",
    nextAvailable: "доступно дальше",
    evidence: "Доказательство",
    graphLive: "ЖИВОЙ ГРАФ ДОКАЗАТЕЛЬСТВ",
    graphOffline: "ГРАФ ИССЛЕДОВАНИЙ НЕДОСТУПЕН",
    graphLoading: "Синхронизирую канонический граф TRINITY…",
    workerPool: "A2A ВОРКЕРЫ ИССЛЕДОВАНИЙ",
    workerPoolCopy:
      "Каждый оплаченный слот несёт одну изолированную Bee и не делит rate limit с соседями.",
    slotsBusy: "слотов занято",
    copyAgent: "COPY TO AGENT",
    copiedAgent: "BOOTSTRAP СКОПИРОВАН",
    copyAgentTitle: "Подключить агента к исследованиям и разработке TRINITY.",
    copyAgentCopy:
      "Копирует публичный A2A-bootstrap, адреса графа, репозитории, evidence-скиллы и правила адаптации. Секреты и права на изменения не копируются.",
    copyFailed: "НЕ УДАЛОСЬ СКОПИРОВАТЬ",
    nodeMaturity: "Зрелость в репозитории",
  },
} as const;

function useQueenStatus(): LoadState {
  const [state, setState] = useState<LoadState>({
    kind: "loading",
    data: null,
    error: null,
  });

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/status`, {
          headers: { Accept: "application/json" },
          cache: "no-store",
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = (await response.json()) as QueenStatus;
        if (active) setState({ kind: "ready", data, error: null });
      } catch (error) {
        if (!active) return;
        setState((previous) => ({
          kind: "error",
          data: previous.data,
          error: error instanceof Error ? error.message : String(error),
        }));
      }
    };

    void read();
    const timer = window.setInterval(read, LIVE_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return state;
}

function useQueenBoard(): {
  data: QueenBoard | null;
  error: string | null;
  syncedAt: Date | null;
} {
  const [data, setData] = useState<QueenBoard | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [syncedAt, setSyncedAt] = useState<Date | null>(null);

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/public-board`, {
          headers: { Accept: "application/json" },
          cache: "no-store",
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = (await response.json()) as QueenBoard;
        if (active) {
          setData(next);
          setError(null);
          setSyncedAt(new Date());
        }
      } catch (nextError) {
        if (active) {
          setError(
            nextError instanceof Error ? nextError.message : String(nextError),
          );
        }
      }
    };

    void read();
    const timer = window.setInterval(read, LIVE_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return { data, error, syncedAt };
}

function useQueenActivity(): {
  data: QueenActivity | null;
  error: string | null;
} {
  const [data, setData] = useState<QueenActivity | null>(null);
  const [error, setError] = useState<string | null>(null);
  const cursor = useRef(Date.now() - 24 * 60 * 60 * 1_000);

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const response = await fetch(
          `${QUEEN_API}/queen/public-activity?since=${cursor.current}`,
          {
            headers: { Accept: "application/json" },
            cache: "no-store",
          },
        );
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = (await response.json()) as QueenActivity;
        if (active) {
          cursor.current = next.cursor - ACTIVITY_POLL_MS;
          setData((previous) => {
            const byId = new Map(
              [...(previous?.events ?? []), ...next.events].map((event) => [
                event.id,
                event,
              ]),
            );
            return {
              cursor: next.cursor,
              events: [...byId.values()]
                .sort(
                  (left, right) =>
                    new Date(right.at).getTime() - new Date(left.at).getTime(),
                )
                .slice(0, 120),
            };
          });
          setError(null);
        }
      } catch (nextError) {
        if (active) {
          setError(
            nextError instanceof Error ? nextError.message : String(nextError),
          );
        }
      }
    };

    void read();
    const timer = window.setInterval(read, ACTIVITY_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return { data, error };
}

function useQueenResearch(): {
  data: ResearchGraph | null;
  error: string | null;
} {
  const [data, setData] = useState<ResearchGraph | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/public-research`, {
          headers: { Accept: "application/json" },
          cache: "no-store",
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = (await response.json()) as ResearchGraph;
        if (active) {
          setData(next);
          setError(null);
        }
      } catch (nextError) {
        if (active) {
          setError(
            nextError instanceof Error ? nextError.message : String(nextError),
          );
        }
      }
    };

    void read();
    const timer = window.setInterval(read, LIVE_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return { data, error };
}

function useQueenHardware(): {
  data: VerifiedHardwareRegistry | null;
  error: string | null;
} {
  const [data, setData] = useState<VerifiedHardwareRegistry | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const response = await fetch(`${QUEEN_API}/queen/public-hardware`, {
          headers: { Accept: "application/json" },
          cache: "no-store",
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const envelope: unknown = await response.json();
        const verified = await verifyHardwareEnvelope(
          envelope,
          PINNED_QUEEN_HARDWARE_PUBLIC_KEY,
        );
        if (!verified) throw new Error("hardware signature verification failed");
        if (active) {
          setData(verified);
          setError(null);
        }
      } catch (nextError) {
        if (active) {
          setData(null);
          setError(
            nextError instanceof Error ? nextError.message : String(nextError),
          );
        }
      }
    };

    void read();
    const timer = window.setInterval(read, LIVE_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return { data, error };
}

function useNow() {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => window.clearInterval(timer);
  }, []);

  return now;
}

function formatInterval(seconds: number, lang: string) {
  if (seconds > 0 && seconds % 60 === 0) {
    const minutes = seconds / 60;
    return lang === "ru" ? `${minutes} мин` : `${minutes} min`;
  }
  return lang === "ru" ? `${seconds} сек` : `${seconds} sec`;
}

function formatMoment(value: string | null | undefined, lang: string) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(lang === "ru" ? "ru-RU" : "en-GB", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZoneName: "short",
  }).format(date);
}

function formatCountdown(seconds: number) {
  const safe = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  const remainder = safe % 60;
  return [hours, minutes, remainder]
    .map((value) => String(value).padStart(2, "0"))
    .join(":");
}

function activityLabel(event: QueenActivityEvent, lang: string) {
  const labels =
    lang === "ru"
      ? {
          dispatch: "Queen делегировала",
          progress: "Bee сообщает прогресс",
          tool: "Bee использует инструмент",
          result: "Bee получила результат",
          usage: "Bee обновила метрики",
          error: "Bee встретила ошибку",
          finished: "Bee завершила работу",
          review: "Queen вынесла вердикт",
        }
      : {
          dispatch: "Queen delegated",
          progress: "Bee reported progress",
          tool: "Bee used a tool",
          result: "Bee received a result",
          usage: "Bee updated metrics",
          error: "Bee hit an error",
          finished: "Bee finished work",
          review: "Queen issued a verdict",
        };
  return labels[event.kind] ?? labels.progress;
}

const LAYER_DESIGN: Record<string, { color: string; icon: string }> = {
  seed: { color: "#00ff88", icon: "◆" },
  ring: { color: "#7dffbf", icon: "◎" },
  silicon: { color: "#ffd700", icon: "▰" },
  runtime: { color: "#29d7ff", icon: "◈" },
  supervisor: { color: "#ff4fb8", icon: "♛" },
  interface: { color: "#b69cff", icon: "▦" },
};

function fallbackBootstrap(): ResearchGraph["agentBootstrap"] {
  return {
    version: "trinity-research-a2a/v1",
    mode: "public-read-only",
    protocol: "A2A",
    endpoints: {
      research: `${QUEEN_API}/queen/public-research`,
      board: `${QUEEN_API}/queen/public-board`,
      activity: `${QUEEN_API}/queen/public-activity`,
    },
    repositories: [
      "https://github.com/gHashTag/trinity",
      "https://github.com/gHashTag/BrowserOS/tree/feat/queen-supervisor/trios",
    ],
    skills: [
      "spec-first acceptance criteria",
      "OBSERVED / CLAIM / INFERENCE / TARGET / UNKNOWN evidence labels",
      "dependency-aware research",
      "adversarial review",
      "append-only experience and checkpoints",
    ],
    adaptation: {
      read: ["research graph", "public board", "public activity"],
      write:
        "Use a scoped repository issue or authenticated A2A session. Public endpoints grant no mutation authority.",
    },
  };
}

function agentBootstrapText(
  bootstrap: ResearchGraph["agentBootstrap"],
  lang: string,
) {
  const mission =
    lang === "ru"
      ? "Подключись к исследованиям и разработке TRINITY. Сначала прочитай граф зависимостей, выбери только доступный узел, зафиксируй проверяемый контракт, работай в изоляции и верни доказательства для adversarial review. Не считай публичный read-only доступ правом на изменения."
      : "Join TRINITY research and development. Read the dependency graph first, choose only an available node, write an observable contract, work in isolation, and return evidence for adversarial review. Public read-only access is never mutation authority.";
  return [
    "# TRINITY RESEARCH · A2A BOOTSTRAP",
    mission,
    "",
    JSON.stringify(bootstrap, null, 2),
  ].join("\n");
}

async function copyToClipboard(value: string) {
  // Prefer the synchronous user-gesture path. Some embedded browsers expose
  // navigator.clipboard but leave writeText pending behind a permission bridge,
  // which made a very visible button appear to do nothing forever.
  const area = document.createElement("textarea");
  area.value = value;
  area.style.position = "fixed";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.select();
  const copied = document.execCommand("copy");
  area.remove();
  if (copied) return;
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }
  throw new Error("Clipboard is unavailable");
}

function TechnologyTree({
  c,
  graph,
  error,
  lang,
}: {
  c: (typeof COPY)["ru"] | (typeof COPY)["en"];
  graph: ResearchGraph | null;
  error: string | null;
  lang: string;
}) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [copyState, setCopyState] = useState<"idle" | "copied" | "error">(
    "idle",
  );
  const nodesById = useMemo(
    () => new Map((graph?.nodes ?? []).map((node) => [node.id, node])),
    [graph],
  );
  const selected =
    (selectedId ? nodesById.get(selectedId) : undefined) ??
    graph?.nodes.find((node) => node.state === "researching") ??
    graph?.nodes.find((node) => node.state === "available") ??
    graph?.nodes[0] ??
    null;
  const stateLabel = {
    researched: c.researched,
    researching: c.researching,
    available: c.available,
    locked: c.locked,
  } satisfies Record<ResearchState, string>;

  const geometry = useMemo(() => {
    if (!graph) return null;
    const nodeWidth = 210;
    const nodeHeight = 100;
    const gapX = 92;
    const gapY = 28;
    const padX = 52;
    const padY = 82;
    const grouped = new Map(
      graph.layers.map((layer) => [
        layer,
        graph.nodes.filter((node) => node.layer === layer),
      ]),
    );
    const maxInLayer = Math.max(
      1,
      ...[...grouped.values()].map((nodes) => nodes.length),
    );
    const width =
      padX * 2 + graph.layers.length * nodeWidth + (graph.layers.length - 1) * gapX;
    const height = padY * 2 + maxInLayer * nodeHeight + (maxInLayer - 1) * gapY;
    const positions = new Map<string, { x: number; y: number }>();
    graph.layers.forEach((layer, layerIndex) => {
      const layerNodes = grouped.get(layer) ?? [];
      const offsetY = ((maxInLayer - layerNodes.length) * (nodeHeight + gapY)) / 2;
      layerNodes.forEach((node, nodeIndex) => {
        positions.set(node.id, {
          x: padX + layerIndex * (nodeWidth + gapX),
          y: padY + offsetY + nodeIndex * (nodeHeight + gapY),
        });
      });
    });
    return { nodeWidth, nodeHeight, width, height, positions };
  }, [graph]);

  const bootstrap = graph?.agentBootstrap ?? fallbackBootstrap();
  const copyBootstrap = async () => {
    try {
      await copyToClipboard(agentBootstrapText(bootstrap, lang));
      setCopyState("copied");
      window.setTimeout(() => setCopyState("idle"), 2_500);
    } catch {
      setCopyState("error");
    }
  };

  const prerequisiteNames =
    selected?.prerequisites.map((id) => nodesById.get(id)?.label ?? id) ?? [];
  const unlockNames =
    selected?.unlocks.map((id) => nodesById.get(id)?.label ?? id) ?? [];

  return (
    <section className="queen27-tech" aria-labelledby="queen-tech-title">
      <div className="queen27-tech-head">
        <div>
          <span className="queen27-section-label" id="queen-tech-title">
            {c.tech}
          </span>
          <h2>{c.techTitle}</h2>
          <p>{c.techCopy}</p>
        </div>
        <div className="queen27-tech-score" aria-label={c.overallResearch}>
          <strong>{graph ? `${graph.summary.percentage}%` : "—"}</strong>
          <span>{c.overallResearch}</span>
        </div>
      </div>

      <div className="queen27-agent-connect">
        <div>
          <span>A2A / SKILLS / ADAPTATION</span>
          <h3>{c.copyAgentTitle}</h3>
          <p>{c.copyAgentCopy}</p>
        </div>
        <button type="button" onClick={copyBootstrap}>
          <i aria-hidden="true">⌘</i>
          <strong>
            {copyState === "copied"
              ? c.copiedAgent
              : copyState === "error"
                ? c.copyFailed
                : c.copyAgent}
          </strong>
          <small>{bootstrap.protocol} · {bootstrap.version}</small>
        </button>
      </div>

      <div className="queen27-tech-stats">
        <span>
          <b>{graph?.summary.researched ?? "—"}</b> {c.researched}
        </span>
        <span>
          <b>{graph?.summary.researching ?? "—"}</b> {c.activeResearch}
        </span>
        <span>
          <b>{graph?.summary.available ?? "—"}</b> {c.nextAvailable}
        </span>
      </div>

      <div className="queen27-worker-pool">
        <div>
          <span>{c.workerPool}</span>
          <strong>
            {graph ? `${graph.workers.active}/${graph.workers.capacity}` : "—"}
          </strong>
          <small>{c.slotsBusy}</small>
        </div>
        <p>{c.workerPoolCopy}</p>
        <div className="queen27-worker-slots">
          {(graph?.workers.slots ?? []).map((slot) => (
            <span className={`is-${slot.state}`} key={slot.slot}>
              <i /> SLOT {String(slot.slot).padStart(2, "0")}
            </span>
          ))}
        </div>
      </div>

      <div className="queen27-tech-console">
        <div
          className="queen27-tech-map"
          role="region"
          aria-label={c.tech}
          tabIndex={0}
        >
          {!graph || !geometry ? (
            <div className="queen27-tech-loading">
              <i />
              <strong>{error ? c.graphOffline : c.graphLoading}</strong>
              {error && <small>{error}</small>}
            </div>
          ) : (
            <div
              className="queen27-tech-canvas"
              style={{ width: geometry.width, height: geometry.height }}
            >
              {graph.layers.map((layer) => {
                const layerIndex = graph.layers.indexOf(layer);
                const design = LAYER_DESIGN[layer] ?? {
                  color: "#ffffff",
                  icon: "◇",
                };
                return (
                  <div
                    className="queen27-tech-layer"
                    key={layer}
                    style={{
                      left: 52 + layerIndex * (geometry.nodeWidth + 92),
                      width: geometry.nodeWidth,
                      "--tech-color": design.color,
                    } as CSSProperties}
                  >
                    <span aria-hidden="true">{design.icon}</span>
                    <b>{layer}</b>
                  </div>
                );
              })}
              <svg
                className="queen27-tech-edges"
                width={geometry.width}
                height={geometry.height}
                aria-hidden="true"
              >
                {graph.edges.map((edge) => {
                  const from = geometry.positions.get(edge.from);
                  const to = geometry.positions.get(edge.to);
                  const fromNode = nodesById.get(edge.from);
                  if (!from || !to || !fromNode) return null;
                  const x1 = from.x + geometry.nodeWidth;
                  const y1 = from.y + geometry.nodeHeight / 2;
                  const x2 = to.x;
                  const y2 = to.y + geometry.nodeHeight / 2;
                  const bend = Math.max(32, Math.abs(x2 - x1) * 0.45);
                  const reverse = x2 <= x1;
                  const d = reverse
                    ? `M ${x1} ${y1} C ${x1 + 28} ${y1}, ${x2 - 28} ${y2}, ${x2} ${y2}`
                    : `M ${x1} ${y1} C ${x1 + bend} ${y1}, ${x2 - bend} ${y2}, ${x2} ${y2}`;
                  return (
                    <path
                      d={d}
                      key={`${edge.from}-${edge.to}`}
                      className={
                        fromNode.state === "researched" ? "is-open" : ""
                      }
                    />
                  );
                })}
              </svg>
              {graph.nodes.map((node) => {
                const position = geometry.positions.get(node.id);
                if (!position) return null;
                const design = LAYER_DESIGN[node.layer] ?? {
                  color: "#ffffff",
                  icon: "◇",
                };
                const isSelected = selected?.id === node.id;
                return (
                  <motion.button
                    type="button"
                    className={`queen27-tech-node is-${node.state}${isSelected ? " is-selected" : ""}`}
                    key={node.id}
                    onClick={() => setSelectedId(node.id)}
                    whileHover={{ y: -3 }}
                    whileTap={{ scale: 0.98 }}
                    aria-pressed={isSelected}
                    style={{
                      left: position.x,
                      top: position.y,
                      width: geometry.nodeWidth,
                      height: geometry.nodeHeight,
                      "--tech-color": design.color,
                    } as CSSProperties}
                  >
                    <small>{stateLabel[node.state]}</small>
                    <strong>{node.label}</strong>
                    <span>{node.id}</span>
                  </motion.button>
                );
              })}
            </div>
          )}
        </div>

        {selected ? (
          <motion.aside
            className={`queen27-tech-details is-${selected.state}`}
            key={selected.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
          >
            <span>{stateLabel[selected.state]}</span>
            <h3>{selected.label}</h3>
            {selected.note && <p>{selected.note}</p>}
            <dl>
              <div>
                <dt>{c.evidence}</dt>
                <dd className="queen27-tech-evidence">{selected.evidence}</dd>
              </div>
              <div>
                <dt>{c.prerequisites}</dt>
                <dd>
                  {prerequisiteNames.length > 0
                    ? prerequisiteNames.join(" · ")
                    : c.noPrerequisites}
                </dd>
              </div>
              <div>
                <dt>{c.unlocks}</dt>
                <dd>
                  {unlockNames.length > 0
                    ? unlockNames.join(" · ")
                    : c.terminalNode}
                </dd>
              </div>
              <div>
                <dt>{c.nodeMaturity}</dt>
                <dd>{selected.maturity}</dd>
              </div>
              {selected.blockedBy && (
                <div>
                  <dt>{c.locked}</dt>
                  <dd>{selected.blockedBy}</dd>
                </div>
              )}
            </dl>
          </motion.aside>
        ) : (
          <aside className="queen27-tech-details">
            <span>{error ? c.graphOffline : c.graphLoading}</span>
          </aside>
        )}
      </div>
    </section>
  );
}

function Metric({
  label,
  value,
  note,
}: {
  label: string;
  value: string | number;
  note?: string;
}) {
  return (
    <article className="queen27-metric">
      <span>{label}</span>
      <strong>{value}</strong>
      {note && <small>{note}</small>}
    </article>
  );
}

export default function Queen() {
  const { lang } = useI18n();
  const c = lang === "ru" ? COPY.ru : COPY.en;
  const state = useQueenStatus();
  const boardState = useQueenBoard();
  const activityState = useQueenActivity();
  const researchState = useQueenResearch();
  const hardwareState = useQueenHardware();
  const [boardView, setBoardView] = useState<
    "kanban" | "map" | "factory"
  >("kanban");
  const now = useNow();
  const data = state.data;
  const isLive = state.kind === "ready";
  const latest = data?.dispatches.latest;
  const decision = data?.lastTick;
  const runningCards =
    boardState.data?.cards.filter((card) => card.column === "running") ?? [];
  const reviewCards =
    boardState.data?.cards.filter((card) => card.column === "review") ?? [];
  const roundSeconds =
    boardState.data?.pulse.roundSeconds ?? data?.scheduler.intervalSeconds ?? 0;
  const lastRoundAt =
    boardState.data?.pulse.lastRoundAt ?? decision?.decidedAt ?? null;
  const elapsedSeconds = lastRoundAt
    ? Math.max(0, (now - new Date(lastRoundAt).getTime()) / 1000)
    : 0;
  const roundRemaining = roundSeconds
    ? Math.max(0, roundSeconds - elapsedSeconds)
    : 0;
  const roundProgress = roundSeconds
    ? Math.min(100, (elapsedSeconds / roundSeconds) * 100)
    : 0;
  const syncLabel = boardState.syncedAt
    ? boardState.syncedAt.toLocaleTimeString(lang === "ru" ? "ru-RU" : "en-GB")
    : "—";
  const boardColumns = boardState.data?.columns ?? FALLBACK_COLUMNS;

  return (
    <main className="queen27-page">
      <nav className="queen27-nav" aria-label="Queen page navigation">
        <Link to="/" className="queen27-brand">
          {c.back}
        </Link>
        <span className="queen27-formula">φ² + 1/φ² = 3</span>
      </nav>

      <header className="queen27-hero">
        <div className="queen27-kicker">{c.eyebrow}</div>
        <div className="queen27-hero-grid">
          <div>
            <h1>{c.title}</h1>
            <p>{c.lede}</p>
          </div>
          <div className="queen27-logo">
            <TrinityLogo withLabel={false} height="clamp(180px, 24vw, 300px)" />
          </div>
        </div>
        <div
          className={`queen27-live ${isLive ? "is-live" : state.kind === "error" ? "is-error" : ""}`}
        >
          <span className="queen27-live-dot" />
          <strong>
            {isLive
              ? c.live
              : state.kind === "error"
                ? c.unavailable
                : c.checking}
          </strong>
          <span>{c.provenance}</span>
        </div>
      </header>

      <section className="queen27-metrics" aria-label="Queen runtime metrics">
        <Metric
          label={c.scheduler}
          value={
            data?.scheduler.enabled
              ? "ON"
              : state.kind === "loading"
                ? "…"
                : "OFF"
          }
          note={
            data
              ? `${c.every} ${formatInterval(data.scheduler.intervalSeconds, lang)}`
              : undefined
          }
        />
        <Metric
          label={c.lastDecision}
          value={formatMoment(decision?.decidedAt, lang)}
        />
        <Metric
          label={c.dispatches}
          value={
            data ? `${data.dispatches.finished}/${data.dispatches.total}` : "—"
          }
        />
        <Metric label={c.active} value={data?.dispatches.running ?? "—"} />
      </section>

      <section
        className="queen27-command"
        aria-labelledby="queen-command-title"
      >
        <div className="queen27-command-head">
          <span className="queen27-section-label" id="queen-command-title">
            {c.command}
          </span>
          <h2>{c.commandTitle}</h2>
          <p>{c.commandCopy}</p>
        </div>

        <div className="queen27-command-grid">
          <article className="queen27-queen-core">
            <div className="queen27-core-orbit" aria-hidden="true">
              <span
                data-role="orbit"
                className="queen27-cycle-ring queen27-cycle-ring-outer"
              />
              <span
                data-role="orbit"
                className="queen27-cycle-ring queen27-cycle-ring-dashed"
              />
              <span
                data-role="orbit"
                className="queen27-cycle-ring queen27-cycle-ring-inner"
              />
              <div className="queen27-cycle-brand">
                <TrinityLogo withLabel={false} height="72px" />
              </div>
            </div>
            <div>
              <span>{c.nextRound}</span>
              <strong>{formatCountdown(roundRemaining)}</strong>
              <small>
                {c.synchronized} · {syncLabel}
              </small>
            </div>
            <i aria-hidden="true">
              <span style={{ width: `${roundProgress}%` }} />
            </i>
          </article>

          <article className="queen27-swarm-live">
            <header>
              <span>
                <b>{runningCards.length}</b> {c.executing}
              </span>
              <span>
                <b>{reviewCards.length}</b> {c.reviewing}
              </span>
            </header>
            {runningCards.length > 0 ? (
              <div className="queen27-bee-list">
                {runningCards.slice(0, 4).map((card) => (
                  <a
                    href={`https://github.com/${boardState.data?.repo}/issues/${card.number}`}
                    target="_blank"
                    rel="noreferrer"
                    key={card.number}
                  >
                    <i aria-hidden="true">◆</i>
                    <span>Bee #{card.number}</span>
                    <strong>{card.title}</strong>
                  </a>
                ))}
              </div>
            ) : (
              <p>{c.noBees}</p>
            )}
            <div className="queen27-review-queue">
              <small>{c.reviewQueue}</small>
              {reviewCards.slice(0, 3).map((card, index) => (
                <a
                  href={`https://github.com/${boardState.data?.repo}/issues/${card.number}`}
                  target="_blank"
                  rel="noreferrer"
                  key={card.number}
                >
                  <span>{String(index + 1).padStart(2, "0")}</span>
                  <b>#{card.number}</b>
                  <strong>{card.title}</strong>
                </a>
              ))}
            </div>
            <div className="queen27-activity-stream">
              <div>
                <small>{c.activity}</small>
                <span className={activityState.error ? "is-offline" : ""}>
                  {c.activityRate}
                </span>
              </div>
              {activityState.data?.events.length ? (
                <motion.ol layout>
                  {activityState.data.events.slice(0, 6).map((event) => (
                    <motion.li
                      layout
                      initial={{ opacity: 0, x: 12 }}
                      animate={{ opacity: 1, x: 0 }}
                      key={event.id}
                    >
                      <time dateTime={event.at}>
                        {new Date(event.at).toLocaleTimeString(
                          lang === "ru" ? "ru-RU" : "en-GB",
                          {
                            hour: "2-digit",
                            minute: "2-digit",
                            second: "2-digit",
                          },
                        )}
                      </time>
                      <i className={`is-${event.kind}`} aria-hidden="true" />
                      <span>
                        <b>
                          {activityLabel(event, lang)}
                          {event.issue ? ` · #${event.issue}` : ""}
                        </b>
                        <strong>{event.title}</strong>
                      </span>
                    </motion.li>
                  ))}
                </motion.ol>
              ) : (
                <p>{c.noActivity}</p>
              )}
            </div>
          </article>
        </div>
      </section>

      <section className="queen27-board" aria-labelledby="queen-board-title">
        <div className="queen27-board-head">
          <div>
            <span className="queen27-section-label" id="queen-board-title">
              {c.board}
            </span>
            <h2>{c.boardTitle}</h2>
            <p>{c.boardCopy}</p>
          </div>
          <div
            className="queen27-board-pulse"
            aria-label="Queen activity in the last 24 hours"
          >
            <span>
              <b>{boardState.data?.pulse.rounds ?? "—"}</b>
              {c.rounds}
            </span>
            <span>
              <b>{boardState.data?.pulse.bees ?? "—"}</b>
              {c.beesStarted}
            </span>
            <span>
              <b>{boardState.data?.pulse.verdicts ?? "—"}</b>
              {c.verdicts}
            </span>
          </div>
        </div>
        <div className="queen27-view-switch" role="group" aria-label={c.board}>
          <button
            type="button"
            className={boardView === "kanban" ? "is-active" : ""}
            aria-pressed={boardView === "kanban"}
            onClick={() => setBoardView("kanban")}
          >
            <i aria-hidden="true">▦</i>
            <span>
              <b>{c.kanbanView}</b>
              <small>{c.kanbanHint}</small>
            </span>
          </button>
          <button
            type="button"
            className={boardView === "map" ? "is-active" : ""}
            aria-pressed={boardView === "map"}
            onClick={() => setBoardView("map")}
          >
            <i aria-hidden="true">⌘</i>
            <span>
              <b>{c.mapView}</b>
              <small>{c.mapHint}</small>
            </span>
          </button>
          <button
            type="button"
            className={boardView === "factory" ? "is-active" : ""}
            aria-pressed={boardView === "factory"}
            onClick={() => setBoardView("factory")}
          >
            <i aria-hidden="true">⚙</i>
            <span>
              <b>{c.factoryView}</b>
              <small>{c.factoryHint}</small>
            </span>
          </button>
        </div>

        {boardView === "kanban" ? (
          <motion.div
            className="queen27-kanban"
            role="region"
            aria-label={c.kanbanView}
            tabIndex={0}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
          >
            {boardColumns.map((column) => {
              const cards =
                boardState.data?.cards.filter(
                  (card) => card.column === column.key,
                ) ?? [];
              return (
                <motion.article
                  className={`queen27-column is-${column.key}`}
                  key={column.key}
                  layout
                >
                  <header>
                    <h3>{column.title}</h3>
                    <span>{cards.length}</span>
                  </header>
                  <small>{column.blurb}</small>
                  <div className="queen27-cards">
                    {cards.map((card) => (
                      <motion.a
                        className="queen27-card"
                        href={`https://github.com/${boardState.data?.repo}/issues/${card.number}`}
                        target="_blank"
                        rel="noreferrer"
                        key={card.number}
                        layout
                        layoutId={`queen-card-${card.number}`}
                        transition={{
                          type: "spring",
                          stiffness: 320,
                          damping: 30,
                        }}
                      >
                        <div className="queen27-card-topline">
                          <b>#{card.number}</b>
                          {(column.key === "running" ||
                            column.key === "review") && (
                            <span className="queen27-card-signal">
                              <i />
                              {column.key === "running"
                                ? c.executing
                                : c.reviewing}
                            </span>
                          )}
                        </div>
                        <strong>{card.title}</strong>
                        {typeof card.criteria === "number" && (
                          <span>
                            {card.criteria} {c.criteria}
                          </span>
                        )}
                        {card.needs && card.needs.length > 0 && (
                          <span>
                            {c.missing}: {card.needs.join(", ")}
                          </span>
                        )}
                      </motion.a>
                    ))}
                    {cards.length === 0 && (
                      <em>{boardState.error ?? c.empty}</em>
                    )}
                  </div>
                </motion.article>
              );
            })}
          </motion.div>
        ) : boardView === "map" ? (
          <motion.div
            className="queen27-mission-map"
            role="region"
            aria-label={c.mapView}
            tabIndex={0}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
          >
            <div className="queen27-map-stars" aria-hidden="true" />
            <div className="queen27-map-route" aria-hidden="true" />
            <div className="queen27-map-sectors">
              {boardColumns.map((column, sectorIndex) => {
                const cards =
                  boardState.data?.cards.filter(
                    (card) => card.column === column.key,
                  ) ?? [];
                return (
                  <motion.section
                    className={`queen27-map-sector is-${column.key}`}
                    key={column.key}
                    layout
                  >
                    <header>
                      <small>
                        {c.sector} {String(sectorIndex + 1).padStart(2, "0")}
                      </small>
                      <h3>{column.title}</h3>
                      <b>{cards.length}</b>
                    </header>
                    <div className="queen27-map-nodes">
                      {cards.map((card, cardIndex) => (
                        <motion.a
                          href={`https://github.com/${boardState.data?.repo}/issues/${card.number}`}
                          target="_blank"
                          rel="noreferrer"
                          key={card.number}
                          layout
                          initial={{ opacity: 0, scale: 0.8 }}
                          animate={{ opacity: 1, scale: 1 }}
                          transition={{
                            delay: Math.min(cardIndex * 0.025, 0.3),
                          }}
                          title={card.title}
                        >
                          <i aria-hidden="true" />
                          <span>#{card.number}</span>
                          <strong>{card.title}</strong>
                          {typeof card.criteria === "number" && (
                            <small>{card.criteria} CR</small>
                          )}
                        </motion.a>
                      ))}
                      {cards.length === 0 && (
                        <em>{boardState.error ?? c.empty}</em>
                      )}
                    </div>
                  </motion.section>
                );
              })}
            </div>
            <p>{c.mapLegend}</p>
          </motion.div>
        ) : (
          <QueenFactory
            columns={boardColumns}
            cards={boardState.data?.cards ?? []}
            repo={boardState.data?.repo ?? null}
            workers={researchState.data?.workers ?? null}
            researchNodes={researchState.data?.nodes ?? []}
            researchEdges={researchState.data?.edges ?? []}
            researchLayers={researchState.data?.layers ?? []}
            researchError={researchState.error}
            hardware={hardwareState.data}
            hardwareError={hardwareState.error}
            error={boardState.error ?? researchState.error}
            labels={{
              aria: c.factoryView,
              flow: c.factoryFlow,
              throughput: c.factoryThroughput,
              queueDensity: c.factoryQueueDensity,
              workerBays: c.factoryWorkerBays,
              active: c.executing,
              idle: c.factoryIdle,
              station: c.factoryStation,
              modules: c.factoryModules,
              empty: c.empty,
              offline: c.factoryOffline,
              criteria: c.criteria,
              missing: c.missing,
              openIssue: c.factoryOpenIssue,
              selectedModule: c.factorySelectedModule,
              liveContract: c.factoryLiveContract,
              cityTitle: c.cityTitle,
              cityCopy: c.cityCopy,
              cityDistricts: c.cityDistricts,
              cityLaboratories: c.cityLaboratories,
              citySelected: c.citySelected,
              cityEvidence: c.cityEvidence,
              cityOffline: c.cityOffline,
              cityBuildTitle: c.cityBuildTitle,
              cityComplete: c.cityComplete,
              cityAssembling: c.cityAssembling,
              cityBlueprint: c.cityBlueprint,
              citySealed: c.citySealed,
              cityDependencies: c.cityDependencies,
              foundryTitle: c.foundryTitle,
              foundryVerified: c.foundryVerified,
              foundryUnavailable: c.foundryUnavailable,
              foundryTotal: c.foundryTotal,
              foundryOnline: c.foundryOnline,
              foundryProgrammed: c.foundryProgrammed,
              foundryKey: c.foundryKey,
            }}
          />
        )}
      </section>

      <section
        className="queen27-decision"
        aria-labelledby="queen-decision-title"
      >
        <div>
          <span className="queen27-section-label" id="queen-decision-title">
            {c.decision}
          </span>
          <h2>
            {decision
              ? decision.allowed
                ? c.chose
                : c.stoodDown
              : c.noDecision}
          </h2>
          {decision && (
            <p>
              {decision.refusal ?? c.queueMeaning} · {decision.skippedCount}{" "}
              {c.reasons}.
            </p>
          )}
        </div>
        <div
          className="queen27-verdict"
          aria-label={decision?.allowed ? "allowed" : "stood down"}
        >
          <span>{decision?.allowed ? "1" : "0"}</span>
          <small>{decision?.allowed ? "ALLOW" : "REFUSE"}</small>
        </div>
      </section>

      <section className="queen27-flow" aria-labelledby="queen-flow-title">
        <span className="queen27-section-label" id="queen-flow-title">
          {c.path}
        </span>
        <div className="queen27-flow-grid">
          <article>
            <b>01</b>
            <h3>{c.spec}</h3>
            <p>{c.specCopy}</p>
          </article>
          <article className="is-queen">
            <b>02</b>
            <h3>{c.queen}</h3>
            <p>{c.queenCopy}</p>
          </article>
          <article>
            <b>03</b>
            <h3>{c.bee}</h3>
            <p>{c.beeCopy}</p>
          </article>
          <article className="is-active">
            <b>04</b>
            <h3>{c.selfReview}</h3>
            <p>{c.selfReviewCopy}</p>
          </article>
          <article className="is-queen">
            <b>05</b>
            <h3>{c.verdict}</h3>
            <p>{c.verdictCopy}</p>
          </article>
          <article>
            <b>06</b>
            <h3>{c.merge}</h3>
            <p>{c.mergeCopy}</p>
          </article>
        </div>
      </section>

      <TechnologyTree
        c={c}
        graph={researchState.data}
        error={researchState.error}
        lang={lang}
      />

      <section className="queen27-latest" aria-labelledby="queen-latest-title">
        <span className="queen27-section-label" id="queen-latest-title">
          {c.latest}
        </span>
        {latest ? (
          <div className="queen27-latest-grid">
            <Metric label={c.issue} value={`#${latest.issue}`} />
            <Metric
              label={c.outcome}
              value={(latest.outcome ?? "—").toUpperCase()}
            />
            <Metric
              label={c.finished}
              value={formatMoment(latest.finishedAt, lang)}
            />
          </div>
        ) : (
          <p>—</p>
        )}
      </section>

      <footer className="queen27-footer">
        <span>{c.source}</span>
        <span>{state.kind === "error" ? state.error : c.refresh}</span>
      </footer>
    </main>
  );
}
