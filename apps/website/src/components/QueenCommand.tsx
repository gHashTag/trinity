import { useEffect, useRef, type CSSProperties } from "react";
import { type HudView } from "./queenHud";

// The COMMAND PANEL of the one-screen HUD: the view switches (one per entry in
// RAIL_VIEWS) stacked down the left edge (or, on a phone, laid out as an icon
// row inside the bottom bar) and a collapse toggle. Switching a view is the only
// thing a button here does; nothing acts on the Queen. The key shown on each
// button is the keyboard shortcut the shell binds, and it travels on the item
// (hudKeyOf) rather than being read from the item's position: the rail is nine
// buttons over a fourteen-name address, because the five ladder layers are
// reached inside SPECS, and a position would have printed the wrong letter on
// every button after it.

export interface CommandItem {
  view: HudView;
  glyph: string;
  label: string;
  hint: string;
  /** The keyboard shortcut this view answers (queenHud.hudKeyOf). */
  hotkey: string;
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
  // Phone row: about six of the buttons fit, so a view opened by a deep link or
  // a key (t, p, r) would leave its button off-screen. Scroll the row itself --
  // scrollIntoView could scroll the one-viewport shell instead.
  const railRef = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!compact) return;
    const rail = railRef.current;
    const button = rail?.querySelector<HTMLElement>(".queen27-hud-cmd.is-active");
    if (!rail || !button) return;
    const r = rail.getBoundingClientRect();
    const b = button.getBoundingClientRect();
    if (b.left < r.left) rail.scrollLeft += b.left - r.left - 4;
    else if (b.right > r.right) rail.scrollLeft += b.right - r.right + 4;
  }, [compact, view]);

  const className = [
    "queen27-hud-command",
    collapsed && !compact ? "is-collapsed" : "",
    compact ? "is-compact" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <nav
      ref={railRef}
      className={className}
      aria-label={labels.aria}
      data-views={items.length}
      style={
        {
          // the rail derives its row count from the item list, never from a hardcoded number
          "--queen-views": items.length,
          "--queen-tile-rows": Math.ceil(items.length / 2),
          // the portrait phone lays the rail out as two rows (queen-phone.css),
          // so its column count is half the views, rounded up: 13 views, 7 columns
          "--queen-phone-cols": Math.ceil(items.length / 2),
        } as CSSProperties
      }
    >
      {items.map((item) => {
        const active = item.view === view;
        const key = item.hotkey;
        return (
          <button
            type="button"
            key={item.view}
            className={`queen27-hud-cmd${active ? " is-active" : ""}`}
            data-view={item.view}
            aria-pressed={active}
            title={`${key} · ${item.label}`}
            onClick={() => onSelect(item.view)}
          >
            <i aria-hidden="true">{item.glyph}</i>
            <span>
              <b>{item.label}</b>
              <small>{item.hint}</small>
            </span>
            <kbd aria-hidden="true">{key}</kbd>
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
