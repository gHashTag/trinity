# Restoring the Queen

What she is made of, and how to rebuild her from nothing if the hosting
provider loses the project. Everything here is reproducible from this
repository — no state lives only in Railway's dashboard.

## What she is

Two services in the Railway project `999`, beside `t27-github-collab`:

| Service | What it is | Image / source |
|---|---|---|
| `queen-ollama` | the model runtime | `ollama/ollama`, volume at `/root/.ollama` |
| `queen-proxy` | the contract the website speaks | this directory |

The website talks only to `queen-proxy`. The proxy talks to `queen-ollama`
over Railway's private network. The model key, if an off-network provider is
ever used instead, lives in the proxy's variables and nowhere else — never in
the website, whose `VITE_` values are compiled into a public bundle.

## Rebuild

```
railway link --project 999
railway add --service queen-ollama --image ollama/ollama \
  --variables OLLAMA_HOST=0.0.0.0:11434 --variables OLLAMA_KEEP_ALIVE=24h
railway volume add --mount-path /root/.ollama

railway add --service queen-proxy
railway service queen-proxy
railway variables \
  --set 'QUEEN_PROVIDER_URL=http://${{queen-ollama.RAILWAY_PRIVATE_DOMAIN}}:11434/v1/chat/completions' \
  --set 'QUEEN_MODEL=qwen3:1.7b' \
  --set 'QUEEN_ALLOWED_ORIGINS=https://t27.ai,http://localhost:4179,http://localhost:5173'
railway up
railway domain
```

Then point the website at the domain it prints: `VITE_QUEEN_CHAT_URL`.

## The model heals itself

Nothing pulls the model by hand. The proxy asks `queen-ollama` for it on boot
and again whenever a health check finds it missing, so a wiped volume or a new
host repairs itself without anyone logging in. `GET /health` reports
`{ok:false, pulling:true}` while that is happening — it never claims to be
ready before the model is actually there.

## If Railway itself is unavailable

The same proxy runs anywhere Node 20 runs, and the website only needs a URL:

```
QUEEN_MODEL=qwen3:4b \
QUEEN_PROVIDER_URL=http://localhost:11434/v1/chat/completions \
node apps/queen-proxy/server.mjs
```

With Ollama on the machine this is a complete Queen, offline, with no account
anywhere. To fall back to a hosted model instead, set `QUEEN_PROVIDER_URL` to
any OpenAI-compatible endpoint (OpenRouter, Groq, Together, DeepSeek) and put
the key in `QUEEN_API_KEY`. Changing provider is three variables, never code.

## Verifying a restore

```
curl -s <url>/health        # {"ok":true,"model":...} once the model is present
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"message":"[view=comb] who are you?"}' <url>/chat
```

`ok:false` is the honest state, not a failure to hide: the panel shows OFFLINE
and answers nothing rather than substituting a sample.
