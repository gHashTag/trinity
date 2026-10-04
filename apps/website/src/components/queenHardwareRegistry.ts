export type HardwareState =
  | "registered"
  | "synthesised"
  | "programmed"
  | "online";

export interface VerifiedHardwareDevice {
  id: string;
  family: string;
  state: HardwareState;
  evidence: string;
  observedAt?: string;
}

export interface VerifiedHardwareRegistry {
  keyId: string;
  generatedAt: string;
  onlineWindowSeconds: number;
  devices: VerifiedHardwareDevice[];
  summary: Record<HardwareState | "total", number>;
}

const STATES = new Set<HardwareState>([
  "registered",
  "synthesised",
  "programmed",
  "online",
]);
const ENVELOPE_MAX_AGE_MS = 30_000;
const FUTURE_SKEW_MS = 10_000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseTimestamp(value: unknown, now: number): string | null {
  if (typeof value !== "string" || value.length > 80) return null;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp) || timestamp > now + FUTURE_SKEW_MS) return null;
  return new Date(timestamp).toISOString();
}

function parseDevice(
  value: unknown,
  now: number,
  onlineWindowSeconds: number,
): VerifiedHardwareDevice | null {
  if (!isRecord(value)) return null;
  if (
    typeof value.id !== "string" ||
    !/^[a-z0-9][a-z0-9-]{0,79}$/.test(value.id) ||
    typeof value.family !== "string" ||
    value.family.trim().length === 0 ||
    value.family.length > 120 ||
    typeof value.state !== "string" ||
    !STATES.has(value.state as HardwareState) ||
    typeof value.evidence !== "string" ||
    value.evidence.length > 1_200
  ) {
    return null;
  }

  try {
    if (new URL(value.evidence).protocol !== "https:") return null;
  } catch {
    return null;
  }

  const observedAt =
    value.observedAt === undefined
      ? undefined
      : parseTimestamp(value.observedAt, now) ?? null;
  if (observedAt === null) return null;
  if (value.state === "online") {
    if (!observedAt) return null;
    if (now - Date.parse(observedAt) > onlineWindowSeconds * 1_000) return null;
  }

  const exactKeys = new Set([
    "id",
    "family",
    "state",
    "evidence",
    ...(observedAt ? ["observedAt"] : []),
  ]);
  if (Object.keys(value).some((key) => !exactKeys.has(key))) return null;

  return {
    id: value.id,
    family: value.family.trim(),
    state: value.state as HardwareState,
    evidence: value.evidence,
    ...(observedAt ? { observedAt } : {}),
  };
}

function decodeBase64Url(value: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  try {
    const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
      Math.ceil(value.length / 4) * 4,
      "=",
    );
    const decoded = atob(padded);
    return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

function pemSpki(value: string): Uint8Array | null {
  const match = value.match(
    /^-----BEGIN PUBLIC KEY-----\n([A-Za-z0-9+/=\n]+)\n-----END PUBLIC KEY-----\n?$/,
  );
  if (!match) return null;
  try {
    const decoded = atob(match[1].replace(/\n/g, ""));
    return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

export async function verifyHardwareEnvelope(
  value: unknown,
  expectedPublicKey: string,
  now = Date.now(),
): Promise<VerifiedHardwareRegistry | null> {
  try {
    if (!isRecord(value) || value.algorithm !== "Ed25519") return null;
    if (
      typeof value.keyId !== "string" ||
      !/^[A-Za-z0-9._-]{1,80}$/.test(value.keyId) ||
      typeof value.publicKey !== "string" ||
      value.publicKey !== expectedPublicKey ||
      typeof value.canonical !== "string" ||
      typeof value.signature !== "string" ||
      !isRecord(value.payload)
    ) {
      return null;
    }
    if (value.canonical !== JSON.stringify(value.payload)) return null;

    const payload = value.payload;
    if (
      payload.version !== "queen-fpga-registry/v1" ||
      !Number.isInteger(payload.onlineWindowSeconds) ||
      (payload.onlineWindowSeconds as number) < 1 ||
      (payload.onlineWindowSeconds as number) > 600 ||
      !Array.isArray(payload.devices) ||
      payload.devices.length > 64 ||
      !isRecord(payload.summary)
    ) {
      return null;
    }
    const generatedAt = parseTimestamp(payload.generatedAt, now);
    if (!generatedAt || now - Date.parse(generatedAt) > ENVELOPE_MAX_AGE_MS) {
      return null;
    }

    const devices = payload.devices.map((device) =>
      parseDevice(device, now, payload.onlineWindowSeconds as number),
    );
    if (devices.some((device) => device === null)) return null;
    const verifiedDevices = devices as VerifiedHardwareDevice[];
    if (new Set(verifiedDevices.map((device) => device.id)).size !== devices.length) {
      return null;
    }
    const count = (state: HardwareState) =>
      verifiedDevices.filter((device) => device.state === state).length;
    const expectedSummary = {
      total: verifiedDevices.length,
      registered: count("registered"),
      synthesised: count("synthesised"),
      programmed: count("programmed"),
      online: count("online"),
    };
    const summary = payload.summary as Record<string, unknown>;
    if (
      Object.keys(summary).length !== 5 ||
      Object.entries(expectedSummary).some(
        ([key, countValue]) => summary[key] !== countValue,
      )
    ) {
      return null;
    }

    const publicKey = pemSpki(value.publicKey);
    const signature = decodeBase64Url(value.signature);
    if (!publicKey || !signature || !globalThis.crypto?.subtle) return null;
    const key = await globalThis.crypto.subtle.importKey(
      "spki",
      Uint8Array.from(publicKey).buffer,
      { name: "Ed25519" },
      false,
      ["verify"],
    );
    const valid = await globalThis.crypto.subtle.verify(
      { name: "Ed25519" },
      key,
      Uint8Array.from(signature).buffer,
      Uint8Array.from(new TextEncoder().encode(value.canonical)).buffer,
    );
    if (!valid) return null;

    return {
      keyId: value.keyId,
      generatedAt,
      onlineWindowSeconds: payload.onlineWindowSeconds as number,
      devices: verifiedDevices,
      summary: expectedSummary,
    };
  } catch {
    return null;
  }
}
