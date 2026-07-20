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

local root = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(560, 400),
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
	Size = UDim2.new(0, 180, 1, -44),
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
}, { new("UIListLayout", { Padding = UDim.new(0, 4) }) })

--------------------------------------------------------------
-- chat panel (right)
--------------------------------------------------------------

local chatPanel = new("Frame", {
	BorderSizePixel = 0,
	Size = UDim2.new(1, -180, 1, -44),
	Position = UDim2.fromOffset(180, 44),
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
	Size = UDim2.new(1, -16, 0, 24),
	Position = UDim2.fromOffset(8, 0),
	BackgroundTransparency = 1,
	Parent = chatPanel,
})

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

local function doSearch()
	local query = searchBox.Text
	if query == "" then
		return
	end

	status.Text = "searching..."
	for _, c in ipairs(results:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end

	task.spawn(function()
		local res = client:SearchCharacters(query)
		if not res.Status then
			status.Text = "search failed: " .. tostring(res.Body)
			return
		end
		status.Text = ""

		for i, char in ipairs(res.Body) do
			if i > 15 then
				break
			end

			local btn = new("TextButton", {
				BorderSizePixel = 0,
				Text = char:GetName(),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = PANEL,
				Size = UDim2.new(1, 0, 0, 26),
				Parent = results,
			}, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })

			btn.MouseButton1Click:Connect(function()
				selectCharacter(char)
			end)
		end
	end)
end

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doSearch()
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

-- that's the whole thing. lumia.
