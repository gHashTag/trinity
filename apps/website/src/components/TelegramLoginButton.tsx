// Telegram's own Login Widget, mounted into a ref.
//
// The widget is the only way a plain web page can prove who is looking at it
// without asking for a password: Telegram signs the user object with the bot's
// token, and the render service verifies that signature before it mints a
// session. Nothing typed here is a credential, and the callback object is
// posted straight to the service and never stored.
//
// It needs one thing done outside this code: the bot whose token verifies the
// hash must have this domain registered with BotFather (/setdomain). Until then
// the button renders and Telegram refuses the origin, so the agent-key door
// below it is the way in.

import { useEffect, useRef } from 'react'

declare global {
  interface Window {
    /** The widget calls this by name from its own script tag. */
    onTelegramAuth?: (user: Record<string, unknown>) => void
  }
}

export function TelegramLoginButton({
  bot,
  onAuth,
  lang,
}: {
  /** Bot username without the @. */
  bot: string
  onAuth: (user: Record<string, unknown>) => void
  lang: string
}) {
  const holder = useRef<HTMLDivElement | null>(null)
  const handler = useRef(onAuth)
  handler.current = onAuth

  useEffect(() => {
    const node = holder.current
    if (!node) return
    window.onTelegramAuth = (user) => handler.current(user)
    const script = document.createElement('script')
    script.src = 'https://telegram.org/js/telegram-widget.js?22'
    script.async = true
    script.setAttribute('data-telegram-login', bot)
    script.setAttribute('data-size', 'large')
    script.setAttribute('data-radius', '6')
    script.setAttribute('data-userpic', 'false')
    script.setAttribute('data-lang', lang === 'ru' ? 'ru' : 'en')
    script.setAttribute('data-onauth', 'onTelegramAuth(user)')
    node.appendChild(script)
    return () => {
      node.replaceChildren()
      delete window.onTelegramAuth
    }
  }, [bot, lang])

  return <div ref={holder} />
}
