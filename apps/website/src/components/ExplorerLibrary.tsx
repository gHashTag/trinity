// The library aside every Explorer page shares: a search box, one category
// select, a row of counted group filters over a stacked bar, collapsible tag
// facets, and the list itself.
//
// Generic over ExplorerItem rather than copied per page: the counts live inside
// the filters, so the summary and the navigation are one control that cannot
// disagree with itself. Three pages now depend on that being true in one place.

import { useMemo, useState } from 'react'
import { C, HEALTH_GLYPH, tagChip, inputStyle, selectStyle, type Health } from '../lib/explorerTheme'
import { HealthDot, StackBar, type StackSegment } from './SpecGraphics'
import type { ViewportTier } from '../lib/viewport.generated'

export interface ExplorerItem {
  id: string
  title: string
  /** Dimmed second line, e.g. the directory a file sits in. */
  subtitle?: string
  /** Small outlined label after the title, e.g. START HERE. */
  badge?: string
  badgeColor?: string
  health?: Health
  tags: string[]
  /** Everything the search box should match, already lower-cased by the page. */
  haystack: string
}

export interface GroupFilter {
  key: string
  label: string
  count: number
  color?: string
  glyph?: string
}

export interface TagFamily {
  prefix: string
  label: string
}

export function ExplorerLibrary({
  items,
  selectedId,
  onPick,
  onPrefetch,
  query,
  setQuery,
  categories,
  category,
  setCategory,
  filters,
  filter,
  setFilter,
  stack,
  tagCounts,
  tagFamilies,
  tagSel,
  toggleTag,
  clearTags,
  tier,
  countLabel,
  titlesAreGenerated,
  ui,
}: {
  items: ExplorerItem[]
  selectedId: string | null
  onPick: (item: ExplorerItem) => void
  onPrefetch?: (item: ExplorerItem) => void
  query: string
  setQuery: (v: string) => void
  /** [value, label, count]; an empty list hides the select. */
  categories: [string, string, number][]
  category: string
  setCategory: (v: string) => void
  filters: GroupFilter[]
  filter: string
  setFilter: (v: string) => void
  stack?: StackSegment[]
  tagCounts: Record<string, number>
  tagFamilies: TagFamily[]
  tagSel: string[]
  toggleTag: (t: string) => void
  clearTags: () => void
  /**
   * From useViewport. Phone: the aside is the whole screen. Phone and tablet:
   * the category, group and tag controls fold into one collapsible row under
   * the search box, so the list keeps the height (spec: TABLET_PANES = 2 with
   * filters as a collapsible row). Desktop: unchanged.
   */
  tier: ViewportTier
  /** e.g. "12 skills" — already interpolated by the page. */
  countLabel: string
  /**
   * Row titles are generated names (a skill's, a job's), not UI copy, so the
   * language audits must not read them as untranslated interface text. The
   * same treatment /specs gives quoted source.
   */
  titlesAreGenerated?: boolean
  ui: {
    search: string
    allCategories: string
    tags: string
    clear: string
    noResults: string
    noneInGroup: string
    filters: string
  }
}) {
  const phone = tier === 'phone'
  const compact = tier === 'phone' || tier === 'tablet'
  const [tagsOpen, setTagsOpen] = useState(false)
  const [filtersOpen, setFiltersOpen] = useState(false)
  // How many constraints are live while the row is folded, so a filtered list
  // never looks like the whole library.
  const activeFilters = (category ? 1 : 0) + (filters.length > 0 && filter !== filters[0].key ? 1 : 0) + tagSel.length
  const allTags = useMemo(
    () => Object.keys(tagCounts).sort((a, b) => (tagCounts[b] ?? 0) - (tagCounts[a] ?? 0) || a.localeCompare(b)),
    [tagCounts],
  )

  return (
    <aside
      style={{
        width: phone ? '100%' : tier === 'tablet' ? 260 : 300,
        minWidth: phone ? 0 : 180,
        flexShrink: 1,
        borderRight: phone ? 'none' : `1px solid ${C.border}`,
        display: 'flex',
        flexDirection: 'column',
        minHeight: 0,
      }}
    >
      <div style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={ui.search}
          aria-label={ui.search}
          style={inputStyle}
        />
        {compact && (categories.length > 0 || filters.length > 0 || allTags.length > 0) && (
          <button
            onClick={() => setFiltersOpen((v) => !v)}
            aria-expanded={filtersOpen}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              width: '100%',
              background: 'transparent',
              border: `1px solid ${activeFilters ? C.accent : C.border}`,
              borderRadius: 5,
              color: activeFilters ? C.accent : C.muted,
              padding: '2px 10px',
              cursor: 'pointer',
              fontSize: 11.5,
              fontFamily: 'inherit',
            }}
          >
            <span aria-hidden="true" style={{ fontSize: 9 }}>{filtersOpen ? '▾' : '▸'}</span>
            <span>{ui.filters}</span>
            {activeFilters > 0 && <span style={{ fontFamily: C.mono }}>{activeFilters}</span>}
          </button>
        )}
        {(!compact || filtersOpen) && <>
        {categories.length > 0 && (
          <select value={category} onChange={(e) => setCategory(e.target.value)} aria-label={ui.allCategories} style={selectStyle}>
            <option value="">{ui.allCategories}</option>
            {categories.map(([value, label, n]) => (
              <option key={value} value={value}>
                {label} ({n})
              </option>
            ))}
          </select>
        )}
        {filters.length > 0 && (
          <>
            <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
              {filters.map((f) => {
                const on = filter === f.key
                const col = f.color ?? C.muted
                return (
                  <button
                    key={f.key}
                    onClick={() => setFilter(f.key)}
                    aria-pressed={on}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 4,
                      background: on ? 'rgba(255,255,255,0.07)' : 'transparent',
                      border: `1px solid ${on ? col : C.border}`,
                      borderRadius: 999,
                      color: on ? col : C.muted,
                      padding: '2px 9px',
                      cursor: 'pointer',
                      fontSize: 11,
                      fontFamily: 'inherit',
                    }}
                  >
                    {f.glyph && <span aria-hidden="true">{f.glyph}</span>}
                    <span>{f.label}</span>
                    <span style={{ fontFamily: C.mono, opacity: 0.8 }}>{f.count}</span>
                  </button>
                )
              })}
            </div>
            {stack && stack.length > 0 && <StackBar segments={stack} />}
          </>
        )}
        {allTags.length > 0 && (
          <div>
            <button
              onClick={() => setTagsOpen((v) => !v)}
              aria-expanded={tagsOpen}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                width: '100%',
                background: 'transparent',
                border: 'none',
                color: tagSel.length ? C.accent : C.muted,
                padding: '2px 0',
                cursor: 'pointer',
                fontSize: 11.5,
                fontFamily: 'inherit',
              }}
            >
              <span aria-hidden="true" style={{ fontSize: 9 }}>{tagsOpen ? '▾' : '▸'}</span>
              <span>{ui.tags}</span>
              {tagSel.length > 0 && <span style={{ fontFamily: C.mono }}>{tagSel.length}</span>}
              {tagSel.length > 0 && (
                <span
                  role="button"
                  tabIndex={0}
                  onClick={(e) => { e.stopPropagation(); clearTags() }}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.stopPropagation(); clearTags() } }}
                  style={{ marginLeft: 'auto', color: C.muted, textDecoration: 'underline', cursor: 'pointer' }}
                >
                  {ui.clear}
                </span>
              )}
            </button>
            {/* Selected tags stay visible when the panel is shut, so the filter
                is never invisibly active. */}
            {!tagsOpen && tagSel.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 3, marginTop: 4 }}>
                {tagSel.map((t) => (
                  <button key={t} onClick={() => toggleTag(t)} style={tagChip(true, false)}>
                    {t} ✕
                  </button>
                ))}
              </div>
            )}
            {tagsOpen && (
              <div style={{ marginTop: 6, display: 'flex', flexDirection: 'column', gap: 7 }}>
                {tagFamilies.map((fam) => {
                  const inFam = allTags.filter((t) => (fam.prefix === '' ? !t.includes('/') : t.startsWith(fam.prefix)))
                  if (!inFam.length) return null
                  return (
                    <div key={fam.prefix || 'plain'}>
                      <div style={{ fontSize: 9.5, letterSpacing: 0.6, color: C.muted, opacity: 0.7, marginBottom: 3 }}>
                        {fam.label.toUpperCase()}
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 3 }}>
                        {inFam.map((t) => {
                          const on = tagSel.includes(t)
                          const n = tagCounts[t] ?? 0
                          const dead = n === 0 && !on
                          return (
                            <button
                              key={t}
                              onClick={() => !dead && toggleTag(t)}
                              disabled={dead}
                              aria-pressed={on}
                              title={t}
                              style={tagChip(on, dead)}
                            >
                              {t.includes('/') ? t.slice(t.indexOf('/') + 1) : t}
                              <span style={{ opacity: 0.6, marginLeft: 4 }}>{n}</span>
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}
        </>}
        <div style={{ fontSize: 11, color: C.muted, fontFamily: C.mono }}>{countLabel}</div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {items.length === 0 && (
          <div style={{ padding: 14, fontSize: 12.5, color: C.muted }}>
            {query || category ? ui.noResults : ui.noneInGroup}
          </div>
        )}
        {items.map((item) => {
          const active = selectedId === item.id
          return (
            <button
              key={item.id}
              onClick={() => onPick(item)}
              onPointerEnter={() => onPrefetch?.(item)}
              onFocus={() => onPrefetch?.(item)}
              aria-label={`${item.title} — ${item.subtitle ?? item.id}`}
              aria-current={active ? 'true' : undefined}
              style={{
                display: 'flex',
                gap: 8,
                width: '100%',
                textAlign: 'left',
                background: active ? 'rgba(0,255,136,0.10)' : 'transparent',
                border: 'none',
                borderLeft: `2px solid ${active ? C.accent : 'transparent'}`,
                color: active ? C.accent : C.text,
                padding: '7px 10px',
                cursor: 'pointer',
                fontFamily: C.mono,
                fontSize: 12,
                alignItems: 'flex-start',
              }}
            >
              {item.health && (
                <span style={{ paddingTop: 2 }}>
                  <HealthDot health={item.health} />
                </span>
              )}
              <span style={{ minWidth: 0, flex: 1 }}>
                <span style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                  <span
                    data-lang-exempt={titlesAreGenerated ? 'live' : undefined}
                    style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', fontWeight: 600 }}
                  >
                    {item.title}
                  </span>
                  {item.badge && (
                    <span
                      style={{
                        fontSize: 8.5,
                        letterSpacing: 0.5,
                        color: item.badgeColor ?? C.golden,
                        border: `1px solid ${item.badgeColor ?? C.golden}`,
                        borderRadius: 3,
                        padding: '0 4px',
                        flexShrink: 0,
                      }}
                    >
                      {item.badge}
                    </span>
                  )}
                  {item.health && (
                    <span aria-hidden="true" style={{ marginLeft: 'auto', opacity: 0.55, fontSize: 10 }}>
                      {HEALTH_GLYPH[item.health]}
                    </span>
                  )}
                </span>
                {item.subtitle && (
                  <span
                    style={{
                      display: 'block',
                      fontSize: 10,
                      color: C.muted,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {item.subtitle}
                  </span>
                )}
              </span>
            </button>
          )
        })}
      </div>
    </aside>
  )
}
