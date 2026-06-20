-- Lumia CharacterAI loader
-- Keep YourToken blank on public GitHub. Put your real token only in your private copy.

getfenv().YourToken = getfenv().YourToken or ""
getfenv().WaitAnswer = true

warn("[Lumia] Main FULL TextChatService fix loaded")

getfenv().CharacterAI_Module = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua", true))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua", true))()
