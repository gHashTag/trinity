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

export function reviewStateOf(card: ReviewCard): QueenReviewState {
  // Old public ledgers supplied only `column: review`. Treating an unknown
  // owner as Queen debt recreates the false counter this screen is fixing, so
  // legacy/unclassified cards are anomalies until the additive field arrives.
  return card.reviewState ?? "reconciliationAnomaly";
}

export function reviewCounts(
  board: ReviewLedger | null,
): Record<QueenReviewState, number> {
  const counts = emptyReviewCounts();
  if (!board) return counts;
  if (board.reviewQueues) return board.reviewQueues;
  for (const card of board.cards) {
    if (card.column === "review") counts[reviewStateOf(card)] += 1;
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
  return title;
}
