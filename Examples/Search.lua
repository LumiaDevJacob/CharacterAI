-- jacobb5214
-- Search for characters and print the top results.
-- Grab your token from the Network tab (Authorization header on a plus/neo.character.ai request), see docs/api-notes.md.

local CharacterAI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua"
))()

local TOKEN = (_G.YourToken and _G.YourToken ~= "" and _G.YourToken) or "PUT_YOUR_TOKEN_HERE"
local client = _G.CharacterAI_Client or CharacterAI.new(TOKEN)

local res = client:SearchCharacters("assistant")
if not res.Status then
	warn("search failed: " .. tostring(res.Body))
	return
end

for i, char in ipairs(res.Body) do
	print(("%d. %s (by %s) - %s"):format(i, char:GetName(), char:GetCreatorName(), char:GetDescription()))
	if i >= 10 then
		break
	end
end
