-- lumia -- jacobb5214
-- List categories, then fetch and display a character's avatar in a ScreenGui.

local CharacterAI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua"
))()

local TOKEN = (getfenv().YourToken and getfenv().YourToken ~= "" and getfenv().YourToken) or "PUT_YOUR_TOKEN_HERE"
local client = getfenv().CharacterAI_Client or CharacterAI.new(TOKEN)

local categories = client:GetCategories()
if categories.Status then
	print("categories: " .. table.concat(categories.Body, ", "))
else
	warn("couldn't load categories: " .. tostring(categories.Body))
end

local featured = client:GetMainPageCharacters()
if not featured.Status or #featured.Body == 0 then
	warn("no featured characters to show")
	return
end

local char = featured.Body[1]
local image = char:GetImage()
if not image.Status then
	warn("couldn't get avatar: " .. tostring(image.Body))
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "CharacterAIAvatar"
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local icon = Instance.new("ImageLabel")
icon.Size = UDim2.fromOffset(150, 150)
icon.Position = UDim2.fromOffset(20, 20)
icon.Image = image.Body
icon.Parent = gui
