export type Block =
  | { kind: 'p'; text: string }
  | { kind: 'h'; text: string }
  | { kind: 'ul'; items: string[] }
  | { kind: 'ol'; items: string[] }
  | { kind: 'quote'; text: string }
  | { kind: 'code'; text: string }
  | { kind: 'table'; head: string[]; rows: string[][] }
  | { kind: 'figure'; svg: string; caption: string }

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
