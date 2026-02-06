# Local Proxy (OpenAI Responses SSE)

This is a tiny dependency-free Node.js proxy for Godot clients.

It accepts:

- `POST /v1/responses` (streaming SSE)

and forwards to:

- `${OPENAI_BASE_URL}/responses` with `Authorization: Bearer ${OPENAI_API_KEY}`

It also accepts:

- `POST /gemini/v1beta/models/<model>:generateContent` (JSON)

and forwards to:

- `${GEMINI_BASE_URL}/v1beta/models/<model>:generateContent` with `x-goog-api-key: ${GEMINI_API_KEY}`

By default, `GEMINI_API_KEY` falls back to `OPENAI_API_KEY` (single-key dev setup).

## Run

```bash
export OPENAI_API_KEY=...
export OPENAI_BASE_URL=https://api.openai.com/v1
node proxy/server.mjs
```

Or via flags:

```bash
node proxy/server.mjs --api-key "$OPENAI_API_KEY" --base-url "https://api.openai.com/v1"
```

### Windows PowerShell example

```powershell
cd E:\development\godot-wry-playwright\proxy
$env:OPENAI_API_KEY = "<your_key>"
$env:OPENAI_BASE_URL = "https://api.openai.com/v1"
node .\server.mjs
```

Health check in another terminal:

```powershell
irm http://127.0.0.1:8787/healthz
```

Defaults:

- `HOST=127.0.0.1`
- `PORT=8787`
  - Gemini proxy base: `http://127.0.0.1:8787/gemini`

## Godot demo env vars

The demo reads:

- `OPENAGENTIC_PROXY_BASE_URL` (default `http://127.0.0.1:8787/v1`)
- `OPENAGENTIC_GEMINI_BASE_URL` (default `http://127.0.0.1:8787/gemini`)
- `OPENAGENTIC_MODEL` (default `gpt-5.2`)
- `OPENAGENTIC_SAVE_ID` (default `slot1`)
- `OPENAGENTIC_NPC_ID` (default `npc_1`)

## API constraint (important)

OpenAI Responses requires each tool name to match:

- `^[a-zA-Z0-9_-]+$`

So tool names like `browser.open` are invalid and will trigger HTTP 400.
Use names like `browser_open` / `browser_click` instead.

## Troubleshooting quick notes

- HTTP 500 + `missing_env OPENAI_API_KEY`: `OPENAI_API_KEY` was not exported in current shell.
- HTTP 400 + `tools[0].name ... pattern`: tool name format invalid (contains `.` or other unsupported chars).
- Health check ok but Godot still fails: verify scene-side proxy URL is `http://127.0.0.1:8787/v1`.
