import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useI18n } from "../i18n/context";
import "./Queen.css";

const DEFAULT_QUEEN_API =
  "https://trios-agent-server-production.up.railway.app";
const QUEEN_API = (
  (import.meta.env.VITE_QUEEN_API as string | undefined) ?? DEFAULT_QUEEN_API
).replace(/\/+$/, "");

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
    refresh: "refreshes every 15 seconds",
    source: "Open operational view",
    board: "REALTIME KANBAN",
    boardTitle: "The whole swarm, in one place.",
    boardCopy:
      "Public GitHub work mapped to the Queen’s own states. Operational secrets stay private.",
    rounds: "rounds / 24h",
    beesStarted: "Bees started",
    verdicts: "verdicts",
    empty: "Nothing here",
    criteria: "criteria",
    missing: "needs",
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
    refresh: "обновление каждые 15 секунд",
    source: "Открытый operational view",
    board: "REALTIME KANBAN",
    boardTitle: "Весь рой — в одном месте.",
    boardCopy:
      "Публичные GitHub-задачи в реальных состояниях Queen. Внутренние данные остаются закрытыми.",
    rounds: "циклов / 24ч",
    beesStarted: "Bees запущено",
    verdicts: "вердиктов",
    empty: "Здесь пусто",
    criteria: "критерия",
    missing: "нужно",
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
    const timer = window.setInterval(read, 15_000);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return state;
}

function useQueenBoard(): { data: QueenBoard | null; error: string | null } {
  const [data, setData] = useState<QueenBoard | null>(null);
  const [error, setError] = useState<string | null>(null);

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
    const timer = window.setInterval(read, 15_000);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return { data, error };
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
  const data = state.data;
  const isLive = state.kind === "ready";
  const latest = data?.dispatches.latest;
  const decision = data?.lastTick;

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
          <div className="queen27-sigil" aria-hidden="true">
            <i />
            <i />
            <i />
            <b>Q</b>
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
        <div
          className="queen27-kanban"
          role="region"
          aria-label={c.board}
          tabIndex={0}
        >
          {(
            boardState.data?.columns ?? [
              { key: "backlog", title: "backlog", blurb: "" },
              { key: "blocked", title: "blocked", blurb: "" },
              { key: "running", title: "running", blurb: "" },
              { key: "review", title: "in review", blurb: "" },
              { key: "done", title: "done", blurb: "" },
              { key: "dropped", title: "dropped", blurb: "" },
            ]
          ).map((column) => {
            const cards =
              boardState.data?.cards.filter(
                (card) => card.column === column.key,
              ) ?? [];
            return (
              <article
                className={`queen27-column is-${column.key}`}
                key={column.key}
              >
                <header>
                  <h3>{column.title}</h3>
                  <span>{cards.length}</span>
                </header>
                <small>{column.blurb}</small>
                <div className="queen27-cards">
                  {cards.map((card) => (
                    <a
                      className="queen27-card"
                      href={`https://github.com/${boardState.data?.repo}/issues/${card.number}`}
                      target="_blank"
                      rel="noreferrer"
                      key={card.number}
                    >
                      <b>#{card.number}</b>
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
                    </a>
                  ))}
                  {cards.length === 0 && <em>{boardState.error ?? c.empty}</em>}
                </div>
              </article>
            );
          })}
        </div>
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
        </div>
      </section>

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
