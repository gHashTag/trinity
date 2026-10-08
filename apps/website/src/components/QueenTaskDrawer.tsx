// One task, opened (gHashTag/t27 specs/queen/dashboard.t27 section 2): its
// history, its lease, its attempts and, for a job, its effects, as
// GET /queen/public-task answers them. The words come from the page's COPY,
// so both languages are checked in one place (qa/queen-language-contract.mjs).

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { loadDrawer, type DrawerLoad } from "../lib/queenDrawer";
import { ageWords, beeBadge, type QueenBee } from "../lib/queenTasks";
import "./QueenTaskDrawer.css";

export interface DrawerWords {
  drawerClose: string;
  drawerTimeline: string;
  drawerLease: string;
  drawerLeaseNone: string;
  drawerLeaseLive: string;
  drawerLeaseExpired: string;
  drawerAttempts: string;
  drawerSendBacks: string;
  drawerFreeAttempts: string;
  drawerCeilingReleases: string;
  drawerReviewerMisses: string;
  drawerReview: string;
  drawerStarted: string;
  drawerFinished: string;
  drawerEffects: string;
  drawerEffectStep: string;
  drawerEffectRuns: string;
  drawerEmpty: string;
  drawerMissing: string;
  drawerLoading: string;
  drawerOnGithub: string;
  evCreated: string;
  evEnded: string;
  evLeaseLost: string;
  evEvidence: string;
  evReviewed: string;
  evAssign: string;
  evCancel: string;
}

export interface DrawerCard {
  key: string;
  kind: string;
  number: number;
  title: string;
  state: string;
  url: string | null;
  bee: QueenBee | null;
}

const fill = (template: string, values: Record<string, string | number>) =>
  template.replace(/\{(\w+)\}/g, (_, name: string) => String(values[name] ?? ""));

// control.t27 EV_* -> the words a person reads; a kind with no words is not drawn
const EVENT_WORD: Record<number, keyof DrawerWords> = {
  0: "evCreated",
  1: "evEnded",
  3: "evLeaseLost",
  4: "evEvidence",
  5: "evReviewed",
  6: "evAssign",
  7: "evCancel",
};

export function QueenTaskDrawer({
  api,
  card,
  words,
  lang,
  onClose,
}: {
  api: string;
  card: DrawerCard;
  words: DrawerWords;
  lang: "en" | "ru";
  onClose: () => void;
}) {
  const [load, setLoad] = useState<DrawerLoad | null>(null);
  useEffect(() => {
    const controller = new AbortController();
    setLoad(null);
    loadDrawer(api, card.key, controller.signal)
      .then(setLoad)
      .catch((error) => {
        if (!controller.signal.aborted) setLoad({ kind: "error", message: error instanceof Error ? error.message : String(error) });
      });
    return () => controller.abort();
  }, [api, card.key]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const now = Date.now();
  const data = load?.kind === "ready" ? load.data : null;
  // how long until `iso`: ageWords counts back from now, so it is asked about the moment as far before now as `iso` is after it
  const left = (iso: string) => {
    const at = Date.parse(iso);
    return Number.isFinite(at) ? ageWords(new Date(2 * now - at).toISOString(), now, lang) ?? "" : "";
  };
  const ago = (iso: string | null) => ageWords(iso, now, lang);
  // Into the body: the board sits in its own stacking context (z-index 1),
  // under the HUD's bar and the Queen's panel, and a drawer inside it would too.
  return createPortal(
    <aside className="queen27-drawer" role="dialog" aria-modal="false" aria-label={card.title} data-drawer={card.key}>
      <header>
        <b>{card.number > 0 ? `#${card.number}` : card.key}</b>
        <span className="queen27-drawer-state">{card.state}</span>
        <button type="button" className="queen27-chip" onClick={onClose} aria-label={words.drawerClose}>
          ×
        </button>
      </header>
      <h3 data-lang-exempt="github-title">{card.title}</h3>
      {card.url && (
        <a href={card.url} target="_blank" rel="noreferrer">
          {words.drawerOnGithub}
        </a>
      )}
      {card.bee && <p className="queen27-drawer-bee" data-bee-state={card.bee.state}>{beeBadge(card.bee, now, lang)}</p>}
      {load === null && <p className="queen27-drawer-note">{words.drawerLoading}</p>}
      {load?.kind === "missing" && <p className="queen27-drawer-note">{words.drawerMissing}</p>}
      {load?.kind === "error" && <p className="queen27-drawer-note">{load.message}</p>}
      {data && (
        <>
          {card.kind === "issue" && (
            <section>
              <h4>{words.drawerLease}</h4>
              <p data-lease={data.lease?.state ?? "none"}>
                {!data.lease || data.lease.state === "none"
                  ? words.drawerLeaseNone
                  : fill(data.lease.state === "live" ? words.drawerLeaseLive : words.drawerLeaseExpired, {
                      fence: data.lease.fence,
                      left: data.lease.state === "live" ? left(data.lease.expiresAt) : ago(data.lease.expiresAt) ?? "",
                    })}
              </p>
            </section>
          )}
          {data.attempts && (
            <section>
              <h4>{words.drawerAttempts}</h4>
              <dl>
                {data.attempts.reviewState && (
                  <>
                    <dt>{words.drawerReview}</dt>
                    <dd>{data.attempts.reviewState}</dd>
                  </>
                )}
                <dt>{words.drawerSendBacks}</dt>
                <dd>{data.attempts.sendBacks}</dd>
                <dt>{words.drawerFreeAttempts}</dt>
                <dd>{data.attempts.freeAttempts}</dd>
                <dt>{words.drawerCeilingReleases}</dt>
                <dd>{data.attempts.ceilingReleases}</dd>
                <dt>{words.drawerReviewerMisses}</dt>
                <dd>{data.attempts.reviewerMisses}</dd>
                {data.attempts.dispatchedAt && (
                  <>
                    <dt>{words.drawerStarted}</dt>
                    <dd>{ago(data.attempts.dispatchedAt)}</dd>
                  </>
                )}
                {data.attempts.finishedAt && (
                  <>
                    <dt>{words.drawerFinished}</dt>
                    <dd>{ago(data.attempts.finishedAt)}</dd>
                  </>
                )}
              </dl>
            </section>
          )}
          {card.kind === "job" && (
            <section>
              <h4>{words.drawerEffects}</h4>
              {data.effects.length === 0 ? (
                <p className="queen27-drawer-note">{words.drawerEmpty}</p>
              ) : (
                <ol>
                  {data.effects.map((effect, index) => (
                    <li key={index}>
                      {words.drawerEffectStep} {effect.step ?? "?"} · {effect.runs} {words.drawerEffectRuns} · {ago(effect.updatedAt) ?? ""}
                    </li>
                  ))}
                </ol>
              )}
            </section>
          )}
          <section>
            <h4>{words.drawerTimeline}</h4>
            {data.timeline.length === 0 ? (
              <p className="queen27-drawer-note">{words.drawerEmpty}</p>
            ) : (
              <ol className="queen27-drawer-timeline">
                {data.timeline.flatMap((event) => {
                  const word = EVENT_WORD[event.kind];
                  if (!word) return [];
                  return [
                    <li key={event.seq} data-event={event.name}>
                      <time dateTime={event.at}>{ago(event.at)}</time>
                      <span>
                        {words[word]}
                        {event.verdict ? `: ${event.verdict}` : ""}
                        {event.outcome ? `: ${event.outcome}` : ""}
                      </span>
                    </li>,
                  ];
                })}
              </ol>
            )}
          </section>
        </>
      )}
    </aside>,
    document.body,
  );
}
