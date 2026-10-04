// NEGATIVE FIXTURE for qa/queen-spec-sync-contract.mjs -- not part of the site.
// The shape the store replaced: a component holding its own copy of the corpus.
// The contract's source scan must name this file.
export const rogueManifest = (): Promise<unknown> =>
  fetch('t27/manifest.json', { credentials: 'omit' }).then((r) => r.json())
