import type { HudView } from "./queenHud";

// The COMMAND PANEL of the one-screen HUD: five view switches stacked down the
// left edge (or, on a phone, laid out as an icon row inside the bottom bar) and
// a collapse toggle. Switching a view is the only thing a button here does;
// nothing acts on the Queen. The digit shown on each button is the keyboard
// shortcut the shell binds (1-5), not a figure from the wire.

export interface CommandItem {
  view: HudView;
  glyph: string;
  label: string;
  hint: string;
}

export interface QueenCommandLabels {
  /** aria-label of the <nav> */
  aria: string;
  collapse: string;
  expand: string;
}

export interface QueenCommandProps {
  items: CommandItem[];
  view: HudView;
  onSelect: (view: HudView) => void;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  /** Phone mode: an icon row, no hints, no collapse button. */
  compact?: boolean;
  labels: QueenCommandLabels;
}

export function QueenCommandPanel({
  items,
  view,
  onSelect,
  collapsed,
  onToggleCollapsed,
  compact = false,
  labels,
}: QueenCommandProps) {
  const className = [
    "queen27-hud-command",
    collapsed && !compact ? "is-collapsed" : "",
    compact ? "is-compact" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <nav className={className} aria-label={labels.aria}>
      {items.map((item, index) => {
        const active = item.view === view;
        return (
          <button
            type="button"
            key={item.view}
            className={`queen27-hud-cmd${active ? " is-active" : ""}`}
            data-view={item.view}
            aria-pressed={active}
            title={`${index + 1} · ${item.label}`}
            onClick={() => onSelect(item.view)}
          >
            <i aria-hidden="true">{item.glyph}</i>
            <span>
              <b>{item.label}</b>
              <small>{item.hint}</small>
            </span>
            <kbd aria-hidden="true">{index + 1}</kbd>
          </button>
        );
      })}
      {!compact && (
        <button
          type="button"
          className="queen27-hud-cmd-collapse"
          aria-pressed={collapsed}
          title={collapsed ? labels.expand : labels.collapse}
          onClick={onToggleCollapsed}
        >
          <i aria-hidden="true">{collapsed ? "»" : "«"}</i>
          <span>{collapsed ? labels.expand : labels.collapse}</span>
        </button>
      )}
    </nav>
  );
}
