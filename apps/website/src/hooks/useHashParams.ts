import { useCallback, useMemo } from 'react'

/**
 * The query part of a hash route, read once on mount.
 *
 * HashRouter puts the route in the fragment, so `#/skills?skill=x&embed=1`
 * carries its parameters after the `?` inside the hash, never in
 * location.search. Nothing here is sent to any server: the fragment stays in
 * the browser by construction.
 */
export function useHashParams() {
  const initial = useMemo(
    () => new URLSearchParams(typeof window === 'undefined' ? '' : window.location.hash.split('?')[1] || ''),
    [],
  )
  const get = useCallback((key: string) => initial.get(key), [initial])
  /** Rewrite the address bar without a history entry, so browsing does not pile up entries. */
  const set = useCallback((hash: string) => {
    window.history.replaceState(null, '', hash)
  }, [])
  return { get, set, embedded: initial.get('embed') === '1' }
}
