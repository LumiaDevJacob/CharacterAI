-- lumia -- jacobb5214
-- Loader. Keep YourToken blank on public GitHub - only fill it in your private copy.

getfenv().YourToken = getfenv().YourToken or ""

warn("[Lumia] CharacterAI loaded - live API rewrite, no dead endpoints")

getfenv().CharacterAI_Module = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua?v=" .. tostring(os.time()),
	true
))()

getfenv().CharacterAI_Client = getfenv().CharacterAI_Module.new(getfenv().YourToken)

if getfenv().YourToken == "" then
	warn("[Lumia] no token set - CharacterAI_Client works but chat needs a real token (see README)")
end
