-- Search for characters and print the top results.
-- Grab your token from c.ai's localStorage (`char_token` -> value), see docs/api-notes.md.

local CharacterAI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/Module/CharacterAI.lua"
))()

local TOKEN = "PUT_YOUR_TOKEN_HERE"
local client = CharacterAI.new(TOKEN)

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
