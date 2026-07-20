# Lumia CharacterAI

Unofficial Character.AI client for Roblox executors. Ground-up rewrite of
[ElWapoteDev/CharacterAI-Luau](https://github.com/ElWapoteDev/CharacterAI-Luau)
against the API c.ai actually runs today - the old module's endpoints
(`beta.character.ai/chat/*`) are dead. Made by jacobb5214, for Lumia.

> [!WARNING]
> Unofficial. Not affiliated with Character.AI. c.ai has no public API;
> everything here is reverse-engineered and can break without notice. See
> [docs/api-notes.md](docs/api-notes.md) for what's verified vs. TODO.

## What changed from the original

- **Live endpoints.** Chat now goes over a websocket
  (`wss://neo.character.ai/ws/`), not the old REST `chat/streaming/` call.
  Character discovery moved to `plus.character.ai` / `neo.character.ai` /
  a tRPC endpoint on `character.ai` itself.
- **No telemetry.** The original silently pinged a Hookdeck webhook on
  startup. This one doesn't talk to anything except Character.AI.
- **Real error handling.** Status checks, Cloudflare/rate-limit detection,
  retry with backoff - see [`Module/CharacterAI.lua`](Module/CharacterAI.lua).
- **Executor-only, on purpose.** No `HttpService`/proxy fallback for
  in-game use - c.ai isn't reliably reachable from vanilla Roblox anyway, and
  chat requires a raw websocket, which stock Roblox scripts can't open. This
  targets executors (Synapse X, Script-Ware, Fluxus, Krnl, Wave, etc.) that
  implement the UNC `WebSocket.connect` / `request` surface.

## Structure

```
Main.lua                 loader - HttpGets the module + an example, wires up a token
Module/CharacterAI.lua   the whole client - one file, one require
Examples/                Search.lua, Chat.lua, CategoriesAndAvatar.lua
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
2. Open dev tools (`F12`) → `Application` → `Local Storage` →
   `https://character.ai`.
3. Find the `char_token` key. Its value is JSON: `{"value":"..."}` - copy
   the `value` string.

Don't share this token. It's full access to your account.

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

Or just run [`Main.lua`](Main.lua) - set `YourToken` before loading it and it
sets up `CharacterAI_Module` / `CharacterAI_Client` globals for you, which
the example scripts pick up automatically if present.

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
