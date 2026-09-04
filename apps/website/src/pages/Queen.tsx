import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type CSSProperties,
  type RefObject,
} from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { QueenComb, queenIndexOf, summariseCells } from "../components/QueenComb";
import { QueenCommandPanel } from "../components/QueenCommand";
import { QueenContext } from "../components/QueenContext";
import { QueenFactory } from "../components/QueenFactory";
import { QueenIntelFeed, QueenSectors } from "../components/QueenIntel";
import { QueenMinimap } from "../components/QueenMinimap";
import {
  ALERT_WINDOW_MS,
  HUD_VIEWS,
  alertCount,
  decisionDetail,
  rewriteEndpoints,
  roundStrip,
  skipReasonWords,
  isAlertKind,
  latestEventFor,
  sectorRows,
  type CombHandle,
  type HudEvent,
  type HudPick,
  type HudView,
  fieldShape,
  placeCards,
} from "../components/queenHud";
import {
  verifyHardwareEnvelope,
  type VerifiedHardwareRegistry,
} from "../components/queenHardwareRegistry";
import { TrinityLogo } from "../components/TrinityLogo";
import { useI18n } from "../i18n/context";
import {
  REVIEW_STATES,
  publicIssueTitle,
  publicResearchText,
  reviewCounts,
  reviewStateOf,
  reviewUnclassified,
  type QueenReviewState,
} from "./queenReviewLifecycle";

// A review card names its queue only when the wire stated one; an absent
// field is a dash, never a label (P0-8).
function reviewSignalLabel(
  state: QueenReviewState | null,
  copy: Record<QueenReviewState, string>,
): string {
  return state ? copy[state] : "—";
}
import "./Queen.css";

const DEFAULT_QUEEN_API =
  "https://trios-agent-server-production.up.railway.app";
const QUEEN_API = (
  (import.meta.env.VITE_QUEEN_API as string | undefined) ?? DEFAULT_QUEEN_API
).replace(/\/+$/, "");
const LIVE_POLL_MS = 5_000;
const ACTIVITY_POLL_MS = 2_000;
const PINNED_QUEEN_HARDWARE_PUBLIC_KEY =
  "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA5+HsGhhkVkICuwo5Qa2pWhfVhT3/wLOLWutK4VKYulw=\n-----END PUBLIC KEY-----\n";

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
    skipSummary?: Record<string, number>;
  } | null;
  dispatches: {
    total: number;
    finished: number;
    running: number;
    unreviewed?: number;
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
    reviewState?: QueenReviewState;
  }>;
  reviewQueues?: Record<QueenReviewState, number>;
  pulse: {
    rounds: number;
    bees: number;
    verdicts: number;
    lastRoundAt: string | null;
    roundSeconds: number | null;
  };
}

type QueenCard = QueenBoard["cards"][number];
type QueenColumn = QueenBoard["columns"][number];

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

/** The activity hook's state: the wire's newest events, plus the alert-kind
 *  events kept for the bell - evicted by age, not by count. */
interface ActivityBuffer extends QueenActivity {
  alerts: QueenActivityEvent[];
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
    latest: "LATEST DISPATCH",
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
    combView: "COMB",
    combHint: "The board as a field of marks",
    combHeld: "held",
    combNeutral: "neutral",
    combFog: "fog",
    combBees: "bees",
    combQueen: "THE QUEEN",
    combQueenCell: "centre cell",
    combNoBee: "no bee here",
    combPick: "Click a cell. A bee on it, or the Queen's own cell, shows a portrait; every cell is one card of the board.",
    combHint2: "drag to orbit · wheel to zoom · click a cell",
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
    beesStarted: "Bees started / 24h",
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
    queenReviewPending: "Queen review pending",
    changesRequested: "Changes requested",
    humanEscalation: "Human escalation",
    reconciliationAnomaly: "Ledger anomaly",
    hudReviewUnclassified: "no state on the wire",
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
    // ---- single-screen HUD ----
    hudBrand: "TRINITY QUEEN",
    hudBees: "BEES",
    hudDone: "DONE",
    hudVerdicts: "VERDICTS",
    hud24h: "24h",
    hudResearch: "RESEARCH",
    hudFoundry: "FOUNDRY",
    hudNextRound: "NEXT ROUND",
    hudAlerts: "ALERTS",
    hudMenu: "MENU",
    hudLanguage: "EN / RU",
    hudViews: "VIEWS",
    hudIntel: "INTEL FEED",
    hudLive: "LIVE",
    hudOffline: "OFFLINE",
    hudViewAll: "VIEW ALL",
    hudCollapseFeed: "COLLAPSE",
    hudOverview: "OVERVIEW",
    hudSectors: "SECTORS",
    hudContext: "CONTEXT DETAILS",
    hudQueue: "BEE QUEUE",
    hudQueueEmpty: "No Bee is running. The Queen holds the queue under policy.",
    hudReviewQueue: "REVIEW QUEUE",
    hudLast: "LAST",
    hudSelected: "SELECTED",
    hudTheQueen: "THE QUEEN",
    hudQueenRole: "Supervisor. Chooses, delegates, judges.",
    hudBackend: "BACKEND",
    hudTerritory: "TERRITORY",
    hudNeeds: "NEEDS",
    hudNoBee: "NO BEE",
    hudSlot: "SLOT",
    hudBusy: "BUSY",
    hudCell: "CELL",
    hudAllow: "ALLOW",
    hudRefuse: "REFUSE",
    hudSchedulerOff: "SCHEDULER OFF",
    hudOverdue: "OVERDUE",
    hudDispatched: "dispatched",
    hudOpenIssue: "OPEN ISSUE",
    hudCopyLink: "COPY LINK",
    hudLinkCopied: "LINK COPIED",
    hudClose: "Close",
    hudOpenPanel: "CONTEXT",
    hudActiveSector: "ACTIVE SECTOR",
    hudProduction: "PRODUCTION",
    hudCards: "CARDS",
    hudHeld: "HELD",
    hudSlots: "SLOTS",
    hudSignature: "SIGNATURE",
    hudVerified: "VERIFIED",
    hudUnverified: "UNVERIFIED",
    hudDevice: "DEVICE",
    hudCommands: "QUICK COMMANDS",
    hudOpenRepo: "OPEN REPO",
    hudFitView: "FIT VIEW",
    hudZoomIn: "ZOOM IN",
    hudZoomOut: "ZOOM OUT",
    hudFullscreen: "FULLSCREEN",
    hudExitFullscreen: "EXIT FULLSCREEN",
    hudCollapse: "COLLAPSE",
    hudExpand: "EXPAND",
    hudNoEvents: "No recorded Bee event yet.",
    researchHint: "Canonical evidence graph",
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
    latest: "ПОСЛЕДНИЙ DISPATCH",
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
    combView: "СОТЫ",
    combHint: "Доска как поле из меток",
    combHeld: "занято",
    combNeutral: "нейтрально",
    combFog: "туман",
    combBees: "пчёлы",
    combQueen: "КОРОЛЕВА",
    combQueenCell: "центральная ячейка",
    combNoBee: "пчелы здесь нет",
    combPick: "Нажмите на ячейку. Пчела на ней или ячейка Королевы покажет портрет; каждая ячейка — одна карточка доски.",
    combHint2: "тяните — вращать · колесо — масштаб · клик — выбрать",
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
    beesStarted: "Bees запущено / 24ч",
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
    queenReviewPending: "Ревью Queen",
    changesRequested: "Нужны изменения",
    humanEscalation: "Решение человека",
    reconciliationAnomaly: "Аномалия реестра",
    hudReviewUnclassified: "состояние не пришло",
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
    // ---- single-screen HUD ----
    hudBrand: "TRINITY QUEEN",
    hudBees: "ПЧЁЛЫ",
    hudDone: "ГОТОВО",
    hudVerdicts: "ВЕРДИКТЫ",
    hud24h: "24ч",
    hudResearch: "ИССЛЕДОВАНИЯ",
    hudFoundry: "ВЕРФЬ",
    hudNextRound: "СЛЕДУЮЩИЙ ЦИКЛ",
    hudAlerts: "СИГНАЛЫ",
    hudMenu: "МЕНЮ",
    hudLanguage: "EN / RU",
    hudViews: "ВИДЫ",
    hudIntel: "ЛЕНТА РАЗВЕДКИ",
    hudLive: "В СЕТИ",
    hudOffline: "НЕ В СЕТИ",
    hudViewAll: "ПОКАЗАТЬ ВСЁ",
    hudCollapseFeed: "СВЕРНУТЬ",
    hudOverview: "ОБЗОР",
    hudSectors: "СЕКТОРА",
    hudContext: "ДЕТАЛИ КОНТЕКСТА",
    hudQueue: "ОЧЕРЕДЬ ПЧЁЛ",
    hudQueueEmpty: "Ни одна Bee не работает. Королева держит очередь по политике.",
    hudReviewQueue: "ОЧЕРЕДЬ РЕВЬЮ",
    hudLast: "ПОСЛЕДНИЙ",
    hudSelected: "ВЫБРАНО",
    hudTheQueen: "КОРОЛЕВА",
    hudQueenRole: "Надзиратель. Выбирает, делегирует, судит.",
    hudBackend: "BACKEND",
    hudTerritory: "ТЕРРИТОРИЯ",
    hudNeeds: "НУЖНО",
    hudNoBee: "ПЧЕЛЫ НЕТ",
    hudSlot: "СЛОТ",
    hudBusy: "ЗАНЯТ",
    hudCell: "ЯЧЕЙКА",
    hudAllow: "РАЗРЕШЕНО",
    hudRefuse: "ОТКАЗ",
    hudSchedulerOff: "ПЛАНИРОВЩИК ВЫКЛЮЧЕН",
    hudOverdue: "ПРОСРОЧЕН",
    hudDispatched: "запущен",
    hudOpenIssue: "ОТКРЫТЬ ЗАДАЧУ",
    hudCopyLink: "КОПИРОВАТЬ ССЫЛКУ",
    hudLinkCopied: "ССЫЛКА СКОПИРОВАНА",
    hudClose: "Закрыть",
    hudOpenPanel: "КОНТЕКСТ",
    hudActiveSector: "АКТИВНЫЙ СЕКТОР",
    hudProduction: "PRODUCTION",
    hudCards: "КАРТОЧЕК",
    hudHeld: "ЗАНЯТО",
    hudSlots: "СЛОТОВ",
    hudSignature: "ПОДПИСЬ",
    hudVerified: "ПРОВЕРЕНА",
    hudUnverified: "НЕ ПРОВЕРЕНА",
    hudDevice: "УСТРОЙСТВО",
    hudCommands: "БЫСТРЫЕ КОМАНДЫ",
    hudOpenRepo: "ОТКРЫТЬ РЕПО",
    hudFitView: "ВПИСАТЬ",
    hudZoomIn: "ПРИБЛИЗИТЬ",
    hudZoomOut: "ОТДАЛИТЬ",
    hudFullscreen: "ВО ВЕСЬ ЭКРАН",
    hudExitFullscreen: "ВЫЙТИ ИЗ ПОЛНОГО ЭКРАНА",
    hudCollapse: "СВЕРНУТЬ",
    hudExpand: "РАЗВЕРНУТЬ",
    hudNoEvents: "Записанных событий Bee пока нет.",
    researchHint: "Канонический граф доказательств",
  },
} as const;

type Copy = (typeof COPY)["ru"] | (typeof COPY)["en"];

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
  data: ActivityBuffer | null;
  error: string | null;
} {
  const [data, setData] = useState<ActivityBuffer | null>(null);
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
            // The bell's buffer. The 120-event cap below holds under a
            // minute of a busy swarm, which would evict a ten-minute-old
            // verdict the bell still owes the reader; alert kinds are kept
            // here for the whole window instead.
            const seenAt = Date.now();
            const alertsById = new Map(
              [...(previous?.alerts ?? []), ...next.events]
                .filter((event) => {
                  if (!isAlertKind(event.kind)) return false;
                  const at = new Date(event.at).getTime();
                  return Number.isFinite(at) && seenAt - at <= ALERT_WINDOW_MS;
                })
                .map((event) => [event.id, event]),
            );
            return {
              cursor: next.cursor,
              events: [...byId.values()]
                .sort(
                  (left, right) =>
                    new Date(right.at).getTime() - new Date(left.at).getTime(),
                )
                .slice(0, 120),
              alerts: [...alertsById.values()],
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

/** A CSS media query as React state; the subscription is the query's own listener. */
function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const list = window.matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    },
    [query],
  );
  const read = useCallback(() => window.matchMedia(query).matches, [query]);
  return useSyncExternalStore(subscribe, read, () => false);
}

/** Close a popover on Escape or on a pointer-down outside its element. */
function useDismiss(
  open: boolean,
  ref: RefObject<HTMLElement | null>,
  onClose: () => void,
) {
  useEffect(() => {
    if (!open) return;
    const onDown = (event: MouseEvent) => {
      const host = ref.current;
      if (host && !host.contains(event.target as Node)) onClose();
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, ref, onClose]);
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
    JSON.stringify(
      { ...bootstrap, endpoints: rewriteEndpoints(bootstrap.endpoints, QUEEN_API) },
      null,
      2,
    ),
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
  embedded = false,
}: {
  c: Copy;
  graph: ResearchGraph | null;
  error: string | null;
  lang: string;
  /** Inside the HUD viewport: a one-line strip instead of the page head. */
  embedded?: boolean;
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
    selected?.prerequisites.map((id) =>
      publicResearchText(nodesById.get(id)?.label ?? id, id, lang, "label"),
    ) ?? [];
  const unlockNames =
    selected?.unlocks.map((id) =>
      publicResearchText(nodesById.get(id)?.label ?? id, id, lang, "label"),
    ) ?? [];

  return (
    <section
      className={`queen27-tech${embedded ? " is-embedded" : ""}`}
      aria-labelledby="queen-tech-title"
    >
      {embedded ? (
        <div className="queen27-tech-strip">
          <span className="queen27-section-label" id="queen-tech-title">
            {c.tech}
          </span>
          <span>
            <b>{graph ? `${graph.summary.percentage}%` : "—"}</b> {c.overallResearch}
          </span>
          <span>
            <b>{graph?.summary.researched ?? "—"}</b> {c.researched}
          </span>
          <span>
            <b>{graph?.summary.researching ?? "—"}</b> {c.activeResearch}
          </span>
          <span>
            <b>{graph?.summary.available ?? "—"}</b> {c.nextAvailable}
          </span>
          <span className="queen27-worker-slots">
            {(graph?.workers.slots ?? []).map((slot) => (
              <span className={`is-${slot.state}`} key={slot.slot}>
                <i /> {String(slot.slot).padStart(2, "0")}
              </span>
            ))}
          </span>
        </div>
      ) : (
        <>
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
        </>
      )}

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
                    <strong>
                      {publicResearchText(node.label, node.id, lang, "label")}
                    </strong>
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
            <h3>
              {publicResearchText(selected.label, selected.id, lang, "label")}
            </h3>
            {selected.note && (
              <p>{publicResearchText(selected.note, selected.id, lang)}</p>
            )}
            <dl>
              <div>
                <dt>{c.evidence}</dt>
                <dd className="queen27-tech-evidence">
                  {publicResearchText(selected.evidence, selected.id, lang)}
                </dd>
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
                <dd>
                  {lang === "ru"
                    ? {
                        shipped: "выпущено",
                        partial: "частично",
                        blocked: "заблокировано",
                        planned: "запланировано",
                        unknown: "неизвестно",
                      }[selected.maturity]
                    : selected.maturity}
                </dd>
              </div>
              {selected.blockedBy && (
                <div>
                  <dt>{c.locked}</dt>
                  <dd>
                    {publicResearchText(
                      selected.blockedBy,
                      selected.id,
                      lang,
                    )}
                  </dd>
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

// The kanban and the mission map, byte-identical in markup to the board views
// the page rendered before the HUD; they now live inside the viewport.
function KanbanView({
  columns,
  cards,
  repo,
  error,
  loaded,
  c,
  lang,
}: {
  columns: QueenColumn[];
  cards: QueenCard[];
  repo: string | null;
  error: string | null;
  /** false until /queen/public-board has answered once: counts read a dash, not 0 */
  loaded: boolean;
  c: Copy;
  lang: string;
}) {
  return (
    <motion.div
      className="queen27-kanban"
      role="region"
      aria-label={c.kanbanView}
      tabIndex={0}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      {columns.map((column) => {
        const columnCards = cards.filter((card) => card.column === column.key);
        return (
          <motion.article
            className={`queen27-column is-${column.key}`}
            key={column.key}
            layout
          >
            <header title={error ?? undefined}>
              <h3>{column.title}</h3>
              <span>{loaded ? columnCards.length : "—"}</span>
            </header>
            <small>{column.blurb}</small>
            <div className="queen27-cards">
              {columnCards.map((card) => (
                <motion.a
                  className="queen27-card"
                  href={`https://github.com/${repo}/issues/${card.number}`}
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
                          : reviewSignalLabel(reviewStateOf(card), c)}
                      </span>
                    )}
                  </div>
                  <strong>{publicIssueTitle(card.title, card.number, lang)}</strong>
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
              {columnCards.length === 0 && (
                <em title={error ?? undefined}>{loaded ? c.empty : "—"}</em>
              )}
            </div>
          </motion.article>
        );
      })}
    </motion.div>
  );
}

function MissionMapView({
  columns,
  cards,
  repo,
  error,
  loaded,
  c,
  lang,
}: {
  columns: QueenColumn[];
  cards: QueenCard[];
  repo: string | null;
  error: string | null;
  /** false until /queen/public-board has answered once: counts read a dash, not 0 */
  loaded: boolean;
  c: Copy;
  lang: string;
}) {
  return (
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
        {columns.map((column, sectorIndex) => {
          const columnCards = cards.filter(
            (card) => card.column === column.key,
          );
          return (
            <motion.section
              className={`queen27-map-sector is-${column.key}`}
              key={column.key}
              layout
            >
              <header title={error ?? undefined}>
                <small>
                  {c.sector} {String(sectorIndex + 1).padStart(2, "0")}
                </small>
                <h3>{column.title}</h3>
                <b>{loaded ? columnCards.length : "—"}</b>
              </header>
              <div className="queen27-map-nodes">
                {columnCards.map((card, cardIndex) => (
                  <motion.a
                    href={`https://github.com/${repo}/issues/${card.number}`}
                    target="_blank"
                    rel="noreferrer"
                    key={card.number}
                    layout
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{
                      delay: Math.min(cardIndex * 0.025, 0.3),
                    }}
                    title={publicIssueTitle(card.title, card.number, lang)}
                  >
                    <i aria-hidden="true" />
                    <span>#{card.number}</span>
                    <strong>{publicIssueTitle(card.title, card.number, lang)}</strong>
                    {typeof card.criteria === "number" && (
                      <small>
                        {card.criteria} {c.criteria}
                      </small>
                    )}
                  </motion.a>
                ))}
                {columnCards.length === 0 && (
                <em title={error ?? undefined}>{loaded ? c.empty : "—"}</em>
              )}
              </div>
            </motion.section>
          );
        })}
      </div>
      <p>{c.mapLegend}</p>
    </motion.div>
  );
}

const EMPTY_CARDS: QueenCard[] = [];
const EMPTY_EVENTS: QueenActivityEvent[] = [];

export default function Queen() {
  const { lang, setLang } = useI18n();
  const c = lang === "ru" ? COPY.ru : COPY.en;
  const state = useQueenStatus();
  const boardState = useQueenBoard();
  const activityState = useQueenActivity();
  const researchState = useQueenResearch();
  const hardwareState = useQueenHardware();
  const [boardView, setBoardView] = useState<
    "kanban" | "map" | "factory" | "comb" | "research"
  >("comb");
  const view: HudView = boardView;
  const now = useNow();
  const isNarrow = useMediaQuery("(max-width: 1100px)");
  const isPhone = useMediaQuery("(max-width: 900px)");

  // ---- HUD state: which panel is open, what is picked. Nothing here acts on
  // the Queen; there is no public write endpoint to act with.
  const [commandCollapsed, setCommandCollapsed] = useState(false);
  const [intelExpanded, setIntelExpanded] = useState(false);
  const [intelOpen, setIntelOpen] = useState(false);
  // The context panel belongs to the comb: it opens with the field (on a
  // desktop) and steps aside for the views that need the whole viewport.
  const [contextOpen, setContextOpen] = useState(!isPhone);
  const setView = useCallback(
    (next: HudView) => {
      setBoardView(next);
      setContextOpen(next === "comb" && !isPhone);
    },
    [isPhone],
  );
  const [menuOpen, setMenuOpen] = useState(false);
  const [doctrineOpen, setDoctrineOpen] = useState(false);
  const [roundOpen, setRoundOpen] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [activeSector, setActiveSector] = useState<string | null>(null);
  const [pick, setPick] = useState<HudPick | null>(null);
  const [agentCopy, setAgentCopy] = useState<"idle" | "copied" | "error">(
    "idle",
  );
  const combRef = useRef<CombHandle>(null);
  const viewportRef = useRef<HTMLElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const roundRef = useRef<HTMLElement>(null);
  const agentCopyTimer = useRef<number | null>(null);

  const data = state.data;
  const isLive = state.kind === "ready";
  const latest = data?.dispatches.latest;
  const decision = data?.lastTick;
  const board = boardState.data;
  const repo = board?.repo ?? null;
  const pulse = board?.pulse;
  const research = researchState.data;
  const workers = research?.workers ?? null;
  const hardware = hardwareState.data;
  const cards = board?.cards ?? EMPTY_CARDS;
  // Placement ledger (P1-20): the board arrives in wire order on every poll,
  // so a positional layout moved every structure and every bee whenever an
  // issue was inserted at the head. Known cards keep their cells across
  // polls; the ledger is adjusted during render when the card list changes
  // (React's derived-state pattern), never in an effect, so the comb, the
  // minimap and the pick all see the same placement in the same frame.
  const [placement, setPlacement] = useState<{
    cards: QueenCard[];
    placed: (QueenCard | null)[];
    ledger: Map<number, number>;
  }>(() => ({ cards, ...placeCards(new Map(), cards, fieldShape(cards.length).cellCount) }));
  let placedCards = placement.placed;
  if (placement.cards !== cards) {
    const next = placeCards(placement.ledger, cards, fieldShape(cards.length).cellCount);
    placedCards = next.placed;
    setPlacement({ cards, placed: next.placed, ledger: next.ledger });
  }
  const events: HudEvent[] = activityState.data?.events ?? EMPTY_EVENTS;
  const boardColumns = board?.columns ?? FALLBACK_COLUMNS;
  const runningCards = useMemo(
    () => cards.filter((card) => card.column === "running"),
    [cards],
  );
  const reviewCards = useMemo(
    () => cards.filter((card) => card.column === "review"),
    [cards],
  );
  const doneCount = useMemo(
    () => cards.filter((card) => card.column === "done").length,
    [cards],
  );
  const reviewQueueCounts = reviewCounts(board);
  const reviewUnclassifiedCount = reviewUnclassified(board);
  const reviewColumnTitle =
    boardColumns.find((column) => column.key === "review")?.title ?? "review";
  // The tile is named by the column the number comes from - the wire's own
  // title - not by a word ("accepted") no endpoint carries.
  const doneColumnTitle = (
    boardColumns.find((column) => column.key === "done")?.title ?? c.hudDone
  ).toUpperCase();
  const roundSeconds =
    board?.pulse.roundSeconds ?? data?.scheduler.intervalSeconds ?? 0;
  const lastRoundAt = board?.pulse.lastRoundAt ?? decision?.decidedAt ?? null;
  const elapsedSeconds = lastRoundAt
    ? Math.max(0, (now - new Date(lastRoundAt).getTime()) / 1000)
    : 0;
  // The clock is only as real as its two inputs, a round length and the
  // moment the last round happened: without both it reads "—", never a
  // fabricated 00:00:00. A disabled scheduler has no next round to count
  // down to; past the round length the clock counts up as overdue.
  const schedulerOff = data ? !data.scheduler.enabled : false;
  const roundKnown = roundSeconds > 0 && lastRoundAt !== null;
  const roundOverdue = roundKnown && elapsedSeconds > roundSeconds;
  const roundProgress =
    roundKnown && !schedulerOff
      ? Math.min(100, (elapsedSeconds / roundSeconds) * 100)
      : 0;
  const syncLabel = boardState.syncedAt
    ? boardState.syncedAt.toLocaleTimeString(lang === "ru" ? "ru-RU" : "en-GB")
    : "—";
  const countdown =
    schedulerOff || !roundKnown
      ? "—"
      : roundOverdue
        ? `+${formatCountdown(elapsedSeconds - roundSeconds)}`
        : formatCountdown(roundSeconds - elapsedSeconds);
  const roundLabel = schedulerOff
    ? c.hudSchedulerOff
    : roundOverdue
      ? c.hudOverdue
      : c.hudNextRound;
  const roundHeading = schedulerOff
    ? c.hudSchedulerOff
    : roundOverdue
      ? c.hudOverdue
      : c.nextRound;
  // A round's resolution moment: when decidedAt changes, the round tile and
  // the gold block flash for six seconds and carry the strip. The change is
  // detected during render (state adjusted from a prop, the documented
  // pattern) and the expiry is read off the 1 Hz clock, so no timer and no
  // effect. The first decidedAt seen after load is history, not news.
  const decidedAt = decision?.decidedAt ?? null;
  const [seenDecidedAt, setSeenDecidedAt] = useState<string | null>(null);
  const [flashUntil, setFlashUntil] = useState(0);
  if (decidedAt !== seenDecidedAt) {
    setSeenDecidedAt(decidedAt);
    if (seenDecidedAt !== null && decidedAt !== null) setFlashUntil(now + 6_000);
  }
  const roundResolved = flashUntil > now;
  const strip =
    roundResolved && decision
      ? roundStrip(
          decision,
          data?.dispatches.running ?? null,
          latest?.issue ?? null,
          {
            allow: c.hudAllow,
            refuse: c.hudRefuse,
            executing: c.executing,
            queueMeaning: c.queueMeaning,
            reasons: c.reasons,
          },
          lang,
        )
      : null;
  const alertEvents: HudEvent[] = activityState.data?.alerts ?? EMPTY_EVENTS;
  const alerts = useMemo(() => alertCount(alertEvents, now), [alertEvents, now]);
  const cellSummaries = useMemo(() => summariseCells(placedCards), [placedCards]);
  const sectors = useMemo(
    () => sectorRows(boardColumns, cards),
    [boardColumns, cards],
  );
  const queue = useMemo(
    () =>
      runningCards.map((card) => ({
        card,
        latest: latestEventFor(events, card.number),
      })),
    [runningCards, events],
  );
  const reviewQueue = useMemo(() => reviewCards.slice(0, 4), [reviewCards]);
  const describe = useCallback(
    (event: HudEvent) => activityLabel(event, lang),
    [lang],
  );
  // The pick is a card number, not a cell index: the field is rebuilt from
  // the card list on every poll, so an index would drift to a stranger's
  // cell. A pick with a card follows its number and re-reads the card; a pick
  // without one (the Queen's cell, an empty cell) keeps its index; a card that
  // left the board clears the pick. Derived, never stored.
  const livePick = useMemo<HudPick | null>(() => {
    if (!pick) return null;
    if (!pick.card) return pick.index < cellSummaries.length ? pick : null;
    const number = pick.card.number;
    const index = cellSummaries.findIndex((cell) => cell.cardNumber === number);
    if (index < 0) return null;
    return {
      ...pick,
      index,
      card: cards.find((card) => card.number === number) ?? pick.card,
      territory: cellSummaries[index].own,
      isQueen: index === queenIndexOf(cellSummaries.length),
    };
  }, [pick, cellSummaries, cards]);
  const pickIndex = livePick?.index ?? null;
  const pickedCard = livePick?.card ?? null;
  const pickedIssueUrl =
    pickedCard && repo
      ? `https://github.com/${repo}/issues/${pickedCard.number}`
      : null;
  // On ALLOW the detail is what the round did; on a refusal it is the refusal.
  const decisionInfo = decision
    ? decisionDetail(decision, data?.dispatches.running ?? null, latest?.issue ?? null, c)
    : null;
  const decisionLine = decision
    ? `${decision.allowed ? c.chose : c.stoodDown} · ${decisionInfo}`
    : c.noDecision;
  const heldCount = doneCount + runningCards.length;
  const device = hardware?.devices[0] ?? null;

  // ---- the shell owns the document while mounted: the body class scopes the
  // height chain in Queen.css and is removed on unmount.
  useEffect(() => {
    document.body.classList.add("queen-shell");
    return () => document.body.classList.remove("queen-shell");
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      const target = event.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable)
      ) {
        return;
      }
      const digit = Number.parseInt(event.key, 10);
      if (digit >= 1 && digit <= HUD_VIEWS.length) setView(HUD_VIEWS[digit - 1]);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [setView]);

  useEffect(() => {
    const onChange = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener("fullscreenchange", onChange);
    return () => document.removeEventListener("fullscreenchange", onChange);
  }, []);

  useEffect(
    () => () => {
      if (agentCopyTimer.current !== null) {
        window.clearTimeout(agentCopyTimer.current);
      }
    },
    [],
  );

  const closeMenu = useCallback(() => setMenuOpen(false), []);
  const closeRound = useCallback(() => setRoundOpen(false), []);
  useDismiss(menuOpen, menuRef, closeMenu);
  useDismiss(roundOpen, roundRef, closeRound);

  const handlePick = useCallback((next: HudPick | null) => {
    setPick(next);
  }, []);

  const toggleFullscreen = () => {
    if (document.fullscreenElement) {
      void document.exitFullscreen();
    } else {
      void viewportRef.current?.requestFullscreen?.();
    }
  };

  const toggleLang = () => setLang(lang === "ru" ? "en" : "ru");

  const copyAgent = async () => {
    if (agentCopyTimer.current !== null) {
      window.clearTimeout(agentCopyTimer.current);
    }
    try {
      await copyToClipboard(
        agentBootstrapText(research?.agentBootstrap ?? fallbackBootstrap(), lang),
      );
      setAgentCopy("copied");
      agentCopyTimer.current = window.setTimeout(() => {
        agentCopyTimer.current = null;
        setAgentCopy("idle");
      }, 2_500);
    } catch {
      setAgentCopy("error");
    }
  };

  const onBell = () => {
    if (isNarrow) setIntelOpen((open) => !open);
    else setIntelExpanded((expanded) => !expanded);
  };

  const commandItems = [
    { view: "comb" as const, glyph: "▽", label: c.combView, hint: c.combHint },
    { view: "kanban" as const, glyph: "▦", label: c.kanbanView, hint: c.kanbanHint },
    { view: "map" as const, glyph: "⌘", label: c.mapView, hint: c.mapHint },
    { view: "factory" as const, glyph: "⚙", label: c.factoryView, hint: c.factoryHint },
    { view: "research" as const, glyph: "◈", label: c.tech, hint: c.researchHint },
  ];
  const viewLabel =
    commandItems.find((item) => item.view === view)?.label ?? c.combView;
  const doctrine = [
    { n: "01", title: c.spec, copy: c.specCopy, tone: "" },
    { n: "02", title: c.queen, copy: c.queenCopy, tone: "is-queen" },
    { n: "03", title: c.bee, copy: c.beeCopy, tone: "" },
    { n: "04", title: c.selfReview, copy: c.selfReviewCopy, tone: "is-active" },
    { n: "05", title: c.verdict, copy: c.verdictCopy, tone: "is-queen" },
    { n: "06", title: c.merge, copy: c.mergeCopy, tone: "" },
  ];
  const statusText = isLive
    ? c.live
    : state.kind === "error"
      ? c.unavailable
      : c.checking;
  const statusTone = isLive ? "is-live" : state.kind === "error" ? "is-cold" : "is-muted";
  const skipEntries = Object.entries(decision?.skipSummary ?? {});

  const intelContent = (
    <>
      <QueenIntelFeed
        events={events}
        error={activityState.error}
        lang={lang}
        repo={repo}
        expanded={intelExpanded}
        onToggle={() => setIntelExpanded((expanded) => !expanded)}
        describe={describe}
        labels={{
          title: c.hudIntel,
          live: c.hudLive,
          offline: c.hudOffline,
          empty: c.hudNoEvents,
          viewAll: c.hudViewAll,
          collapse: c.hudCollapseFeed,
        }}
      />
      {!intelExpanded && (
        <>
          <section className="queen27-hud-panel queen27-hud-minimap" aria-label={c.hudOverview}>
            <header className="queen27-hud-panel-head">
              <span>{c.hudOverview}</span>
              <span>{board ? cards.length : "—"} {c.hudCards}</span>
            </header>
            <div className="queen27-hud-minimap-body">
              <QueenMinimap
                cards={placedCards}
                picked={pickIndex}
                onPick={(index) => {
                  // The same cell the comb would name: summariseCells is
                  // the comb's own layout. No bee: the sprites' positions
                  // are the comb's flight animation, not a fact.
                  const cell = cellSummaries[index];
                  handlePick(
                    cell
                      ? {
                          index,
                          isQueen: index === queenIndexOf(cellSummaries.length),
                          territory: cell.own,
                          card:
                            cell.cardNumber === null
                              ? null
                              : (cards.find((card) => card.number === cell.cardNumber) ?? null),
                          bee: null,
                        }
                      : null,
                  );
                  setView("comb");
                }}
                labels={{ aria: c.hudOverview }}
              />
            </div>
          </section>
          <QueenSectors
            rows={board ? sectors : null}
            active={activeSector}
            onSelect={(key) => {
              setActiveSector(key);
              setView("kanban");
            }}
            labels={{
              title: c.hudSectors,
              held: c.combHeld,
              neutral: c.combNeutral,
              fog: c.combFog,
              cards: c.hudCards,
            }}
          />
        </>
      )}
    </>
  );

  const roundPopover = roundOpen && (
    <div
      className="queen27-hud-round-pop"
      id="queen-round-pop"
      role="dialog"
      aria-label={c.decision}
    >
      <span className="queen27-section-label">{c.decision}</span>
      <div className="queen27-hud-round-pop-grid">
        <div
          className="queen27-verdict"
          aria-label={
            decision ? (decision.allowed ? c.hudAllow : c.hudRefuse) : c.noDecision
          }
        >
          <span>{decision ? (decision.allowed ? "1" : "0") : "—"}</span>
          <small>{decision ? (decision.allowed ? c.hudAllow : c.hudRefuse) : "—"}</small>
        </div>
        <div>
          <strong>
            {decision
              ? decision.allowed
                ? c.chose
                : c.stoodDown
              : c.noDecision}
          </strong>
          {decision && (
            <p>
              {decisionInfo} · {decision.skippedCount}{" "}
              {c.reasons}.
            </p>
          )}
          {skipEntries.length > 0 && (
            <ul className="queen27-hud-skips">
              {skipEntries.map(([reason, count]) => (
                <li key={reason}>
                  <b>{count}</b> {skipReasonWords(reason)}
                </li>
              ))}
            </ul>
          )}
          <small>
            {c.lastDecision}: {formatMoment(decision?.decidedAt, lang)} ·{" "}
            {c.synchronized} · {syncLabel}
          </small>
        </div>
      </div>
    </div>
  );

  return (
    <main
      className={`queen27-page is-shell${commandCollapsed ? " is-command-collapsed" : ""}`}
      data-view={view}
    >
      <header className="queen27-hud-top">
        <Link to="/" className="queen27-hud-res queen27-hud-brand">
          <TrinityLogo withLabel={false} height="34px" />
          <span className="queen27-hud-brand-text">
            <strong>{c.hudBrand}</strong>
            <span>{c.eyebrow}</span>
          </span>
        </Link>

        <div className="queen27-hud-res queen27-hud-res-bees">
          <i aria-hidden="true">◆</i>
          <small>{c.hudBees}</small>
          <strong id="stat-bees">
            {data ? data.dispatches.running : "—"}/{workers?.capacity ?? "—"}
          </strong>
          <span>
            {workers?.idle ?? "—"} {c.factoryIdle}
          </span>
        </div>

        <div className="queen27-hud-res">
          <i aria-hidden="true">✓</i>
          <small>{doneColumnTitle}</small>
          <strong id="stat-accepted">{board ? doneCount : "—"}</strong>
          <span>
            +{pulse?.bees ?? "—"} {c.beesStarted}
          </span>
        </div>

        <div className="queen27-hud-res">
          <i aria-hidden="true">▲</i>
          <small>{c.hudVerdicts}</small>
          <strong id="stat-verdicts">{pulse?.verdicts ?? "—"}</strong>
          <span>
            {c.hud24h} · {board ? `${reviewCards.length} ${reviewColumnTitle}` : "—"}
          </span>
        </div>

        <div className="queen27-hud-res">
          <i aria-hidden="true">◈</i>
          <small>{c.hudResearch}</small>
          <strong id="stat-research">
            {research ? `${research.summary.percentage}%` : "—"}
          </strong>
          <span>
            {research
              ? `${research.summary.researched}/${research.summary.total}`
              : researchState.error
                ? c.graphOffline
                : c.graphLoading}
          </span>
        </div>

        <div className="queen27-hud-res">
          <i aria-hidden="true">▰</i>
          <small>{c.hudFoundry}</small>
          <strong id="stat-foundry">
            {hardware
              ? `${hardware.summary.online}/${hardware.summary.total}`
              : "—"}
          </strong>
          <span title={hardware ? hardware.keyId : hardwareState.error ?? undefined}>
            {hardware
              ? `${hardware.summary.programmed} ${c.foundryProgrammed} · ${hardware.keyId}`
              : hardwareState.error
                ? c.foundryUnavailable
                : c.checking}
          </span>
        </div>

        <div
          className={`queen27-hud-res queen27-hud-res-round${roundResolved ? " is-resolved" : ""}`}
        >
          <i aria-hidden="true">◎</i>
          <small>{roundLabel}</small>
          <strong id="stat-round">{countdown}</strong>
          <span>
            {strip ? (
              <b className="queen27-hud-round-strip">{strip}</b>
            ) : data ? (
              `${c.every} ${formatInterval(data.scheduler.intervalSeconds, lang)} · ${formatMoment(decision?.decidedAt, lang)}`
            ) : (
              "—"
            )}
          </span>
        </div>

        <div className="queen27-hud-res queen27-hud-bell">
          <button
            type="button"
            onClick={onBell}
            aria-pressed={isNarrow ? intelOpen : intelExpanded}
            title={c.hudAlerts}
          >
            <i aria-hidden="true">◉</i>
            <strong
              id="stat-alerts"
              className={activityState.data && alerts > 0 ? "is-alert" : ""}
            >
              {activityState.data ? alerts : "—"}
            </strong>
            <small>{c.hudAlerts}</small>
          </button>
        </div>

        <div className="queen27-hud-res queen27-hud-status" ref={menuRef}>
          <span
            className={`queen27-hud-pill ${statusTone}`}
            id="stat-status"
            title={state.kind === "error" ? state.error : c.provenance}
          >
            <i aria-hidden="true" />
            {statusText}
          </span>
          <button
            type="button"
            className="queen27-hud-menu-btn"
            aria-expanded={menuOpen}
            aria-controls="queen-hud-menu"
            onClick={() => setMenuOpen((open) => !open)}
          >
            {c.hudMenu} ▾
          </button>
          {menuOpen && (
            <ul className="queen27-hud-menu" id="queen-hud-menu">
              <li>
                <button type="button" onClick={toggleLang}>
                  <span>{c.hudLanguage}</span>
                  <b>{lang.toUpperCase()}</b>
                </button>
              </li>
              <li>
                {repo ? (
                  <a href={`https://github.com/${repo}`} target="_blank" rel="noreferrer">
                    <span>{c.hudOpenRepo}</span>
                    <b>{repo}</b>
                  </a>
                ) : (
                  <button type="button" disabled>
                    <span>{c.hudOpenRepo}</span>
                    <b>—</b>
                  </button>
                )}
              </li>
              <li>
                <button
                  type="button"
                  aria-expanded={doctrineOpen}
                  onClick={() => setDoctrineOpen((open) => !open)}
                >
                  <span>{c.path}</span>
                  <b>{doctrineOpen ? "▴" : "▾"}</b>
                </button>
                {doctrineOpen && (
                  <ol className="queen27-hud-doctrine">
                    {doctrine.map((step) => (
                      <li key={step.n} className={step.tone}>
                        <b>{step.n}</b>
                        <strong>{step.title}</strong>
                        <p>{step.copy}</p>
                      </li>
                    ))}
                  </ol>
                )}
              </li>
              <li className="queen27-hud-menu-note">
                <span>{c.latest}</span>
                <b>
                  {latest
                    ? latest.finishedAt
                      ? `#${latest.issue} · ${(latest.outcome ?? "—").toUpperCase()} · ${formatMoment(latest.finishedAt, lang)}`
                      : `#${latest.issue} · ${c.hudDispatched} ${formatMoment(latest.dispatchedAt, lang)}`
                    : "—"}
                </b>
              </li>
              <li className="queen27-hud-menu-note">
                <span>{c.reviewQueue}</span>
                <div className="queen27-review-summary">
                  {REVIEW_STATES.map((reviewState) => (
                    <span className={`is-${reviewState}`} key={reviewState}>
                      <b>{reviewQueueCounts[reviewState] ?? "—"}</b>
                      {c[reviewState]}
                    </span>
                  ))}
                  {reviewUnclassifiedCount !== null && reviewUnclassifiedCount > 0 && (
                    <span className="is-unclassified">
                      <b>{reviewUnclassifiedCount}</b>
                      {c.hudReviewUnclassified}
                    </span>
                  )}
                </div>
              </li>
              <li className="queen27-hud-menu-note">
                <span>{c.source}</span>
                <b title={state.kind === "error" ? state.error : undefined}>
                  {state.kind === "error" ? c.hudOffline : c.refresh}
                </b>
              </li>
            </ul>
          )}
        </div>
      </header>

      {!isPhone && (
        <QueenCommandPanel
          items={commandItems}
          view={view}
          onSelect={setView}
          collapsed={commandCollapsed}
          onToggleCollapsed={() => setCommandCollapsed((collapsed) => !collapsed)}
          labels={{ aria: c.hudViews, collapse: c.hudCollapse, expand: c.hudExpand }}
        />
      )}

      <section
        className="queen27-hud-viewport"
        ref={viewportRef}
        aria-label={viewLabel}
        data-errors-as="title"
              data-pick-index={pickIndex ?? undefined}
        data-pick-number={pickedCard?.number ?? undefined}
      >
        <header className="queen27-hud-vp-head">
          <span className="queen27-hud-vp-title">
            {c.sector.toUpperCase()}: {repo ?? "—"}
          </span>
          <span className="queen27-hud-vp-sep" aria-hidden="true">
            ///
          </span>
          <span className="queen27-hud-vp-view">{viewLabel}</span>
          <div className="queen27-hud-vp-tools">
            {view === "comb" && (
              <>
                <button
                  type="button"
                  onClick={() => combRef.current?.fit()}
                  title={c.hudFitView}
                >
                  {c.hudFitView}
                </button>
                <button
                  type="button"
                  onClick={() => combRef.current?.zoomOut()}
                  aria-label={c.hudZoomOut}
                  title={c.hudZoomOut}
                >
                  −
                </button>
                <button
                  type="button"
                  onClick={() => combRef.current?.zoomIn()}
                  aria-label={c.hudZoomIn}
                  title={c.hudZoomIn}
                >
                  +
                </button>
              </>
            )}
            <button
              type="button"
              onClick={toggleFullscreen}
              aria-pressed={isFullscreen}
              title={isFullscreen ? c.hudExitFullscreen : c.hudFullscreen}
            >
              {isFullscreen ? c.hudExitFullscreen : c.hudFullscreen}
            </button>
          </div>
        </header>

        <div className="queen27-hud-vp-body">
          {boardView === "kanban" ? (
            <KanbanView
              columns={boardColumns}
              cards={cards}
              repo={repo}
              error={boardState.error}
              loaded={board !== null}
              c={c}
              lang={lang}
            />
          ) : boardView === "map" ? (
            <MissionMapView
              columns={boardColumns}
              cards={cards}
              repo={repo}
              error={boardState.error}
              loaded={board !== null}
              c={c}
              lang={lang}
            />
          ) : boardView === "comb" ? (
            <QueenComb
              embedded
              handleRef={combRef}
              onPick={handlePick}
              pickIndex={pickIndex}
              fitInset={contextOpen ? (isPhone ? 0.56 : 0.46) : 0}
              events={events}
              devices={hardware?.devices ?? null}
              columns={boardColumns}
              cards={placedCards}
              repo={repo}
              workers={workers}
              error={boardState.error ?? researchState.error}
              labels={{
                aria: c.combView,
                held: c.combHeld,
                neutral: c.combNeutral,
                fog: c.combFog,
                bees: c.combBees,
                queen: c.combQueen,
                queenCell: c.combQueenCell,
                noBee: c.combNoBee,
                pick: c.combPick,
                hint: c.combHint2,
                offline: c.factoryOffline,
              }}
            />
          ) : boardView === "research" ? (
            <TechnologyTree
              c={c}
              graph={researchState.data}
              error={researchState.error}
              lang={lang}
              embedded
            />
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
        </div>

        <QueenContext
          open={contextOpen}
          onClose={() => setContextOpen(false)}
          onOpen={() => setContextOpen(true)}
          lang={lang}
          repo={repo}
          columns={boardColumns}
          queue={board ? queue : null}
          reviewQueue={reviewQueue}
          latestDispatch={latest ?? null}
          pick={livePick}
          queenStats={{
            backendLive: isLive,
            accepted: board ? doneCount : null,
            verdicts: pulse?.verdicts ?? null,
            running: data?.dispatches.running ?? null,
            capacity: workers?.capacity ?? null,
            // pulse.rounds counts the rows of a one-row lease table (0 or 1); a
            // dash until the server counts real rounds (backlog P3-2).
            rounds: null,
            beesStarted: pulse?.bees ?? null,
          }}
          describe={describe}
          labels={{
            title: c.hudContext,
            queue: c.hudQueue,
            queueEmpty: c.hudQueueEmpty,
            reviewQueue: c.hudReviewQueue,
            last: c.hudLast,
            selected: c.hudSelected,
            theQueen: c.hudTheQueen,
            queenRole: c.hudQueenRole,
            backend: c.hudBackend,
            live: c.hudLive,
            offline: c.hudOffline,
            accepted: doneColumnTitle,
            verdicts: c.verdicts,
            bees: c.hudBees,
            rounds: c.rounds,
            beesStarted: c.beesStarted,
            sector: c.sector,
            territory: c.hudTerritory,
            held: c.combHeld,
            neutral: c.combNeutral,
            fog: c.combFog,
            criteria: c.criteria,
            needs: c.hudNeeds,
            noBee: c.hudNoBee,
            slot: c.hudSlot,
            busy: c.hudBusy,
            idle: c.factoryIdle,
            cell: c.hudCell,
            dispatched: c.hudDispatched,
            openIssue: c.hudOpenIssue,
            copyLink: c.hudCopyLink,
            linkCopied: c.hudLinkCopied,
            close: c.hudClose,
            openPanel: c.hudOpenPanel,
          }}
        />
      </section>

      {isNarrow ? (
        intelOpen && (
          <aside
            className={`queen27-hud-intel is-drawer${intelExpanded ? " is-expanded" : ""}`}
            aria-label={c.hudIntel}
          >
            <button
              type="button"
              className="queen27-hud-drawer-close"
              onClick={() => setIntelOpen(false)}
              aria-label={c.hudClose}
            >
              ×
            </button>
            {intelContent}
          </aside>
        )
      ) : (
        <aside
          className={`queen27-hud-intel${intelExpanded ? " is-expanded" : ""}`}
          aria-label={c.hudIntel}
        >
          {intelContent}
        </aside>
      )}

      <footer className="queen27-hud-bottom">
        {isPhone ? (
          <>
            <QueenCommandPanel
              items={commandItems}
              view={view}
              onSelect={setView}
              collapsed={false}
              onToggleCollapsed={() => undefined}
              compact
              labels={{ aria: c.hudViews, collapse: c.hudCollapse, expand: c.hudExpand }}
            />
            <section className="queen27-hud-round-cell is-mini" ref={roundRef} aria-label={c.hudNextRound}>
              <button
                type="button"
                className="queen27-hud-round-mini"
                aria-expanded={roundOpen}
                aria-controls="queen-round-pop"
                onClick={() => setRoundOpen((open) => !open)}
              >
                <small>{roundLabel}</small>
                <strong className="queen27-hud-countdown">{countdown}</strong>
              </button>
              {roundPopover}
            </section>
          </>
        ) : (
          <>
            <section className="queen27-hud-sector" aria-label={c.hudActiveSector}>
              <header className="queen27-hud-panel-head">
                <span>{c.hudActiveSector}</span>
              </header>
              <div className="queen27-hud-sector-body">
                <span className="queen27-hud-sector-mark" aria-hidden="true">
                  <TrinityLogo withLabel={false} height="40px" />
                </span>
                <div className="queen27-hud-sector-text">
                  <strong>{repo ?? "—"}</strong>
                  <small>{c.hudProduction}</small>
                  <dl>
                    <div>
                      <dt>{c.hudCards}</dt>
                      <dd>{board ? cards.length : "—"}</dd>
                    </div>
                    <div>
                      <dt>{c.hudHeld}</dt>
                      <dd>{board ? heldCount : "—"}</dd>
                    </div>
                    <div>
                      <dt>{c.hudSlots}</dt>
                      <dd>{workers?.capacity ?? "—"}</dd>
                    </div>
                    <div>
                      <dt>{c.hudSignature}</dt>
                      <dd
                        className={
                          hardware ? "is-green" : hardwareState.error ? "is-cold" : "is-muted"
                        }
                        title={hardware ? hardware.keyId : hardwareState.error ?? undefined}
                      >
                        {hardware
                          ? c.hudVerified
                          : hardwareState.error
                            ? c.hudUnverified
                            : c.checking}
                      </dd>
                    </div>
                  </dl>
                  <em title={c.hudDevice}>
                    {device ? `${device.id} · ${device.state}` : "—"}
                  </em>
                </div>
              </div>
            </section>

            <section className="queen27-hud-commands" aria-label={c.hudCommands}>
              <header className="queen27-hud-panel-head">
                <span>{c.hudCommands}</span>
              </header>
              <div className="queen27-hud-tiles">
                <button
                  type="button"
                  className={`queen27-hud-tile${agentCopy === "copied" ? " is-gold" : ""}`}
                  onClick={copyAgent}
                >
                  <i aria-hidden="true">⌘</i>
                  <b>
                    {agentCopy === "copied"
                      ? c.copiedAgent
                      : agentCopy === "error"
                        ? c.copyFailed
                        : c.copyAgent}
                  </b>
                </button>
                {repo ? (
                  <a
                    className="queen27-hud-tile"
                    href={`https://github.com/${repo}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <i aria-hidden="true">◇</i>
                    <b>{c.hudOpenRepo}</b>
                  </a>
                ) : (
                  <button type="button" className="queen27-hud-tile" disabled>
                    <i aria-hidden="true">◇</i>
                    <b>{c.hudOpenRepo}</b>
                  </button>
                )}
                {pickedIssueUrl ? (
                  <a
                    className="queen27-hud-tile"
                    href={pickedIssueUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <i aria-hidden="true">#</i>
                    <b>{c.hudOpenIssue}</b>
                  </a>
                ) : (
                  <button type="button" className="queen27-hud-tile" disabled>
                    <i aria-hidden="true">#</i>
                    <b>{c.hudOpenIssue}</b>
                  </button>
                )}
                <button
                  type="button"
                  className="queen27-hud-tile"
                  onClick={() => {
                    setView("comb");
                    combRef.current?.fit();
                  }}
                >
                  <i aria-hidden="true">▽</i>
                  <b>{c.hudFitView}</b>
                </button>
                <button
                  type="button"
                  className="queen27-hud-tile"
                  onClick={toggleFullscreen}
                  aria-pressed={isFullscreen}
                >
                  <i aria-hidden="true">⤢</i>
                  <b>{isFullscreen ? c.hudExitFullscreen : c.hudFullscreen}</b>
                </button>
                <button type="button" className="queen27-hud-tile" onClick={toggleLang}>
                  <i aria-hidden="true">⟲</i>
                  <b>{c.hudLanguage}</b>
                </button>
              </div>
            </section>

            <section className="queen27-hud-round-cell" ref={roundRef} aria-label={c.hudNextRound}>
              <div className={`queen27-hud-round${roundResolved ? " is-resolved" : ""}`}>
                <div className="queen27-hud-orbit" aria-hidden="true">
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
                </div>
                <button
                  type="button"
                  className="queen27-hud-round-btn"
                  aria-expanded={roundOpen}
                  aria-controls="queen-round-pop"
                  onClick={() => setRoundOpen((open) => !open)}
                >
                  <small>{roundHeading}</small>
                  <strong className="queen27-hud-countdown">{countdown}</strong>
                  <i aria-hidden="true">
                    <span style={{ width: `${roundProgress}%` }} />
                  </i>
                  <em>{strip ?? decisionLine}</em>
                </button>
              </div>
              {roundPopover}
            </section>
          </>
        )}
      </footer>
    </main>
  );
}
