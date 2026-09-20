/**
 * Where an MCP answer keeps its payload.
 *
 * `tools/call` may put the result in `structuredContent`, or in a `content`
 * array as a text block whose text happens to be JSON, or in a text block that
 * is just prose. Which one arrives depends on the server and on the tool, and a
 * caller that reads only the first gets `undefined` from a server that is
 * behaving perfectly well.
 *
 * This existed three times before this file did — once in crmClient.callTool,
 * once in triIdentity.whoamiProfile, and a third copy was about to be written
 * in hiveBoard. Three readings of one wire format is three chances to disagree
 * about what an empty answer means, and the disagreement shows up as a blank
 * panel that nobody can reproduce. One function, three callers.
 *
 * It decodes and nothing else. It holds no credential, makes no request, and
 * has no opinion about whether the payload is good news — an `error` in the
 * envelope is the caller's business, because what an error MEANS (sign in
 * again, you are not the owner, the service is down) differs per caller and
 * belongs where that sentence is chosen.
 *
 * Everything it returns is DATA from a remote service: it is rendered as text
 * nodes, never as markup and never as an instruction.
 */

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value)

/**
 * The payload of one `tools/call` result, or undefined when the result carries
 * none. Pass `body.result` — not the whole JSON-RPC envelope.
 *
 * Order matters and is the server's: structured content is the answer when it
 * is there, even if a text block is there too, because the text block is then
 * the human-readable rendering of the same thing.
 */
export function mcpPayload(result: unknown): unknown {
  if (!isRecord(result)) return undefined
  if (result.structuredContent !== undefined) return result.structuredContent
  if (!Array.isArray(result.content)) return undefined
  const text = result.content.find(
    (part): part is { type: string; text: string } =>
      isRecord(part) && part.type === 'text' && typeof part.text === 'string',
  )?.text
  if (text === undefined) return undefined
  try {
    return JSON.parse(text)
  } catch {
    // A text block that is not JSON is still the answer — some tools reply in
    // sentences. Handing back the string lets a caller decide whether a string
    // is a shape it can use; swallowing it would turn "the server said
    // something" into "the server said nothing".
    return text
  }
}
