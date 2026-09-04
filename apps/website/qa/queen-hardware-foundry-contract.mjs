import { generateKeyPairSync, sign } from 'node:crypto'
import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = fileURLToPath(new URL('..', import.meta.url))
const modelPath = `${root}/src/components/queenHardwareRegistry.ts`
const cityPath = `${root}/src/components/QueenResearchCity.tsx`
const queenPath = `${root}/src/pages/Queen.tsx`
const errors = []

function requirePattern(source, pattern, message) {
  if (!pattern.test(source)) errors.push(message)
}

if (!existsSync(modelPath)) {
  errors.push('Signed hardware registry verifier is missing')
} else {
  try {
    const bundled = await build({
      entryPoints: [modelPath],
      bundle: true,
      format: 'esm',
      platform: 'node',
      write: false,
      logLevel: 'silent',
    })
    const source = bundled.outputFiles[0].text
    const model = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)
    const { publicKey, privateKey } = generateKeyPairSync('ed25519')
    const pinnedKey = publicKey.export({ format: 'pem', type: 'spki' }).toString()
    const now = Date.parse('2026-09-01T18:00:00.000Z')
    const payload = {
      version: 'queen-fpga-registry/v1',
      generatedAt: new Date(now).toISOString(),
      onlineWindowSeconds: 120,
      devices: [
        {
          id: 'wukong-xc7a200t',
          family: 'QMTech Wukong V1 / XC7A200T',
          state: 'programmed',
          evidence: 'https://github.com/gHashTag/t27/blob/master/fpga/HARDWARE_SSOT.md',
        },
      ],
      summary: { total: 1, registered: 0, synthesised: 0, programmed: 1, online: 0 },
    }
    const canonical = JSON.stringify(payload)
    const envelope = {
      algorithm: 'Ed25519',
      keyId: 'queen-fpga-test',
      publicKey: pinnedKey,
      canonical,
      signature: sign(null, Buffer.from(canonical), privateKey).toString('base64url'),
      payload,
    }
    const verified = await model.verifyHardwareEnvelope(envelope, pinnedKey, now)
    if (!verified || verified.devices.length !== 1 || verified.devices[0].state !== 'programmed') {
      errors.push('A valid pinned Ed25519 envelope must expose its verified device')
    }
    if (await model.verifyHardwareEnvelope({ ...envelope, signature: `${envelope.signature}x` }, pinnedKey, now)) {
      errors.push('Invalid signatures must fail closed')
    }
    const other = generateKeyPairSync('ed25519').publicKey.export({ format: 'pem', type: 'spki' }).toString()
    if (await model.verifyHardwareEnvelope(envelope, other, now)) {
      errors.push('A non-pinned public key must fail closed')
    }
    const stalePayload = { ...payload, generatedAt: new Date(now - 60_000).toISOString() }
    const staleCanonical = JSON.stringify(stalePayload)
    const stale = {
      ...envelope,
      canonical: staleCanonical,
      payload: stalePayload,
      signature: sign(null, Buffer.from(staleCanonical), privateKey).toString('base64url'),
    }
    if (await model.verifyHardwareEnvelope(stale, pinnedKey, now)) {
      errors.push('Stale envelopes must fail closed')
    }
    const onlinePayload = {
      ...payload,
      devices: [{ ...payload.devices[0], state: 'online', observedAt: new Date(now - 180_000).toISOString() }],
      summary: { total: 1, registered: 0, synthesised: 0, programmed: 0, online: 1 },
    }
    const onlineCanonical = JSON.stringify(onlinePayload)
    const staleOnline = {
      ...envelope,
      canonical: onlineCanonical,
      payload: onlinePayload,
      signature: sign(null, Buffer.from(onlineCanonical), privateKey).toString('base64url'),
    }
    if (await model.verifyHardwareEnvelope(staleOnline, pinnedKey, now)) {
      errors.push('Online hardware without a fresh signed heartbeat must fail closed')
    }
  } catch (error) {
    errors.push(`Executable hardware verifier failed: ${error instanceof Error ? error.message : error}`)
  }
}

if (existsSync(cityPath)) {
  const city = readFileSync(cityPath, 'utf8')
  // the foundry is drawn by the Babylon scene beside the component (B-4)
  const scenePath = `${root}/src/components/queenResearchCityScene.ts`
  const sceneSource = existsSync(scenePath) ? readFileSync(scenePath, 'utf8') : ''
  requirePattern(sceneSource, /fpga-pad-\$\{device\.id\}/, 'Research City must render a native hardware foundry')
  requirePattern(sceneSource, /hardware\?\.devices/, 'Hardware structures must derive from verified devices')
  requirePattern(city, /hardware=\{hardware\}|hardware,/, 'The city must pass the verified registry to its scene')
}

if (existsSync(queenPath)) {
  const queen = readFileSync(queenPath, 'utf8')
  requirePattern(queen, /\/queen\/public-hardware/, 'Queen must poll the public hardware endpoint')
  requirePattern(queen, /verifyHardwareEnvelope/, 'Queen must verify the signed registry before rendering')
  if (/__QUEEN_HARDWARE_PUBLIC_KEY__/.test(queen)) errors.push('Production hardware public key must be pinned')
}

if (errors.length) {
  errors.forEach((error) => console.error(`Queen hardware foundry contract: ${error}`))
  process.exitCode = 1
} else {
  console.log('Queen hardware foundry contract: PASS (pinned signature, fail-closed heartbeats, native structures)')
}
