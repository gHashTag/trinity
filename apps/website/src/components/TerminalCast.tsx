import { useEffect, useRef } from 'react'
import { useI18n } from '../i18n/context'

// A recorded terminal session in a post. The player itself is public/term/player.js,
// the one the t27.ai/term/<id>/ share pages use, loaded at run time so the VT code
// exists once on the web. Recordings are made and published with `tri cast`.

type Player = { destroy: () => void }
type PlayerModule = { mount: (el: HTMLElement, o: { src: string; title?: string; share?: string }) => Player }

export default function TerminalCast({ src, title, caption, share }: { src: string; title?: string; caption: string; share?: string }) {
  const box = useRef<HTMLDivElement>(null)
  const { lang } = useI18n()

  useEffect(() => {
    let player: Player | null = null
    let live = true
    const url = new URL('term/player.js', document.baseURI).href
    import(/* @vite-ignore */ url)
      .then((m: PlayerModule) => {
        if (live && box.current) player = m.mount(box.current, { src: new URL(src, document.baseURI).href, title, share })
      })
      .catch(() => {
        if (box.current) box.current.textContent = 'The terminal player could not load.'
      })
    return () => {
      live = false
      player?.destroy()
    }
  }, [src, title, share])

  return (
    <figure style={{ margin: '0 0 1.8em' }}>
      <div ref={box} />
      <figcaption style={{ fontSize: '0.86rem', opacity: 0.75, marginTop: '10px', lineHeight: 1.5 }}>
        {caption}
        {share && (
          <>
            {' '}
            <a href={share} style={{ color: 'var(--accent, #00FF88)' }}>
              {lang === 'ru' ? 'Открыть запись на отдельной странице.' : 'Open the recording on its own page.'}
            </a>
          </>
        )}
      </figcaption>
    </figure>
  )
}
