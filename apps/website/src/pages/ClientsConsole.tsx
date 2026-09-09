// Clients -- the owner's console over the farm's CRM memory.
//
// WHO SEES THIS. Nobody but the owner. The page holds no data of its own: every
// row comes from the agent's tools over /mcp, and those tools refuse anyone who
// is not the owner, server-side, before a query runs. A second reader signing in
// here gets the refusal and an empty screen; there is no client-side check to
// forget, because there is no client-side check.
//
// WHAT IT CANNOT DO. It cannot send. crm_offer, crm_deliver_photo and every
// Telegram writer are refused in the browser before a request leaves (see
// TOOL_ALLOWLIST in crmClient.ts) and refused again by the service, which only
// confirms outward actions on the bot card. The single write this page performs
// is crm_touch, which changes our own memory and reaches nobody.
//
// The one path to a message is "Prepare in the bot": it opens the bot with a
// payload, the bot drafts, and the owner presses in Telegram. That press is the
// only thing that sends, and it never happens here.

import { useCallback, useEffect, useMemo, useState } from 'react'
import { useI18n } from '../i18n/context'
import { usePageMeta } from '../hooks/usePageMeta'
import { useHashParams } from '../hooks/useHashParams'
import { ExplorerHeader } from '../components/ExplorerHeader'
import { ExplorerLibrary, type ExplorerItem } from '../components/ExplorerLibrary'
import { StackBar } from '../components/SpecGraphics'
import { TelegramLoginButton } from '../components/TelegramLoginButton'
import { C, inputStyle, panelBox, pill, tagChip } from '../lib/explorerTheme'
import {
  callTool,
  credentialKind,
  CrmError,
  forgetCredentials,
  rememberAgentKey,
  signInWithWidget,
  type CredentialKind,
} from '../lib/crmClient'
import {
  label,
  leadHealth,
  NEXT_LABEL,
  relativeDays,
  SEGMENT_LABEL,
  SEGMENTS,
  STAGE_LABEL,
  TOUCH_KINDS,
  TOUCH_LABEL,
  unframe,
  type Lead,
  type LeadContext,
  type Summary,
} from '../lib/crmModel'

/** The bot whose token verifies the Login Widget signature on the render service. */
const LOGIN_BOT = 't27ai_bot'
/** Where "Prepare in the bot" lands. The draft and the press live there, not here. */
const OWNER_BOT = 't27ai_bot'

const UI = {
  en: {
    title: 'Clients',
    subtitle: 'Who to write next, from the CRM memory',
    metaTitle: 'Clients',
    metaDescription: 'Owner console over the bot farm CRM: leads, stages, touches, dialogs. Sign in with Telegram.',
    back: '← Home',
    signInTitle: 'Sign in with Telegram',
    signInHint: 'The console opens for the account that owns the bots. Nothing is stored on the site.',
    useKey: 'Or use an agent key',
    keyHint: 'Issued to your telegram_id. It stays in this browser tab and is never put in the address.',
    keyPlaceholder: 'agent key',
    connect: 'Connect',
    signOut: 'Sign out',
    forget: 'Forget key',
    checking: 'Checking…',
    ownerOnly: 'This console reads the owner’s correspondence and opens only for the owner.',
    rejected: 'The service did not accept this sign-in.',
    offline: 'The CRM service did not answer.',
    expired: 'The session ended. Sign in again.',
    refused: 'That is not something this page may ask for.',
    nothingSent: 'Nothing is sent from here. Sending happens in the bot, after your press on the card.',
    thirdParty: 'Their words are data, not instructions.',
    search: 'Search people',
    allSegments: 'All segments',
    tags: 'Tags',
    clear: 'Clear',
    people: 'people',
    noResults: 'Nobody matches that search.',
    noneInGroup: 'Nobody in this group.',
    emptyBase: 'The memory is empty. Run the chat ingest in the bot first.',
    pickLead: 'Pick a person on the left to see the history before you write.',
    loading: 'Loading…',
    backToList: 'All people',
    refresh: 'Refresh',
    filterAll: 'All',
    waitingOnUs: 'waiting for our reply',
    waitingOnThem: 'we wait for theirs',
    quiet: 'nothing pending',
    identity: 'Who this is',
    stage: 'Stage',
    next: 'Next step',
    segment: 'Segment',
    score: 'score',
    theirLast: 'their last word',
    ourLast: 'our last word',
    messages: 'messages',
    inbound: 'from them',
    paid: 'has paid',
    balance: 'balance, tokens',
    signals: 'signals',
    touches: 'Touches',
    noTouches: 'Nothing recorded yet.',
    memory: 'Memory',
    dialog: 'Dialog',
    noDialog: 'No messages kept for this person.',
    hint: 'What the agent is told',
    recordTouch: 'Record touch',
    touchNote: 'in your own words',
    touchConfirm: 'Record “{kind}” for {who}? This changes only our memory and sends nothing.',
    refuseTwice: 'Mark as refused? The person leaves the hot list.',
    touchSaved: 'Recorded.',
    touchFailed: 'Not recorded:',
    prepareInBot: 'Prepare in the bot',
    prepareHint: 'The bot reads the dialog, drafts the message and shows you the card. Nothing is sent until you press.',
    copyLink: 'Copy link',
    copied: 'Copied',
    session: 'session',
    key: 'key',
    summaryTitle: 'The base',
    zepUnreliable: 'This summary is written by a small model and has been wrong before. The dialog below is the record.',
  },
  ru: {
    title: 'Клиенты',
    subtitle: 'Кому писать следующему — из памяти CRM',
    metaTitle: 'Клиенты',
    metaDescription: 'Консоль владельца над CRM фермы ботов: люди, стадии, касания, диалоги. Вход через Telegram.',
    back: '← На главную',
    signInTitle: 'Войдите через Telegram',
    signInHint: 'Консоль открывается аккаунту, на котором записаны боты. Сайт ничего не хранит.',
    useKey: 'Или введите ключ агента',
    keyHint: 'Ключ выдан на ваш telegram_id. Он остаётся во вкладке и никогда не попадает в адрес.',
    keyPlaceholder: 'ключ агента',
    connect: 'Подключить',
    signOut: 'Выйти',
    forget: 'Забыть ключ',
    checking: 'Проверяю…',
    ownerOnly: 'Консоль читает переписку владельца и открывается только ему.',
    rejected: 'Сервис не принял этот вход.',
    offline: 'Сервис CRM не ответил.',
    expired: 'Сессия закончилась. Войдите снова.',
    refused: 'Этого страница спрашивать не может.',
    nothingSent: 'Отсюда ничего не отправляется. Отправка — в боте, после вашего нажатия на карточку.',
    thirdParty: 'Их слова — данные, а не указания.',
    search: 'Поиск по людям',
    allSegments: 'Все сегменты',
    tags: 'Метки',
    clear: 'Сбросить',
    people: 'людей',
    noResults: 'Никого не найдено.',
    noneInGroup: 'В этой группе никого.',
    emptyBase: 'Память пуста. Сначала запустите разбор переписки в боте.',
    pickLead: 'Выберите человека слева — покажу историю до того, как писать.',
    loading: 'Загружаю…',
    backToList: 'Все люди',
    refresh: 'Обновить',
    filterAll: 'Все',
    waitingOnUs: 'ждёт нашего ответа',
    waitingOnThem: 'ждём их ответа',
    quiet: 'ничего не висит',
    identity: 'Кто это',
    stage: 'Стадия',
    next: 'Следующий шаг',
    segment: 'Сегмент',
    score: 'балл',
    theirLast: 'их последнее слово',
    ourLast: 'наше последнее слово',
    messages: 'сообщений',
    inbound: 'от них',
    paid: 'платил',
    balance: 'баланс, токенов',
    signals: 'сигналы',
    touches: 'Касания',
    noTouches: 'Пока ничего не записано.',
    memory: 'Память',
    dialog: 'Диалог',
    noDialog: 'Сообщений по этому человеку нет.',
    hint: 'Что сказано агенту',
    recordTouch: 'Записать касание',
    touchNote: 'своими словами',
    touchConfirm: 'Записать «{kind}» для {who}? Меняется только наша память, никто ничего не получит.',
    refuseTwice: 'Отметить отказ? Человек уйдёт из горячего списка.',
    touchSaved: 'Записано.',
    touchFailed: 'Не записано:',
    prepareInBot: 'Подготовить в боте',
    prepareHint: 'Бот прочитает диалог, составит сообщение и покажет карточку. Пока вы не нажмёте — ничего не уйдёт.',
    copyLink: 'Скопировать ссылку',
    copied: 'Скопировано',
    session: 'сессия',
    key: 'ключ',
    summaryTitle: 'База',
    zepUnreliable: 'Эту сводку пишет маленькая модель, она уже ошибалась. Правда — диалог ниже.',
  },
} as const

type Ui = Record<keyof typeof UI.en, string>

interface LeadsAnswer {
  candidates?: Lead[]
  how_to_read?: string
}

export default function ClientsConsole() {
  const { lang } = useI18n()
  const short: 'en' | 'ru' = lang === 'ru' ? 'ru' : 'en'
  const ui: Ui = short === 'ru' ? UI.ru : UI.en
  usePageMeta(ui.metaTitle, ui.metaDescription)
  const params = useHashParams()
  const embedded = params.embedded

  const [kind, setKind] = useState<CredentialKind | null>(() => credentialKind())
  const [who, setWho] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [fail, setFail] = useState<string | null>(null)
  const [keyDraft, setKeyDraft] = useState('')

  const [leads, setLeads] = useState<Lead[]>([])
  const [hint, setHint] = useState<string | null>(null)
  const [summary, setSummary] = useState<Summary | null>(null)
  const [selected, setSelected] = useState<Lead | null>(null)
  const [context, setContext] = useState<LeadContext | null>(null)
  const [touchKind, setTouchKind] = useState<string>('note')
  const [touchNote, setTouchNote] = useState('')
  const [touchSaid, setTouchSaid] = useState<string | null>(null)

  const [query, setQuery] = useState('')
  const [segment, setSegment] = useState('')
  const [waitFilter, setWaitFilter] = useState<'all' | 'ours' | 'theirs'>('all')
  const [tagSel, setTagSel] = useState<string[]>([])
  const [copied, setCopied] = useState(false)
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

  // A console over one person's correspondence has no business in a search
  // index, and the hash carries a lead id in browser history as it is.
  useEffect(() => {
    const tag = document.createElement('meta')
    tag.name = 'robots'
    tag.content = 'noindex, nofollow'
    document.head.appendChild(tag)
    return () => {
      tag.remove()
    }
  }, [])

  const say = useCallback(
    (e: unknown) => {
      if (e instanceof CrmError) {
        setFail(
          e.reason === 'ownerOnly'
            ? ui.ownerOnly
            : e.reason === 'offline'
              ? ui.offline
              : e.reason === 'expired'
                ? ui.expired
                : e.reason === 'refused'
                  ? ui.refused
                  : ui.rejected,
        )
        if (e.reason === 'expired') setKind(null)
      } else {
        setFail(ui.offline)
      }
    },
    [ui],
  )

  const load = useCallback(async () => {
    setBusy(true)
    setFail(null)
    try {
      const me = await callTool<{ telegram_id?: string }>('whoami')
      setWho(me?.telegram_id ? String(me.telegram_id) : null)
      const [rows, base] = await Promise.all([
        callTool<LeadsAnswer>('crm_leads', { limit: 50, ...(segment ? { segment } : {}) }),
        callTool<Summary>('crm_summary', {}).catch(() => null),
      ])
      setLeads(rows?.candidates ?? [])
      setHint(rows?.how_to_read ?? null)
      setSummary(base)
      setKind(credentialKind())
    } catch (e) {
      say(e)
    } finally {
      setBusy(false)
    }
  }, [say, segment])

  useEffect(() => {
    if (kind) void load()
    // The credential decides whether anything loads at all; the filter reload
    // is driven by the Refresh button so a typing pause never fires a request.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [kind])

  const open = useCallback(
    async (lead: Lead) => {
      setSelected(lead)
      setContext(null)
      setTouchSaid(null)
      params.set(`#/clients?lead=${encodeURIComponent(lead.lead)}${embedded ? '&embed=1' : ''}`)
      try {
        const ctx = await callTool<LeadContext>('crm_lead_context', { chat: lead.lead, limit: 30 })
        setContext(ctx)
      } catch (e) {
        say(e)
      }
    },
    [embedded, params, say],
  )

  // A deep link names a person; it is honoured once the list is in hand.
  const [wanted] = useState(() => params.get('lead'))
  useEffect(() => {
    if (!wanted || selected || !leads.length) return
    const found = leads.find((l) => l.lead === wanted)
    if (found) {
      setPane('detail')
      void open(found)
    }
  }, [wanted, leads, selected, open])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return leads.filter((l) => {
      if (waitFilter === 'ours' && !l.waiting_for_reply) return false
      if (waitFilter === 'theirs' && l.waiting_for_reply) return false
      if (tagSel.length) {
        const tags = [`next/${l.next}`, `stage/${l.stage}`, `segment/${l.segment}`, l.paid ? 'paid/yes' : 'paid/no']
        if (!tagSel.every((t) => tags.includes(t))) return false
      }
      if (!q) return true
      return (
        (l.display ?? '').toLowerCase().includes(q) ||
        (l.name ?? '').toLowerCase().includes(q) ||
        (l.username ?? '').toLowerCase().includes(q) ||
        l.lead.includes(q)
      )
    })
  }, [leads, query, waitFilter, tagSel])

  const tagCounts = useMemo(() => {
    const acc: Record<string, number> = {}
    for (const l of filtered) {
      for (const t of [`next/${l.next}`, `stage/${l.stage}`, `segment/${l.segment}`, l.paid ? 'paid/yes' : 'paid/no']) {
        acc[t] = (acc[t] ?? 0) + 1
      }
    }
    return acc
  }, [filtered])

  const items: ExplorerItem[] = useMemo(
    () =>
      filtered.map((l) => ({
        id: l.lead,
        title: l.display || l.lead,
        subtitle: `${label(SEGMENT_LABEL, l.segment, short)} · ${label(NEXT_LABEL, l.next, short)} · ${relativeDays(l.days_since_their_last_word, short)}`,
        badge: l.paid ? ui.paid : undefined,
        badgeColor: l.paid ? C.golden : undefined,
        health: leadHealth(l),
        tags: [`next/${l.next}`, `stage/${l.stage}`, `segment/${l.segment}`],
        haystack: `${l.display ?? ''} ${l.lead}`.toLowerCase(),
      })),
    [filtered, short, ui.paid],
  )

  const waitCounts = useMemo(() => {
    const ours = leads.filter((l) => l.waiting_for_reply).length
    return { ours, theirs: leads.length - ours }
  }, [leads])

  const record = useCallback(async () => {
    if (!selected) return
    const who = selected.display || selected.lead
    const kindLabel = label(TOUCH_LABEL, touchKind, short)
    if (!window.confirm(ui.touchConfirm.replace('{kind}', kindLabel).replace('{who}', who))) return
    if (touchKind === 'refused' && !window.confirm(ui.refuseTwice)) return
    try {
      await callTool('crm_touch', { telegram_id: selected.lead, kind: touchKind, note: touchNote })
      setTouchNote('')
      setTouchSaid(ui.touchSaved)
      const ctx = await callTool<LeadContext>('crm_lead_context', { chat: selected.lead, limit: 30 })
      setContext(ctx)
    } catch (e) {
      setTouchSaid(`${ui.touchFailed} ${e instanceof CrmError ? (e.detail ?? e.reason) : String(e)}`)
    }
  }, [selected, touchKind, touchNote, short, ui])

  const copy = useCallback(() => {
    if (!selected) return
    navigator.clipboard?.writeText(`https://t27.ai/#/clients?lead=${encodeURIComponent(selected.lead)}`).then(
      () => {
        setCopied(true)
        window.setTimeout(() => setCopied(false), 1400)
      },
      () => {},
    )
  }, [selected])

  const box = panelBox(embedded)

  // ------------------------------------------------------------- signed out
  if (!kind) {
    return (
      <div
        className="spec-x"
        style={{ minHeight: '100dvh', background: C.bg, color: C.text, fontFamily: "'Outfit', system-ui, sans-serif", display: 'flex', flexDirection: 'column' }}
      >
        <ExplorerHeader title={ui.title} subtitle={ui.subtitle} back={ui.back} narrow={narrow} phone={phone} />
        <main style={{ flex: 1, display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '48px 16px' }}>
          <div style={{ ...box, padding: 20, maxWidth: 460, display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: C.golden }}>{ui.signInTitle}</div>
            <div style={{ fontSize: 12.5, color: '#b9bfc6', lineHeight: 1.55 }}>{ui.signInHint}</div>
            <TelegramLoginButton
              bot={LOGIN_BOT}
              lang={short}
              onAuth={(user) => {
                setBusy(true)
                setFail(null)
                signInWithWidget(user)
                  .then(() => setKind(credentialKind()))
                  .catch(say)
                  .finally(() => setBusy(false))
              }}
            />
            <div style={{ borderTop: `1px solid ${C.border}`, paddingTop: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ fontSize: 12.5, color: C.text }}>{ui.useKey}</div>
              <div style={{ fontSize: 11.5, color: C.muted, lineHeight: 1.5 }}>{ui.keyHint}</div>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  type="password"
                  value={keyDraft}
                  onChange={(e) => setKeyDraft(e.target.value)}
                  placeholder={ui.keyPlaceholder}
                  aria-label={ui.useKey}
                  autoComplete="off"
                  style={{ ...inputStyle, flex: 1, minWidth: 0 }}
                />
                <button
                  onClick={() => {
                    rememberAgentKey(keyDraft)
                    setKeyDraft('')
                    setKind(credentialKind())
                  }}
                  style={{ ...pill, cursor: 'pointer' }}
                >
                  {ui.connect}
                </button>
              </div>
            </div>
            {busy && <div style={{ fontSize: 12, color: C.muted }}>{ui.checking}</div>}
            {fail && <div style={{ fontSize: 12.5, color: C.bad }}>{fail}</div>}
            <div style={{ fontSize: 11, color: C.muted, lineHeight: 1.5, borderTop: `1px solid ${C.border}`, paddingTop: 12 }}>
              {ui.nothingSent}
            </div>
          </div>
        </main>
      </div>
    )
  }

  // -------------------------------------------------------------- signed in
  const stack = [
    { key: 'ours', count: waitCounts.ours, color: C.bad, label: ui.waitingOnUs },
    { key: 'theirs', count: waitCounts.theirs, color: C.accent, label: ui.waitingOnThem },
  ]

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
          narrow={narrow}
          phone={phone}
          right={
            <span style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: C.mono }}>
              <span>
                {who ?? '—'} · {kind === 'session' ? ui.session : ui.key}
              </span>
              <button
                onClick={() => {
                  forgetCredentials()
                  setKind(null)
                  setLeads([])
                  setSelected(null)
                  setContext(null)
                }}
                style={{ ...pill, cursor: 'pointer' }}
              >
                {kind === 'session' ? ui.signOut : ui.forget}
              </button>
            </span>
          }
        />
      )}

      <div
        style={{
          flexShrink: 0,
          padding: '8px 14px',
          borderBottom: `1px solid ${C.border}`,
          fontSize: 11.5,
          color: C.warn,
          display: 'flex',
          gap: 10,
          alignItems: 'center',
          flexWrap: 'wrap',
        }}
      >
        <span>⚠ {ui.nothingSent}</span>
        <button onClick={() => void load()} style={{ ...pill, marginLeft: 'auto', cursor: 'pointer' }} disabled={busy}>
          {busy ? ui.loading : ui.refresh}
        </button>
      </div>

      {fail && (
        <div className="spec-x-banner" style={{ margin: '10px 14px 0', padding: '9px 12px', background: 'rgba(248,81,73,0.10)', border: `1px solid ${C.bad}`, borderRadius: 5, fontSize: 12, color: '#d8d8d8' }}>
          {fail}
        </div>
      )}

      <div style={{ flex: 1, display: 'flex', minHeight: 0, minWidth: 0 }}>
        {(!phone || pane === 'list') && (
          <ExplorerLibrary
            items={items}
            selectedId={selected?.lead ?? null}
            onPick={(item) => {
              const lead = leads.find((l) => l.lead === item.id)
              if (lead) {
                setPane('detail')
                void open(lead)
              }
            }}
            query={query}
            setQuery={setQuery}
            categories={SEGMENTS.map((s) => [s, label(SEGMENT_LABEL, s, short), (summary?.segments as Record<string, number> | undefined)?.[s] ?? 0] as [string, string, number])}
            category={segment}
            setCategory={(v) => {
              setSegment(v)
            }}
            filters={[
              { key: 'all', label: ui.filterAll, count: leads.length },
              { key: 'ours', label: ui.waitingOnUs, count: waitCounts.ours, color: C.bad, glyph: '!' },
              { key: 'theirs', label: ui.waitingOnThem, count: waitCounts.theirs, color: C.accent, glyph: '·' },
            ]}
            filter={waitFilter}
            setFilter={(v) => setWaitFilter(v as 'all' | 'ours' | 'theirs')}
            stack={stack}
            tagCounts={tagCounts}
            tagFamilies={[
              { prefix: 'next/', label: 'next step' },
              { prefix: 'stage/', label: 'stage' },
              { prefix: 'segment/', label: 'segment' },
              { prefix: 'paid/', label: 'paid' },
            ]}
            tagSel={tagSel}
            toggleTag={(t) => setTagSel((prev) => (prev.includes(t) ? prev.filter((x) => x !== t) : [...prev, t]))}
            clearTags={() => setTagSel([])}
            phone={phone}
            countLabel={`${filtered.length} ${ui.people}`}
            titlesAreGenerated
            ui={{
              search: ui.search,
              allCategories: `${ui.allSegments} (${leads.length})`,
              tags: ui.tags,
              clear: ui.clear,
              noResults: ui.noResults,
              noneInGroup: leads.length === 0 ? ui.emptyBase : ui.noneInGroup,
            }}
          />
        )}

        {(!phone || pane === 'detail') && (
          <main style={{ flex: 1, minWidth: 0, minHeight: 0, overflowY: 'auto', padding: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
            {!selected && <div style={{ color: C.muted, fontSize: 13 }}>{busy ? ui.loading : ui.pickLead}</div>}
            {selected && (
              <>
                {phone && (
                  <button onClick={() => setPane('list')} style={{ ...pill, alignSelf: 'flex-start', cursor: 'pointer' }}>
                    ← {ui.backToList}
                  </button>
                )}

                <div style={{ ...box, padding: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                    <span style={{ fontSize: 15, fontWeight: 700 }} data-lang-exempt="live">
                      {selected.display || selected.lead}
                    </span>
                    <span style={{ fontFamily: C.mono, fontSize: 11, color: C.muted }}>{selected.lead}</span>
                    <span style={{ ...tagChip(false, false), color: C.accent, borderColor: C.accent }}>
                      {label(NEXT_LABEL, selected.next, short)}
                    </span>
                    <span style={tagChip(false, false)}>{label(STAGE_LABEL, selected.stage, short)}</span>
                    <span style={tagChip(false, false)}>{label(SEGMENT_LABEL, selected.segment, short)}</span>
                    {selected.paid && <span style={{ ...tagChip(false, false), color: C.golden, borderColor: C.golden }}>{ui.paid}</span>}
                  </div>
                  <div style={{ fontSize: 12, color: '#b9bfc6', lineHeight: 1.55 }} data-lang-exempt="live">
                    {selected.because}
                  </div>
                  <div style={{ fontSize: 11.5, color: C.muted, fontFamily: C.mono }}>
                    {selected.waiting_for_reply ? `⚠ ${ui.waitingOnUs}` : ui.waitingOnThem} · {ui.theirLast}:{' '}
                    {relativeDays(selected.days_since_their_last_word, short)} · {ui.ourLast}:{' '}
                    {relativeDays(selected.days_since_our_last_word, short)} · {selected.messages} {ui.messages} ({selected.inbound} {ui.inbound}) ·{' '}
                    {ui.score} {selected.score}
                    {context?.balance_tokens !== null && context?.balance_tokens !== undefined ? ` · ${ui.balance}: ${context.balance_tokens}` : ''}
                  </div>
                  {selected.signals.length > 0 && (
                    <div style={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
                      {selected.signals.map((s) => (
                        <span key={s} style={tagChip(false, false)}>
                          {s}
                        </span>
                      ))}
                    </div>
                  )}
                  <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', marginTop: 4 }}>
                    <a
                      href={`https://t.me/${OWNER_BOT}?start=crm-prep-${encodeURIComponent(selected.lead)}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      title={ui.prepareHint}
                      style={{ ...pill, color: C.accent, borderColor: C.accent }}
                    >
                      {ui.prepareInBot}
                    </a>
                    <button onClick={copy} style={{ ...pill, cursor: 'pointer', color: copied ? C.accent : C.muted }}>
                      {copied ? ui.copied : ui.copyLink}
                    </button>
                  </div>
                  <div style={{ fontSize: 11, color: C.muted, lineHeight: 1.5 }}>{ui.prepareHint}</div>
                </div>

                {summary && (
                  <div style={{ ...box, padding: 12 }}>
                    <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono, marginBottom: 6 }}>{ui.summaryTitle}</div>
                    <StackBar segments={stack} />
                    <div style={{ marginTop: 6, fontSize: 11.5, color: C.muted, fontFamily: C.mono }}>
                      {String(summary.people ?? leads.length)} {ui.people} · {String(summary.messages ?? '')} {ui.messages} ·{' '}
                      {String(summary.waiting ?? waitCounts.ours)} {ui.waitingOnUs}
                    </div>
                  </div>
                )}

                <div style={{ ...box, padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                  <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>{ui.touches}</div>
                  {context?.touches?.length ? (
                    context.touches.map((t, i) => (
                      <div key={`${t.at}:${i}`} style={{ fontSize: 12, color: '#d8d8d8', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        <span style={{ color: C.accent, fontFamily: C.mono }}>{label(TOUCH_LABEL, t.kind, short)}</span>
                        <span style={{ color: C.muted, fontFamily: C.mono, fontSize: 11 }}>{t.at.replace('T', ' ').slice(0, 16)}</span>
                        {t.note && <span data-lang-exempt="live">{t.note}</span>}
                      </div>
                    ))
                  ) : (
                    <div style={{ fontSize: 12, color: C.muted }}>{ui.noTouches}</div>
                  )}
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', marginTop: 4 }}>
                    <select value={touchKind} onChange={(e) => setTouchKind(e.target.value)} aria-label={ui.recordTouch} style={{ ...inputStyle, padding: '5px 8px', fontSize: 12 }}>
                      {TOUCH_KINDS.map((k) => (
                        <option key={k} value={k}>
                          {label(TOUCH_LABEL, k, short)}
                        </option>
                      ))}
                    </select>
                    <input
                      value={touchNote}
                      onChange={(e) => setTouchNote(e.target.value)}
                      placeholder={ui.touchNote}
                      aria-label={ui.touchNote}
                      style={{ ...inputStyle, flex: 1, minWidth: 140, padding: '5px 8px', fontSize: 12 }}
                    />
                    <button onClick={() => void record()} style={{ ...pill, cursor: 'pointer' }}>
                      {ui.recordTouch}
                    </button>
                  </div>
                  {touchSaid && <div style={{ fontSize: 11.5, color: C.muted }}>{touchSaid}</div>}
                </div>

                {context?.zep_context && (
                  <div style={{ ...box, padding: 12 }}>
                    <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono, marginBottom: 6 }}>{ui.memory}</div>
                    <div style={{ fontSize: 11.5, color: C.warn, marginBottom: 6, lineHeight: 1.5 }}>{ui.zepUnreliable}</div>
                    <div style={{ fontSize: 12, color: '#b9bfc6', whiteSpace: 'pre-wrap', lineHeight: 1.55 }} data-lang-exempt="live">
                      {unframe(context.zep_context)}
                    </div>
                  </div>
                )}

                <div style={{ ...box, padding: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8 }}>
                    <span style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>{ui.dialog}</span>
                    <span style={{ fontSize: 10.5, color: C.warn }}>{ui.thirdParty}</span>
                  </div>
                  {context?.dialog?.length ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }} data-lang-exempt="live">
                      {context.dialog.map((m, i) => (
                        <div
                          key={`${m.at}:${i}`}
                          style={{
                            alignSelf: m.who === 'owner' ? 'flex-end' : 'flex-start',
                            maxWidth: '86%',
                            background: m.who === 'owner' ? 'rgba(0,255,136,0.08)' : C.raised,
                            border: `1px solid ${m.who === 'owner' ? 'rgba(0,255,136,0.2)' : C.border}`,
                            borderRadius: 6,
                            padding: '7px 10px',
                          }}
                        >
                          <div style={{ fontSize: 10, color: C.muted, fontFamily: C.mono, marginBottom: 3 }}>{m.at.replace('T', ' ').slice(0, 16)}</div>
                          <div style={{ fontSize: 12.5, color: '#d8d8d8', whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{unframe(m.text)}</div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div style={{ fontSize: 12, color: C.muted }}>{context ? ui.noDialog : ui.loading}</div>
                  )}
                </div>

                {hint && (
                  <div style={{ ...box, padding: 12 }}>
                    <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono, marginBottom: 6 }}>{ui.hint}</div>
                    <div style={{ fontSize: 11.5, color: C.muted, lineHeight: 1.55 }} data-lang-exempt="live">
                      {hint}
                    </div>
                  </div>
                )}
              </>
            )}
          </main>
        )}
      </div>
    </div>
  )
}
