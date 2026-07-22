-- lumia -- jacobb5214
-- In-game chat window: search a character, click it, talk to it.
-- Needs _G.CharacterAI_Client (Main.lua sets this) or a token below.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CharacterAI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Module/CharacterAI.lua"
))()

local TOKEN = (_G.YourToken and _G.YourToken ~= "" and _G.YourToken) or "PUT_YOUR_TOKEN_HERE"
local client = _G.CharacterAI_Client or CharacterAI.new(TOKEN)
if not _G.CharacterAI_Client and _G.WsProxyUrl and _G.WsProxyUrl ~= "" then
	client:UseProxy(_G.WsProxyUrl)
end

local BG, PANEL, ACCENT, TEXT, SUBTEXT =
	Color3.fromRGB(24, 22, 30), Color3.fromRGB(32, 30, 40),
	Color3.fromRGB(140, 110, 255), Color3.fromRGB(235, 235, 240), Color3.fromRGB(150, 150, 160)

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

--------------------------------------------------------------
-- shell
--------------------------------------------------------------

local gui = new("ScreenGui", { Name = "LumiaCharacterAI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local SIDEBAR = 210

local root = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(640, 430),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = BG,
	Parent = gui,
}, { corner(10) })

local titleBar = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = PANEL,
	Parent = root,
}, { corner(10) })

new("TextLabel", {
	BorderSizePixel = 0,
	Text = "Lumia CharacterAI",
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1,
	Parent = titleBar,
})

local closeBtn = new("TextButton", {
	BorderSizePixel = 0,
	Text = "x",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = SUBTEXT,
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -36, 0, 0),
	BackgroundTransparency = 1,
	Parent = titleBar,
})
closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- drag
do
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, dragStart, startPos = true, input.Position, root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local status = new("TextLabel", {
	BorderSizePixel = 0,
	Text = TOKEN == "PUT_YOUR_TOKEN_HERE" and "no token set - see README" or "",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = SUBTEXT,
	Size = UDim2.new(1, -16, 0, 16),
	Position = UDim2.new(0, 8, 1, -20),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = root,
})

--------------------------------------------------------------
-- search panel (left)
--------------------------------------------------------------

local searchPanel = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.new(0, SIDEBAR, 1, -44),
	Position = UDim2.fromOffset(0, 44),
	BackgroundTransparency = 1,
	Parent = root,
})

local searchBox = new("TextBox", {
	BorderSizePixel = 0,
	PlaceholderText = "search characters...",
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = TEXT,
	PlaceholderColor3 = SUBTEXT,
	BackgroundColor3 = PANEL,
	Size = UDim2.new(1, -16, 0, 28),
	Position = UDim2.fromOffset(8, 0),
	ClearTextOnFocus = false,
	Parent = searchPanel,
}, { corner(6) })

local results = new("ScrollingFrame", {
	BorderSizePixel = 0,
	Size = UDim2.new(1, -16, 1, -36),
	Position = UDim2.fromOffset(8, 36),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = searchPanel,
}, { new("UIListLayout", { Padding = UDim.new(0, 6) }) })

--------------------------------------------------------------
-- chat panel (right)
--------------------------------------------------------------

local chatPanel = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.new(1, -SIDEBAR, 1, -44),
	Position = UDim2.fromOffset(SIDEBAR, 44),
	BackgroundTransparency = 1,
	Parent = root,
})

local chatHeader = new("TextLabel", {
	BorderSizePixel = 0,
	Text = "pick a character",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -76, 0, 24),
	Position = UDim2.fromOffset(8, 0),
	BackgroundTransparency = 1,
	Parent = chatPanel,
})

-- click a nearby player (or leave it off) and their in-game chat gets relayed
-- to whichever character is selected, replies get typed back into chat
local liveBtn = new("TextButton", {
	BorderSizePixel = 0,
	Text = "live: off",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = TEXT,
	BackgroundColor3 = PANEL,
	Size = UDim2.new(0, 60, 0, 20),
	Position = UDim2.new(1, -68, 0, 2),
	Parent = chatPanel,
}, { corner(5) })

local log = new("ScrollingFrame", {
	BorderSizePixel = 0,
	Size = UDim2.new(1, -16, 1, -76),
	Position = UDim2.fromOffset(8, 28),
	BackgroundColor3 = PANEL,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = chatPanel,
}, {
	corner(6),
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})

local inputBox = new("TextBox", {
	BorderSizePixel = 0,
	PlaceholderText = "type a message...",
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = TEXT,
	PlaceholderColor3 = SUBTEXT,
	BackgroundColor3 = PANEL,
	Size = UDim2.new(1, -60, 0, 32),
	Position = UDim2.new(0, 8, 1, -40),
	ClearTextOnFocus = false,
	Parent = chatPanel,
}, { corner(6) })

local sendBtn = new("TextButton", {
	BorderSizePixel = 0,
	Text = "send",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = TEXT,
	BackgroundColor3 = ACCENT,
	Size = UDim2.new(0, 44, 0, 32),
	Position = UDim2.new(1, -44, 1, -40),
	Parent = chatPanel,
}, { corner(6) })

--------------------------------------------------------------
-- state + logic
--------------------------------------------------------------

local current -- selected Character
local sessionKey = "lumia-ui-" .. tostring(Players.LocalPlayer.UserId)

local function bubble(text, fromMe)
	new("TextLabel", {
		BorderSizePixel = 0,
		Text = (fromMe and "you: " or "") .. text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = fromMe and SUBTEXT or TEXT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		Parent = log,
	})
end

local function selectCharacter(char)
	current = char
	chatHeader.Text = char:GetName()
	for _, c in ipairs(log:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	bubble("chatting with " .. char:GetName() .. " - say something", false)
end

-- deterministic fallback color so the same character always gets the same
-- placeholder circle instead of a random flicker every rebuild
local function charColor(seed)
	local hash = 0
	for i = 1, #seed do
		hash = (hash * 31 + seed:byte(i)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.45, 0.55)
end

local function buildCard(char, parent)
	local name = char:GetName()
	local initial = (name ~= "" and name:sub(1, 1):upper()) or "?"

	local card = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = PANEL,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = parent,
	}, { corner(8) })

	local avatar = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = charColor(initial),
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(6, 6),
		Parent = card,
	}, {
		corner(18),
		new("TextLabel", {
			BorderSizePixel = 0,
			Text = initial,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = TEXT,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}),
	})

	local avatarImg = new("ImageLabel", {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Image = "",
		Size = UDim2.fromScale(1, 1),
		Parent = avatar,
	}, { corner(18) })

	task.spawn(function()
		local ok, img = pcall(function()
			return char:GetImage()
		end)
		if ok and img.Status then
			avatarImg.Image = img.Body
		end
	end)

	new("TextLabel", {
		BorderSizePixel = 0,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -52, 0, 18),
		Position = UDim2.fromOffset(48, 6),
		Parent = card,
	})

	new("TextLabel", {
		BorderSizePixel = 0,
		Text = "@" .. char:GetCreatorName(),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -52, 0, 14),
		Position = UDim2.fromOffset(48, 25),
		Parent = card,
	})

	local click = new("TextButton", {
		BorderSizePixel = 0,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = card,
	})
	click.MouseButton1Click:Connect(function()
		selectCharacter(char)
	end)
end

local function fillResults(characters)
	for _, c in ipairs(results:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, char in ipairs(characters) do
		if i > 20 then
			break
		end
		buildCard(char, results)
	end
end

local function doSearch()
	local query = searchBox.Text
	if query == "" then
		return
	end

	status.Text = "searching..."

	task.spawn(function()
		local res = client:SearchCharacters(query)
		if not res.Status then
			status.Text = "search failed: " .. tostring(res.Body)
			return
		end
		status.Text = ""
		fillResults(res.Body)
	end)
end

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doSearch()
	end
end)

task.spawn(function()
	status.Text = "loading characters..."
	local res = client:GetMainPageCharacters()
	if res.Status then
		fillResults(res.Body)
		status.Text = TOKEN == "PUT_YOUR_TOKEN_HERE" and "no token set - see README" or ""
	else
		status.Text = "couldn't load characters: " .. tostring(res.Body)
	end
end)

local function doSend()
	if not current then
		return
	end

	local text = inputBox.Text
	if text == "" then
		return
	end

	inputBox.Text = ""
	bubble(text, true)

	local thinking = new("TextLabel", {
		BorderSizePixel = 0,
		Text = "...",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = SUBTEXT,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 18),
		Parent = log,
	})

	task.spawn(function()
		local reply = current:SendMessage(sessionKey, text)
		thinking:Destroy()

		if not reply.Status then
			bubble("[error] " .. tostring(reply.Body), false)
			return
		end

		bubble(reply.Body.Text, false)
	end)
end

sendBtn.MouseButton1Click:Connect(doSend)
inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doSend()
	end
end)

--------------------------------------------------------------
-- live relay: click a player in the world, their in-game chat
-- feeds the selected character, replies get typed back automatically.
-- this is the part the old CharHub.lua actually existed for.
--------------------------------------------------------------

local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

local live = false
local focusChar -- Model, or nil = anyone within 7 studs of you
local focusHighlight
local relaying = false

liveBtn.MouseButton1Click:Connect(function()
	if not current then
		status.Text = "pick a character first"
		return
	end
	live = not live
	liveBtn.Text = "live: " .. (live and "on" or "off")
	liveBtn.BackgroundColor3 = live and ACCENT or PANEL
	status.Text = live and ("live: " .. current:GetName()) or ""
end)

local function setFocus(char)
	if focusHighlight then
		focusHighlight:Destroy()
		focusHighlight = nil
	end

	if focusChar == char then
		focusChar = nil
		return
	end

	focusChar = char
	focusHighlight = new("Highlight", {
		FillColor = ACCENT,
		FillTransparency = 0.6,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Parent = char,
	})
end

local function hookClicks(plr)
	if plr == LocalPlayer then
		return
	end

	local function onCharacter(char)
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if not root then
			return
		end

		local click = new("ClickDetector", { MaxActivationDistance = 32, Parent = root })
		click.MouseClick:Connect(function(clicker)
			if clicker == LocalPlayer then
				setFocus(char)
			end
		end)
	end

	if plr.Character then
		onCharacter(plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacter)
end

for _, plr in ipairs(Players:GetPlayers()) do
	hookClicks(plr)
end
Players.PlayerAdded:Connect(hookClicks)

local function sendChat(text)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local channel = channels and channels:FindFirstChild("RBXGeneral")
		if not channel then
			local cfg = TextChatService:FindFirstChild("ChatInputBarConfiguration")
			channel = cfg and cfg.TargetTextChannel
		end
		if channel then
			channel:SendAsync(text)
		end
	end)
end

-- roblox chat has a length cap, so long replies get split on word boundaries
local function splitForChat(text, limit)
	limit = limit or 150
	local chunks, chunk = {}, ""
	for word in text:gmatch("%S+") do
		if #chunk > 0 and #chunk + 1 + #word > limit then
			table.insert(chunks, chunk)
			chunk = word
		else
			chunk = (#chunk == 0) and word or (chunk .. " " .. word)
		end
	end
	if #chunk > 0 then
		table.insert(chunks, chunk)
	end
	return chunks
end

local function relay(plr, text)
	if not current or relaying then
		return
	end
	relaying = true
	status.Text = "relaying " .. plr.Name .. "..."

	task.spawn(function()
		local reply = current:SendMessage(plr.Name, plr.DisplayName .. ": " .. text)
		relaying = false

		if not reply.Status then
			status.Text = "relay error: " .. tostring(reply.Body)
			return
		end
		status.Text = live and ("live: " .. current:GetName()) or ""

		for _, chunk in ipairs(splitForChat(reply.Body.Text)) do
			sendChat(chunk)
			task.wait(2)
		end
	end)
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.MessageReceived:Connect(function(msg)
		if not live or not current then
			return
		end

		local speaker = msg.TextSource and Players:GetPlayerByUserId(msg.TextSource.UserId)
		if not speaker then
			return
		end

		if speaker == LocalPlayer then
			if msg.Text:sub(1, 1) == "!" then
				relay(speaker, msg.Text:sub(2))
			end
			return
		end

		if focusChar then
			if speaker.Character == focusChar then
				relay(speaker, msg.Text)
			end
			return
		end

		local myChar = LocalPlayer.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local otherRoot = speaker.Character and speaker.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and otherRoot and (otherRoot.Position - myRoot.Position).Magnitude < 7 then
			relay(speaker, msg.Text)
		end
	end)
else
	warn("[Lumia] this game uses legacy chat, not TextChatService - live relay won't work")
end

-- that's the whole thing. lumia.
