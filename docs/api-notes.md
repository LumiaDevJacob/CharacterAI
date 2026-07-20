# Character.AI API notes (2026-07)

Working notes on the live API surface, gathered by cross-referencing the
website's own network calls (via active OSS wrappers, mainly
[PyCharacterAI](https://github.com/Xtr4F/PyCharacterAI), which is updated
against the real site) with what's still reachable. None of this is official
- c.ai has no public API and ships no changelog for it. Anything not marked
verified could break without notice.

The original module (`ElWapoteDev/CharacterAI-Luau`) targeted
`beta.character.ai/chat/*`. That host still resolves but every endpoint under
it now 404s or redirects - it's the pre-2023 REST API and it's dead. This
rewrite targets the three hosts the live site actually calls.

## Hosts

| Host | Used for |
|---|---|
| `plus.character.ai` | account, character CRUD, personas, categories, legacy chat history |
| `neo.character.ai` | chat listing/history REST, and the chat websocket |
| `character.ai` | web app itself, tRPC search endpoints |

All three require the same bearer token; no per-host auth.

## Auth

**Correction (confirmed by a user testing against a live account):** there is
no `char_token` key in localStorage anymore. That was this doc's first pass,
sourced from stale third-party blog posts, and it's wrong - flagging it here
instead of just silently fixing it so nobody else copies it from an old
commit. The current site doesn't stash the token client-side under a
predictable key at all.

The reliable way to get it (per PyCharacterAI, which is actively maintained
against the real site): open dev tools → Network tab, interact with the site
(load your profile, send a message, whatever), find any request to
`plus.character.ai` or `neo.character.ai`, and read the `Authorization`
header off it - it's `Token <the token>`. Copy everything after `Token `.

Every authenticated request sends:

```
Authorization: Token <token>
Content-Type: application/json
```

No separate login call - this token *is* the credential, however you get it.
A second cookie, `web-next-auth`, exists for the web app's session but is
only needed for the avatar-upload endpoint. Not used here.

There's no verified way to mint a token headlessly (login flow is behind
Cloudflare + the site's own JS challenge). **TODO**: this module assumes the
caller already has a token; it does not attempt to log in with
username/password.

## REST endpoints (verified against current wrapper source, not live-tested)

### Character discovery

- `GET plus.character.ai/chat/curated_categories/characters/`
  Response: `{ characters_by_curated_category: { [category]: Character[] } }`
- `GET plus.character.ai/chat/character/categories/`
  Response: `{ categories: string[] }` (category names only)
- `GET plus.character.ai/chat/characters/featured_v2/`
  Response: `{ characters: Character[] }` - this is the closest live
  equivalent to the old module's "main page characters"
- `GET neo.character.ai/recommendation/v1/user` - personalized, requires auth
- `GET character.ai/api/trpc/search.search?batch=1&input=<json>`
  tRPC-shaped. `input` is
  `{"0":{"json":{"searchQuery":"<url-encoded query>"}}}`.
  Response is an array; characters are at
  `response[0].result.data.json.characters`.

### Character info

- `POST neo.character.ai/character/v1/get_character_info`
  Body: `{"external_id":"<id>"}`
  Response: `{ character: {...} }`, or `{status:"NOT_OK", error:"..."}`

### Account

- `GET plus.character.ai/chat/user/`
  Response: `{ user: { user: {...} } }` (yes, double-nested)

### Chat history (REST, chat-v2/"neo" model)

- `GET neo.character.ai/chats/?character_ids=<id>&num_preview_turns=<n>`
- `GET neo.character.ai/chat/<chat_id>/`
- `GET neo.character.ai/chats/recent/`
- `GET neo.character.ai/turns/<chat_id>/` (paginated via `?next_token=`)

These all use the same `{command:"neo_error", comment:"..."}` shape for
errors instead of an HTTP error status, so a 200 isn't proof of success -
check for a `command` field too.

### Character avatars

Not a separate call - avatar file names come back inline on character
objects (`avatar_file_name`). The image itself:

```
https://characterai.io/i/400/static/avatars/<file_name>?webp=true&anim=0
```

Same CDN path the original module used - this hasn't moved.

## Chat (sending messages) - this is the part that actually changed

The old REST flow (`chat/streaming/`) is gone. Sending a message and getting
a reply now goes over a **websocket**, not a POST:

```
wss://neo.character.ai/ws/
```

Connect with the auth token as a cookie: `HTTP_AUTHORIZATION: Token <token>`
(that's a cookie *named* `HTTP_AUTHORIZATION`, not a header - matches what
the site's own client does).

Every message sent over the socket is JSON with a `command`, a
`request_id` (uuid), and a `payload`. Replies come back on the same socket
tagged with matching data, not necessarily in strict request/response order,
so a receiver needs to filter by content rather than assume the next frame
is the answer.

### Creating a chat

Send:
```json
{
  "command": "create_chat",
  "request_id": "<uuid>",
  "payload": {
    "chat": {
      "chat_id": "<uuid>",
      "creator_id": "<account_id>",
      "visibility": "VISIBILITY_PRIVATE",
      "character_id": "<character external_id>",
      "type": "TYPE_ONE_ON_ONE"
    },
    "with_greeting": true
  }
}
```

Expect a `create_chat_response` frame with the new `chat`, then (if
`with_greeting`) an `add_turn` frame carrying the greeting as the character's
first turn.

### Sending a message

```json
{
  "command": "create_and_generate_turn",
  "origin_id": "web-next",
  "request_id": "<uuid>",
  "payload": {
    "character_id": "<id>",
    "num_candidates": 1,
    "selected_language": "",
    "tts_enabled": false,
    "user_name": "",
    "previous_annotations": { "...": "see below" },
    "turn": {
      "author": { "author_id": "<account_id>", "is_human": true, "name": "" },
      "candidates": [{ "candidate_id": "<uuid>", "raw_content": "<text>" }],
      "primary_candidate_id": "<same uuid>",
      "turn_key": { "chat_id": "<chat_id>", "turn_id": "<uuid>" }
    }
  }
}
```

`previous_annotations` is a fixed object of ~23 int fields (feedback tags
like `funny`, `boring`, `repetitive`, `not_helpful`...) all zeroed. The site
sends the full set every time; sending a partial object hasn't been
confirmed to work, so this module sends the full thing.

Replies stream back as repeated `add_turn` / `update_turn` frames, each with
a `turn.candidates[0]`. Skip frames where `turn.author.is_human` is true
(that's an echo of your own message). The reply is done when
`turn.candidates[0].is_final` is true - that's the terminal condition, not a
close frame or a special "done" command.

### Errors on the socket

A frame with `"command": "neo_error"` means the request failed; the message
is in `comment`. There's also `filter_user_input_self_harm` for messages
that tripped their safety filter.

## Websocket in Luau

This is the part with no standard library support - stock Roblox
`HttpService` cannot open a websocket, and the http request functions
(`http_request`/`request`/`syn.request`) are one-shot HTTP, not sockets.
Executor-only is the explicit target here, so this module leans on the
`WebSocket` global that's part of the executor UNC (Unified Naming
Convention) and shipped by every mainstream executor (Synapse X, Script-Ware,
Fluxus, Krnl, Wave, etc): `WebSocket.connect(url) -> { Send, Close, OnMessage,
OnClose }`.

**TODO**: no fallback exists for executors that lack `WebSocket.connect`.
If that turns out to matter in practice, the honest options are (a) require
it and fail loudly, which is what this module does now, or (b) poll a REST
endpoint instead - but there's no verified non-socket way to send a message
in the current API, so that's not a real fallback, just a worse client.

**TODO / known gap**: the strict UNC signature is `WebSocket.connect(url)`
with no way to attach the `HTTP_AUTHORIZATION` cookie the real handshake
needs. Some executors accept an extra options table
(`WebSocket.connect(url, {Headers = {...}})`); this module tries that form
first and falls back to the bare call. On executors that support neither, the
socket will connect but the server will likely reject or silently ignore
authenticated commands - not independently confirmed since it depends on the
specific executor's websocket implementation.

## Rate limits / Cloudflare

Not independently measured - no live token to test against. From wrapper
behavior and general reports:

- `401` = bad/expired token (all endpoints, confirmed via `requester.py`
  raising on 401 uniformly).
- `403` with an HTML body (instead of JSON) is the Cloudflare challenge page,
  not an app-level error. Treat "response isn't valid JSON" as its own error
  case rather than trying to parse it as one.
- `429` for rate limiting is plausible but **unverified** - not confirmed
  against a live response.

This module treats any non-2xx, any non-JSON body, and any `neo_error`
command as distinct failure modes and reports which one it hit rather than
collapsing them into one generic error.

## What's intentionally out of scope

Persona management, character creation/editing, voice, avatar upload
(needs `web_next_auth`), pinning/editing/deleting turns, "another response"
candidate regeneration. All exist in the live API (see PyCharacterAI's
`account.py`/`chat.py` for shape) but aren't part of the public surface this
module commits to. Can be added later without breaking the existing API.

---

lumia -- made by jacobb5214
