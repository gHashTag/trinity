import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import { COURSE, type CourseLesson } from '../lib/course.generated'
import './Course.css'

// Every word, the order of the lessons and the widget each one opens come from
// specs/course/course.t27 (and its Russian bundle) through
// scripts/course-from-spec.mjs. This file only draws them: a reader-visible
// string written here instead of in the spec is a bug (skill course-forge).

type Lang = 'en' | 'ru'
type Say = (typeof COURSE.say)['en']
type Frame = { key: string; title: string; preview: string; height: number; page?: string; spec?: boolean }

const LESSONS = COURSE.lessons
const TOTAL = LESSONS.length
const ORIGIN = 'https://t27.ai/'
// Pages load from wherever the site is served (t27.ai, or app.t27.ai/game/);
// only absolute t27.ai addresses are made relative.
const local = (url: string) => (url.startsWith(ORIGIN) ? url.slice(ORIGIN.length) : url)
const fmt = (s: string, ...args: (string | number)[]) =>
  args.reduce<string>((out, a, i) => out.split(`{${i}}`).join(String(a)), s)

function readDone(): string[] {
  try {
    const raw = window.localStorage.getItem(COURSE.progressKey)
    const list = raw ? JSON.parse(raw) : []
    // Only ids the course still has: a renamed lesson must not inflate the count.
    return Array.isArray(list) ? list.filter((x): x is string => typeof x === 'string' && LESSONS.some((l) => l.id === x)) : []
  } catch {
    return []
  }
}

function useProgress() {
  const [done, setDone] = useState<string[]>(() => (typeof window === 'undefined' ? [] : readDone()))
  const toggle = useCallback((id: string) => {
    setDone((prev) => {
      const next = prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
      try {
        window.localStorage.setItem(COURSE.progressKey, JSON.stringify(next))
      } catch {
        // private mode: progress lives only as long as the tab
      }
      return next
    })
  }, [])
  return { done, toggle }
}

function CourseMap({ lang, say, done, current }: { lang: Lang; say: Say; done: string[]; current?: string }) {
  return (
    <ol className="course-map" aria-label={say.ALL}>
      {COURSE.modules.map((m) => (
        <li key={m.id} className="course-map-row">
          <div className="course-map-head">
            <span className="course-map-big" aria-hidden="true">
              {String(m.n).padStart(2, '0')}
            </span>
            <span className="course-map-n">{fmt(say.MODULE, m.n)}</span>
            <span className="course-map-title">{m[lang].title}</span>
            <span className="course-map-line">{m[lang].line}</span>
          </div>
          <div className="course-map-cells">
            {m.lessons.map((id) => {
              const l = LESSONS.find((x) => x.id === id)!
              const cls = ['course-cell', done.includes(id) ? 'is-done' : '', current === id ? 'is-current' : '']
                .filter(Boolean)
                .join(' ')
              return (
                <Link key={id} to={`/${COURSE.route}/${id}`} className={cls} aria-current={current === id ? 'page' : undefined}>
                  <span className="course-cell-n">{String(l.n).padStart(2, '0')}</span>
                  <span className="course-cell-title">{l[lang].title}</span>
                </Link>
              )
            })}
          </div>
        </li>
      ))}
    </ol>
  )
}

function Overview({ lang, say, done }: { lang: Lang; say: Say; done: string[] }) {
  const left = LESSONS.find((l) => !done.includes(l.id))
  const next = left ?? LESSONS[0]
  // All done: offer the course again from the start, not "continue" to lesson 1.
  const started = done.length > 0 && left !== undefined
  return (
    <div className="course-hero">
      <p className="course-kicker course-masthead">{say.KICKER}</p>
      <h1 className="course-title">{say.TITLE}</h1>
      <p className="course-lead">{say.LEAD}</p>
      <p className="course-desc">{say.DESCRIPTION}</p>
      <div className="course-hero-actions">
        <Link className="course-btn is-primary" to={`/${COURSE.route}/${next.id}`}>
          {started ? `${say.CONTINUE}: ${next[lang].title}` : say.START}
        </Link>
        <span className="course-progress">{fmt(say.PROGRESS, done.length, TOTAL)}</span>
      </div>
      <div className="course-bar" aria-hidden="true" style={{ gridTemplateColumns: `repeat(${TOTAL}, 1fr)` }}>
        {LESSONS.map((l) => (
          <span key={l.id} className={done.includes(l.id) ? 'is-done' : ''} />
        ))}
      </div>
      <p className="course-shape">{say.SHAPE}</p>
      <CourseMap lang={lang} say={say} done={done} />
      <CourseNotes say={say} />
    </div>
  )
}

function CourseNotes({ say }: { say: Say }) {
  return (
    <div className="course-notes">
      <p>{say.PRIVATE}</p>
      <p>{say.WIDGET_LANG}</p>
      <p>
        <a href={COURSE.source.publicSpec.replace(/^public\//, '')} target="_blank" rel="noreferrer">
          {say.SOURCE}
        </a>
      </p>
      <p>
        <Link to={`/${COURSE.cohortRoute}`}>{say.COHORT}</Link>
      </p>
    </div>
  )
}

type Also = { id: string; title: string; preview: string | null; height: number; url: string }
const alsoOf = (l: CourseLesson) => l.also as readonly Also[]

/** Widgets with no framable page (a site tab, not a widget page) open as links, never as an empty frame. */
function linksOf(l: CourseLesson) {
  return alsoOf(l)
    .filter((w) => !w.preview)
    .map((w) => ({ key: w.id, title: w.title, page: local(w.url) }))
}

function framesOf(l: CourseLesson): Frame[] {
  const main: Frame = { key: l.widget.id, title: l.widget.title, preview: l.widget.preview, height: l.widget.height, page: local(l.widget.url) }
  const also: Frame[] = alsoOf(l)
    .filter((w) => w.preview)
    .map((w) => ({ key: w.id, title: w.title, preview: w.preview!, height: w.height, page: local(w.url) }))
  const spec: Frame[] = l.spec ? [{ key: 'spec', title: l.spec.path, preview: l.spec.preview, height: l.spec.height, spec: true }] : []
  return [main, ...spec, ...also]
}

function Lesson({ lesson, lang, say, done, toggle }: { lesson: CourseLesson; lang: Lang; say: Say; done: string[]; toggle: (id: string) => void }) {
  const frames = useMemo(() => framesOf(lesson), [lesson])
  const links = useMemo(() => linksOf(lesson), [lesson])
  const [key, setKey] = useState(frames[0].key)
  useEffect(() => {
    setKey(frames[0].key)
    window.scrollTo(0, 0)
  }, [lesson.id, frames])
  const frame = frames.find((f) => f.key === key) ?? frames[0]
  const mod = COURSE.modules.find((m) => m.id === lesson.module)!
  const i = lesson.n - 1
  const prev = i > 0 ? LESSONS[i - 1] : null
  const next = i < TOTAL - 1 ? LESSONS[i + 1] : null
  const isDone = done.includes(lesson.id)
  const t = lesson[lang]

  return (
    <article className="course-lesson">
      <nav className="course-crumbs">
        <Link to={`/${COURSE.route}`}>{say.ALL}</Link>
        <span>
          {fmt(say.MODULE, mod.n)} · {mod[lang].title}
        </span>
        <span>{fmt(say.LESSON, lesson.n, TOTAL)}</span>
      </nav>

      <header className="course-lesson-head">
        <span className="course-lesson-n" aria-hidden="true">
          {String(lesson.n).padStart(2, '0')}
        </span>
        <h1 className="course-lesson-title">{t.title}</h1>
        <p className="course-goal">
          <span className="course-label">{say.GOAL}</span>
          {t.goal}
        </p>
      </header>

      <div className="course-lesson-grid">
        <div className="course-lesson-text">
          <p className="course-dropcap">{t.text}</p>
          <div className="course-task">
            <span className="course-label">{say.TRY}</span>
            <p>{t.task}</p>
          </div>
          <button type="button" className={`course-btn course-mark${isDone ? ' is-done' : ''}`} aria-pressed={isDone} onClick={() => toggle(lesson.id)}>
            {isDone ? `✓ ${say.MARKED}` : say.MARK}
          </button>
        </div>

        <div className="course-stage">
          <div className="course-frame-tabs" role="tablist">
            {frames.map((f, n) => (
              <button
                key={f.key}
                type="button"
                role="tab"
                aria-selected={f.key === frame.key}
                className={`course-chip${f.key === frame.key ? ' is-on' : ''}${f.spec ? ' is-spec' : ''}`}
                onClick={() => setKey(f.key)}
              >
                {n === 0 ? <span data-lang-exempt="widget-title">{f.title}</span> : f.spec ? say.SPEC : <span data-lang-exempt="widget-title">{f.title}</span>}
              </button>
            ))}
          </div>
          {links.length > 0 ? (
            <div className="course-frame-tabs">
              {links.map((w) => (
                <a key={w.key} className="course-chip" href={w.page} target="_blank" rel="noreferrer">
                  <span data-lang-exempt="widget-title">{w.title}</span> ↗
                </a>
              ))}
            </div>
          ) : null}
          {lesson.also.length > 0 ? (
            <p className="course-hint">
              {say.ALSO}: {say.ALSO_HINT}
            </p>
          ) : null}
          <div className="course-frame" style={{ height: frame.height }}>
            <iframe key={frame.preview} src={frame.preview} title={frame.title} loading="lazy" allow="clipboard-write" />
          </div>
          <div className="course-frame-foot">
            {frame.key !== frames[0].key ? (
              <button type="button" className="course-link" onClick={() => setKey(frames[0].key)}>
                ← {say.BACK_TO_MAIN}
              </button>
            ) : (
              <span />
            )}
            {frame.page ? (
              <a className="course-link" href={frame.page} target="_blank" rel="noreferrer">
                {say.OPEN_PAGE} ↗
              </a>
            ) : (
              <span className="course-link-muted" data-lang-exempt="spec-path">
                {frame.title}
              </span>
            )}
          </div>
        </div>
      </div>

      <nav className="course-pager">
        {prev ? (
          <Link className="course-pager-link" to={`/${COURSE.route}/${prev.id}`}>
            <span className="course-label">← {say.PREV}</span>
            {prev[lang].title}
          </Link>
        ) : (
          <span />
        )}
        {next ? (
          <Link className="course-pager-link is-next" to={`/${COURSE.route}/${next.id}`}>
            <span className="course-label">{say.NEXT} →</span>
            {next[lang].title}
          </Link>
        ) : (
          <span />
        )}
      </nav>

      <CourseMap lang={lang} say={say} done={done} current={lesson.id} />
      <p className="course-progress is-foot">{fmt(say.PROGRESS, done.length, TOTAL)}</p>
      <CourseNotes say={say} />
    </article>
  )
}

export default function Course() {
  const { lessonId } = useParams<{ lessonId?: string }>()
  const { lang: siteLang } = useI18n()
  const lang: Lang = siteLang === 'ru' ? 'ru' : 'en'
  const say = COURSE.say[lang] as Say
  const { done, toggle } = useProgress()
  const lesson = lessonId ? LESSONS.find((l) => l.id === lessonId) : undefined
  usePageMeta(lesson ? `${lesson[lang].title} · ${say.KICKER}` : say.TITLE, lesson ? lesson[lang].goal : say.DESCRIPTION)

  return (
    <div className="course-page">
      <Navigation />
      <main className="course-main">
        {lessonId && !lesson ? (
          <div className="course-hero">
            <p className="course-lead">{say.NOT_FOUND}</p>
            <Link className="course-btn" to={`/${COURSE.route}`}>
              {say.ALL}
            </Link>
          </div>
        ) : lesson ? (
          <Lesson lesson={lesson} lang={lang} say={say} done={done} toggle={toggle} />
        ) : (
          <Overview lang={lang} say={say} done={done} />
        )}
      </main>
      <Footer />
    </div>
  )
}
