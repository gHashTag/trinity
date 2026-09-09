// The spec side of a skill or cron card, shared by both Explorers.
//
// A skill or a job is a fact only when a .t27 spec states it; the code the
// site's sync scripts scanned is the witness that the fact is also deployed.
// This panel shows the spec itself (its bytes, its hash, the compiler's verdict
// on it), where it can be changed, where the job can be started, and how it is
// linked to its neighbours — without inventing a control it does not have: a
// timer inside a process has no outside handle, and a page with no control
// plane configured says so instead of pretending a button does something.
//
// The copy lives here rather than in each page's UI literal because the two
// pages must say exactly the same thing about the same spec.

import { useCallback, useEffect, useMemo, useState } from 'react'
import { SpecCodeView } from './SpecCodeView'
import { C, pill, tagChip } from '../lib/explorerTheme'
import { highlightCode, highlightSource, type Span } from '../lib/highlight'
import { analyze } from '../lib/t27Compiler'
import { specExplorerHash } from '../lib/specCatalog'
import {
  type I18nContract,
  agentControlUrl,
  canonicalSpecEditUrl,
  loadAgentSpecSource,
  requestControl,
  specSlug,
  vendoredSpecUrl,
  WITNESS_LABEL,
  type ControlAction,
  type AgentSpecEntry,
  type FunctionSpecEntry,
  type CronSpecEntry,
  type SkillSpecEntry,
  type ToolSpecEntry,
} from '../lib/agentSpecs'

const COPY = {
  en: {
    spec: 'SPEC',
    control: 'CONTROL',
    links: 'LINKS',
    verdictOk: 'typecheck ok',
    verdictFail: 'typecheck failed',
    verdictNote: 'the compiler accepted the module; the field schema is checked by the generator, and both must hold',
    discarded: 'discarded',
    sha: 'sha256',
    shaVerified: 'bytes match the catalog hash',
    shaMismatch: 'served bytes differ from the catalog hash — the vendored copy and the generated JSON are out of step',
    shaUnchecked: 'hash not verified here (no WebCrypto)',
    openSpec: 'Open in Spec Explorer →',
    notInCorpus: 'not in the vendored corpus manifest yet (sync-t27-specs has not been re-run)',
    loading: 'loading the spec…',
    failed: 'could not load the spec:',
    codeOnly: 'This card is built from code only: no .t27 spec states it yet. The fields shown come from the sync script’s scan, not from a spec.',
    createSpec: 'Write the spec →',
    enabled: 'ENABLED',
    on: 'true',
    off: 'false',
    readOnly: 'read from the spec; change it there',
    editSpec: 'Edit in the spec →',
    vendored: 'vendored copy',
    runNow: 'Run now →',
    viaActions: 'GitHub Actions workflow page',
    viaRailway: 'Railway service',
    viaInngest: 'Inngest dashboard',
    timerDisabled: 'timer inside the process — controlled by the service’s deployment',
    unknownService: 'the Railway service id is not known to the site',
    skillRun: 'a skill is launched by an agent with its command; there is no run button without a control plane',
    command: 'command',
    noPlane: 'No control plane connected — actions go through the spec and the hosts’ panels',
    plane: 'control plane',
    actRun: 'run',
    actEnable: 'enable',
    actDisable: 'disable',
    sent: 'accepted',
    rejected: 'rejected',
    runs: 'runs skills',
    runBy: 'run by jobs',
    noRuns: 'names no skill',
    noRunBy: 'no job names this skill',
    holds: 'holds skills',
    noHolds: 'no source binds a skill to this letter',
    ownedBy: 'owned by agents',
    noOwnedBy: 'no source binds a letter to this tool',
    toolRun: 'a tool is read from its source (clap doc comments, MCP manifests); it is run from a terminal or by an MCP client, not from here',
    agentRun: 'an agent is a letter of the alphabet bound by SOUL.md and AGENTS.md; it is not launched from here — it holds skills, and jobs launch those',
    relates: 'related cards',
    noRelates: 'no cron card states this schedule; an event function has none',
    functionRun: 'an Inngest function runs when its event arrives or its cron fires; this page never sends an event — the safe probe of 2026-09-09 is recorded in the spec, not repeated here',
    unresolved: 'unresolved id',
    summary: 'summary',
    translations: 'translations',
    noTranslations: 'none declared',
    translationsTitle: 'Specs are English-only (t27 LANG-EN). Each locale is connected through a contract spec under specs/i18n/ that names the bundle carrying the text; n/total is how many entries of this catalog that bundle covers.',
    viaSpec: 'via',
    copy: 'copy',
    copied: 'copied',
    messages: 'generator notes',
  },
  ru: {
    spec: 'СПЕКА',
    control: 'УПРАВЛЕНИЕ',
    links: 'СВЯЗИ',
    verdictOk: 'типизация ок',
    verdictFail: 'типизация не прошла',
    verdictNote: 'компилятор принял модуль; схему полей проверяет генератор, и нужны оба',
    discarded: 'отброшено',
    sha: 'sha256',
    shaVerified: 'байты совпадают с хешем каталога',
    shaMismatch: 'отданные байты не совпадают с хешем каталога — вендорная копия и сгенерированный JSON разошлись',
    shaUnchecked: 'хеш здесь не проверен (нет WebCrypto)',
    openSpec: 'Открыть в Обозревателе спек →',
    notInCorpus: 'ещё не в манифесте вендорного корпуса (sync-t27-specs не перезапускался)',
    loading: 'загружаем спеку…',
    failed: 'не удалось загрузить спеку:',
    codeOnly: 'Эта карточка построена только из кода: спеки .t27 для неё ещё нет. Поля взяты из сканирования скриптом синхронизации, а не из спеки.',
    createSpec: 'Написать спеку →',
    enabled: 'ENABLED',
    on: 'true',
    off: 'false',
    readOnly: 'читается из спеки; менять там',
    editSpec: 'Изменить в спеке →',
    vendored: 'вендорная копия',
    runNow: 'Запустить сейчас →',
    viaActions: 'страница workflow в GitHub Actions',
    viaRailway: 'сервис в Railway',
    viaInngest: 'панель Inngest',
    timerDisabled: 'таймер внутри процесса — управляется деплоем сервиса',
    unknownService: 'id сервиса Railway сайту не известен',
    skillRun: 'скилл запускает агент по его команде; без контура управления кнопки запуска нет',
    command: 'команда',
    noPlane: 'Контур управления не подключён — действия идут через спеку и панели хостов',
    plane: 'контур управления',
    actRun: 'запустить',
    actEnable: 'включить',
    actDisable: 'выключить',
    sent: 'принято',
    rejected: 'отклонено',
    runs: 'запускает скиллы',
    runBy: 'запускается заданиями',
    noRuns: 'не называет ни одного скилла',
    noRunBy: 'ни одно задание не называет этот скилл',
    holds: 'держит скиллы',
    noHolds: 'ни один источник не привязывает скилл к этой букве',
    ownedBy: 'владеют агенты',
    noOwnedBy: 'ни один источник не привязывает букву к этому инструменту',
    toolRun: 'инструмент прочитан из своего исходника (док-комментарии clap, манифесты MCP); он запускается из терминала или MCP-клиентом, а не отсюда',
    agentRun: 'агент — буква алфавита, связанная SOUL.md и AGENTS.md; отсюда он не запускается — он держит скиллы, а их запускают задания',
    relates: 'связанные карточки',
    noRelates: 'ни одна крон-карточка не описывает это расписание; у событийной функции её и нет',
    functionRun: 'функция Inngest выполняется, когда приходит её событие или срабатывает крон; эта страница событий не отправляет — безопасная проба 2026-09-09 записана в спеке и здесь не повторяется',
    unresolved: 'неизвестный id',
    summary: 'кратко',
    translations: 'переводы',
    noTranslations: 'не объявлены',
    translationsTitle: 'Спеки только на английском (t27 LANG-EN). Каждая локаль подключена через спеку-контракт в specs/i18n/, которая называет бандл с текстом; n/total — сколько записей этого каталога бандл покрывает.',
    viaSpec: 'через',
    copy: 'копировать',
    copied: 'скопировано',
    messages: 'заметки генератора',
  },
} as const

type Copy = Record<keyof typeof COPY.en, string>

export interface CrossLink {
  id: string
  href: string
  ok: boolean
}

interface Props {
  lang: 'en' | 'ru'
  kind: 'skill' | 'cron' | 'agent' | 'function' | 'tool'
  /** The catalog id of the card, for the code-only case where there is no spec. */
  id: string
  entry: SkillSpecEntry | CronSpecEntry | AgentSpecEntry | FunctionSpecEntry | ToolSpecEntry | null
  links: CrossLink[]
  /** Whether the reader can jump to the Spec Explorer in this frame. */
  embedded: boolean
  /** The catalog's translation contracts, for the `translations:` line. */
  i18n?: I18nContract[]
  /** Extra buttons the page adds to the management strip (an agent's SOUL.md, its experience log). */
  extraControls?: React.ReactNode
}

async function sha256Hex(text: string): Promise<string | null> {
  const subtle = globalThis.crypto?.subtle
  if (!subtle) return null
  const digest = await subtle.digest('SHA-256', new TextEncoder().encode(text))
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}

function label(kind: Props['kind'], t: Copy): { links: string; empty: string } {
  if (kind === 'cron') return { links: t.runs, empty: t.noRuns }
  if (kind === 'agent') return { links: t.holds, empty: t.noHolds }
  if (kind === 'function') return { links: t.relates, empty: t.noRelates }
  if (kind === 'tool') return { links: t.ownedBy, empty: t.noOwnedBy }
  return { links: t.runBy, empty: t.noRunBy }
}

const SPEC_DIR: Record<Props['kind'], string> = { skill: 'specs/skills', cron: 'specs/crons', agent: 'specs/agents', function: 'specs/functions', tool: 'specs/tools' }
const LINK_GLYPH: Record<Props['kind'], string> = { skill: '◷', cron: '⟲', agent: '◈', function: '⟲', tool: 'Ω' }

export function AgentSpecPanel({ lang, kind, id, entry, links, embedded, i18n = [], extraControls }: Props) {
  const t: Copy = COPY[lang]
  // An agent is not a job: the control plane's run/enable/disable verbs do not
  // apply to a letter, so the plane is shown for skills and crons only.
  // A function has no control-plane verb here either: it is launched by its event or cron;
  // a tool is a command or a server, not a run.
  const planeApplies = kind !== 'agent' && kind !== 'function' && kind !== 'tool'
  // Everything fetched for one spec travels together, keyed by its path, so a
  // change of card is a change of key rather than a burst of resets.
  interface Loaded { path: string; source: string; lines: Span[][]; err: string | null; sha: 'pending' | 'ok' | 'mismatch' | 'unchecked' }
  const [loaded, setLoaded] = useState<Loaded | null>(null)
  const [copied, setCopied] = useState(false)
  const [planeNote, setPlaneNote] = useState<string | null>(null)
  const plane = agentControlUrl()

  const specPath = entry?.specPath ?? null
  const expectedSha = entry?.sha256 ?? null
  useEffect(() => {
    if (!specPath || !expectedSha) return
    let alive = true
    const path = specPath
    loadAgentSpecSource(path)
      .then(async (text) => {
        if (!alive) return
        const hex = await sha256Hex(text)
        const sha: Loaded['sha'] = hex === null ? 'unchecked' : hex === expectedSha ? 'ok' : 'mismatch'
        let lines: Span[][]
        try {
          lines = highlightSource(text, (await analyze(text)).tokens)
        } catch {
          lines = highlightCode(text, 't27')
        }
        if (alive) setLoaded({ path, source: text, lines, err: null, sha })
      })
      .catch((e) => alive && setLoaded({ path, source: '', lines: [], err: String(e instanceof Error ? e.message : e), sha: 'unchecked' }))
    return () => {
      alive = false
    }
  }, [specPath, expectedSha])

  const current = loaded && loaded.path === specPath ? loaded : null
  const source = current?.source ?? ''
  const lines = current?.lines ?? []
  const err = current?.err ?? null
  const shaState = current?.sha ?? 'pending'

  const copySha = useCallback(() => {
    if (!entry) return
    navigator.clipboard?.writeText(entry.sha256).then(
      () => {
        setCopied(true)
        window.setTimeout(() => setCopied(false), 1400)
      },
      () => {},
    )
  }, [entry])

  const act = useCallback(
    async (action: ControlAction) => {
      if (!plane || kind === 'agent' || kind === 'function' || kind === 'tool') return
      setPlaneNote('…')
      try {
        const r = await requestControl(plane, kind, id, action)
        setPlaneNote(`${r.ok ? t.sent : t.rejected} · HTTP ${r.status}${r.body ? ` · ${r.body.slice(0, 160)}` : ''}`)
      } catch (e) {
        setPlaneNote(`${t.rejected} · ${String(e instanceof Error ? e.message : e)}`)
      }
    },
    [plane, kind, id, t.sent, t.rejected],
  )

  const heading = (text: string) => <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>{text}</div>
  const box: React.CSSProperties = { background: C.panel, border: `1px solid ${C.border}`, borderRadius: 6, padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }

  const runNow = useMemo(() => {
    if (!entry || kind !== 'cron') return null
    return (entry as CronSpecEntry).runNow
  }, [entry, kind])

  // The spec is English-only (LANG-EN). Any other locale reaches this panel
  // through a contract spec under specs/i18n/ and its bundle; when that locale
  // has no entry for this spec, the English text from the spec is shown (the
  // contract's FALLBACK).
  const summary = entry ? (entry.summary[lang] ?? entry.summary.en) : ''
  const { links: linksLabel, empty: emptyLabel } = label(kind, t)

  // ---- code-only: no spec to show, but an honest card and a way to write one.
  if (!entry) {
    const dir = SPEC_DIR[kind]
    const filename = `${id.replace(/[^A-Za-z0-9_.-]+/g, '-')}.t27`
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ ...box, borderColor: 'rgba(240,160,32,0.4)' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
            {heading(t.spec)}
            <span style={{ ...tagChip(false, false), color: C.warn, borderColor: C.warn }}>{WITNESS_LABEL['code-only'][lang]}</span>
          </div>
          <div style={{ fontSize: 12.5, lineHeight: 1.55, color: '#d8d8d8' }}>{t.codeOnly}</div>
          <div>
            <a
              href={`https://github.com/gHashTag/t27/new/master/${dir}?filename=${encodeURIComponent(filename)}`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ ...pill, color: C.warn, borderColor: 'rgba(240,160,32,0.4)' }}
            >
              {t.createSpec}
            </a>
          </div>
        </div>
        <div style={box}>
          {heading(t.control)}
          <div style={{ fontSize: 12, color: C.muted, lineHeight: 1.5 }}>{t.noPlane}</div>
        </div>
      </div>
    )
  }

  const witnessColor = entry.witness === 'spec+code' || entry.witness === 'spec+experience' || entry.witness === 'help-output' ? C.accent : entry.witness === 'source-parse' ? C.golden : C.warn
  const verdictColor = entry.typecheckOk && entry.discarded === 0 ? C.accent : C.bad

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      {/* ---- the spec itself ---- */}
      <div style={box}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
          {heading(t.spec)}
          <span style={{ fontFamily: C.mono, fontSize: 11.5, color: C.accent }} data-lang-exempt="live">
            {entry.specPath}
          </span>
          <span style={{ ...tagChip(false, false), color: witnessColor, borderColor: witnessColor }}>{WITNESS_LABEL[entry.witness][lang]}</span>
          <span title={t.verdictNote} style={{ ...tagChip(false, false), color: verdictColor, borderColor: verdictColor }}>
            {entry.typecheckOk ? t.verdictOk : t.verdictFail}
            {entry.discarded > 0 ? ` · ${t.discarded} ${entry.discarded}` : ''}
          </span>
        </div>
        {summary && (
          <div style={{ fontSize: 12.5, lineHeight: 1.55, color: '#d8d8d8' }} data-lang-exempt="live">
            {summary}
          </div>
        )}
        <div style={{ fontFamily: C.mono, fontSize: 10.5, color: C.muted }} title={t.translationsTitle}>
          {t.translations}:{' '}
          {i18n.length === 0
            ? t.noTranslations
            : i18n.map((c, i) => (
                <span key={c.locale} data-lang-exempt="live">
                  {i > 0 ? ' · ' : ''}
                  <b style={{ color: entry.summary[c.locale] ? '#d8d8d8' : C.muted }}>{c.locale}</b> {t.viaSpec}{' '}
                  <a href={vendoredSpecUrl(c.spec)} target="_blank" rel="noopener noreferrer" style={{ color: C.muted }}>
                    {c.spec}
                  </a>{' '}
                  ({c.coverage.n}/{c.coverage.total}){c.enabled ? '' : ' · off'}
                </span>
              ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', fontFamily: C.mono, fontSize: 11 }}>
          <span style={{ color: C.muted }}>{t.sha}</span>
          <span style={{ color: '#d8d8d8' }} title={entry.sha256}>
            {entry.sha256.slice(0, 16)}…
          </span>
          <button onClick={copySha} style={{ ...pill, color: copied ? C.accent : C.muted }}>
            {copied ? t.copied : t.copy}
          </button>
          <span style={{ color: shaState === 'ok' ? C.muted : shaState === 'mismatch' ? C.bad : C.muted, opacity: shaState === 'mismatch' ? 1 : 0.8 }}>
            {shaState === 'ok' ? `✓ ${t.shaVerified}` : shaState === 'mismatch' ? `✕ ${t.shaMismatch}` : shaState === 'unchecked' ? t.shaUnchecked : ''}
          </span>
        </div>
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
          {entry.inSpecCorpus ? (
            <a href={specExplorerHash(entry.specPath, { embedded })} style={pill}>
              {t.openSpec}
            </a>
          ) : (
            <span style={{ ...pill, cursor: 'default', opacity: 0.7 }}>{t.notInCorpus}</span>
          )}
        </div>
        {entry.messages.length > 0 && (
          <div style={{ fontSize: 11.5, color: C.warn, lineHeight: 1.5 }}>
            <span style={{ fontFamily: C.mono, fontSize: 10.5 }}>{t.messages}: </span>
            <span data-lang-exempt="live">{entry.messages.join(' · ')}</span>
          </div>
        )}
        <div style={{ border: `1px solid ${C.border}`, borderRadius: 5, maxHeight: 420, overflow: 'auto', background: C.bg }}>
          {err ? (
            <div style={{ padding: 12, fontSize: 12, color: C.bad }}>
              {t.failed} <span data-lang-exempt="live">{err}</span>
            </div>
          ) : source ? (
            <SpecCodeView lines={lines.length ? lines : highlightCode(source, 't27')} raw={source} copyLabel={t.copy} copiedLabel={t.copied} meta={`${entry.specPath} · ${entry.moduleName ?? ''}`} />
          ) : (
            <div style={{ padding: 12, fontSize: 12, color: C.muted }}>{t.loading}</div>
          )}
        </div>
      </div>

      {/* ---- cross links ---- */}
      <div style={box}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          {heading(t.links)}
          <span style={{ fontSize: 11, color: C.muted }}>{linksLabel}</span>
        </div>
        {links.length === 0 ? (
          <div style={{ fontSize: 12, color: C.muted }}>
            {emptyLabel}
            {kind === 'cron' && (entry as CronSpecEntry).fields.RUNS_NOTE ? (
              <span data-lang-exempt="live"> — {(entry as CronSpecEntry).fields.RUNS_NOTE}</span>
            ) : null}
            {kind === 'agent' && (entry as AgentSpecEntry).fields.SKILLS_NOTE ? (
              <span data-lang-exempt="live"> — {(entry as AgentSpecEntry).fields.SKILLS_NOTE}</span>
            ) : null}
            {kind === 'tool' && (entry as ToolSpecEntry).fields.AGENTS_NOTE ? (
              <span data-lang-exempt="live"> — {(entry as ToolSpecEntry).fields.AGENTS_NOTE}</span>
            ) : null}
          </div>
        ) : (
          <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
            {links.map((l) =>
              l.ok ? (
                <a key={l.id} href={l.href} style={{ ...tagChip(false, false), color: C.accent, borderColor: C.borderBright, textDecoration: 'none' }} data-lang-exempt="live">
                  {LINK_GLYPH[kind]} {l.id}
                </a>
              ) : (
                <span key={l.id} title={t.unresolved} style={{ ...tagChip(false, false), color: C.bad, borderColor: C.bad }} data-lang-exempt="live">
                  ✕ {l.id}
                </span>
              ),
            )}
          </div>
        )}
      </div>

      {/* ---- management strip ---- */}
      <div style={box}>
        {heading(t.control)}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {/* A function spec has no ENABLED: whether it runs is the manifest's
              deployed flag, shown by the Function Explorer, not a spec switch. */}
          {'ENABLED' in entry.fields ? (
            <span
              title={t.readOnly}
              style={{ ...tagChip(false, false), cursor: 'default', color: entry.fields.ENABLED ? C.accent : C.muted, borderColor: entry.fields.ENABLED ? C.accent : C.border }}
            >
              {t.enabled} = {entry.fields.ENABLED ? t.on : t.off}
            </span>
          ) : null}
          <a href={canonicalSpecEditUrl(entry.specPath)} target="_blank" rel="noopener noreferrer" style={pill}>
            {t.editSpec}
          </a>
          <a href={vendoredSpecUrl(entry.specPath)} target="_blank" rel="noopener noreferrer" style={{ ...pill, opacity: 0.8 }}>
            {t.vendored}
          </a>
          {extraControls}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {kind === 'agent' ? (
            <span style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{t.agentRun}</span>
          ) : kind === 'function' ? (
            <span style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{t.functionRun}</span>
          ) : kind === 'tool' ? (
            <span style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{t.toolRun}</span>
          ) : kind === 'cron' && runNow ? (
            runNow.kind === 'link' ? (
              <>
                <a href={runNow.url} target="_blank" rel="noopener noreferrer" style={{ ...pill, color: C.golden, borderColor: 'rgba(255,215,0,0.4)' }}>
                  {t.runNow}
                </a>
                <span style={{ fontSize: 11, color: C.muted }}>
                  {runNow.via === 'github-actions' ? t.viaActions : runNow.via === 'railway' ? t.viaRailway : t.viaInngest}
                </span>
              </>
            ) : (
              <>
                <span aria-disabled="true" style={{ ...pill, cursor: 'default', opacity: 0.5 }}>
                  {t.runNow}
                </span>
                <span style={{ fontSize: 11, color: C.muted }}>{runNow.reason === 'timer' ? t.timerDisabled : t.unknownService}</span>
              </>
            )
          ) : (
            <span style={{ fontSize: 11, color: C.muted }}>
              {t.skillRun}
              {(entry as SkillSpecEntry).fields.COMMAND ? (
                <>
                  {' · '}
                  {t.command}: <span style={{ fontFamily: C.mono, color: C.golden }} data-lang-exempt="live">{(entry as SkillSpecEntry).fields.COMMAND}</span>
                </>
              ) : null}
            </span>
          )}
        </div>
        {!planeApplies ? null : plane ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 10.5, color: C.muted, fontFamily: C.mono }}>{t.plane}</span>
            <button onClick={() => void act('run')} style={pill}>
              {t.actRun}
            </button>
            {kind === 'cron' && (
              <>
                <button onClick={() => void act('enable')} style={pill}>
                  {t.actEnable}
                </button>
                <button onClick={() => void act('disable')} style={pill}>
                  {t.actDisable}
                </button>
              </>
            )}
            {planeNote && (
              <span style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }} data-lang-exempt="live">
                {planeNote}
              </span>
            )}
          </div>
        ) : (
          <div style={{ fontSize: 11.5, color: C.muted, lineHeight: 1.5 }}>{t.noPlane}</div>
        )}
        <div style={{ fontSize: 10.5, color: C.muted, opacity: 0.7, fontFamily: C.mono }} data-lang-exempt="live">
          {specSlug(entry.specPath)}
        </div>
      </div>
    </div>
  )
}
