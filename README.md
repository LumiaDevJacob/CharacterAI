# Lumia CharacterAI

Roblox/Luau Character.AI wrapper and chat UI by Jacobb5214 for Lumia.

## Load

```lua
getfenv().YourToken = ""
getfenv().WaitAnswer = true
getfenv().LumiaStatsEnabled = true
getfenv().LumiaStatsWebhook = "PUT_YOUR_DISCORD_WEBHOOK_HERE"

loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua?v=" .. tostring(os.time()), true))()
```

Leave `YourToken` empty to test. For proper chat/search, use your own Character.AI token.

## Files

- `Main.lua` - loader
- `Examples/CharHub.lua` - UI
- `Module/CharacterAI.lua` - API wrapper
- `docs/index.md` - method notes

Credits: Jacobb5214 for Lumia.
