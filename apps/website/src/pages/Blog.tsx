import { Link, useParams } from 'react-router-dom'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import { publishedPosts, postBySlug, type Block, type Post } from '../data/blog/posts'
import { useI18n } from '../i18n/context'

// The blog was English-only whatever the language switcher said. These are the
// page's own words; a post's words travel with the post, in its `ru` field.
const UI = {
  en: {
    blog: 'Blog',
    lede: 'Measured results and the methods behind them. Published here first; every other channel links back to this page.',
    empty: 'No posts published yet. Drafts exist but still have gaps — a post goes live when every number in it can be traced to an artefact.',
    openLabel: 'Not proven / still open',
    receipts: 'Receipts',
    notPublished: 'Not published',
    missing: 'This post either does not exist or is still a draft.',
    back: 'Back to the blog',
    allPosts: '← All posts',
    min: 'min',
    onlyEnglish: 'This post has not been translated yet, so it is shown in English.',
  },
  ru: {
    blog: 'Блог',
    lede: 'Измеренные результаты и методы, которыми они получены. Публикуется сначала здесь; все остальные площадки ссылаются сюда.',
    empty: 'Опубликованных постов пока нет. Черновики есть, но в них остались пробелы — пост выходит, когда каждую цифру в нём можно возвести к артефакту.',
    openLabel: 'Не доказано / остаётся открытым',
    receipts: 'Чем это подтверждено',
    notPublished: 'Не опубликовано',
    missing: 'Этого поста либо нет, либо он ещё черновик.',
    back: 'Вернуться в блог',
    allPosts: '← Все посты',
    min: 'мин',
    onlyEnglish: 'Этот пост ещё не переведён и показан по-английски.',
  },
} as const

/** A post in the reader's language, or the English one when there is no translation. */
function localise(post: Post, lang: string): Post {
  return lang === 'ru' && post.ru ? { ...post, ...post.ru } : post
}

function ui(lang: string) {
  return lang === 'ru' ? UI.ru : UI.en
}

const wrap: React.CSSProperties = {
  maxWidth: '760px',
  margin: '0 auto',
  padding: '120px 24px 80px',
}

const meta: React.CSSProperties = {
  color: 'var(--text-dim, #8a8a8a)',
  fontSize: '0.85rem',
  letterSpacing: '0.04em',
  textTransform: 'uppercase',
}

const card: React.CSSProperties = {
  display: 'block',
  padding: '24px',
  border: '1px solid var(--border, #2a2a2a)',
  borderRadius: '10px',
  marginBottom: '20px',
  textDecoration: 'none',
  color: 'inherit',
}

function renderBlock(b: Block, i: number) {
  switch (b.kind) {
    case 'h':
      return (
        <h2 key={i} style={{ marginTop: '2.4em', marginBottom: '0.6em', fontSize: '1.4rem' }}>
          {b.text}
        </h2>
      )
    case 'p':
      return (
        <p key={i} style={{ lineHeight: 1.75, marginBottom: '1.1em' }}>
          {b.text}
        </p>
      )
    case 'ul':
      return (
        <ul key={i} style={{ lineHeight: 1.75, marginBottom: '1.1em', paddingLeft: '1.2em' }}>
          {b.items.map((it, j) => (
            <li key={j} style={{ marginBottom: '0.5em' }}>
              {it}
            </li>
          ))}
        </ul>
      )
    case 'ol':
      return (
        <ol key={i} style={{ lineHeight: 1.75, marginBottom: '1.1em', paddingLeft: '1.2em' }}>
          {b.items.map((it, j) => (
            <li key={j} style={{ marginBottom: '0.5em' }}>
              {it}
            </li>
          ))}
        </ol>
      )
    case 'quote':
      return (
        <blockquote
          key={i}
          style={{
            borderLeft: '3px solid var(--accent, #d4af37)',
            margin: '1.6em 0',
            padding: '0.2em 0 0.2em 1.2em',
            fontStyle: 'italic',
            lineHeight: 1.7,
          }}
        >
          {b.text}
        </blockquote>
      )
    case 'code':
      return (
        <pre
          key={i}
          style={{
            background: 'var(--bg-alt, #111)',
            border: '1px solid var(--border, #2a2a2a)',
            borderRadius: '8px',
            padding: '16px',
            overflowX: 'auto',
            fontSize: '0.85rem',
            lineHeight: 1.6,
            marginBottom: '1.4em',
          }}
        >
          <code>{b.text}</code>
        </pre>
      )
    case 'table':
      return (
        <div key={i} style={{ overflowX: 'auto', marginBottom: '1.6em' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.92rem' }}>
            <thead>
              <tr>
                {b.head.map((h, j) => (
                  <th
                    key={j}
                    style={{
                      textAlign: 'left',
                      padding: '10px 12px',
                      borderBottom: '1px solid var(--accent, #d4af37)',
                    }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {b.rows.map((r, j) => (
                <tr key={j}>
                  {r.map((c, k) => (
                    <td
                      key={k}
                      style={{ padding: '10px 12px', borderBottom: '1px solid var(--border, #2a2a2a)' }}
                    >
                      {c}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )
  }
}

/** Renders before the body on purpose: what is not proven comes first, not last. */
function OpenQuestions({ post, lang }: { post: Post; lang: string }) {
  if (!post.openQuestions.length) return null
  return (
    <section
      style={{
        border: '1px solid var(--border, #2a2a2a)',
        borderLeft: '3px solid var(--accent, #d4af37)',
        borderRadius: '8px',
        padding: '18px 20px',
        margin: '2em 0',
      }}
    >
      <div style={{ ...meta, marginBottom: '10px' }}>{ui(lang).openLabel}</div>
      <ul style={{ margin: 0, paddingLeft: '1.2em', lineHeight: 1.7 }}>
        {post.openQuestions.map((q, i) => (
          <li key={i} style={{ marginBottom: '0.4em' }}>
            {q}
          </li>
        ))}
      </ul>
    </section>
  )
}

function Receipts({ post, lang }: { post: Post; lang: string }) {
  if (!post.receipts.length) return null
  return (
    <section style={{ margin: '2.4em 0' }}>
      <div style={{ ...meta, marginBottom: '10px' }}>{ui(lang).receipts}</div>
      <ul style={{ margin: 0, paddingLeft: '1.2em', lineHeight: 1.8 }}>
        {post.receipts.map((r, i) => (
          <li key={i}>
            <a href={r.href} target="_blank" rel="noopener noreferrer">
              {r.label}
            </a>
          </li>
        ))}
      </ul>
    </section>
  )
}

export function BlogIndex() {
  const { lang } = useI18n()
  const t = ui(lang)
  const items = publishedPosts().map((p) => localise(p, lang))
  return (
    <main>
      <Navigation />
      <div style={wrap}>
        <h1 style={{ marginBottom: '0.3em' }}>{t.blog}</h1>
        <p style={{ color: 'var(--text-dim, #8a8a8a)', marginBottom: '2.4em', lineHeight: 1.7 }}>
          {t.lede}
        </p>

        {items.length === 0 ? (
          <p style={{ color: 'var(--text-dim, #8a8a8a)' }}>
            {t.empty}
          </p>
        ) : (
          items.map((p) => (
            <Link key={p.slug} to={`/blog/${p.slug}`} style={card}>
              <div style={meta}>
                {p.date} · {p.readingMinutes} {t.min} · {p.tags.join(' · ')}
              </div>
              <h2 style={{ margin: '10px 0 8px', fontSize: '1.25rem' }}>{p.title}</h2>
              <p style={{ margin: 0, lineHeight: 1.7, color: 'var(--text-dim, #8a8a8a)' }}>
                {p.summary}
              </p>
            </Link>
          ))
        )}
      </div>
      <Footer />
    </main>
  )
}

export function BlogPost() {
  const { slug } = useParams<{ slug: string }>()
  const { lang } = useI18n()
  const t = ui(lang)
  const source = slug ? postBySlug(slug) : undefined
  const post = source ? localise(source, lang) : undefined

  if (!post || !post.published) {
    return (
      <main>
        <Navigation />
        <div style={wrap}>
          <h1>{t.notPublished}</h1>
          <p style={{ lineHeight: 1.7 }}>
            {t.missing}{' '}
            <Link to="/blog">{t.back}</Link>.
          </p>
        </div>
        <Footer />
      </main>
    )
  }

  return (
    <main>
      <Navigation />
      <article style={wrap}>
        <div style={meta}>
          {post.date} · {post.readingMinutes} {t.min} · {post.tags.join(' · ')}
        </div>
        <h1 style={{ margin: '12px 0 16px', lineHeight: 1.25 }}>{post.title}</h1>
        <p style={{ fontSize: '1.05rem', lineHeight: 1.75, color: 'var(--text-dim, #8a8a8a)' }}>
          {post.summary}
        </p>

        <OpenQuestions post={post} lang={lang} />
        {post.body.map(renderBlock)}
        <Receipts post={post} lang={lang} />

        <p style={{ marginTop: '3em' }}>
          <Link to="/blog">{t.allPosts}</Link>
        </p>
      </article>
      <Footer />
    </main>
  )
}

export default BlogIndex
