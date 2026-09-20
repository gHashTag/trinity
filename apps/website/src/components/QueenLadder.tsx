// The sub-navigation of the SPECS module: the six layers of the ladder.
//
// SPECS, SKILLS, CRONS, AGENTS, TOOLS and FUNCTIONS used to be six of the
// rail's fourteen buttons, side by side with the comb and the kanban board as
// though they were the same kind of thing. They are not: each is a catalog
// generated from .t27 specs, and each names the one below it. The rail now
// carries SPECS alone and this row carries the layers, which is also the first
// place in the shell where the ladder is drawn as a ladder -- numbered, in
// order, with the layer you are standing on marked.
//
// A button is the Queen's own `setView`, so a layer is still a tab in the
// address (#/queen?tab=agents&agent=E) and still opens on its old key. Nothing
// about deep links, the keyboard or the Explorer frames changed; only where the
// button lives.

import { SPEC_LAYERS, hudKeyOf, type HudView, type SpecLayer } from './queenHud'

export interface LadderLayer {
  layer: SpecLayer
  glyph: string
  label: string
  hint: string
}

export function QueenLadder({
  layers,
  current,
  onSelect,
  aria,
}: {
  layers: readonly LadderLayer[]
  current: HudView
  onSelect: (layer: SpecLayer) => void
  aria: string
}) {
  return (
    <nav className="queen27-ladder" aria-label={aria}>
      {layers.map((item, index) => {
        const active = item.layer === current
        const key = hudKeyOf(item.layer)
        return (
          <button
            type="button"
            key={item.layer}
            className={`queen27-ladder-step${active ? ' is-active' : ''}`}
            data-layer={item.layer}
            aria-pressed={active}
            aria-current={active ? 'page' : undefined}
            title={`${key} · ${item.label} — ${item.hint}`}
            onClick={() => onSelect(item.layer)}
          >
            <em aria-hidden="true">{index + 1}</em>
            <i aria-hidden="true">{item.glyph}</i>
            <b>{item.label}</b>
            <kbd aria-hidden="true">{key}</kbd>
          </button>
        )
      })}
    </nav>
  )
}

/** The ladder in the order queenHud states it, for a caller building its own labels. */
export const LADDER_ORDER = SPEC_LAYERS
