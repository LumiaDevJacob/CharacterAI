-- lumia -- jacobb5214
-- Loader. Keep YourToken blank on public GitHub - only fill it in your private copy.
-- Uses _G, not getfenv() - _G is what actually persists across separately
-- executed scripts on every executor. getfenv() only scopes to the running
-- function and isn't guaranteed to be visible from a second script.

_G.YourToken = _G.YourToken or ""

warn("[Lumia] CharacterAI loading...")

_G.CharacterAI_Module = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua?v=" .. tostring(os.time()),
	true
))()

_G.CharacterAI_Client = _G.CharacterAI_Module.new(_G.YourToken)

if _G.YourToken == "" then
	warn("[Lumia] no token set - UI will load but search/chat will fail (see README)")
end

loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/ChatUI.lua?v=" .. tostring(os.time()),
	true
))()
