#!/usr/bin/env node
// Optional KIE.AI asset front end for the hive display.
//
// Status, 2026-09-06: the supplied key is NOT usable. The API answers
// 401 Unauthorized / "Organization access is disabled", so this repository
// contains no generated cards and the Babylon comb remains pure geometry.
// Run this only after an organization-enabled KIE_API_KEY exists. The key is
// deliberately read from the environment and never written to git.
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = resolve(ROOT, "public/queen/kie");
const API = "https://api.kie.ai/api/v1";

const ASSETS = {
  "event-card": "square card face for a dark science-fiction strategy HUD, raised honeycomb cell, deep near-black green background, one subtle honey-yellow border, crisp geometric slots for text, no letters, no numbers, no logos",
  "cell-frame": "single hexagonal honeycomb frame for a dark science-fiction strategy game, precise thin luminous rim, near-black green interior, subtle depth and wax material, centered with clear outer margin, no text, no logo",
};

const args = process.argv.slice(2);
const argOf = (name) => {
  const at = args.indexOf(`--${name}`);
  return at >= 0 && args[at + 1] ? args[at + 1] : null;
};
const asset = argOf("asset") ?? "event-card";
const promptOverride = argOf("prompt");
const seed = Number.parseInt(argOf("seed") ?? "27050", 10);

if (!Object.hasOwn(ASSETS, asset)) {
  console.error(`unknown --asset ${asset}; choose ${Object.keys(ASSETS).join(", ")}`);
  process.exit(2);
}
if (!Number.isInteger(seed) || seed < 0 || seed > 2_147_483_647) {
  console.error("--seed must be an integer from 0 through 2147483647");
  process.exit(2);
}

const key = process.env.KIE_API_KEY;
if (!key) {
  console.error("KIE_API_KEY is required. Do not paste keys into this script.");
  process.exit(2);
}

const headers = { Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
const request = async (url, init = {}) => {
  const response = await fetch(url, { ...init, headers: { ...headers, ...(init.headers ?? {}) } });
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { raw: text }; }
  if (!response.ok) {
    throw new Error(`KIE ${response.status}: ${typeof body === "object" ? body.msg ?? body.error ?? text : text}`);
  }
  return body;
};

const created = await request(`${API}/jobs/createTask`, {
  method: "POST",
  body: JSON.stringify({
    model: "bytedance/seedream-v4-text-to-image",
    input: {
      prompt: promptOverride ?? ASSETS[asset],
      image_size: "square_hd",
      image_resolution: "1K",
      max_images: 1,
      seed,
      nsfw_checker: true,
    },
  }),
});
const taskId = created?.data?.taskId ?? created?.result?.task_id ?? created?.task_id;
if (!taskId) throw new Error(`KIE created no task id: ${JSON.stringify(created)}`);
console.log(`KIE task ${taskId}`);

const deadline = Date.now() + 5 * 60_000;
let urls = [];
for (;;) {
  await new Promise((r) => setTimeout(r, 4_000));
  const record = await request(`${API}/jobs/recordInfo?taskId=${encodeURIComponent(taskId)}`);
  const state = record?.data?.state ?? record?.state;
  console.log(`state ${state}`);
  if (state === "success") {
    urls = record?.data?.resultUrls ?? record?.result_urls ?? record?.resultUrls ?? [];
    break;
  }
  if (state === "failed" || Date.now() > deadline) {
    throw new Error(`KIE task did not succeed: ${JSON.stringify(record).slice(0, 1000)}`);
  }
}
if (urls.length === 0) throw new Error("KIE success carried no resultUrls");

await mkdir(OUT_DIR, { recursive: true });
for (const [n, url] of urls.entries()) {
  const image = await fetch(url);
  if (!image.ok) throw new Error(`download failed (${image.status})`);
  const file = resolve(OUT_DIR, `${asset}-${seed}-${taskId}${n ? `-${n}` : ""}.png`);
  await writeFile(file, Buffer.from(await image.arrayBuffer()));
  console.log(file);
}
