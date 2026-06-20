--[[
    Lumia CharacterAI
    Credits: Jacobb5214 for Lumia

    DISCLAIMER:
    I am not affiliated with Character.AI.
    This is an unofficial project made for fun.
    Character.AI does not provide an official public API, so endpoints can change.

    Official Character.AI site:
    https://character.ai/
]]

getfenv().YourToken = "" -- Paste your own Character.AI token here. Do NOT upload your real token to GitHub.
getfenv().WaitAnswer = true

--[[
    IMPORTANT:

    - Keep YourToken blank in the public GitHub file.
    - Put your token in your private/local copy only.
    - New Character.AI chat replies use WebSockets now.
      If your environment does not support WebSocket.connect/syn.websocket.connect,
      browsing/search can still work but live replies may not.
]]

loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua", true))()
