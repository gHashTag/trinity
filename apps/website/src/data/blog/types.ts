export type Block =
  | { kind: 'p'; text: string }
  | { kind: 'h'; text: string }
  | { kind: 'ul'; items: string[] }
  | { kind: 'ol'; items: string[] }
  | { kind: 'quote'; text: string }
  | { kind: 'code'; text: string }
  | { kind: 'table'; head: string[]; rows: string[][] }
  | { kind: 'figure'; svg: string; caption: string }
  // A recorded terminal session (asciicast v2 under public/), replayed in the page by
  // TerminalCast; `share` is its page at /term/<id>/ (made by `tri cast publish`).
  | { kind: 'terminal'; src: string; title: string; caption: string; share?: string }

export interface PostRuMeta {
  title: string
  summary: string
  openQuestions: string[]
}

export interface PostMeta {
  slug: string
  title: string
  summary: string
  date: string
  readingMinutes: number
  tags: string[]
  receipts: { label: string; href: string }[]
  openQuestions: string[]
  published: boolean
  ru?: PostRuMeta
}

export interface Post extends PostMeta {
  body: Block[]
  ru?: PostRuMeta & { body: Block[] }
}

export interface PostBody {
  body: Block[]
  ruBody?: Block[]
}
