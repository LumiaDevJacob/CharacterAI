-- jacobb5214
-- Loader. Keep YourToken blank on public GitHub - only fill it in your private copy.
-- Uses _G, not getfenv() - _G is what actually persists across separately
-- executed scripts on every executor. getfenv() only scopes to the running
-- function and isn't guaranteed to be visible from a second script.

_G.YourToken = _G.YourToken or ""

-- set this to "ws://127.0.0.1:8765" (or wherever) if direct chat gets blocked -
-- run Server/proxy.py first. See docs/api-notes.md for why this exists.
_G.WsProxyUrl = _G.WsProxyUrl or ""

warn("[CharacterAI] loading...")

_G.CharacterAI_Module = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua?v=" .. tostring(os.time()),
	true
))()

_G.CharacterAI_Client = _G.CharacterAI_Module.new(_G.YourToken)

if _G.WsProxyUrl ~= "" then
	_G.CharacterAI_Client:UseProxy(_G.WsProxyUrl)
	warn("[CharacterAI] chat routed through proxy: " .. _G.WsProxyUrl)
end

if _G.YourToken == "" then
	warn("[CharacterAI] no token set - UI will load but search/chat will fail (see README)")
end

loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/ChatUI.lua?v=" .. tostring(os.time()),
	true
))()
