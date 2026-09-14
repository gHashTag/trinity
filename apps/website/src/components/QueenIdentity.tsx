// The Queen's identity chip: who is playing, from src/lib/triIdentity.ts.
//
// Signed in: avatar, name and hive role, all text nodes. Signed out: "Sign in",
// a top-level link to the player's login that returns to this view. A web
// session the server does not accept as a parent: "Sign in again in TRI".
// Nothing while the answer is pending, the bridge is asking for its click, or
// the identity is unavailable.

import { useSyncExternalStore } from 'react'
import { HUD_VIEWS } from './queenHud'
import { signInHref, triIdentity, type HiveRole } from '../lib/triIdentity'

export interface IdentityCopy {
  signIn: string
  signInTitle: string
  signInAgain: string
  signedIn: string
  roleKeeper: string
  roleOwner: string
  roleBee: string
}

const roleLabel = (c: IdentityCopy, role: HiveRole): string =>
  role === 'keeper' ? c.roleKeeper : role === 'owner' ? c.roleOwner : c.roleBee

export function QueenIdentity({ c, view }: { c: IdentityCopy; view: string }) {
  const identity = triIdentity()
  const me = useSyncExternalStore(identity.subscribe, identity.getSnapshot)

  if (me.state === 'signed-out') {
    return (
      <a data-tool="identity" data-identity="signed-out" className="queen27-identity" href={signInHref(view, HUD_VIEWS)} target="_top" rel="noopener" title={c.signInTitle}>
        {c.signIn}
      </a>
    )
  }
  if (me.state === 'unavailable' && me.code === 'game_token_parent_not_web') {
    return (
      <a data-tool="identity" data-identity="sign-in-again" className="queen27-identity" href="#/queen?tab=tri">
        {c.signInAgain}
      </a>
    )
  }
  if (me.state !== 'signed-in') return null
  const name = me.name ?? c.signedIn
  return (
    <span data-tool="identity" data-identity="signed-in" className="queen27-identity" title={name}>
      {me.avatar && <img className="queen27-identity-avatar" src={me.avatar} alt="" width={18} height={18} referrerPolicy="no-referrer" />}
      <span className="queen27-identity-name">{name}</span>
      {me.role && <span className="queen27-identity-role">{roleLabel(c, me.role)}</span>}
    </span>
  )
}
