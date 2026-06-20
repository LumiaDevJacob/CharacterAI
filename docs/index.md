# Lumia CharacterAI Docs

## Start

```lua
local CharacterAI = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua?v=" .. tostring(os.time()), true))()
local session = CharacterAI.new(getfenv().YourToken)
```

## Useful methods

- `CharacterAI.new(token)`
- `session:GetRecentCharacters()`
- `session:GetMainPageCharacters()`
- `session:SearchCharacters(query)`
- `session:GetCharacterByExternalId(id)`
- `character:SendMessage(key, text)`

Credits: Jacobb5214 for Lumia.
