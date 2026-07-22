# Method reference

Everything returns `{Status: boolean, Body: any}`. Check `Status` first -
`Body` is a success payload on `true`, or an error description (string, or
a table with a `Kind` field) on `false`. `Kind` is one of `auth`,
`cloudflare`, `ratelimit`, `server`, `filtered`, or absent for things that
don't map to an HTTP status (bad response shape, timeout, missing http
function).

## Requirements

- An executor request function: `syn.request`, `http_request`, or `request`.
- `WebSocket.connect` (UNC), for anything that sends or receives messages.
- `getsynasset` or `getcustomasset` + the filesystem globals
  (`isfile`/`writefile`/`makefolder`/`isfolder`), only if you call
  `Character:GetImage()`.

The module throws at load time if the request function or `WebSocket` is
missing, since nothing useful works without them.

## `CharacterAI.new(token)`

```lua
local client = CharacterAI.new("YOUR_TOKEN")
```

`token` is the value from the `Authorization: Token <...>` header on any
authenticated request to `plus.character.ai`/`neo.character.ai` - pull it
from your browser's Network tab (see the README).
You can pass `nil`/`""` for unauthenticated access, but most endpoints
(including chat) require a real token.

---

## Client methods

### `client:SearchCharacters(query: string)`

`{Status, Body: Character[]}`

Hits `character.ai`'s tRPC search endpoint. Returns whatever they rank as
matches for `query` - no pagination exposed.

### `client:GetMainPageCharacters()`

`{Status, Body: Character[]}`

Pulls `plus.character.ai/chat/characters/featured_v2/` - the closest live
analogue to what used to be the site's front page.

### `client:GetCategories()`

`{Status, Body: string[]}`

Category names only (no character lists attached - use
`SearchCharacters` or curated-category calls for that if you extend this).

### `client:GetCharacterInfo(characterId: string)`

`{Status, Body: Character}`

Full character record by external id, for when you already know the id
(e.g. from a saved link) and don't want to search.

---

## Character methods

A `Character` wraps one character record - returned from search, featured,
or `GetCharacterInfo`. All the getters below read from that record and
never make a network call themselves (except `GetImage`).

### `char:GetName()` → `string`
### `char:GetCreatorName()` → `string`
### `char:GetId()` → `string` (the `external_id` c.ai uses everywhere)

### `char:GetDescription()` → `string`

Falls back through `title` → `greeting` → name, whichever's first non-empty
- same priority the original module used.

### `char:GetImage()`

`{Status, Body: assetId-or-url}`

Downloads the avatar (`characterai.io/i/400/static/avatars/<file>`), caches
it to `CharacterAi/<file>.png` on disk, and returns a `getsynasset` /
`getcustomasset` asset id you can drop straight into `ImageLabel.Image`.
Repeat calls for the same character hit the disk cache instead of
re-downloading. If neither asset function exists, returns the raw CDN URL
instead (won't render in an `ImageLabel` - Roblox doesn't load arbitrary web
images - but at least you get the URL).

### `char:SendMessage(key: string, text: string)`

`{Status, Body: {Text: string, TurnId: string, ChatId: string}}`

`key` is yours to define - it's just how this module tells conversations
apart. First call with a new key opens a new chat (and eats the greeting
turn, which isn't returned - call `GetCharacterInfo` if you want the
greeting text up front). Every later call with the same key continues that
same chat. Use a different key (player UserId, a per-NPC id, whatever) to
run multiple independent conversations with the same character at once.

Blocks until the character's reply is fully generated (waits for
`is_final` on the socket) - typically a few seconds, up to a 30s timeout.
There's no streaming/partial-token callback in this version.

### `char:ResetChat(key: string)`

Drops the stored session for that key. The next `SendMessage` with the same
key starts a brand new chat instead of continuing the old one. Doesn't
delete anything server-side, just forgets the `chat_id` locally.

---

## Error kinds

| `Kind` | Meaning |
|---|---|
| `auth` | 401, or the websocket wouldn't open - token is missing/invalid/expired |
| `cloudflare` | got a non-JSON 403 - Cloudflare challenge, not an app error |
| `ratelimit` | 429, already retried through backoff and still failing |
| `server` | 5xx, already retried through backoff and still failing |
| `filtered` | c.ai's safety filter rejected the message content |
| *(none)* | timeout, malformed response, or no request function - `Body` is a plain string |

REST calls auto-retry `ratelimit`/`server`/network failures 3x with backoff
(0.6s / 1.5s / 3s) before giving up and returning the error. Auth and
Cloudflare failures aren't retried - retrying won't fix a bad token or a
challenge page.

See [api-notes.md](api-notes.md) for the underlying endpoints and exactly
what's been verified vs. is still a TODO.

---

made by jacobb5214
