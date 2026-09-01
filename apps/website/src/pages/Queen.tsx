import { useEffect, useState, type CSSProperties } from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { TrinityLogo } from "../components/TrinityLogo";
import {
  techBranches,
  type TechNode,
} from "../components/TechTree/techTreeData";
import { useI18n } from "../i18n/context";
import "./Queen.css";

const DEFAULT_QUEEN_API =
  "https://trios-agent-server-production.up.railway.app";
const QUEEN_API = (
  (import.meta.env.VITE_QUEEN_API as string | undefined) ?? DEFAULT_QUEEN_API
).replace(/\/+$/, "");
const LIVE_POLL_MS = 5_000;
const ACTIVITY_POLL_MS = 2_000;
const TECH_NODES = techBranches.flatMap((branch) => branch.nodes);
const TECH_BY_ID = new Map(TECH_NODES.map((node) => [node.id, node]));

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
    kanbanHint: "Operational columns",
    mapHint: "Strategic lifecycle sectors",
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
    kanbanHint: "Операционные колонки",
    mapHint: "Стратегические сектора цикла",
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

  useEffect(() => {
    let active = true;
    const read = async () => {
      try {
        const since = Date.now() - 15 * 60 * 1_000;
        const response = await fetch(
          `${QUEEN_API}/queen/public-activity?since=${since}`,
          {
            headers: { Accept: "application/json" },
            cache: "no-store",
          },
        );
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = (await response.json()) as QueenActivity;
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
    const timer = window.setInterval(read, ACTIVITY_POLL_MS);
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

type TechState = "done" | "researching" | "available" | "locked";

function getTechState(node: TechNode): TechState {
  if (node.status === "done") return "done";
  if (node.status === "in_progress") return "researching";
  const isAvailable = node.prerequisites.every(
    (id) => TECH_BY_ID.get(id)?.status === "done",
  );
  return isAvailable ? "available" : "locked";
}

function TechnologyTree({
  c,
}: {
  c: (typeof COPY)["ru"] | (typeof COPY)["en"];
}) {
  const initialNode =
    TECH_NODES.find((node) => node.status === "in_progress") ?? TECH_NODES[0];
  const [selectedId, setSelectedId] = useState(initialNode.id);
  const selected = TECH_BY_ID.get(selectedId) ?? initialNode;
  const selectedState = getTechState(selected);
  const completed = TECH_NODES.filter((node) => node.status === "done").length;
  const researching = TECH_NODES.filter(
    (node) => node.status === "in_progress",
  ).length;
  const available = TECH_NODES.filter(
    (node) => getTechState(node) === "available",
  ).length;
  const stateLabel = {
    done: c.researched,
    researching: c.researching,
    available: c.available,
    locked: c.locked,
  } satisfies Record<TechState, string>;
  const prerequisiteNames = selected.prerequisites.map(
    (id) => TECH_BY_ID.get(id)?.name ?? id,
  );
  const unlockNames = selected.unlocks.map(
    (id) => TECH_BY_ID.get(id)?.name ?? id,
  );

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
          <strong>{Math.round((completed / TECH_NODES.length) * 100)}%</strong>
          <span>{c.overallResearch}</span>
        </div>
      </div>

      <div className="queen27-tech-stats">
        <span>
          <b>{completed}</b> {c.researched}
        </span>
        <span>
          <b>{researching}</b> {c.activeResearch}
        </span>
        <span>
          <b>{available}</b> {c.nextAvailable}
        </span>
      </div>

      <div className="queen27-tech-console">
        <div
          className="queen27-tech-map"
          role="region"
          aria-label={c.tech}
          tabIndex={0}
        >
          {techBranches.map((branch) => (
            <div
              className="queen27-tech-lane"
              key={branch.id}
              style={{ "--tech-color": branch.color } as CSSProperties}
            >
              <header>
                <span aria-hidden="true">{branch.icon}</span>
                <b>{branch.name}</b>
              </header>
              <div className="queen27-tech-nodes">
                {branch.nodes.map((node) => {
                  const techState = getTechState(node);
                  const isSelected = selected.id === node.id;
                  return (
                    <motion.button
                      type="button"
                      className={`queen27-tech-node is-${techState}${isSelected ? " is-selected" : ""}`}
                      key={node.id}
                      onClick={() => setSelectedId(node.id)}
                      whileHover={{ y: -3 }}
                      whileTap={{ scale: 0.98 }}
                      aria-pressed={isSelected}
                    >
                      <small>{stateLabel[techState]}</small>
                      <strong>{node.name}</strong>
                      {node.metrics && <span>{node.metrics}</span>}
                      {techState === "researching" && (
                        <i>
                          <span style={{ width: `${node.progress ?? 0}%` }} />
                        </i>
                      )}
                    </motion.button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        <motion.aside
          className={`queen27-tech-details is-${selectedState}`}
          key={selected.id}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <span>{stateLabel[selectedState]}</span>
          <h3>{selected.name}</h3>
          <p>{selected.description}</p>
          {typeof selected.progress === "number" && (
            <strong>{selected.progress}%</strong>
          )}
          <dl>
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
          </dl>
        </motion.aside>
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
  const [boardView, setBoardView] = useState<"kanban" | "map">("kanban");
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
              <span />
              <span />
              <span />
              <TrinityLogo withLabel={false} height="72px" />
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
        ) : (
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

      <TechnologyTree c={c} />

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
