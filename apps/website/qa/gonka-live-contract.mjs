// The PROVIDERS tab's live read of the Gonka chain, checked without the chain.
//
// src/lib/gonkaLive.ts parses what four public Gonka endpoints answer and lists
// every field where a model card (specs/providers/gonka/*.t27) and the chain now
// disagree. This gate feeds it responses recorded in the chain's own shape --
// rebuilt from the committed cards, so a faithful chain is zero differences --
// then bends one value at a time and asks for exactly that difference back. It
// also holds the page to the two things it promised never to do: keep a host's
// address, seed or validator key, and send a request to a model.
//
//   node --experimental-strip-types qa/gonka-live-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  GONKA_MODELS_URL, GONKA_PARAMS_URL, GONKA_PRICING_URL, GONKA_PARTICIPANTS_URL,
  chainInteger, scaledDecimal, maxModelLen, parseModelsAll, parsePocModels, parsePricing, parseParticipants, chainDistance,
} from '../src/lib/gonkaLive.ts'
import { PROVIDERS_OUT } from '../scripts/agents-from-specs.mjs'

const catalog = JSON.parse(readFileSync(PROVIDERS_OUT, 'utf8'))
const cards = catalog.providers.filter((p) => p.family === 'model')
assert.ok(cards.length > 0, 'no model cards to compare')

// ---- 1. The endpoints are Gonka's public node, read over https, nothing else.
for (const url of [GONKA_MODELS_URL, GONKA_PARAMS_URL, GONKA_PRICING_URL, GONKA_PARTICIPANTS_URL]) {
  assert.match(url, /^https:\/\/node3\.gonka\.ai\//, `${url}: not the public Gonka node`)
}
// Every source a card names for its numbers is one of them, and every endpoint
// FIELD_SOURCE_RULE copies a field from is named: PRICE_PER_TOKEN comes from the
// pricing endpoint, HOSTS from the participants.
for (const c of cards) {
  for (const url of [GONKA_MODELS_URL, GONKA_PARAMS_URL, GONKA_PRICING_URL, GONKA_PARTICIPANTS_URL]) assert.ok(c.fields.SOURCES.includes(url), `${c.id}: SOURCES does not name ${url}, which a field on the card is copied from`)
  for (const s of c.fields.SOURCES) {
    if (/^https:\/\/node3\.gonka\.ai\//.test(s)) assert.ok([GONKA_MODELS_URL, GONKA_PARAMS_URL, GONKA_PRICING_URL, GONKA_PARTICIPANTS_URL].some((u) => s.startsWith(u)), `${c.id}: SOURCES names ${s}, which the page never re-reads`)
  }
}

// ---- 2. Numbers: the chain's decimal strings and {value, exponent} fractions, exactly.
assert.equal(chainInteger('320', 'x'), 320)
assert.equal(chainInteger(413, 'x'), 413, 'the /v1 API sends JSON numbers')
for (const bad of ['', '01', '-1', '1.5', '1e3', ' 1', null, 1.5, '9007199254740993']) {
  assert.throws(() => chainInteger(bad, 'x'), /unexpected shape/, `chainInteger accepted ${JSON.stringify(bad)}`)
}
assert.equal(scaledDecimal({ value: '922', exponent: -3 }, 3, 'x'), 922)
assert.equal(scaledDecimal({ value: '246', exponent: -3 }, 4, 'x'), 2460)
assert.equal(scaledDecimal({ value: '9225', exponent: -4 }, 3, 'x'), null, 'a threshold that is not whole per mille is null, never rounded')
assert.equal(scaledDecimal({ value: '1', exponent: '0' }, 3, 'x'), 1000, 'an exponent may arrive as a string')
assert.throws(() => scaledDecimal({ value: '-1', exponent: 0 }, 3, 'x'), /unexpected shape/)
assert.equal(maxModelLen(['--max-model-len', '180000']), 180000)
assert.equal(maxModelLen(['--max-model-len=65536']), 65536)
assert.equal(maxModelLen(['--tensor-parallel-size', '8']), null)
assert.equal(maxModelLen(['--max-model-len', 'auto']), null)

// ---- 3. Recorded responses in the chain's shape, rebuilt from the cards.
const fraction = (scaled, scale) => ({ value: String(scaled), exponent: -scale })
const MODELS_ALL = {
  model: cards.map((c) => ({
    proposed_by: 'gonka1example',
    id: c.fields.MODEL_ID,
    units_of_compute_per_token: String(c.fields.UNITS_OF_COMPUTE_PER_TOKEN),
    hf_repo: c.fields.MODEL_ID,
    hf_commit: c.fields.HF_COMMIT,
    model_args: c.fields.VLLM_ARGS,
    v_ram: String(c.fields.VRAM_GB),
    throughput_per_nonce: String(c.fields.THROUGHPUT_PER_NONCE),
    validation_threshold: fraction(c.fields.VALIDATION_PERMILLE, 3),
  })),
}
const PARAMS = {
  params: {
    poc_params: {
      models: cards.filter((c) => c.fields.POC_MODEL).map((c) => ({ model_id: c.fields.MODEL_ID, weight_scale_factor: fraction(c.fields.POC_WEIGHT_SCALE_E4, 4) })),
    },
  },
}
const PRICING = {
  unit_of_compute_price: 1,
  dynamic_pricing_enabled: true,
  models: cards.map((c) => ({ id: c.fields.MODEL_ID, price_per_token: c.fields.PRICE_PER_TOKEN, units_of_compute_per_token: c.fields.UNITS_OF_COMPUTE_PER_TOKEN })),
}
const epoch = cards[0].fields.EPOCH
const hosts = []
for (const c of cards) for (let i = 0; i < c.fields.HOSTS; i++) hosts.push(c.fields.MODEL_ID)
// One participant per served model slot, each carrying the fields the page must drop.
const PARTICIPANTS = {
  active_participants: {
    epoch_id: epoch,
    participants: hosts.map((model, i) => ({
      index: `gonka1host${i}`,
      validator_key: `KEY${i}SHOULDNEVERLEAVE`,
      weight: 1,
      inference_url: `https://host${i}.invalid:8000`,
      seed: { participant: `gonka1host${i}`, epoch_index: epoch, signature: `SEED${i}SHOULDNEVERLEAVE` },
      models: [model, model],
    })),
  },
}

const read = {
  models: parseModelsAll(MODELS_ALL),
  poc: parsePocModels(PARAMS),
  pricing: parsePricing(PRICING),
  participants: parseParticipants(PARTICIPANTS),
}
// The participants reduce to counts: nothing a host sent survives but its models.
assert.deepEqual(Object.keys(read.participants).sort(), ['active', 'epoch', 'hostsByModel'])
assert.doesNotMatch(JSON.stringify(read), /SHOULDNEVERLEAVE|\.invalid|gonka1host/, 'a host address, seed or key left parseParticipants')
assert.equal(read.participants.active, hosts.length)
for (const c of cards) assert.equal(read.participants.hostsByModel[c.fields.MODEL_ID] ?? 0, c.fields.HOSTS, `${c.id}: a model listed twice by one host counts that host once`)

// A faithful chain is zero differences, nothing uncarded, nothing unlisted.
const same = chainDistance(cards, read)
assert.deepEqual(same, { differences: [], uncarded: [], unlisted: [] }, `the recorded chain disagrees with the cards:\n${JSON.stringify(same, null, 2)}`)

// A part of the chain nobody read is never compared.
assert.deepEqual(chainDistance(cards, {}), { differences: [], uncarded: [], unlisted: [] })

// ---- 4. Bend one value, get exactly that difference back.
const [first] = cards
const bent = (path, mutate) => {
  const copy = structuredClone({ MODELS_ALL, PARAMS, PRICING, PARTICIPANTS })
  mutate(copy)
  const r = { models: parseModelsAll(copy.MODELS_ALL), poc: parsePocModels(copy.PARAMS), pricing: parsePricing(copy.PRICING), participants: parseParticipants(copy.PARTICIPANTS) }
  return chainDistance(cards, r)
}
let bentCount = 0
const only = (d, field, chain) => {
  bentCount++
  assert.deepEqual(d.differences.map((x) => [x.providerId, x.field, x.chain]), [[first.id, field, chain]], `expected only ${field}, got ${JSON.stringify(d.differences)}`)
}
only(bent('hf', (x) => { x.MODELS_ALL.model[0].hf_commit = 'f'.repeat(40) }), 'HF_COMMIT', 'f'.repeat(40))
only(bent('vram', (x) => { x.MODELS_ALL.model[0].v_ram = String(first.fields.VRAM_GB + 1) }), 'VRAM_GB', first.fields.VRAM_GB + 1)
only(bent('threshold', (x) => { x.MODELS_ALL.model[0].validation_threshold = { value: '1', exponent: -1 } }), 'VALIDATION_PERMILLE', 100)
only(bent('context', (x) => { x.MODELS_ALL.model[0].model_args = ['--max-model-len', '4096'] }), 'CONTEXT_TOKENS', 4096)
only(bent('price', (x) => { x.PRICING.models[0].price_per_token = first.fields.PRICE_PER_TOKEN + 1 }), 'PRICE_PER_TOKEN', first.fields.PRICE_PER_TOKEN + 1)
// A model dropped from Proof of Compute: POC_MODEL turns false and its weight is no longer compared.
if (first.fields.POC_MODEL) only(bent('poc', (x) => { x.PARAMS.params.poc_params.models = x.PARAMS.params.poc_params.models.filter((m) => m.model_id !== first.fields.MODEL_ID) }), 'POC_MODEL', false)
// One host fewer within the card's epoch is HOSTS; a later epoch is EPOCH on every card, never a host count.
if (first.fields.HOSTS > 0) {
  only(bent('hosts', (x) => { x.PARTICIPANTS.active_participants.participants.splice(hosts.indexOf(first.fields.MODEL_ID), 1) }), 'HOSTS', first.fields.HOSTS - 1)
}
const later = bent('epoch', (x) => { x.PARTICIPANTS.active_participants.epoch_id = epoch + 1 })
assert.deepEqual(later.differences.map((d) => d.field), cards.map(() => 'EPOCH'), 'a later epoch reports EPOCH, not HOSTS')
// A model the chain lists and no card states, and a card the chain no longer lists.
const extra = bent('uncarded', (x) => { x.MODELS_ALL.model.push({ ...x.MODELS_ALL.model[0], id: 'example/new-model' }) })
assert.deepEqual(extra.uncarded, ['example/new-model'])
const gone = bent('unlisted', (x) => { x.MODELS_ALL.model.shift() })
assert.deepEqual(gone.unlisted, [first.id])

// ---- 5. Shapes the page refuses, rather than guesses.
assert.throws(() => parseModelsAll({ models: [] }), /models_all\.model/)
assert.throws(() => parseModelsAll({ model: [{ ...MODELS_ALL.model[0], v_ram: '80GB' }] }), /v_ram/)
assert.throws(() => parsePocModels({ params: {} }), /poc_params/)
assert.throws(() => parsePricing({ unit_of_compute_price: '1', models: {} }), /pricing\.models/)
assert.throws(() => parseParticipants({ active_participants: { epoch_id: 'x', participants: [] } }), /epoch_id/)

// ---- 6. The page reads the chain and never writes to a model.
const page = readFileSync('src/pages/ProviderExplorer.tsx', 'utf8')
assert.doesNotMatch(page, /method:\s*['"](POST|PUT|PATCH|DELETE)['"]/i, 'the Provider Explorer sends something; "connect" shows the request and never sends it')
assert.doesNotMatch(page, /inference_url|validator_key/, 'the Provider Explorer names a participant field it must never show')
assert.doesNotMatch(page, /localStorage|sessionStorage|document\.cookie/, 'the Provider Explorer stores something; it never takes or keeps a key')
assert.match(page, /credentials: 'omit'/, 'the chain is read without cookies')
const fetches = page.match(/\bfetch\(/g) ?? []
assert.equal(fetches.length, 1, 'one fetch helper, so every read goes through the same no-cookie, no-cache call')

console.log(`gonka-live-contract: ${cards.length} model cards round-trip the recorded chain with 0 differences; ${bentCount} bent values each found alone; participants reduced to counts (epoch ${epoch}, ${hosts.length} recorded participants); the page reads only, stores nothing`)
