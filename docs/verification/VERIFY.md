# Verifying a website change before calling it done

Three checks in this repository each returned a confident green on something
broken. They are listed first, because knowing why an instrument lies is worth
more than the commands that follow.

## Instruments that lied

| Instrument | What it missed | Why |
|---|---|---|
| `npm run build:ci` | A call to `setIsOpen`, which does not exist in the component. Three mobile-menu links would have thrown on tap. | `build:ci` is `vite build`. It does not run `tsc`. Vite strips types without checking them. |
| `grep -o 'assets/index-[A-Za-z0-9]*\.js'` | Whether the site had published at all. | Vite hashes contain `_` and `-` (`index-EJpEX_uT.js`). The pattern matched nothing, and the deploy check compared an empty string against an empty string and passed. |
| Opening `t27.ai/#/verification` and seeing the right page | That every link preview resolved to the homepage. | A URL fragment is never sent to the server. The browser resolves it; a crawler does not. |

The shape is the same each time: the signal used to diagnose sat inside the
thing being diagnosed. Before trusting a green, ask what a failure would look
like through this instrument — and if the answer is "the same", get another one.

## Checks

### Types — your own files only

The repository has 231 pre-existing type errors, so `tsc -b` as a gate is
useless: it is red before you touch anything. Check the files you changed.

```bash
cd apps/website && npx tsc --noEmit -p tsconfig.app.json 2>&1 | grep -E "YourFile|AnotherFile"
```

Empty output means your files are clean. Non-empty means fix it — do not
proceed because `build:ci` is green.

### Build

```bash
cd apps/website && npm run build:ci
```

Necessary, not sufficient. It proves the bundle can be produced, nothing more.

### The header still fits

The dock is a single fixed-height row. New links go in the `PAGES` array in
`Navigation.tsx`, behind the disclosure — never into the row itself. If you
touch the row, measure it in the browser rather than looking at it:

```js
const d = document.querySelector('.nav-dock')
JSON.stringify({ content: d.scrollWidth, box: d.clientWidth, overflows: d.scrollWidth > d.clientWidth + 1 })
```

`overflows: false` at 1024px wide is the bar.

### Publishing actually happened

The apex repository serves a manually committed build, so "pushed" and "live"
are different facts. Compare the hash you published against the hash being
served — and fail loudly if either is empty, because two empty strings compare
equal.

```bash
LOCAL=$(grep -o 'assets/index-[A-Za-z0-9_-]*\.js' index.html | head -1)
LIVE=$(curl -s "https://t27.ai/index.html?cb=$RANDOM" | grep -o 'assets/index-[A-Za-z0-9_-]*\.js' | head -1)
[ -n "$LOCAL" ] && [ "$LOCAL" = "$LIVE" ] && echo "live: $LIVE" || echo "NOT LIVE (local=$LOCAL live=$LIVE)"
```

Pages takes 20–90 seconds. A stale hash means wait, not that it failed.

### The content is in the bundle

Grepping a large minified file through a shell variable silently fails. Write
it to disk first.

```bash
curl -s "https://t27.ai/assets/index-<hash>.js" -o /tmp/live.js
grep -c "a phrase you just added" /tmp/live.js
```

### Every page answers

```bash
for u in "" verification course ip proof cases about; do
  printf "  %-14s %s\n" "/$u" "$(curl -s -o /dev/null -w '%{http_code}' -L "https://t27.ai/$u")"
done
```

All 200. These clean paths are static stubs that redirect into the SPA; they
exist so links carry a real preview. Adding a route to `main.tsx` is only half
the job — the stub in the apex repository is the other half.

### Link previews

A new page needs its own stub with its own `og:title`, `og:description` and
`og:image`. Check what a crawler actually receives:

```bash
curl -s https://t27.ai/verification/ | grep -E 'og:(title|description|image)'
```

Never publish or send a `t27.ai/#/page` link. The preview will show the
homepage.

## Before merging

- [ ] Own files clean under `tsc`
- [ ] `build:ci` passes
- [ ] Header does not overflow at 1024px
- [ ] Failing CI checks match the set already failing on `main` (compare with
      `gh api repos/gHashTag/trinity/commits/main/check-runs`) — a *new* red is
      yours

## After publishing

- [ ] Live hash equals published hash, and neither is empty
- [ ] A phrase you added is present in the served bundle
- [ ] Every clean path returns 200
- [ ] New pages have their own stub and preview tags
