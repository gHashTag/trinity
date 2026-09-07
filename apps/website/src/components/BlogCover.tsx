import { useState } from 'react'
import { BLOG_COVER_CAPTIONS, BLOG_COVER_VERSIONS } from '../data/blog/coverVersions'

type Props = {
  slug: string
  title: string
  lang: string
  className: string
  priority?: boolean
}

/** Whole triptychs: cards stay non-interactive inside their article Link;
 * article heroes expose full-size viewing and verified panel transcriptions. */
export default function BlogCover({ slug, title, lang, className, priority = false }: Props) {
  const locale = lang === 'ru' ? 'ru' : 'en'
  const version = BLOG_COVER_VERSIONS[slug]?.[locale]
  const src = `/og-blog-${slug}${locale === 'ru' ? '-ru' : ''}.png${version ? `?v=${version}` : ''}`
  const [failedSrc, setFailedSrc] = useState<string | null>(null)
  if (failedSrc === src) return null

  const entry = BLOG_COVER_CAPTIONS[slug]
  const panelLang = entry?.[locale] ? locale : 'en'
  const panels = entry?.[panelLang] ?? []
  const alt = `${locale === 'ru' ? 'Гравюрный триптих к статье' : 'Three-panel engraved illustration for'}: ${title}`
    + (panels.length ? `. ${panels.map(p => p.heading).join(' / ')}` : '')
  const fullSize = locale === 'ru'
    ? 'Открыть полный триптих в исходном размере' : 'View the complete triptych at full size'
  const picture = (
    <img src={src} alt={alt} width={1200} height={630}
      loading={priority ? 'eager' : 'lazy'} decoding="async"
      className={className} onError={() => setFailedSrc(src)} />
  )

  // A BlogCard already wraps this in a router Link. Never nest a link or
  // button inside it; only the standalone article hero is a figure/link.
  if (!priority) return picture
  return (
    <figure className="blog-cover-figure">
      <a href={src} target="_blank" rel="noopener" aria-label={`${fullSize} — ${title}`}>
        {picture}
      </a>
      <figcaption>
        {panels.length > 0 && <>
          <span>{locale === 'ru' ? 'Три панели, слева направо' : 'Three panels, left to right'}</span>
          {locale === 'ru' && panelLang === 'en' && (
            <p className="blog-cover-language">Подписи на изображении — на английском.</p>
          )}
          <ol className="blog-cover-panels" lang={panelLang}>
            {panels.map((panel, index) => (
              <li key={index}><strong>{panel.heading}</strong><span>{panel.caption}</span></li>
            ))}
          </ol>
        </>}
        <a href={src} target="_blank" rel="noopener" aria-label={`${fullSize} — ${title}`}>
          {fullSize}
        </a>
      </figcaption>
    </figure>
  )
}
