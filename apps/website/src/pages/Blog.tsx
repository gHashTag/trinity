import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import { publishedPosts, postBySlug } from '../data/blog/index'
import type { Block, Post, PostBody, PostMeta } from '../data/blog/types'
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
    share: 'Share',
    copyLink: 'Copy link',
    copied: 'Copied',
    feed: 'RSS',
    loading: 'Loading post…',
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
    share: 'Поделиться',
    copyLink: 'Скопировать ссылку',
    copied: 'Скопировано',
    feed: 'RSS',
    loading: 'Загрузка поста…',
  },
} as const

/** A post in the reader's language, or the English one when there is no translation. */
function localise(post: Post, lang: string): Post {
  return lang === 'ru' && post.ru ? { ...post, ...post.ru } : post
}

function localiseMeta(post: PostMeta, lang: string): PostMeta {
  return lang === 'ru' && post.ru ? { ...post, ...post.ru } : post
}

const bodyModules = import.meta.glob('../data/blog/bodies/*.ts') as Record<
  string,
  () => Promise<PostBody>
>

function loadPostBody(slug: string) {
  const loader = bodyModules[`../data/blog/bodies/${slug}.ts`]
  return loader ? loader() : Promise.resolve(undefined)
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
  border: '1px solid var(--border, #2a2a2a)',
  borderRadius: '12px',
  marginBottom: '24px',
  textDecoration: 'none',
  color: 'inherit',
  overflow: 'hidden',
}

/** Карточка поста в списке: обложка сверху, под ней мета и краткое содержание.
 *
 * Заголовок напечатан на самой обложке — том же файле, что уходит в og:image.
 * Поэтому текстовый заголовок в карточке показывается ТОЛЬКО когда картинка не
 * загрузилась: рядом с обложкой он читался как удвоенный заголовок, а без него
 * пост остался бы без названия там, где картинки нет (dev, локальный dist,
 * отключённые изображения). Для читалок заголовок есть всегда, скрытым.
 */
function BlogCard({ post, lang, minLabel }: { post: PostMeta; lang: string; minLabel: string }) {
  const [cover, setCover] = useState<'pending' | 'shown' | 'failed'>('pending')
  return (
    <Link to={`/blog/${post.slug}`} style={card} className="blog-card">
      {cover !== 'failed' && (
        <img
          src={`/og-blog-${post.slug}${lang === 'ru' ? '-ru' : ''}.png`}
          alt=""
          loading="lazy"
          width={1200}
          height={630}
          className="blog-card-cover"
          onLoad={() => setCover('shown')}
          onError={() => setCover('failed')}
        />
      )}
      <div className="blog-card-body">
        <div style={meta}>
          {post.date} · {post.readingMinutes} {minLabel} · {post.tags.join(' · ')}
        </div>
        <h2
          className={cover === 'shown' ? 'visually-hidden' : undefined}
          style={cover === 'shown' ? undefined : { margin: '10px 0 8px', fontSize: '1.25rem', fontWeight: 800 }}
        >
          {post.title}
        </h2>
        <p style={{ margin: '10px 0 0', lineHeight: 1.7, color: 'var(--text-dim, #8a8a8a)' }}>
          {post.summary}
        </p>
      </div>
    </Link>
  )
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
    case 'figure':
      // The SVG here is authored in this repository's own data files, never
      // supplied by a reader, so no untrusted markup reaches this path.
      return (
        <figure key={i} style={{ margin: '0 0 1.8em', overflowX: 'auto' }}>
          <div
            style={{ color: 'var(--fg, #e8e8e8)', width: '100%' }}
            dangerouslySetInnerHTML={{ __html: b.svg }}
          />
          <figcaption
            style={{
              fontSize: '0.86rem',
              opacity: 0.75,
              marginTop: '10px',
              lineHeight: 1.5,
            }}
          >
            {b.caption}
          </figcaption>
        </figure>
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
function OpenQuestions({ post, lang }: { post: PostMeta; lang: string }) {
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

function Receipts({ post, lang }: { post: PostMeta; lang: string }) {
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

/**
 * Адрес поста для репоста — статическая страница, НЕ hash-маршрут.
 *
 * Фрагмент после решётки браузер серверу не отправляет, поэтому бот любой
 * площадки читает метатеги главной страницы: карточка предпросмотра либо не
 * собирается вовсе, либо под каждым постом стоит один и тот же чужой
 * заголовок. У статической страницы есть свои og:title, og:description и
 * og:image, и она читается без JavaScript.
 */
export function postUrl(slug: string, lang = 'en') {
  return lang === 'ru'
    ? `https://t27.ai/ru/blog/${slug}/`
    : `https://t27.ai/blog/${slug}/`
}

/**
 * Share links, as plain intent URLs.
 *
 * No embedded platform widgets on purpose: every one of them is a third-party
 * script that reads the reader before they have decided to share anything. A
 * link costs nothing and tracks nobody.
 */
function Share({ post, lang }: { post: PostMeta; lang: string }) {
  const t = ui(lang)
  const [copied, setCopied] = useState(false)
  const url = postUrl(post.slug, lang)
  const u = encodeURIComponent(url)
  const title = encodeURIComponent(post.title)

  const targets = [
    { name: 'X', href: `https://twitter.com/intent/tweet?url=${u}&text=${title}` },
    { name: 'LinkedIn', href: `https://www.linkedin.com/sharing/share-offsite/?url=${u}` },
    { name: 'Telegram', href: `https://t.me/share/url?url=${u}&text=${title}` },
    { name: 'Hacker News', href: `https://news.ycombinator.com/submitlink?u=${u}&t=${title}` },
    { name: 'Reddit', href: `https://www.reddit.com/submit?url=${u}&title=${title}` },
  ]

  return (
    <section style={{ margin: '2.4em 0' }}>
      <div style={{ ...meta, marginBottom: '10px' }}>{t.share}</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', alignItems: 'center' }}>
        {targets.map((s) => (
          <a
            key={s.name}
            href={s.href}
            target="_blank"
            rel="noopener noreferrer"
            className="share-pill"
          >
            {s.name}
          </a>
        ))}
        <button
          type="button"
          onClick={() => {
            navigator.clipboard?.writeText(url).then(
              () => {
                setCopied(true)
                window.setTimeout(() => setCopied(false), 2000)
              },
              () => setCopied(false),
            )
          }}
          className="share-pill"
          style={{ background: 'none', cursor: 'pointer', fontFamily: 'inherit' }}
        >
          {copied ? t.copied : t.copyLink}
        </button>
      </div>
    </section>
  )
}

export function BlogIndex() {
  const { lang } = useI18n()
  const t = ui(lang)
  const items = publishedPosts().map((p) => localiseMeta(p, lang))
  return (
    <main>
      <Navigation />
      <div style={wrap}>
        <h1 style={{ marginBottom: '0.3em' }}>{t.blog}</h1>
        <p style={{ color: 'var(--text-dim, #8a8a8a)', marginBottom: '1em', lineHeight: 1.7 }}>
          {t.lede}
        </p>
        {/* Absolute, not a router link: the feed is a static file beside the
            SPA, and a hash route would never reach it. */}
        <p style={{ marginBottom: '2.4em' }}>
          <a href="https://t27.ai/rss.xml" target="_blank" rel="noopener noreferrer" className="blog-link">
            {t.feed}
          </a>
        </p>

        {items.length === 0 ? (
          <p style={{ color: 'var(--text-dim, #8a8a8a)' }}>
            {t.empty}
          </p>
        ) : (
          items.map((p) => <BlogCard key={p.slug} post={p} lang={lang} minLabel={t.min} />)
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
  const [body, setBody] = useState<PostBody>()

  useEffect(() => {
    let active = true
    setBody(undefined)
    if (source?.published) {
      loadPostBody(source.slug).then((loaded) => {
        if (active) setBody(loaded)
      })
    }
    return () => {
      active = false
    }
  }, [source?.slug, source?.published])

  if (!source || !source.published) {
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

  if (!body) {
    return (
      <main>
        <Navigation />
        <article style={wrap}>
          <div style={meta}>
            {source.date} · {source.readingMinutes} {t.min} · {source.tags.join(' · ')}
          </div>
          <h1 style={{ margin: '12px 0 16px', lineHeight: 1.25 }}>
            {localiseMeta(source, lang).title}
          </h1>
          <p style={{ lineHeight: 1.7 }}>{t.loading}</p>
        </article>
        <Footer />
      </main>
    )
  }

  const fullPost: Post = {
    ...source,
    body: body.body,
    ru: source.ru && body.ruBody ? { ...source.ru, body: body.ruBody } : undefined,
  }
  const post = localise(fullPost, lang)

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
        <Share post={post} lang={lang} />

        <p style={{ marginTop: '3em' }}>
          <Link to="/blog" className="blog-link">{t.allPosts}</Link>
        </p>
      </article>
      <Footer />
    </main>
  )
}

export default BlogIndex
