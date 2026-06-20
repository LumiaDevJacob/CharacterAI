# Lumia CharacterAI Docs

Credits: **Jacobb5214 for Lumia**

This project is unofficial. Character.AI does not provide an official public API, so these methods use private web routes that can change.

## `CharacterAI.new(token, options)`

Creates a Lumia CharacterAI session.

```lua
local CharacterAI = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua", true))()
local session = CharacterAI.new(getfenv().YourToken)
```

## `session:IsOnline()`

Checks whether `https://character.ai/` is reachable.

Returns a boolean.

## `session:GetMainPageCharacters()`

Returns curated/featured characters as a category map.

```lua
local chars = session:GetMainPageCharacters()
if chars.Status then
    CharacterAI:printTable(chars.Body)
end
```

## `session:GetFeaturedCharacters()`

Returns featured characters using the newer recommendation route.

## `session:GetRecommendedCharacters()`

Returns recommended characters for the current token/account, when available.

## `session:GetRecentCharacters()`

Returns recent chats/characters for the current token/account.

## `session:GetUserCharacters()`

Returns characters created by the current account, when available.

## `session:SearchCharacters(query)`

Searches characters.

```lua
local results = session:SearchCharacters("Sonic")
```

## `session:GetCharacterByExternalId(externalCharacterId)`

Gets one character by its external ID.

## Character helper methods

Returned characters are patched with helper methods:

```lua
character:GetName()
character:GetCreatorName()
character:GetInteractions(true)
character:GetDescription()
character:GetImage()
character:SendMessage("chat-key", "Hello")
character:DeleteChat("chat-key")
```

## Chat notes

Newer Character.AI chat replies use WebSockets. Your environment must support one of these:

```lua
WebSocket.connect
syn.websocket.connect
websocket.connect
```

If no WebSocket connector is available, browsing/search may still work, but chat replies can fail.

## Safety

Never commit a real token to GitHub.
