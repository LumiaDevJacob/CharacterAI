# Lumia CharacterAI

Unofficial Character.AI client for Roblox executors. Ground-up rewrite of
[ElWapoteDev/CharacterAI-Luau](https://github.com/ElWapoteDev/CharacterAI-Luau)
against the API c.ai actually runs today - the old module's endpoints
(`beta.character.ai/chat/*`) are dead. Made by jacobb5214, for Lumia.

> [!WARNING]
> Unofficial. Not affiliated with Character.AI. c.ai has no public API;
> everything here is reverse-engineered and can break without notice. See
> [docs/api-notes.md](docs/api-notes.md) for what's verified vs. TODO.

## Quick start

Grab your token (see [Getting a token](#getting-a-token) below), then paste
this into your executor:

```lua
_G.YourToken = "YOUR_TOKEN_HERE"
loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Main.lua"))()
```

That opens the chat UI - search a character, click it, type. `Main.lua` also
sets two globals for scripting instead: `CharacterAI_Module` (the raw
module) and `CharacterAI_Client` (already authenticated). If you're running
the UI and a console script separately, use `_G`, not `getfenv()` - `_G` is
what actually persists across separately-executed scripts on every executor;
`getfenv()` only scopes to the script that's currently running.

```lua
local char = _G.CharacterAI_Client:SearchCharacters("assistant").Body[1]
print(char:GetName())
print(char:SendMessage("test", "hey there").Body.Text)
```

## What changed from the original

- **Live endpoints.** Chat now goes over a websocket
  (`wss://neo.character.ai/ws/`), not the old REST `chat/streaming/` call.
  Character discovery moved to `plus.character.ai` / `neo.character.ai` /
  a tRPC endpoint on `character.ai` itself.
- **No telemetry.** The original silently pinged a Hookdeck webhook on
  startup. This one doesn't talk to anything except Character.AI.
- **Real error handling.** Status checks, Cloudflare/rate-limit detection,
  retry with backoff - see [`Module/CharacterAI.lua`](Module/CharacterAI.lua).
- **Executor-only, no `HttpService` fallback.** c.ai isn't reliably reachable
  from vanilla Roblox anyway, and chat requires a raw websocket, which stock
  Roblox scripts can't open. Targets executors (Synapse X, Script-Ware,
  Fluxus, Krnl, Wave, etc.) implementing the UNC `WebSocket.connect` /
  `request` surface. **Caveat found after building this:** `neo.character.ai`
  sits behind Cloudflare's TLS fingerprinting, which blocks direct executor
  websocket connections outright - confirmed on two different executors, see
  [docs/api-notes.md](docs/api-notes.md). Search/discovery (plain HTTP) work
  fine executor-direct; chat needs [`Server/proxy.py`](#chat-not-connecting)
  running locally.

## Structure

```
Main.lua                 loader - pulls the module, wires up a token, opens ChatUI
Module/CharacterAI.lua   the whole client - one file, one require
Examples/                Search.lua, Chat.lua, CategoriesAndAvatar.lua, ChatUI.lua
Server/proxy.py          local chat proxy - only needed if direct websocket is blocked
docs/api-notes.md        endpoint-by-endpoint notes from live research
docs/index.md            method reference
```

The original split things across a big single file too; this one stays a
single file on purpose. Executors load this by `loadstring`-ing one raw URL,
so `Module/http.lua` + `auth.lua` + `chat.lua` as separate `require()`d
ModuleScripts would just mean juggling multiple HTTP fetches for no benefit -
the internals are still cleanly sectioned inside the file (rest layer, auth
headers, websocket chat, character wrapper), just not physically split.

## Getting a token

1. Open [character.ai](https://character.ai) and log in.
2. Open dev tools (`F12`) → `Network` tab.
3. Interact with the site (open your profile, send a message, anything) so
   requests start showing up.
4. Click any request to `plus.character.ai` or `neo.character.ai`, check its
   request headers, find `Authorization: Token <token>`, copy the part after
   `Token `.

There's no localStorage key with it anymore - despite what a lot of old
guides say. The Network tab is the reliable way.

Don't share this token. It's full access to your account.

## Chat not connecting?

Search and character browsing are plain HTTP and work fine straight from the
executor. Chat is a websocket to `neo.character.ai`, and that host sits
behind Cloudflare's TLS fingerprinting - confirmed to block direct executor
connections outright on two different executors (see
[docs/api-notes.md](docs/api-notes.md) for how this was diagnosed and
verified). If you see `couldn't open chat websocket` in the UI, this is why.

The fix is [`Server/proxy.py`](Server/proxy.py): a small local server that
does the TLS impersonation `curl_cffi` is built for (the same trick
PyCharacterAI uses) instead of relying on the executor's socket stack. Your
token stays local, on your machine, in this process.

**Setup (one time):**

```
pip install curl_cffi websockets
```

**Run it** (keep this terminal open while you play):

```
python Server/proxy.py YOUR_TOKEN
```

**Point the module at it** - set this before loading `Main.lua`:

```lua
_G.YourToken = "YOUR_TOKEN_HERE"
_G.WsProxyUrl = "ws://127.0.0.1:8765"
loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Main.lua"))()
```

Or, scripting directly instead of through `Main.lua`:

```lua
local client = CharacterAI.new("YOUR_TOKEN")
client:UseProxy("ws://127.0.0.1:8765")
```

Search/browse don't need any of this - only chat and the live relay do.

## Usage

```lua
local CharacterAI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua"
))()

local client = CharacterAI.new("YOUR_TOKEN")

local results = client:SearchCharacters("assistant")
if not results.Status then
    warn(results.Body)
    return
end

local char = results.Body[1]
print(char:GetName(), char:GetDescription())

local reply = char:SendMessage("my-session-key", "hey there")
if reply.Status then
    print(reply.Body.Text)
end
```

`SendMessage`'s first argument is a session key you pick - reuse the same
key to continue a conversation, use a different one to start a fresh chat
with the same character. See [`Examples/`](Examples) for full scripts.

Or just run [`Main.lua`](Main.lua) - set `_G.YourToken` before loading it and
it opens the UI plus sets up `CharacterAI_Module` / `CharacterAI_Client`
globals, which the example scripts pick up automatically if present.

## API

`CharacterAI.new(token)` → client instance

**Client:**
- `:SearchCharacters(query)` → `{Status, Body: Character[]}`
- `:GetMainPageCharacters()` → `{Status, Body: Character[]}`
- `:GetCategories()` → `{Status, Body: string[]}`
- `:GetCharacterInfo(characterId)` → `{Status, Body: Character}`

**Character:**
- `:GetName()`, `:GetCreatorName()`, `:GetDescription()`, `:GetId()`
- `:GetImage()` → `{Status, Body: assetId}` (caches to disk, needs
  `getsynasset`/`getcustomasset`; falls back to a raw CDN URL if neither
  exists)
- `:SendMessage(key, text)` → `{Status, Body: {Text, TurnId, ChatId}}`
- `:ResetChat(key)` - drops the session so the next `SendMessage` starts over

Every call returns `{Status: boolean, Body: ...}`. On failure `Body` is a
string (or a table with a `Kind` field for `auth` / `cloudflare` /
`ratelimit` / `filtered`) - check `Status` before touching `Body`.

Full method-by-method reference: [docs/index.md](docs/index.md).
Endpoint research and payload shapes: [docs/api-notes.md](docs/api-notes.md).

## Credits

Made by [jacobb5214](https://github.com/LumiaDevJacob) for Lumia. Original
concept/API shape from [ElWapoteDev/CharacterAI-Luau](https://github.com/ElWapoteDev/CharacterAI-Luau) -
none of the old code survived, but credit where it's due.

## License

MIT.
