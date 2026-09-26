// Which DIRECTION a task belongs to — CRM, content, code, and the four other
// things this board actually spends its days on — and the colour that lets a
// reader pick one out of a thousand cards without reading a thousand titles.
//
// WHY THIS IS DERIVED AND NOT FETCHED
//
// The wire says nothing about direction. `GET /queen/public-board` sends each
// card as `{number, title, column, criteria, needs}` and no labels at all, so
// there is no field to read: measured on the live board, 1100 of 1100 cards
// carry those five keys and nothing else. Either the hive learns to label
// (a server change and a separate deploy) or the browser reads the title it
// was already sent. This is the second. It adds no request, asks the hive for
// nothing new, and cannot show a reader a card the server did not send —
// exactly the property lib/hiveBoard.ts insists on for the clients lane.
//
// WHY SEVEN AND NOT THREE
//
// The ask was "CRM, code, content". On this board those three are not a
// description of the work. Measured on the live board the day this was written:
// content 5 cards and CRM 4, against 354 code, 90 hardware, 88 proof and 76
// infra — so everything that is not those nine cards would have had to be
// called "code". A filter that paints the whole board one colour tells the
// reader nothing they did not already know. The three asked for are all here,
// by name and first; the four the board is actually made of are here beside
// them. The reader sees the real distribution, which was the point of the ask:
// "so that any direction can be picked out".
//
// WHY `other` IS A DIRECTION AND NOT A DEFAULT
//
// 483 of the 1100 cards match no rule, and 383 of those are the finished ones
// the hive sends as a bare `#1234` with no title to read at all. Of the 717
// cards that do have a title, 126 still match nothing — and only 86 of those
// are unfinished work. Those are not code. Calling them code would be a guess
// wearing a colour, and a colour is read as a fact. `other` is the honest name
// for "this title said nothing": it is grey, and its count rides on its chip so
// the size of the blind spot is on screen instead of hidden inside the biggest
// bucket.
//
// (The 383 titleless cards are a defect in what the hive SENDS, not in what is
// read here. It belongs to the agent server and costs a separate deploy.)
//
// ORDER IS MEANING HERE
//
// The array below is BOTH the match order and the chip order — one list, so a
// rule cannot be added to the matcher and forgotten in the legend. Narrow
// subjects come first and `code` comes last of the matching rules, because
// "test", "build" and "refactor" are said about silicon and deploys too: a
// card that mentions both an FPGA and a test is hardware work with a test in
// it, not test work.
//
// COLOUR IS NEVER THE ONLY CHANNEL
//
// Every card carries the direction's short label in text next to its dot, and
// every chip carries its name. Two of these hues are hard to tell apart for a
// reader with red-green colour blindness; the text is why that costs them
// nothing.

export type DirectionKey =
  | "crm"
  | "content"
  | "hardware"
  | "proof"
  | "infra"
  | "code"
  | "other";

export interface Direction {
  key: DirectionKey;
  /** The card tint, the dot, and the chip. A CSS colour, not a token name. */
  color: string;
  /**
   * The chip label, and the tag drawn on every card of this direction. Both
   * languages sit on the entry rather than in the two COPY dictionaries, so a
   * direction added without its Russian is a missing field the compiler
   * refuses — not a key that qa/queen-language-contract.mjs has to notice.
   */
  en: string;
  ru: string;
  /**
   * Evidence in the title. Null for `other`, which is the absence of evidence
   * and must never be something a title can match into.
   */
  match: RegExp | null;
}

export const DIRECTIONS: readonly Direction[] = [
  {
    key: "crm",
    color: "#ff8a3d",
    en: "CRM",
    ru: "CRM",
    // No `checkout` here on purpose: it caught "fails on every clean checkout",
    // which is a git clone, not a customer.
    match:
      /\b(crm|client|clients|customer|customers|tenant|tenants|lead|leads|billing|invoice|subscription|onboarding|funnel)\b/i,
  },
  {
    key: "content",
    color: "#c77dff",
    en: "CONTENT",
    ru: "КОНТЕНТ",
    match:
      /\b(content|article|blog|landing|readme|docs?|documentation|wording|copywriting|translation|i18n|locale|locales|seo|newsletter|paper|abstract)\b/i,
  },
  {
    key: "hardware",
    color: "#ff5d73",
    en: "HARDWARE",
    ru: "ЖЕЛЕЗО",
    // `board` is missing and stays missing: this page is a board.
    match:
      /\b(fpga|verilog|vhdl|silicon|zynq|pluto|jtag|yosys|nextpnr|openfpgaloader|bitstream|rtl|asic|hardware|gpio|uart|fabric|igla|dma|prefetch)\b/i,
  },
  {
    key: "proof",
    color: "#5ec8ff",
    en: "PROOF",
    // The ordinary Russian abbreviation for "доказательство", and short on
    // purpose: this label is drawn on every single card, not only on the chip.
    ru: "ДОК-ВО",
    match:
      /\b(proof|proofs|prove[sdn]?|theorem|lemma|axiom|formal|coq|lean|invariant|invariants|parity|bit-exact|bitexact|equivalence|soundness)\b/i,
  },
  {
    key: "infra",
    color: "#7c9cff",
    en: "INFRA",
    ru: "ИНФРА",
    match:
      // `gate`, `seal`, `census`, `swarm` and `worker` are this board's own
      // words for its own machinery, and they were read off it rather than
      // guessed: they are the commonest nouns among the titles the first draft
      // of this table could not name.
      /\b(deploy|deploys|deployment|railway|docker|ci|cd|workflow|workflows|pipeline|cron|runner|runners|dns|certificate|tls|ssl|nginx|kubernetes|k8s|uptime|rollout|release|monitoring|gate|gates|seal|seals|sealed|census|audit|swarm|queue|dispatch|probe|health|watchdog|timer|daemon|worker|workers|bee|bees)\b/i,
  },
  {
    key: "code",
    color: "#00e58a",
    en: "CODE",
    ru: "КОД",
    match:
      // Same source as the infra list: the rest of the vocabulary this board
      // actually writes its tickets in. A word earns its place here only if it
      // is said about software and about nothing else — which is why `wave`
      // and `loop`, the two commonest words left over, are still absent. They
      // are how this project organises work, not what the work is about, and a
      // colour drawn from them would be a colour that means nothing.
      /\b(code|test|tests|build|builds|refactor|bug|fix|fixes|type|types|typecheck|lint|parser|parse|compiler|compile|api|ui|ux|css|swift|rust|zig|t27|module|modules|function|handler|route|routes|schema|migration|regression|crash|crashes|leak|import|imports|fail|fails|failing|broken|hang|hangs|flaky|assert|assertion|spec|specs|specify|contract|contracts|corpus|error|errors|defect|defects|declaration|declarations|enum|emit|emitted|regex|cli|backend|frontend|commit|commits|branch|merge|diff|patch|grammar|syntax|token|tokens|encode|encoding|decode|null|gen-c|gen-rust|gen-zig|gen-verilog|lowering|lower|ternary|json|array|struct|pointer|closure|codegen|overflow)\b/i,
  },
  {
    key: "other",
    color: "#8a8a8a",
    en: "OTHER",
    ru: "ПРОЧЕЕ",
    match: null,
  },
];

const BY_KEY = new Map<DirectionKey, Direction>(
  DIRECTIONS.map((direction) => [direction.key, direction]),
);

/**
 * The direction a title claims. First rule in DIRECTIONS order wins; a title
 * that claims nothing — including the bare `#1234` the hive sends for finished
 * work — is `other`, never a guess.
 */
export function directionOf(title: string | null | undefined): DirectionKey {
  const text = typeof title === "string" ? title : "";
  if (!text.trim()) return "other";
  for (const direction of DIRECTIONS) {
    if (direction.match && direction.match.test(text)) return direction.key;
  }
  return "other";
}

export function directionColor(key: DirectionKey): string {
  return BY_KEY.get(key)?.color ?? "#8a8a8a";
}

/** Russian for the Russian page, English everywhere else — same rule as Copy. */
export function directionLabel(key: DirectionKey, lang: string): string {
  const direction = BY_KEY.get(key);
  if (!direction) return key.toUpperCase();
  return lang === "ru" ? direction.ru : direction.en;
}

/**
 * How many of these cards fall in each direction, in DIRECTIONS order and
 * only for directions that are actually present. A chip for a direction with
 * no cards is a promise the board cannot keep.
 */
export function directionCounts<T extends { title?: string | null }>(
  cards: readonly T[],
): Array<{ key: DirectionKey; count: number }> {
  const tally = new Map<DirectionKey, number>();
  for (const card of cards) {
    const key = directionOf(card.title);
    tally.set(key, (tally.get(key) ?? 0) + 1);
  }
  return DIRECTIONS.filter((direction) => (tally.get(direction.key) ?? 0) > 0).map(
    (direction) => ({ key: direction.key, count: tally.get(direction.key) ?? 0 }),
  );
}

/**
 * The narrowing itself, and the only thing the chips do.
 *
 * It can hide and it can do nothing else: the result is always a subset of the
 * cards handed in, in the order they were handed in, whatever is in `narrow` —
 * an empty selection, a direction with no cards, a key from a newer build this
 * one has never heard of. Nothing here asks the hive anything, so no chip can
 * be turned into a question about somebody else's work.
 */
export function narrowByDirection<T extends { title?: string | null }>(
  cards: readonly T[],
  narrow: readonly DirectionKey[],
): T[] {
  if (narrow.length === 0) return [...cards];
  const wanted = new Set(narrow);
  return cards.filter((card) => wanted.has(directionOf(card.title)));
}
