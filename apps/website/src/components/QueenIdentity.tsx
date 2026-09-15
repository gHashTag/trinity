// The Queen's identity chip: who is playing, from src/lib/triIdentity.ts.
//
// Never blank. One polite status region of one fixed width, and one next step
// for every answer (chipOf in triIdentity.ts):
//   pending            a quiet skeleton; "Checking TRI…" for a screen reader
//   consent-required   "Confirm in TRI", pointing at the prompt; after Not now
//                      the same button asks for the prompt again
//   signed-out         "Sign in": the player's login, returning to this view
//                      (in the player's Hive it asks the player, which opens
//                      its login in place)
//   expired            "Resume in TRI": the same return link; the player renews
//                      the session silently and comes back
//   sign-in-again      "Sign in again in TRI": a Telegram session is not a web one
//   unavailable        a short reason and Retry
//   web-only, off-site a sentence, nothing to press
//   signed-in          avatar, name and hive role, all text nodes

import { useEffect, useSyncExternalStore, type ReactNode } from 'react'
import { HUD_VIEWS } from './queenHud'
import { TRI_SCREENS } from '../lib/triScreens'
import { chipOf, signInHref, triIdentity, type ChipReason, type HiveRole } from '../lib/triIdentity'

export interface IdentityCopy {
  signIn: string
  signInTitle: string
  signInAgain: string
  signedIn: string
  roleKeeper: string
  roleOwner: string
  roleBee: string
  pending: string
  confirm: string
  confirmTitle: string
  confirmAgainTitle: string
  resume: string
  resumeTitle: string
  retry: string
  offline: string
  noAnswer: string
  busy: string
  refused: string
  unavailable: string
  webOnly: string
  offSite: string
}

const SCREEN_IDS = TRI_SCREENS.map((entry) => entry.screen)

const roleLabel = (c: IdentityCopy, role: HiveRole): string =>
  role === 'keeper' ? c.roleKeeper : role === 'owner' ? c.roleOwner : c.roleBee

const reasonText = (c: IdentityCopy, reason: ChipReason | undefined): string =>
  reason === 'offline' ? c.offline : reason === 'no_answer' ? c.noAnswer : reason === 'busy' ? c.busy : reason === 'refused' ? c.refused : c.unavailable

export function QueenIdentity({ c, view, screen, lang }: { c: IdentityCopy; view: string; screen: string | null; lang: string }) {
  const identity = triIdentity()
  // Before the store subscribes, so the bridge mounts in this language.
  useEffect(() => {
    identity.setLanguage(lang)
  }, [identity, lang])
  const me = useSyncExternalStore(identity.subscribe, identity.getSnapshot)
  const chip = chipOf(me)

  const signIn = (text: string, title: string) =>
    identity.inPlayer() ? (
      <button type="button" className="queen27-identity-action" onClick={() => identity.signIn()} title={title}>
        {text}
      </button>
    ) : (
      <a className="queen27-identity-action" href={signInHref(view, HUD_VIEWS, screen, SCREEN_IDS)} target="_top" rel="noopener" title={title}>
        {text}
      </a>
    )

  let body: ReactNode
  switch (chip.kind) {
    case 'pending':
      body = (
        <>
          <span className="queen27-identity-skeleton" aria-hidden="true" />
          <span className="queen27-identity-sr">{c.pending}</span>
        </>
      )
      break
    case 'consent-required':
      body = (
        <button type="button" className="queen27-identity-action" onClick={() => identity.retry()} title={me.dismissed ? c.confirmAgainTitle : c.confirmTitle}>
          {c.confirm}
          {!me.dismissed && <span aria-hidden="true"> ↘</span>}
        </button>
      )
      break
    case 'signed-out':
      body = signIn(c.signIn, c.signInTitle)
      break
    case 'expired':
      body = signIn(c.resume, c.resumeTitle)
      break
    case 'sign-in-again':
      body = (
        <a className="queen27-identity-action" href="#/queen?tab=tri">
          {c.signInAgain}
        </a>
      )
      break
    case 'unavailable':
      body = (
        <>
          <span className="queen27-identity-reason" title={reasonText(c, chip.reason)}>
            {reasonText(c, chip.reason)}
          </span>
          <button type="button" className="queen27-identity-action queen27-identity-retry" onClick={() => identity.retry()}>
            {c.retry}
          </button>
        </>
      )
      break
    case 'web-only':
      body = <span className="queen27-identity-reason">{c.webOnly}</span>
      break
    case 'off-site':
      body = <span className="queen27-identity-reason">{c.offSite}</span>
      break
    case 'signed-in': {
      const name = me.name ?? c.signedIn
      body = (
        <span className="queen27-identity-who" title={name}>
          {me.avatar && <img className="queen27-identity-avatar" src={me.avatar} alt="" width={18} height={18} referrerPolicy="no-referrer" />}
          <span className="queen27-identity-name">{name}</span>
          {me.role && <span className="queen27-identity-role">{roleLabel(c, me.role)}</span>}
        </span>
      )
      break
    }
  }

  return (
    <span data-tool="identity" data-identity={chip.kind} data-code={me.code} className="queen27-identity" role="status" aria-live="polite" lang={lang === 'ru' ? 'ru' : 'en'}>
      {body}
    </span>
  )
}
