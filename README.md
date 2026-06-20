# Lumia CharacterAI

Credits: **Jacobb5214 for Lumia**

Lumia CharacterAI is an unofficial Luau wrapper/UI for experimenting with Character.AI-style chat inside Roblox-style Luau environments.

> Important: Character.AI does **not** provide an official public API. This repo uses unofficial/private web routes, so it can break whenever Character.AI changes their site or backend.

## Files

```text
Main.lua                  Loader users run locally
Examples/CharHub.lua      Lumia chat UI
Module/CharacterAI.lua    Lumia CharacterAI wrapper
README.md                 Setup + notes
docs/index.md             Method docs
```

## Loader

```lua
getfenv().YourToken = "" -- keep blank on GitHub
getfenv().WaitAnswer = true

loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua", true))()
```

## Token safety

Do **not** upload your real token to GitHub.

Keep this in public files:

```lua
getfenv().YourToken = ""
```

Only paste your own token in your private local copy while testing.

## What was updated

- Rebranded old CharacterAI-Luau wording to Lumia.
- Updated credits to **Jacobb5214 for Lumia**.
- Changed raw GitHub links to `LumiaDevJacob/CharacterAI`.
- Removed webhook/stat tracking from `Module/CharacterAI.lua`.
- Updated character search/info/recent/recommended routes to newer `neo.character.ai` / `plus.character.ai` routes.
- Added a WebSocket chat path for newer Character.AI chat replies.
- Kept a legacy fallback for older environments, but it may not work if Character.AI fully removed old endpoints.

## Requirements

Your running environment needs:

- `request`, `http_request`, or `syn.request` for HTTP requests.
- `WebSocket.connect`, `syn.websocket.connect`, or `websocket.connect` for live chat replies.

Search and character browsing may work with HTTP only. Sending/receiving chat replies usually needs WebSocket support now.

## Basic usage

```lua
local CharacterAI = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua", true))()

local session = CharacterAI.new(getfenv().YourToken)
local results = session:SearchCharacters("Mario")

if results.Status and results.Body[1] then
    local character = results.Body[1]
    local response = character:SendMessage("default", "Hello!")

    if response.Status then
        print(response.Body.replies[1].text)
    else
        warn(response.Body)
    end
end
```

## Push update to GitHub

After replacing the files, run:

```bat
cd /d "C:\Users\Jack\Desktop\CharacterAI\CharacterAI"
git add .
git commit -m "Update Lumia CharacterAI wrapper"
git push
```
