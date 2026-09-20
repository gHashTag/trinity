// The sub-navigation a module draws for the views it holds.
//
// SPECS, SKILLS, CRONS, AGENTS, TOOLS and FUNCTIONS used to be six of the
// rail's fourteen buttons, side by side with the comb and the kanban board as
// though they were the same kind of thing. They are not: each is a catalog
// generated from .t27 specs, and each names the one below it. The rail now
// carries SPECS alone and this row carries the layers, which is also the first
// place in the shell where the ladder is drawn as a ladder -- numbered, in
// order, with the layer you are standing on marked.
//
// The board asks the same of its three: KANBAN, MISSION MAP and FACTORY are
// three readings of the one board, so KANBAN carries them here rather than the
// rail carrying three buttons for one subject. One row, one style, one place a
// family is drawn -- which is why this component is a family's row and not the
// ladder's alone, and why what it takes is a HudView rather than a SpecLayer.
//
// A button is the Queen's own `setView`, so a member is still a tab in the
// address (#/queen?tab=agents&agent=E, #/queen?tab=map) and still opens on its
// old key. Nothing about deep links, the keyboard or the Explorer frames
// changed; only where the button lives.

import type { LadderCounts } from '../lib/agentSpecs'
import { SPEC_LAYERS, hudKeyOf, type HudView } from './queenHud'

export interface LadderLayer {
  layer: HudView
  glyph: string
  label: string
  hint: string
}

export function QueenLadder({
  layers,
  current,
  onSelect,
  aria,
  counts,
  family = 'specs',
}: {
  layers: readonly LadderLayer[]
  current: HudView
  onSelect: (layer: HudView) => void
  aria: string
  /** How many each layer holds; null until the catalog answers, and on failure.
   *  The board has no such number, and draws the row without one. */
  counts?: LadderCounts | null
  /** Which family this row is, for anything that needs to tell them apart. */
  family?: 'specs' | 'board'
}) {
  return (
    <nav className="queen27-ladder" data-family={family} aria-label={aria}>
      {layers.map((item, index) => {
        const active = item.layer === current
        const key = hudKeyOf(item.layer)
        // The count the Explorer's own strip used to carry. It arrives one
        // fetch late, so the element is always drawn and the CSS reserves its
        // width -- a number appearing into a row that then rewraps is the jump
        // this change exists to remove.
        const count = counts && item.layer in counts ? counts[item.layer as keyof LadderCounts] : null
        return (
          <button
            type="button"
            key={item.layer}
            className={`queen27-ladder-step${active ? ' is-active' : ''}`}
            data-layer={item.layer}
            aria-pressed={active}
            aria-current={active ? 'page' : undefined}
            title={`${key} · ${item.label}${count === null ? '' : ` · ${count}`} — ${item.hint}`}
            onClick={() => onSelect(item.layer)}
          >
            <em aria-hidden="true">{index + 1}</em>
            <i aria-hidden="true">{item.glyph}</i>
            <b>{item.label}</b>
            <span className="queen27-ladder-count" data-lang-exempt="live">
              {count === null ? '' : count}
            </span>
            <kbd aria-hidden="true">{key}</kbd>
          </button>
        )
      })}
    </nav>
  )
}

/** The ladder in the order queenHud states it, for a caller building its own labels. */
export const LADDER_ORDER = SPEC_LAYERS
