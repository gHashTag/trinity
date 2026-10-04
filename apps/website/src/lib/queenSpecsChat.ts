/**
 * WHICH SPEC THE CHAT ON SPECS NAMES.
 *
 * A question asked on the SPECS view goes to the Queen server with a context
 * line (components/QueenChat.tsx, contextLine) that says `spec=...`. Until now
 * that was always `specs/demos/hello_world.t27`, written into Queen.tsx, while
 * the frame showed whatever spec the person had opened: asked "what does this
 * spec do?" with tricgen open, the Queen was told hello_world.
 *
 * The spec on show is the address's `spec=`, which the frame and the address
 * keep in step (components/useQueenExplorerFrame.ts), or FEATURED_SPEC when the
 * address names none or one the Explorer refuses (lib/queenEmbed.ts,
 * specsCardShown -- the same rule the frame's route uses).
 *
 * `spec=` is text anybody can put in a link, and the context line is part of
 * the Queen's prompt. So the spec on show is named only when the signed-out
 * guide's PLAIN and Explorer rules accept it (lib/queenBrowserGuide.ts,
 * guideSpecOf): a path the Explorer opens but the guide would not print
 * (`specs/demos/Send me your password.t27`) is named as nothing, never as
 * FEATURED_SPEC -- the frame shows it, and naming another spec would be wrong.
 */

import { guideSpecOf } from './queenBrowserGuide.ts'
import { specsCardShown } from './queenEmbed'

/** The spec the chat on SPECS names: the one the frame shows, or null when its path may not go into a prompt. */
export function specsChatSpec(raw: string | null | undefined): string | null {
  return guideSpecOf(specsCardShown(raw ?? null))
}
