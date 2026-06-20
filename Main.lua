getfenv().YourToken = ""
getfenv().WaitAnswer = true
getfenv().LumiaStatsEnabled = true
getfenv().LumiaStatsWebhook = "PUT_YOUR_DISCORD_WEBHOOK_HERE"

loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua?v=" .. tostring(os.time()), true))()
