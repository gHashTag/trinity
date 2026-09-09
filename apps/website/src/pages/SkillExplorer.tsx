// Skill Explorer -- every published skill of the three repositories, and the
// .t27 spec it stands on.
//
// The same shell as /specs, over a different corpus: `public/skills/` is a
// vendored, committed mirror written by scripts/sync-skills.mjs and indexed at
// prebuild by scripts/skills-core.mjs. Vendoring costs drift, so the manifest
// records the exact commit of each source repository and the header shows it.
//
// The link to a spec is DECLARED (frontmatter `specs:`, or the site's own
// bindings.json for repositories whose files are not ours to edit) and the
// reverse direction is DERIVED at index time. A path merely mentioned in the
// prose is a candidate, drawn with its status: discovery is evidence, never
// acceptance.

import { useCallback, useEffect, useMemo, useState } from 'react'
import { useI18n } from '../i18n/context'
import { usePageMeta } from '../hooks/usePageMeta'
import { useHashParams } from '../hooks/useHashParams'
import { ExplorerHeader } from '../components/ExplorerHeader'
import { ExplorerLibrary, type ExplorerItem } from '../components/ExplorerLibrary'
import { SpecCodeView } from '../components/SpecCodeView'
import { SkillSpecChips } from '../components/SpecChips'
import { StackBar } from '../components/SpecGraphics'
import { C, panelBox, pill, tagChip, type Health } from '../lib/explorerTheme'
import { highlightMarkdown } from '../lib/highlight'
import { specExplorerHash } from '../lib/specCatalog'
import { canonicalSkillUrl, resolveManifestSkill, skillExplorerHash } from '../lib/skillsCatalog'
import {
  loadSkillSource,
  loadSkillsCore,
  loadSkillsManifest,
  prefetchSkill,
  type SkillEntry,
  type SkillsCore,
  type SkillsManifest,
} from '../lib/skillsLoader'

const UI = {
  en: {
    title: 'Skill Explorer',
    subtitle: 'Every published skill, and the .t27 spec it stands on',
    metaTitle: 'Skill Explorer',
    metaDescription:
      'Claude Code skills from the t27, trinity and bot-farm repositories, each linked to the .t27 spec it stands on, with coverage both ways.',
    note: 'Vendored corpus, linked to the spec corpus',
    back: '← Home',
    search: 'Search skills',
    allRepos: 'All repositories',
    tags: 'Tags',
    clear: 'Clear',
    skills: 'skills',
    noResults: 'No skill matches that search.',
    noneInGroup: 'No skill in this group.',
    pickSkill: 'Pick a skill from the library to read it and see what it stands on.',
    loading: 'Loading the catalog…',
    linkAll: 'All',
    linkBound: 'Bound',
    linkUnbound: 'No spec',
    linkBroken: 'Broken',
    layerSource: 'Skill',
    layerFrontmatter: 'Frontmatter',
    layerOutline: 'Outline',
    layerSpecs: 'Specs',
    layerCoverage: 'Coverage',
    healthOk: 'Declares a spec, and it resolves',
    healthWarn: 'No spec declared yet',
    healthFail: 'Declares a spec that does not resolve',
    declared: 'declared',
    candidate: 'mentioned in the text',
    missing: 'not in the corpus',
    ambiguous: 'more than one match',
    openSpec: 'Open the spec',
    viaFrontmatter: 'from the skill’s own frontmatter',
    viaSite: 'from the site’s bindings',
    viaBody: 'found in the text',
    noRefs: 'This skill names no spec. Every skill that relies on one should say so.',
    specsHint:
      'A declared spec is a claim the build checks: if it stops resolving, the site fails to build. A mentioned one is only evidence.',
    coverageTitle: 'Coverage',
    skillsWithoutSpec: 'Skills without a spec',
    specsWithSkill: 'Specs a skill stands on',
    baseline: 'without a spec: {n}, at most {max}',
    baselineHint: 'That ceiling may only come down. A change that raises it fails the build.',
    proposeSpec: 'Propose a spec',
    edit: 'Edit on GitHub',
    privateRepo: 'Private repository — no public link to the file',
    share: 'Share',
    copyLink: 'Copy link',
    copied: 'Copied',
    lines: 'lines',
    bytes: 'bytes',
    lang: 'language',
    langRu: 'Russian',
    langEn: 'English',
    langMixed: 'mixed',
    source: 'file',
    provenance: 'Skills from',
    snapshotDirty: 'uncommitted changes',
    sourceNote: 'A vendored copy, verified by SHA-256; the live file may have moved on.',
    verified: 'SHA-256 verified',
    withheld: '{n} more skills are in the repositories and not published here.',
    liveShell: 'runs a shell command when loaded',
    extras: 'extra files',
    noFrontmatter: 'no frontmatter',
    headings: 'headings',
    codeBlocks: 'code blocks',
    links: 'links',
    backToLibrary: 'All skills',
    detail: 'Skill',
    failed: 'The catalog could not be read:',
  },
  ru: {
    title: 'Обозреватель скилов',
    subtitle: 'Каждый опубликованный скил и спека .t27, на которой он стоит',
    metaTitle: 'Обозреватель скилов',
    metaDescription:
      'Скилы Claude Code из репозиториев t27, trinity и фермы ботов; каждый связан со спекой .t27, на которой стоит, покрытие в обе стороны.',
    note: 'Копия корпуса, связанная с корпусом спек',
    back: '← На главную',
    search: 'Поиск по скилам',
    allRepos: 'Все репозитории',
    tags: 'Метки',
    clear: 'Сбросить',
    skills: 'скилов',
    noResults: 'Ничего не найдено.',
    noneInGroup: 'В этой группе пусто.',
    pickSkill: 'Выберите скил слева — он откроется целиком, вместе со спеками, на которых стоит.',
    loading: 'Загружаю каталог…',
    linkAll: 'Все',
    linkBound: 'Со спекой',
    linkUnbound: 'Без спеки',
    linkBroken: 'Битые',
    layerSource: 'Скил',
    layerFrontmatter: 'Шапка',
    layerOutline: 'Оглавление',
    layerSpecs: 'Спеки',
    layerCoverage: 'Покрытие',
    healthOk: 'Спека объявлена и найдена',
    healthWarn: 'Спека ещё не объявлена',
    healthFail: 'Объявлена спека, которой нет',
    declared: 'объявлена',
    candidate: 'упомянута в тексте',
    missing: 'нет в корпусе',
    ambiguous: 'больше одного совпадения',
    openSpec: 'Открыть спеку',
    viaFrontmatter: 'из шапки самого скила',
    viaSite: 'из связей сайта',
    viaBody: 'найдена в тексте',
    noRefs: 'Скил не называет ни одной спеки. Тот, кто на спеку опирается, должен это сказать.',
    specsHint:
      'Объявленная спека — это заявление, которое проверяет сборка: перестанет находиться — сборка упадёт. Упомянутая — только свидетельство.',
    coverageTitle: 'Покрытие',
    skillsWithoutSpec: 'Скилы без спеки',
    specsWithSkill: 'Спеки, на которых стоят скилы',
    baseline: 'без спеки: {n}, не больше {max}',
    baselineHint: 'Этот потолок можно только опускать. Правка, которая его поднимает, роняет сборку.',
    proposeSpec: 'Предложить спеку',
    edit: 'Править на GitHub',
    privateRepo: 'Приватный репозиторий — публичной ссылки на файл нет',
    share: 'Поделиться',
    copyLink: 'Скопировать ссылку',
    copied: 'Скопировано',
    lines: 'строк',
    bytes: 'байт',
    lang: 'язык',
    langRu: 'русский',
    langEn: 'английский',
    langMixed: 'смешанный',
    source: 'файл',
    provenance: 'Скилы из',
    snapshotDirty: 'незакоммиченные правки',
    sourceNote: 'Копия, сверенная по SHA-256; живой файл мог уйти вперёд.',
    verified: 'SHA-256 сверен',
    withheld: 'Ещё {n} скилов есть в репозиториях и здесь не опубликованы.',
    liveShell: 'выполняет команду оболочки при загрузке',
    extras: 'файлы рядом',
    noFrontmatter: 'без шапки',
    headings: 'заголовков',
    codeBlocks: 'блоков кода',
    links: 'ссылок',
    backToLibrary: 'Все скилы',
    detail: 'Скил',
    failed: 'Каталог не прочитан:',
  },
} as const

type Ui = Record<keyof typeof UI.en, string>

const LAYERS = ['source', 'frontmatter', 'outline', 'specs', 'coverage'] as const
type LayerId = (typeof LAYERS)[number]

const TAG_FAMILIES = [
  { prefix: 'src/', label: 'repository' },
  { prefix: 'link/', label: 'spec link' },
  { prefix: 'lang/', label: 'language' },
  { prefix: 'has/', label: 'contains' },
  { prefix: 'issue/', label: 'problems' },
  { prefix: 'size/', label: 'size' },
]

const LINK_COLOR: Record<string, string> = { bound: C.accent, unbound: C.warn, broken: C.bad }

/** A skill in a public repository can be opened on GitHub; a private one cannot. */
function githubBase(entry: SkillEntry, manifest: SkillsManifest): { url: string | null; issues: string | null } {
  const source = manifest.generatedFrom.find((p) => p.repo.endsWith(`/${entry.repo}`))
  if (!source || source.private) return { url: null, issues: null }
  return {
    url: `https://github.com/${source.repo}/blob/${source.commit}/.claude/skills/${entry.dir}/${entry.source}`,
    issues: `https://github.com/${source.repo}/issues/new`,
  }
}

export default function SkillExplorer() {
  const { lang } = useI18n()
  const ui: Ui = lang === 'ru' ? UI.ru : UI.en
  usePageMeta(ui.metaTitle, ui.metaDescription)
  const params = useHashParams()
  const embedded = params.embedded

  const [manifest, setManifest] = useState<SkillsManifest | null>(null)
  const [core, setCore] = useState<SkillsCore | null>(null)
  const [selected, setSelected] = useState<SkillEntry | null>(null)
  const [source, setSource] = useState('')
  const [verified, setVerified] = useState(false)
  const [err, setErr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [layer, setLayer] = useState<LayerId>('source')
  const [query, setQuery] = useState('')
  const [repo, setRepo] = useState('')
  const [linkFilter, setLinkFilter] = useState<'all' | 'bound' | 'unbound' | 'broken'>('all')
  const [tagSel, setTagSel] = useState<string[]>([])
  const [openSpec, setOpenSpec] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  // Below this width the two panes cannot both be useful, so the library and
  // the detail take turns.
  const [phone, setPhone] = useState(() => (typeof window === 'undefined' ? false : window.innerWidth < 760))
  const [narrow, setNarrow] = useState(() => (typeof window === 'undefined' ? false : window.innerWidth < 1100))
  const [pane, setPane] = useState<'list' | 'detail'>('list')
  useEffect(() => {
    const onResize = () => {
      setPhone(window.innerWidth < 760)
      setNarrow(window.innerWidth < 1100)
    }
    onResize()
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  const pick = useCallback(
    async (entry: SkillEntry, pinned?: string) => {
      setSelected(entry)
      setSource('')
      setVerified(false)
      setErr(null)
      setOpenSpec(null)
      setLayer('source')
      setBusy(true)
      try {
        params.set(skillExplorerHash(entry.id, { embedded, sha256: pinned }))
        const text = await loadSkillSource(entry.id, pinned)
        setSource(text)
        setVerified(Boolean(pinned))
      } catch (e) {
        setErr(String(e instanceof Error ? e.message : e))
      } finally {
        setBusy(false)
      }
    },
    [embedded, params],
  )

  useEffect(() => {
    let alive = true
    loadSkillsManifest()
      .then((m) => {
        if (!alive) return
        setManifest(m)
        const wanted = params.get('skill')
        const pinned = params.get('sha256') ?? undefined
        try {
          const target = resolveManifestSkill(m, wanted)
          if (wanted) setPane('detail')
          void pick(target, wanted ? pinned : undefined)
        } catch (e) {
          setErr(String(e instanceof Error ? e.message : e))
          setPane('detail')
        }
      })
      .catch((e) => {
        if (!alive) return
        setErr(String(e instanceof Error ? e.message : e))
        setPane('detail')
      })
    loadSkillsCore()
      .then((c) => alive && setCore(c))
      .catch(() => {/* the coverage layer says so on its own */})
    return () => {
      alive = false
    }
    // Mount only: the deep link is read once, exactly as /specs reads it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // `?? []` creates a new array on every render, which would make every useMemo
  // below re-run for nothing.
  const skills = useMemo(() => manifest?.skills ?? [], [manifest])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return skills.filter((s) => {
      if (repo && s.repo !== repo) return false
      if (linkFilter !== 'all' && s.link !== linkFilter) return false
      if (tagSel.length && !tagSel.every((t) => s.tags.includes(t))) return false
      if (!q) return true
      return (
        s.id.toLowerCase().includes(q) ||
        s.name.toLowerCase().includes(q) ||
        s.description.toLowerCase().includes(q) ||
        s.specsDeclared.some((p) => p.toLowerCase().includes(q))
      )
    })
  }, [skills, query, repo, linkFilter, tagSel])

  const tagCounts = useMemo(() => {
    const acc: Record<string, number> = {}
    for (const s of filtered) for (const t of s.tags) acc[t] = (acc[t] ?? 0) + 1
    for (const t of Object.keys(manifest?.tags ?? {})) acc[t] = acc[t] ?? 0
    return acc
  }, [filtered, manifest])

  const items: ExplorerItem[] = useMemo(
    () =>
      filtered.map((s) => ({
        id: s.id,
        title: s.name || s.dir,
        subtitle: `${s.repo}/${s.dir}`,
        badge: s.id === manifest?.featured ? 'START HERE' : undefined,
        health: s.health as Health,
        tags: s.tags,
        haystack: `${s.id} ${s.name} ${s.description}`.toLowerCase(),
      })),
    [filtered, manifest],
  )

  const linkCounts = useMemo(() => {
    const acc = { bound: 0, unbound: 0, broken: 0 }
    for (const s of skills) acc[s.link] += 1
    return acc
  }, [skills])

  const lines = useMemo(() => (source ? highlightMarkdown(source) : []), [source])

  const gh = manifest && selected ? githubBase(selected, manifest) : { url: null, issues: null }

  const copy = useCallback(() => {
    if (!selected) return
    navigator.clipboard?.writeText(canonicalSkillUrl(selected.id)).then(
      () => {
        setCopied(true)
        window.setTimeout(() => setCopied(false), 1400)
      },
      () => {},
    )
  }, [selected])

  const proposeHref = (entry: SkillEntry) => {
    const base = manifest ? githubBase(entry, manifest).issues : null
    if (!base) return null
    const title = `${entry.dir}: which .t27 spec does this skill stand on?`
    const body = [
      `**Skill:** \`.claude/skills/${entry.dir}/${entry.source}\` (${entry.repo})`,
      `**Seen at:** ${canonicalSkillUrl(entry.id)}`,
      '',
      'This skill declares no spec, so the Skill Explorer lists it as unbound.',
      '',
      'If a spec already covers what it does, add the binding to its frontmatter:',
      '',
      '```yaml',
      'specs:',
      '  - specs/<area>/<file>.t27',
      '```',
      '',
      'If no spec covers it yet, this issue is the place to say what one would have to state.',
    ].join('\n')
    return `${base}?title=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}`
  }

  const box = panelBox(embedded)
  const showList = !phone || pane === 'list'
  const showDetail = !phone || pane === 'detail'

  return (
    <div
      className="spec-x"
      data-embedded={embedded ? '1' : undefined}
      style={{
        height: '100dvh',
        display: 'flex',
        flexDirection: 'column',
        background: C.bg,
        color: C.text,
        fontFamily: "'Outfit', system-ui, sans-serif",
        overflow: 'hidden',
      }}
    >
      {!embedded && (
        <ExplorerHeader
          title={ui.title}
          subtitle={ui.subtitle}
          back={ui.back}
          note={ui.note}
          provenance={manifest?.generatedFrom}
          provenanceLabel={ui.provenance}
          dirtyLabel={ui.snapshotDirty}
          narrow={narrow}
          phone={phone}
        />
      )}

      <div style={{ flex: 1, display: 'flex', minHeight: 0, minWidth: 0 }}>
        {showList && (
          <ExplorerLibrary
            items={items}
            selectedId={selected?.id ?? null}
            onPick={(item) => {
              const entry = skills.find((s) => s.id === item.id)
              if (entry) {
                setPane('detail')
                void pick(entry)
              }
            }}
            onPrefetch={(item) => void prefetchSkill(item.id)}
            query={query}
            setQuery={setQuery}
            categories={Object.entries(manifest?.bySource ?? {}).map(([r, n]) => [r, r, n] as [string, string, number])}
            category={repo}
            setCategory={setRepo}
            filters={[
              { key: 'all', label: ui.linkAll, count: skills.length },
              { key: 'bound', label: ui.linkBound, count: linkCounts.bound, color: C.accent, glyph: '◆' },
              { key: 'unbound', label: ui.linkUnbound, count: linkCounts.unbound, color: C.warn, glyph: '·' },
              { key: 'broken', label: ui.linkBroken, count: linkCounts.broken, color: C.bad, glyph: '✕' },
            ]}
            filter={linkFilter}
            setFilter={(v) => setLinkFilter(v as 'all' | 'bound' | 'unbound' | 'broken')}
            stack={[
              { key: 'bound', count: linkCounts.bound, color: C.accent, label: ui.linkBound },
              { key: 'unbound', count: linkCounts.unbound, color: C.warn, label: ui.linkUnbound },
              { key: 'broken', count: linkCounts.broken, color: C.bad, label: ui.linkBroken },
            ]}
            tagCounts={tagCounts}
            tagFamilies={TAG_FAMILIES}
            tagSel={tagSel}
            toggleTag={(t) => setTagSel((prev) => (prev.includes(t) ? prev.filter((x) => x !== t) : [...prev, t]))}
            clearTags={() => setTagSel([])}
            phone={phone}
            countLabel={`${filtered.length} ${ui.skills}`}
            titlesAreGenerated
            ui={{
              search: ui.search,
              allCategories: `${ui.allRepos} (${manifest?.skillCount ?? 0})`,
              tags: ui.tags,
              clear: ui.clear,
              noResults: ui.noResults,
              noneInGroup: ui.noneInGroup,
            }}
          />
        )}

        {showDetail && (
          <main style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, minHeight: 0, overflowY: phone ? 'auto' : 'hidden' }}>
            {err && (
              <div
                className="spec-x-banner"
                style={{
                  margin: '10px 14px 0',
                  padding: '9px 12px',
                  background: 'rgba(248,81,73,0.10)',
                  border: `1px solid ${C.bad}`,
                  borderRadius: 5,
                  fontSize: 12,
                  color: '#d8d8d8',
                }}
              >
                <span style={{ color: C.bad, fontWeight: 700 }}>⚠ {ui.failed}</span> {err}
              </div>
            )}
            {!selected && !err && (
              <div style={{ padding: 24, color: C.muted, fontSize: 13 }}>{manifest ? ui.pickSkill : ui.loading}</div>
            )}
            {selected && (
              <>
                {phone && (
                  <button onClick={() => setPane('list')} style={{ ...pill, alignSelf: 'flex-start', margin: '10px 14px 0' }}>
                    ← {ui.backToLibrary}
                  </button>
                )}
                {/* brief */}
                <div style={{ flexShrink: 0, padding: '10px 14px 0', display: 'flex', gap: 18, alignItems: 'flex-start', flexWrap: 'wrap' }}>
                  <div style={{ flex: '1 1 320px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                      <span style={{ fontSize: 15, fontWeight: 700, color: C.text }} data-lang-exempt="live">
                        {selected.name || selected.dir}
                      </span>
                      <span style={{ fontFamily: C.mono, fontSize: 11, color: C.muted }}>{selected.id}</span>
                      <span
                        title={selected.health === 'ok' ? ui.healthOk : selected.health === 'warn' ? ui.healthWarn : ui.healthFail}
                        style={{ ...tagChip(false, false), color: LINK_COLOR[selected.link], borderColor: LINK_COLOR[selected.link] }}
                      >
                        {selected.link === 'bound' ? ui.linkBound : selected.link === 'unbound' ? ui.linkUnbound : ui.linkBroken}
                      </span>
                    </div>
                    {selected.description && (
                      <p style={{ margin: 0, fontSize: 12.5, lineHeight: 1.55, color: '#b9bfc6' }} data-lang-exempt="live">
                        {selected.description}
                      </p>
                    )}
                    <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>
                      {selected.source} · {selected.lines} {ui.lines} · {selected.bytes} {ui.bytes} ·{' '}
                      {selected.lang === 'ru' ? ui.langRu : selected.lang === 'en' ? ui.langEn : ui.langMixed}
                      {verified ? ` · ${ui.verified}` : ''}
                    </div>
                    <div style={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
                      {selected.tags.map((t) => (
                        <button
                          key={t}
                          onClick={() => setTagSel((prev) => (prev.includes(t) ? prev : [...prev, t]))}
                          title={t}
                          style={tagChip(tagSel.includes(t), false)}
                        >
                          {t}
                        </button>
                      ))}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5, flexWrap: 'wrap' }}>
                      <span style={{ fontSize: 10, color: C.muted, opacity: 0.7, fontFamily: C.mono }}>{ui.share}</span>
                      <button onClick={copy} style={{ ...pill, color: copied ? C.accent : C.muted }}>
                        {copied ? ui.copied : ui.copyLink}
                      </button>
                      {gh.url ? (
                        <a href={gh.url} target="_blank" rel="noopener noreferrer" style={pill}>
                          {ui.edit}
                        </a>
                      ) : (
                        <span style={{ ...pill, cursor: 'default', opacity: 0.75 }}>{ui.privateRepo}</span>
                      )}
                      {selected.link !== 'bound' && proposeHref(selected) && (
                        <a href={proposeHref(selected) as string} target="_blank" rel="noopener noreferrer" style={{ ...pill, color: C.warn, borderColor: 'rgba(240,160,32,0.4)' }}>
                          {ui.proposeSpec}
                        </a>
                      )}
                    </div>
                  </div>
                </div>

                {/* layer tabs */}
                <div style={{ flexShrink: 0, display: 'flex', flexWrap: 'wrap', gap: 2, padding: '10px 14px 0' }}>
                  {LAYERS.map((id) => {
                    const active = layer === id
                    const label =
                      id === 'source' ? ui.layerSource : id === 'frontmatter' ? ui.layerFrontmatter : id === 'outline' ? ui.layerOutline : id === 'specs' ? ui.layerSpecs : ui.layerCoverage
                    const badge =
                      id === 'outline'
                        ? String(selected.headings.length)
                        : id === 'specs'
                          ? String(selected.specRefs.length)
                          : id === 'frontmatter'
                            ? String(Object.keys(selected.frontmatter).length)
                            : ''
                    return (
                      <button
                        key={id}
                        onClick={() => setLayer(id)}
                        aria-current={active ? 'true' : undefined}
                        style={{
                          display: 'flex',
                          alignItems: 'baseline',
                          gap: 6,
                          background: active ? C.raised : 'transparent',
                          border: `1px solid ${active ? C.borderBright : 'transparent'}`,
                          borderBottom: active ? `1px solid ${C.bg}` : `1px solid ${C.border}`,
                          borderRadius: '5px 5px 0 0',
                          color: active ? C.accent : C.muted,
                          padding: '6px 12px',
                          cursor: 'pointer',
                          fontSize: 12.5,
                          fontFamily: 'inherit',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        <span>{label}</span>
                        {badge && <span style={{ fontSize: 10, fontFamily: C.mono, opacity: 0.65 }}>{badge}</span>}
                      </button>
                    )
                  })}
                </div>

                {/* layer body */}
                <div style={{ flex: phone ? 'none' : 1, minHeight: phone ? '70vh' : 0, padding: '0 14px 14px', display: 'flex' }}>
                  <div
                    className="spec-x-pane spec-x-scroll"
                    data-pending={busy ? 'true' : 'false'}
                    style={{ ...box, flex: 1, minHeight: 0, borderTopLeftRadius: 0, ...(phone ? { overflow: 'visible' } : null) }}
                  >
                    <div className="spec-x-swap" key={`${selected.id}:${layer}`}>
                      {layer === 'source' && (
                        <SpecCodeView
                          lines={lines}
                          raw={source}
                          copyLabel={ui.copyLink}
                          copiedLabel={ui.copied}
                          meta={`${selected.path} · ${ui.sourceNote}`}
                        />
                      )}

                      {layer === 'frontmatter' && (
                        <div style={{ padding: 14, fontSize: 12.5 }}>
                          {Object.keys(selected.frontmatter).length === 0 ? (
                            <div style={{ color: C.warn }}>{ui.noFrontmatter}</div>
                          ) : (
                            <table style={{ borderCollapse: 'collapse', width: '100%' }}>
                              <tbody>
                                {Object.entries(selected.frontmatter).map(([k, v]) => (
                                  <tr key={k}>
                                    <td style={{ padding: '4px 12px 4px 0', color: C.golden, fontFamily: C.mono, verticalAlign: 'top', whiteSpace: 'nowrap' }}>{k}</td>
                                    <td style={{ padding: '4px 0', color: '#d8d8d8', wordBreak: 'break-word' }} data-lang-exempt="live">
                                      {v}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          )}
                          <div style={{ marginTop: 12, fontSize: 11, color: C.muted, fontFamily: C.mono }}>
                            {selected.headings.length} {ui.headings} · {selected.codeBlocks.length} {ui.codeBlocks} · {selected.links.length} {ui.links}
                            {selected.liveShell ? ` · ${ui.liveShell}` : ''}
                            {selected.extras.length ? ` · ${selected.extras.length} ${ui.extras}` : ''}
                          </div>
                        </div>
                      )}

                      {layer === 'outline' && (
                        <div style={{ padding: 14, fontSize: 12.5 }} data-lang-exempt="live">
                          {selected.headings.map((h, i) => (
                            <div
                              key={`${h.line}:${i}`}
                              style={{
                                paddingLeft: (h.level - 1) * 16,
                                color: h.level <= 2 ? C.text : C.muted,
                                fontWeight: h.level <= 2 ? 600 : 400,
                                lineHeight: 1.9,
                              }}
                            >
                              <span style={{ fontFamily: C.mono, fontSize: 10, opacity: 0.5, marginRight: 8 }}>{h.line}</span>
                              {h.text}
                            </div>
                          ))}
                        </div>
                      )}

                      {layer === 'specs' && (
                        <div style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10, minHeight: 0 }}>
                          {selected.specRefs.length === 0 ? (
                            <div style={{ color: C.warn, fontSize: 12.5 }}>{ui.noRefs}</div>
                          ) : (
                            <>
                              <SkillSpecChips
                                refs={selected.specRefs}
                                onOpen={(path) => setOpenSpec(path)}
                                labels={{
                                  declared: ui.declared,
                                  candidate: ui.candidate,
                                  missing: ui.missing,
                                  ambiguous: ui.ambiguous,
                                  openSpec: ui.openSpec,
                                  via: { frontmatter: ui.viaFrontmatter, site: ui.viaSite, body: ui.viaBody },
                                }}
                              />
                              <div style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{ui.specsHint}</div>
                              {openSpec && (
                                <div style={{ flex: 1, minHeight: 320, display: 'flex', flexDirection: 'column' }}>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                                    <span style={{ fontFamily: C.mono, fontSize: 11, color: C.accent }}>{openSpec}</span>
                                    <a href={specExplorerHash(openSpec)} style={{ ...pill, marginLeft: 'auto' }}>
                                      {ui.openSpec}
                                    </a>
                                  </div>
                                  <iframe
                                    title={openSpec}
                                    // The frame is a document of its own: it boots
                                    // with whatever localStorage said, so the
                                    // language rides in the search, exactly as the
                                    // landing block does.
                                    src={`./?lang=${lang === 'ru' ? 'ru' : 'en'}${specExplorerHash(openSpec, { embedded: true })}`}
                                    sandbox="allow-scripts allow-same-origin"
                                    style={{ flex: 1, width: '100%', minHeight: 300, border: `1px solid ${C.border}`, borderRadius: 5, background: C.bg }}
                                  />
                                </div>
                              )}
                            </>
                          )}
                        </div>
                      )}

                      {layer === 'coverage' && (
                        <div style={{ padding: 14, fontSize: 12.5, display: 'flex', flexDirection: 'column', gap: 14 }}>
                          {!core && <div style={{ color: C.muted }}>{ui.loading}</div>}
                          {core && (
                            <>
                              <div>
                                <div style={{ color: C.muted, fontSize: 11, marginBottom: 6 }}>
                                  {ui.baseline.replace('{n}', String(core.coverage.skillsUnbound.length)).replace('{max}', String(core.coverage.baselineUnbound))}
                                </div>
                                <StackBar
                                  segments={[
                                    { key: 'bound', count: core.coverage.skillsBound.length, color: C.accent, label: ui.linkBound },
                                    { key: 'unbound', count: core.coverage.skillsUnbound.length, color: C.warn, label: ui.linkUnbound },
                                    { key: 'broken', count: core.coverage.skillsBroken.length, color: C.bad, label: ui.linkBroken },
                                  ]}
                                />
                                <div style={{ marginTop: 6, fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{ui.baselineHint}</div>
                              </div>
                              <div>
                                <div style={{ color: C.warn, fontWeight: 600, marginBottom: 6 }}>
                                  {ui.skillsWithoutSpec} ({core.coverage.skillsUnbound.length})
                                </div>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                                  {core.coverage.skillsUnbound.map((id) => {
                                    const entry = skills.find((s) => s.id === id)
                                    const href = entry ? proposeHref(entry) : null
                                    return (
                                      <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: C.mono, fontSize: 11.5 }}>
                                        <a href={skillExplorerHash(id)} style={{ color: C.text, textDecoration: 'none' }}>
                                          {id}
                                        </a>
                                        {href && (
                                          <a href={href} target="_blank" rel="noopener noreferrer" style={{ ...pill, fontSize: 9.5, padding: '0 7px' }}>
                                            {ui.proposeSpec}
                                          </a>
                                        )}
                                      </div>
                                    )
                                  })}
                                </div>
                              </div>
                              <div>
                                <div style={{ color: C.accent, fontWeight: 600, marginBottom: 6 }}>
                                  {ui.specsWithSkill} ({core.coverage.specsWithSkill.length})
                                </div>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                                  {core.coverage.specsWithSkill.map((path) => (
                                    <div key={path} style={{ display: 'flex', alignItems: 'baseline', gap: 8, fontFamily: C.mono, fontSize: 11.5 }}>
                                      <a href={specExplorerHash(path)} style={{ color: C.text, textDecoration: 'none' }}>
                                        {path}
                                      </a>
                                      <span style={{ color: C.muted, opacity: 0.7 }}>{(core.specToSkills[path] ?? []).map((i) => i.split('/')[1]).join(', ')}</span>
                                    </div>
                                  ))}
                                </div>
                              </div>
                              {manifest && manifest.withheld > 0 && (
                                <div style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>
                                  {ui.withheld.replace('{n}', String(manifest.withheld))}
                                </div>
                              )}
                            </>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </>
            )}
          </main>
        )}
      </div>
    </div>
  )
}
