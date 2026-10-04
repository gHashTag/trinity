// The Gonka chain, re-read in the browser, and the distance from the provider cards.
//
// A model card (specs/providers/gonka/<slug>.t27) is a copy of the chain taken on
// its CHECKED date; specs/providers/catalog.t27 FIELD_SOURCE_RULE names the
// endpoint and the arithmetic behind every copied field. This module is that rule
// as pure functions: it parses what the four public endpoints return and lists
// every field where the card and the chain now disagree. It fetches nothing and
// renders nothing, so the QA contract can feed it recorded responses.
//
// Two things it never does. It never keeps a participant's inference_url, seed or
// validator key: a host count is all the page needs, and the URLs are bare IP
// addresses. And it never calls a model: every inference request on Gonka is paid
// and signed (catalog.t27 CALL_RULE).
//
// The chain encodes every integer as a decimal string and every fraction as
// {value, exponent}; a string that is not a plain decimal integer is a parse
// error, never a guess.

import type { ProviderModelEntry } from './agentSpecs'

export const GONKA_NODE = 'https://node3.gonka.ai'
export const GONKA_MODELS_URL = `${GONKA_NODE}/chain-api/productscience/inference/inference/models_all`
export const GONKA_PARAMS_URL = `${GONKA_NODE}/chain-api/productscience/inference/inference/params`
export const GONKA_PRICING_URL = `${GONKA_NODE}/v1/governance/pricing`
/** About half a megabyte (it carries the epoch's proofs): read only when asked. */
export const GONKA_PARTICIPANTS_URL = `${GONKA_NODE}/v1/epochs/current/participants`

export interface ChainModel {
  modelId: string
  hfCommit: string
  vramGb: number
  throughputPerNonce: number
  unitsOfComputePerToken: number
  /** validation_threshold x 1000, or null when that is not a whole number. */
  validationPermille: number | null
  /** The --max-model-len in model_args, or null when the args name none. */
  contextTokens: number | null
  vllmArgs: string[]
}

export interface ChainPocModel {
  modelId: string
  /** weight_scale_factor x 10000, or null when that is not a whole number. */
  weightScaleE4: number | null
}

export interface ChainPrice {
  modelId: string
  pricePerToken: number
  unitsOfComputePerToken: number
}

export interface ChainPricing {
  unitOfComputePrice: number
  dynamicPricing: boolean
  models: ChainPrice[]
}

export interface ChainParticipants {
  epoch: number
  active: number
  /** Active participants of the epoch whose models list names the model. */
  hostsByModel: Record<string, number>
}

export interface ChainRead {
  models?: ChainModel[]
  poc?: ChainPocModel[]
  pricing?: ChainPricing
  participants?: ChainParticipants
}

export type CardField =
  | 'HF_COMMIT'
  | 'VRAM_GB'
  | 'THROUGHPUT_PER_NONCE'
  | 'UNITS_OF_COMPUTE_PER_TOKEN'
  | 'VALIDATION_PERMILLE'
  | 'CONTEXT_TOKENS'
  | 'POC_MODEL'
  | 'POC_WEIGHT_SCALE_E4'
  | 'PRICE_PER_TOKEN'
  | 'HOSTS'
  | 'EPOCH'

export interface CardDifference {
  providerId: string
  field: CardField
  card: string | number | boolean
  chain: string | number | boolean | null
}

export interface ChainDistance {
  differences: CardDifference[]
  /** Models the chain lists that no card states. */
  uncarded: string[]
  /** Cards whose MODEL_ID the chain no longer lists (only when models_all was read). */
  unlisted: string[]
}

class ChainShapeError extends Error {
  constructor(what: string) {
    super(`The Gonka endpoint answered an unexpected shape: ${what}`)
  }
}

const DECIMAL = /^(0|[1-9][0-9]*)$/

function record(value: unknown, what: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new ChainShapeError(what)
  return value as Record<string, unknown>
}

function list(value: unknown, what: string): unknown[] {
  if (!Array.isArray(value)) throw new ChainShapeError(what)
  return value
}

function text(value: unknown, what: string): string {
  if (typeof value !== 'string') throw new ChainShapeError(what)
  return value
}

/** A chain integer: a decimal string (or, from the /v1 API, a JSON number) that fits a double exactly. */
export function chainInteger(value: unknown, what: string): number {
  const s = typeof value === 'number' && Number.isInteger(value) ? String(value) : value
  if (typeof s !== 'string' || !DECIMAL.test(s)) throw new ChainShapeError(what)
  const n = Number(s)
  if (!Number.isSafeInteger(n)) throw new ChainShapeError(`${what} is past 2^53`)
  return n
}

/**
 * value x 10^exponent x 10^scale as an exact integer, or null when it is not one.
 * {value: "922", exponent: -3} at scale 3 is 922; {value: "246", exponent: -3} at
 * scale 4 is 2460.
 */
export function scaledDecimal(fraction: unknown, scale: number, what: string): number | null {
  const f = record(fraction, what)
  const digits = text(f.value, `${what}.value`)
  if (!DECIMAL.test(digits)) throw new ChainShapeError(`${what}.value`)
  const exponent = typeof f.exponent === 'number' ? f.exponent : Number(text(f.exponent, `${what}.exponent`))
  if (!Number.isInteger(exponent)) throw new ChainShapeError(`${what}.exponent`)
  const shift = exponent + scale
  let out: bigint
  if (shift >= 0) {
    out = BigInt(digits) * 10n ** BigInt(shift)
  } else {
    const divisor = 10n ** BigInt(-shift)
    if (BigInt(digits) % divisor !== 0n) return null
    out = BigInt(digits) / divisor
  }
  return out <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(out) : null
}

/** The value after --max-model-len in vLLM arguments (either `--max-model-len N` or `--max-model-len=N`). */
export function maxModelLen(args: readonly string[]): number | null {
  for (let i = 0; i < args.length; i++) {
    const a = args[i]
    const value = a === '--max-model-len' ? args[i + 1] : a.startsWith('--max-model-len=') ? a.slice('--max-model-len='.length) : undefined
    if (value !== undefined) return DECIMAL.test(value) ? Number(value) : null
  }
  return null
}

/** GET models_all. */
export function parseModelsAll(json: unknown): ChainModel[] {
  return list(record(json, 'models_all').model, 'models_all.model').map((raw, i) => {
    const m = record(raw, `model[${i}]`)
    const args = list(m.model_args ?? [], `model[${i}].model_args`).map((a, j) => text(a, `model[${i}].model_args[${j}]`))
    return {
      modelId: text(m.id, `model[${i}].id`),
      hfCommit: text(m.hf_commit, `model[${i}].hf_commit`),
      vramGb: chainInteger(m.v_ram, `model[${i}].v_ram`),
      throughputPerNonce: chainInteger(m.throughput_per_nonce, `model[${i}].throughput_per_nonce`),
      unitsOfComputePerToken: chainInteger(m.units_of_compute_per_token, `model[${i}].units_of_compute_per_token`),
      validationPermille: scaledDecimal(m.validation_threshold, 3, `model[${i}].validation_threshold`),
      contextTokens: maxModelLen(args),
      vllmArgs: args,
    }
  })
}

/** GET params: the models Proof of Compute still races, and each one's weight scale. */
export function parsePocModels(json: unknown): ChainPocModel[] {
  const poc = record(record(record(json, 'params').params, 'params.params').poc_params, 'params.poc_params')
  return list(poc.models, 'poc_params.models').map((raw, i) => {
    const m = record(raw, `poc_params.models[${i}]`)
    return {
      modelId: text(m.model_id, `poc_params.models[${i}].model_id`),
      weightScaleE4: scaledDecimal(m.weight_scale_factor, 4, `poc_params.models[${i}].weight_scale_factor`),
    }
  })
}

/** GET /v1/governance/pricing. */
export function parsePricing(json: unknown): ChainPricing {
  const p = record(json, 'pricing')
  return {
    unitOfComputePrice: chainInteger(p.unit_of_compute_price, 'pricing.unit_of_compute_price'),
    dynamicPricing: p.dynamic_pricing_enabled === true,
    models: list(p.models, 'pricing.models').map((raw, i) => {
      const m = record(raw, `pricing.models[${i}]`)
      return {
        modelId: text(m.id, `pricing.models[${i}].id`),
        pricePerToken: chainInteger(m.price_per_token, `pricing.models[${i}].price_per_token`),
        unitsOfComputePerToken: chainInteger(m.units_of_compute_per_token, `pricing.models[${i}].units_of_compute_per_token`),
      }
    }),
  }
}

/**
 * GET /v1/epochs/current/participants, reduced to counts. Only `models` is read
 * from each participant; its inference_url, seed and validator key are never
 * copied out of this function.
 */
export function parseParticipants(json: unknown): ChainParticipants {
  const active = record(record(json, 'participants').active_participants, 'active_participants')
  const participants = list(active.participants, 'active_participants.participants')
  const hostsByModel: Record<string, number> = {}
  participants.forEach((raw, i) => {
    const models = new Set(list(record(raw, `participants[${i}]`).models ?? [], `participants[${i}].models`).map((m, j) => text(m, `participants[${i}].models[${j}]`)))
    for (const id of models) hostsByModel[id] = (hostsByModel[id] ?? 0) + 1
  })
  return { epoch: chainInteger(active.epoch_id, 'active_participants.epoch_id'), active: participants.length, hostsByModel }
}

/**
 * Every field where a model card and the chain disagree. A part of the chain that
 * was not read (`read.pricing` undefined, say) is not compared: no difference is
 * claimed from a source nobody asked. HOSTS is compared only within the card's own
 * EPOCH; a later epoch reports EPOCH as the difference, since a host count of
 * another epoch is not a contradiction of the card.
 */
export function chainDistance(cards: readonly ProviderModelEntry[], read: ChainRead): ChainDistance {
  const differences: CardDifference[] = []
  const add = (providerId: string, field: CardField, card: string | number | boolean, chain: string | number | boolean | null) => {
    if (card !== chain) differences.push({ providerId, field, card, chain })
  }
  const carded = new Set(cards.map((c) => c.fields.MODEL_ID))
  const listed = read.models ? new Set(read.models.map((m) => m.modelId)) : null
  for (const card of cards) {
    const f = card.fields
    const model = read.models?.find((m) => m.modelId === f.MODEL_ID)
    if (model) {
      add(card.id, 'HF_COMMIT', f.HF_COMMIT, model.hfCommit)
      add(card.id, 'VRAM_GB', f.VRAM_GB, model.vramGb)
      add(card.id, 'THROUGHPUT_PER_NONCE', f.THROUGHPUT_PER_NONCE, model.throughputPerNonce)
      add(card.id, 'UNITS_OF_COMPUTE_PER_TOKEN', f.UNITS_OF_COMPUTE_PER_TOKEN, model.unitsOfComputePerToken)
      add(card.id, 'VALIDATION_PERMILLE', f.VALIDATION_PERMILLE, model.validationPermille)
      add(card.id, 'CONTEXT_TOKENS', f.CONTEXT_TOKENS, model.contextTokens)
    }
    if (read.poc) {
      const poc = read.poc.find((m) => m.modelId === f.MODEL_ID)
      add(card.id, 'POC_MODEL', f.POC_MODEL, poc !== undefined)
      if (poc) add(card.id, 'POC_WEIGHT_SCALE_E4', f.POC_WEIGHT_SCALE_E4, poc.weightScaleE4)
    }
    if (read.pricing) {
      const price = read.pricing.models.find((m) => m.modelId === f.MODEL_ID)
      add(card.id, 'PRICE_PER_TOKEN', f.PRICE_PER_TOKEN, price ? price.pricePerToken : null)
    }
    if (read.participants) {
      if (read.participants.epoch !== f.EPOCH) add(card.id, 'EPOCH', f.EPOCH, read.participants.epoch)
      else add(card.id, 'HOSTS', f.HOSTS, read.participants.hostsByModel[f.MODEL_ID] ?? 0)
    }
  }
  return {
    differences,
    uncarded: read.models ? read.models.map((m) => m.modelId).filter((id) => !carded.has(id)) : [],
    unlisted: listed ? cards.filter((c) => !listed.has(c.fields.MODEL_ID)).map((c) => c.id) : [],
  }
}
