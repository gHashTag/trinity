import { useEffect } from 'react'

const SITE = 'TRINITY'

/**
 * Sets the document title and meta description for a routed page.
 *
 * This helps tabs, bookmarks and browser history — but note it cannot fix link
 * previews: the app uses HashRouter, and a URL fragment is never sent to the
 * server, so a crawler fetching t27.ai/#/verification receives the homepage and
 * never runs this code. Per-route previews come from the static stub pages in
 * the apex repository instead.
 */
export function usePageMeta(title: string, description?: string) {
  useEffect(() => {
    const previousTitle = document.title
    document.title = `${title} · ${SITE}`

    let previousDescription: string | undefined
    let tag: HTMLMetaElement | null = null
    if (description) {
      tag = document.querySelector('meta[name="description"]')
      if (tag) {
        previousDescription = tag.content
        tag.content = description
      }
    }

    return () => {
      document.title = previousTitle
      if (tag && previousDescription !== undefined) tag.content = previousDescription
    }
  }, [title, description])
}
