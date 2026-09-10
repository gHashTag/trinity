import { useCallback, useEffect, useMemo, useState } from 'react'

/**
 * The query part of a hash route.
 *
 * HashRouter puts the route in the fragment, so `#/skills?skill=x&embed=1`
 * carries its parameters after the `?` inside the hash, never in
 * location.search. Nothing here is sent to any server: the fragment stays in
 * the browser by construction.
 *
 * `get` reads the address bar as it is now, and `changes` counts the
 * `hashchange` / `popstate` events since mount, so a page can follow a deep
 * link that arrives after it mounted (the back button, a link on the same
 * page, a script setting location.hash). Measured before this: a phone loading
 * `#/tools` kept the list even when the hash was changed to a `?tool=` deep
 * link afterwards, because the parameters were read once. `set` uses
 * replaceState, which fires neither event, so a page writing its own state
 * back to the address bar does not hear itself.
 */
const readHash = () => new URLSearchParams(typeof window === 'undefined' ? '' : window.location.hash.split('?')[1] || '')

export function useHashParams() {
  const initial = useMemo(() => readHash(), [])
  const [changes, setChanges] = useState(0)
  useEffect(() => {
    const bump = () => setChanges((n) => n + 1)
    window.addEventListener('hashchange', bump)
    window.addEventListener('popstate', bump)
    return () => {
      window.removeEventListener('hashchange', bump)
      window.removeEventListener('popstate', bump)
    }
  }, [])
  const get = useCallback((key: string) => readHash().get(key), [])
  /** Rewrite the address bar without a history entry, so browsing does not pile up entries. */
  const set = useCallback((hash: string) => {
    window.history.replaceState(null, '', hash)
  }, [])
  // Memoised: the pages hold callbacks that close over this object, and a new
  // identity on every render would rebuild every one of them for nothing.
  // `embedded` is read once: the frame that embeds a page does not change under it.
  return useMemo(() => ({ get, set, embedded: initial.get('embed') === '1', changes }), [get, set, initial, changes])
}
