-- jacobb5214
-- Standalone test: does WebSocket.connect work at all on this executor,
-- and specifically against neo.character.ai? Run this by itself.

local function tryConnect(name, url)
	local ok, ws = pcall(function()
		return WebSocket.connect(url)
	end)

	if ok and ws then
		print("[" .. name .. "] connected OK")
		task.spawn(function()
			ws.OnMessage:Connect(function(msg)
				print("[" .. name .. "] got message: " .. tostring(msg):sub(1, 200))
			end)
		end)
		task.wait(3)
		pcall(function()
			ws:Close()
		end)
	else
		warn("[" .. name .. "] FAILED: " .. tostring(ws))
	end
end

print("--- test 1: known-good public echo server ---")
tryConnect("echo", "wss://echo.websocket.org")

print("--- test 2: neo.character.ai ---")
tryConnect("neo.character.ai", "wss://neo.character.ai/ws/")
