// THE MCP FLEET: every Model Context Protocol server this machine can reach, as
// it answers now.
//
// It lives inside TOOLS (key t) as that view's second face rather than as a rail
// entry of its own, because it is the same subject seen from the other side —
// see TOOL_FACES in QueenAgents.tsx.
//
// Why this is not a file in the repository. The inventory names private
// projects, so it is never built into the published site; the page reads it
// live over loopback from a hub the owner runs on their own machine
// (~/mcp-hub/scan.mjs --serve). A browser treats http://127.0.0.1 as a
// potentially trustworthy origin even from an https page, and the hub answers
// with Access-Control-Allow-Origin: * and Access-Control-Allow-Private-Network,
// so the fetch is allowed without the site ever carrying the data.
//
// The contract that matters: with the hub down this view SAYS the hub is down
// and prints the command that starts it. It never draws an empty catalogue,
// because an empty catalogue and a stopped hub look identical to a reader and
// only one of them means "you have no MCP servers".
//
// The Explorer face reads the spec corpus: what a tool is declared to be. This
// face is the other half — whether it answers, and with how many tools. A
// declared server that is offline and a healthy one are the same text in a spec.
import { useCallback, useEffect, useState } from "react";
import "./QueenMcp.css";

// Overridable for a hub on another port; the default is the one scan.mjs binds.
const HUB = (import.meta.env?.VITE_MCP_HUB as string | undefined) ?? "http://127.0.0.1:8899";

/** Three states, not two. See statusWord. */
export type McpStatus = "online" | "reachable" | "offline";

export interface McpServer {
  name: string;
  transport: string;
  url: string | null;
  command: string | null;
  args: string[];
  envKeys: string[];
  headerKeys: string[];
  secretsInConfig: boolean;
  /** Which config files registered it; more than one means it is defined twice. */
  origins: string[];
  status: McpStatus;
  ms: number | null;
  error: string | null;
  serverInfo: { name?: string; version?: string } | null;
  toolCount: number | null;
  tools: Array<{ name: string; description?: string }>;
}

export interface McpFleet {
  generatedAt: string;
  host: string;
  counts: { servers: number; online: number; reachable: number; offline: number; tools: number };
  note?: string;
  servers: McpServer[];
}

export interface McpCopy {
  title: string;
  subtitle: string;
  servers: string;
  online: string;
  reachable: string;
  offline: string;
  tools: string;
  loading: string;
  hubDown: string;
  hubDownBody: string;
  retry: string;
  rescan: string;
  scanned: string;
  /** [one, few, many] — the card count is prose, so "1 tools" is not acceptable. */
  toolWords: readonly [string, string, string];
  noTools: string;
  secretMark: string;
  registeredIn: string;
  reachableNote: string;
}

// The copy lives here rather than in the page's string tables because it is
// this view's own vocabulary — "reachable" and the hub-down command mean
// nothing anywhere else on the page, and the page is long enough already.
const MCP_COPY: Record<"en" | "ru", McpCopy> = {
  en: {
    title: "MCP FLEET",
    subtitle: "Read live from your own hub, not from this site",
    servers: "servers",
    online: "online",
    reachable: "answering",
    offline: "offline",
    tools: "tools",
    loading: "Asking the hub…",
    hubDown: "The hub is not running",
    hubDownBody:
      "This view reads the inventory from a hub on your own machine, because the list names private projects and is never built into the published site. Start it and press Retry:",
    retry: "Retry",
    rescan: "Re-probe",
    scanned: "probed",
    toolWords: ["tool", "tools", "tools"],
    noTools: "no tools listed",
    secretMark: "a value in this server's config looks like a secret; only key names are shown",
    registeredIn: "registered in",
    reachableNote:
      "answering — it replied, but the reply did not parse. That is not the same as dead.",
  },
  ru: {
    title: "ПАРК MCP",
    subtitle: "Читается живьём с вашего хаба, а не с этого сайта",
    servers: "серверов",
    online: "онлайн",
    reachable: "отвечает",
    offline: "офлайн",
    tools: "инструментов",
    loading: "Спрашиваю хаб…",
    hubDown: "Хаб не запущен",
    hubDownBody:
      "Эта вкладка читает инвентарь с хаба на вашей же машине: список называет приватные проекты и никогда не попадает в опубликованный сайт. Запустите его и нажмите «Ещё раз»:",
    retry: "Ещё раз",
    rescan: "Переопросить",
    scanned: "опрошено",
    toolWords: ["инструмент", "инструмента", "инструментов"],
    noTools: "инструменты не перечислены",
    secretMark: "значение в конфиге этого сервера похоже на секрет; показаны только имена ключей",
    registeredIn: "прописан в",
    reachableNote:
      "отвечает — ответ пришёл, но не разобрался. Это не то же самое, что мёртв.",
  },
};

/** The copy for a page language; anything that is not Russian reads English. */
export function mcpCopy(lang: string): McpCopy {
  return lang === "ru" ? MCP_COPY.ru : MCP_COPY.en;
}

/**
 * The middle state earns its place. browseros-neo answers HTTP 200 with a body
 * the probe cannot parse; with two states it would be filed "offline" while it
 * is in fact running and usable. An answer that does not parse is "it replied",
 * never "it is dead".
 */
function statusWord(status: McpStatus, c: McpCopy): string {
  if (status === "online") return c.online;
  if (status === "reachable") return c.reachable;
  return c.offline;
}

/**
 * "1 tool", "2 инструмента", "13 инструментов". Russian has three forms and
 * English two, so the picker is shared and the copy carries the words: 11-14 are
 * the many form in Russian even though they end in 1-4, which is the case a
 * naive n % 10 gets wrong.
 */
function plural(n: number, words: readonly [string, string, string], lang: string): string {
  if (lang !== "ru") return `${n} ${n === 1 ? words[0] : words[1]}`;
  const teen = n % 100;
  const last = n % 10;
  if (last === 1 && teen !== 11) return `${n} ${words[0]}`;
  if (last >= 2 && last <= 4 && (teen < 12 || teen > 14)) return `${n} ${words[1]}`;
  return `${n} ${words[2]}`;
}

/** Where the server came from, in a form short enough for a card. */
function originLabel(origin: string): string {
  return origin.replace(/^claude:/, "");
}

/**
 * `hidden` is the second face of the TOOLS view being put away, not unmounted:
 * the probe results and the reader's expanded card survive a switch back to the
 * spec catalogue, and the hub is not asked again for a view nobody is reading.
 */
export function QueenMcp({ c, lang, hidden = false }: { c: McpCopy; lang: string; hidden?: boolean }) {
  const [fleet, setFleet] = useState<McpFleet | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [open, setOpen] = useState<string | null>(null);

  const load = useCallback(async (rescan = false) => {
    setBusy(true);
    try {
      const response = await fetch(`${HUB}${rescan ? "/rescan" : "/mcp.json"}`, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as McpFleet;
      // A hub that answers with no servers is still a working hub reporting an
      // empty machine; only a failed fetch means "the hub is not running".
      setFleet(data);
      setError(null);
    } catch (cause) {
      setFleet(null);
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  if (error !== null) {
    return (
      <div className="mcp-view" hidden={hidden}>
        <div className="mcp-down">
          <h2>{c.hubDown}</h2>
          <p>{c.hubDownBody}</p>
          <code className="mcp-cmd">node ~/mcp-hub/scan.mjs --serve</code>
          <p className="mcp-err">{HUB} — {error}</p>
          <button type="button" className="mcp-btn" onClick={() => void load()} disabled={busy}>
            {c.retry}
          </button>
        </div>
      </div>
    );
  }

  if (fleet === null) {
    return <div className="mcp-view" hidden={hidden}><p className="mcp-loading">{c.loading}</p></div>;
  }

  const scannedAt = new Date(fleet.generatedAt);
  const clock = Number.isNaN(scannedAt.getTime())
    ? "—"
    : scannedAt.toLocaleTimeString(lang === "ru" ? "ru-RU" : "en-GB", { hour: "2-digit", minute: "2-digit", hour12: false });

  return (
    <div className="mcp-view" hidden={hidden}>
      <header className="mcp-head">
        <h2>{c.title}</h2>
        <p>{c.subtitle}</p>
      </header>

      {/* Its own class, not .queen-card: that is a <section> with a global
          display:flex; align-items:center which collapses these metrics into a
          single 150px column. */}
      <div className="mcp-summary">
        <div className="mcp-metric"><b>{fleet.counts.servers}</b><span>{c.servers}</span></div>
        <div className="mcp-metric is-online"><b>{fleet.counts.online}</b><span>{c.online}</span></div>
        <div className="mcp-metric is-reachable"><b>{fleet.counts.reachable}</b><span>{c.reachable}</span></div>
        <div className="mcp-metric is-offline"><b>{fleet.counts.offline}</b><span>{c.offline}</span></div>
        <div className="mcp-metric"><b>{fleet.counts.tools}</b><span>{c.tools}</span></div>
      </div>

      <div className="mcp-bar">
        <span className="mcp-scanned">{c.scanned}: {clock}</span>
        <button type="button" className="mcp-btn" onClick={() => void load(true)} disabled={busy}>
          {busy ? c.loading : c.rescan}
        </button>
      </div>

      {fleet.counts.reachable > 0 ? <p className="mcp-note">{c.reachableNote}</p> : null}

      <ul className="mcp-list">
        {fleet.servers.map((server) => {
          const isOpen = open === server.name;
          const count = server.toolCount ?? 0;
          return (
            <li key={server.name} className={`mcp-card is-${server.status}`}>
              <button
                type="button"
                className="mcp-card-head"
                aria-expanded={isOpen}
                onClick={() => setOpen(isOpen ? null : server.name)}
              >
                <span className={`mcp-dot is-${server.status}`} aria-hidden="true" />
                <span className="mcp-name">
                  {server.name}
                  {/* A mark, never the value: the hub publishes key names only. */}
                  {server.secretsInConfig ? <span className="mcp-lock" title={c.secretMark}>🔒</span> : null}
                </span>
                <span className="mcp-transport">{server.transport}</span>
                <span className="mcp-count">{count > 0 ? plural(count, c.toolWords, lang) : c.noTools}</span>
                <span className="mcp-state">{statusWord(server.status, c)}</span>
                {server.ms !== null ? <span className="mcp-ms">{server.ms} ms</span> : null}
              </button>

              {server.error !== null ? <p className="mcp-card-err">{server.error}</p> : null}

              {isOpen ? (
                <div className="mcp-card-body">
                  <p className="mcp-origins">
                    {c.registeredIn}: {server.origins.map(originLabel).join(" · ")}
                  </p>
                  {server.envKeys.length > 0 ? (
                    <p className="mcp-keys">env: {server.envKeys.join(", ")}</p>
                  ) : null}
                  {server.headerKeys.length > 0 ? (
                    <p className="mcp-keys">headers: {server.headerKeys.join(", ")}</p>
                  ) : null}
                  {server.tools.length > 0 ? (
                    <ul className="mcp-tools">
                      {server.tools.map((tool) => (
                        <li key={tool.name}>
                          <code>{tool.name}</code>
                          {tool.description ? <span>{tool.description}</span> : null}
                        </li>
                      ))}
                    </ul>
                  ) : null}
                </div>
              ) : null}
            </li>
          );
        })}
      </ul>

      {fleet.note ? <p className="mcp-foot">{fleet.note}</p> : null}
    </div>
  );
}

export default QueenMcp;
