export type QueenReviewState =
  | "queenReviewPending"
  | "changesRequested"
  | "humanEscalation"
  | "reconciliationAnomaly";

export const REVIEW_STATES: QueenReviewState[] = [
  "queenReviewPending",
  "changesRequested",
  "humanEscalation",
  "reconciliationAnomaly",
];

export interface ReviewCard {
  column: string;
  reviewState?: QueenReviewState;
}

export interface ReviewLedger {
  cards: ReviewCard[];
  reviewQueues?: Record<QueenReviewState, number>;
}

export function emptyReviewCounts(): Record<QueenReviewState, number> {
  return {
    queenReviewPending: 0,
    changesRequested: 0,
    humanEscalation: 0,
    reconciliationAnomaly: 0,
  };
}

export function reviewStateOf(card: ReviewCard): QueenReviewState | null {
  // The public ledger supplies `column: review` and, additively, a
  // `reviewState`. On 2026-09-04 no review card carried the field. An absent
  // field is absent: it reads as a dash on the card and as null in the
  // queues. Naming it "reconciliationAnomaly" would print a ledger failure
  // nobody measured, and defaulting it to Queen debt would recreate the
  // false counter this model exists to avoid.
  const state = card.reviewState;
  return state && REVIEW_STATES.includes(state) ? state : null;
}

export function reviewUnclassified(board: ReviewLedger | null): number | null {
  if (!board) return null;
  let count = 0;
  for (const card of board.cards) {
    if (card.column === "review" && reviewStateOf(card) === null) count += 1;
  }
  return count;
}

export function reviewCounts(
  board: ReviewLedger | null,
): Record<QueenReviewState, number | null> {
  if (!board) {
    return {
      queenReviewPending: null,
      changesRequested: null,
      humanEscalation: null,
      reconciliationAnomaly: null,
    };
  }
  if (board.reviewQueues) return board.reviewQueues;
  const counts = emptyReviewCounts();
  let stated = 0;
  let inReview = 0;
  for (const card of board.cards) {
    if (card.column !== "review") continue;
    inReview += 1;
    const state = reviewStateOf(card);
    if (state === null) continue;
    stated += 1;
    counts[state] += 1;
  }
  // Cards sit in review but none says which queue it is in: the wire has not
  // stated the fact, so no queue may read 0. An empty column is an honest 0.
  if (inReview > 0 && stated === 0) {
    return {
      queenReviewPending: null,
      changesRequested: null,
      humanEscalation: null,
      reconciliationAnomaly: null,
    };
  }
  return counts;
}

export function publicIssueTitle(
  title: string,
  issue: number,
  lang: string,
): string {
  // GitHub tasks are English by policy now, but the public ledger still has
  // historical titles from before that gate. Do not make the English shell
  // silently violate its own language contract; keep the canonical title in
  // Russian mode and provide a truthful, linked identifier in English mode.
  if (lang === "en" && /[А-Яа-яЁё]/.test(title)) {
    return `Issue #${issue} — legacy title hidden by English-only GitHub policy`;
  }
  if (lang === "ru" && !/[А-Яа-яЁё]/.test(title)) {
    return `Задача #${issue} — оригинальное название доступно по ссылке`;
  }
  return title;
}

export function publicResearchText(
  text: string,
  nodeId: string,
  lang: string,
  kind: "label" | "detail" = "detail",
): string {
  const hasCyrillic = /[А-Яа-яЁё]/.test(text);
  const wrongLanguage = lang === "en" ? hasCyrillic : !hasCyrillic;
  if (!wrongLanguage) return text;
  if (lang === "ru") {
    return kind === "label"
      ? `Технология ${nodeId}`
      : `Публичные данные узла ${nodeId} доступны по его идентификатору.`;
  }
  return kind === "label"
    ? `Technology ${nodeId}`
    : `Public data for node ${nodeId} is available by its identifier.`;
}
