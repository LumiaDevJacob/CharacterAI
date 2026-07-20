-- lumia -- jacobb5214
-- Pick a character off the main page and hold a short conversation with it.

local CharacterAI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua"
))()

local TOKEN = (getfenv().YourToken and getfenv().YourToken ~= "" and getfenv().YourToken) or "PUT_YOUR_TOKEN_HERE"
local client = getfenv().CharacterAI_Client or CharacterAI.new(TOKEN)

local featured = client:GetMainPageCharacters()
if not featured.Status then
	warn("couldn't load main page characters: " .. tostring(featured.Body))
	return
end

local char = featured.Body[1]
print("chatting with " .. char:GetName())

local sessionKey = "example-session"
local lines = { "hey", "what do you do for fun?", "nice, tell me more" }

for _, line in ipairs(lines) do
	print("> " .. line)

	local reply = char:SendMessage(sessionKey, line)
	if not reply.Status then
		warn("send failed: " .. tostring(reply.Body))
		break
	end

	print(char:GetName() .. ": " .. reply.Body.Text)
	task.wait(1)
end
