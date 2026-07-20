-- lumia -- jacobb5214
-- Unofficial Character.AI client for Roblox executors.
-- Token: Network tab -> any plus/neo.character.ai request -> Authorization header. See docs/api-notes.md.
-- No telemetry, no phone-home, no webhook calls anywhere in this file.

local HttpService = game:GetService("HttpService")

local fetch = (syn and syn.request) or http_request or request
	or (fluxus and fluxus.request) or (http and http.request)

local wsConnect = WebSocket and WebSocket.connect

if not fetch then
	error("CharacterAI: no http request function found (syn.request / http_request / request)", 0)
end

if not wsConnect then
	error("CharacterAI: no WebSocket.connect found - this executor can't run chat", 0)
end

--============================================================--
-- small utils
--============================================================--

local function uuid()
	return HttpService:GenerateGUID(false):lower()
end

local function encode(v)
	return HttpService:JSONEncode(v)
end

local function decode(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, s)
	if ok then
		return v
	end
	return nil
end

--============================================================--
-- rest layer: retries, backoff, cloudflare/ratelimit detection
--============================================================--

local BACKOFF = { 0.6, 1.5, 3 }
local MAX_RETRIES = 3

local function classify(status, body)
	if status == 401 then
		return "auth"
	elseif status == 403 and not decode(body) then
		-- html instead of json on a 403 = cloudflare's saying hi, not the app
		return "cloudflare"
	elseif status == 429 then
		return "ratelimit"
	elseif status >= 500 then
		return "server"
	elseif status >= 200 and status < 300 then
		return "ok"
	end
	return "error"
end

local function rest(method, url, headers, body)
	headers = headers or {}
	headers["Content-Type"] = headers["Content-Type"] or "application/json"
	if type(body) == "table" then
		body = encode(body)
	end

	local attempt = 0
	while true do
		attempt += 1
		local ok, res = pcall(fetch, {
			Url = url,
			Method = method,
			Headers = headers,
			Body = body,
		})

		if not ok then
			if attempt > MAX_RETRIES then
				return { Status = false, Body = "request failed: " .. tostring(res) }
			end
			task.wait(BACKOFF[math.min(attempt, #BACKOFF)])
			continue
		end

		local status = res.StatusCode or res.status_code or 0
		local raw = res.Body or res.body or ""
		local kind = classify(status, raw)

		if kind == "ok" then
			return { Status = true, Body = decode(raw) or raw, StatusCode = status }
		end

		if (kind == "ratelimit" or kind == "server") and attempt <= MAX_RETRIES then
			task.wait(BACKOFF[math.min(attempt, #BACKOFF)])
			continue
		end

		return { Status = false, Body = decode(raw) or raw, StatusCode = status, Kind = kind }
	end
end

--============================================================--
-- chat turn payload boilerplate
--============================================================--

-- the site sends all 23 of these, zeroed, on every turn - so do we
local PREV_ANNOTATIONS = {
	bad_memory = 0, boring = 0, ends_chat_early = 0, funny = 0, helpful = 0,
	inaccurate = 0, interesting = 0, long = 0, not_bad_memory = 0, not_boring = 0,
	not_ends_chat_early = 0, not_funny = 0, not_helpful = 0, not_inaccurate = 0,
	not_interesting = 0, not_long = 0, not_out_of_character = 0, not_repetitive = 0,
	not_short = 0, out_of_character = 0, repetitive = 0, short = 0,
}

--============================================================--
-- CharacterAI
--============================================================--

local CharacterAI = {}
CharacterAI.__index = CharacterAI

local Character = {}
Character.__index = Character

function CharacterAI.new(token)
	return setmetatable({
		Token = token,
		AccountId = nil,
		Ws = nil,
		WsQueue = {},
		Sessions = {}, -- Sessions[characterId][key] = { ChatId = ... }
	}, CharacterAI)
end

function CharacterAI:Headers()
	local h = { ["Content-Type"] = "application/json" }
	if self.Token and self.Token ~= "" then
		h["Authorization"] = "Token " .. self.Token
	end
	return h
end

--------------------------------------------------------------
-- character discovery
--------------------------------------------------------------

function CharacterAI:SearchCharacters(query)
	local input = encode({ ["0"] = { json = { searchQuery = query } } })
	local url = "https://character.ai/api/trpc/search.search?batch=1&input=" .. HttpService:UrlEncode(input)

	local res = rest("GET", url, self:Headers())
	if not res.Status then
		return res
	end

	local ok, raw = pcall(function()
		return res.Body[1].result.data.json.characters
	end)
	if not ok then
		return { Status = false, Body = "unexpected search response shape" }
	end

	local out = {}
	for _, c in ipairs(raw) do
		table.insert(out, Character.new(self, c))
	end
	return { Status = true, Body = out }
end

function CharacterAI:GetMainPageCharacters()
	local res = rest("GET", "https://plus.character.ai/chat/characters/featured_v2/", self:Headers())
	if not res.Status then
		return res
	end

	local out = {}
	for _, c in ipairs(res.Body.characters or {}) do
		table.insert(out, Character.new(self, c))
	end
	return { Status = true, Body = out }
end

function CharacterAI:GetCategories()
	local res = rest("GET", "https://plus.character.ai/chat/character/categories/", self:Headers())
	if not res.Status then
		return res
	end
	return { Status = true, Body = res.Body.categories or {} }
end

function CharacterAI:GetCharacterInfo(characterId)
	local res = rest("POST", "https://neo.character.ai/character/v1/get_character_info", self:Headers(), {
		external_id = characterId,
	})
	if not res.Status then
		return res
	end
	if res.Body.status == "NOT_OK" then
		return { Status = false, Body = res.Body.error or "character not found" }
	end
	return { Status = true, Body = Character.new(self, res.Body.character) }
end

--------------------------------------------------------------
-- account id (needed to stamp our own turns on the socket)
--------------------------------------------------------------

function CharacterAI:_EnsureAccountId()
	if self.AccountId then
		return { Status = true, Body = self.AccountId }
	end

	local res = rest("GET", "https://plus.character.ai/chat/user/", self:Headers())
	if not res.Status then
		return res
	end

	local ok, id = pcall(function()
		return res.Body.user.user.id
	end)
	if not ok or not id then
		return { Status = false, Body = "couldn't read account id from /chat/user/ response" }
	end

	self.AccountId = tostring(id)
	return { Status = true, Body = self.AccountId }
end

--------------------------------------------------------------
-- websocket: connect once, pump frames into a queue, match by
-- request_id or a caller-supplied predicate
--------------------------------------------------------------

function CharacterAI:_EnsureWs()
	if self.Ws then
		return { Status = true }
	end

	-- UNC's WebSocket.connect only guarantees a url arg, so this second table is a
	-- polite suggestion some executors take and others just ignore. jacobb5214 was here.
	local ok, ws = pcall(wsConnect, "wss://neo.character.ai/ws/", {
		Headers = { Cookie = "HTTP_AUTHORIZATION=Token " .. tostring(self.Token) },
	})
	if not ok or not ws then
		ok, ws = pcall(wsConnect, "wss://neo.character.ai/ws/")
	end
	if not ok or not ws then
		return { Status = false, Body = "couldn't open chat websocket", Kind = "auth" }
	end

	self.Ws = ws
	self.WsQueue = {}

	ws.OnMessage:Connect(function(msg)
		local frame = decode(msg)
		if frame then
			table.insert(self.WsQueue, frame)
		end
	end)

	ws.OnClose:Connect(function()
		self.Ws = nil
	end)

	return { Status = true }
end

function CharacterAI:_WsSend(msg)
	local ready = self:_EnsureWs()
	if not ready.Status then
		return ready
	end

	local ok, err = pcall(function()
		self.Ws:Send(encode(msg))
	end)
	if not ok then
		self.Ws = nil
		return { Status = false, Body = "websocket send failed: " .. tostring(err) }
	end
	return { Status = true }
end

-- pulls frames off the queue until `match(frame)` is true or we time out
function CharacterAI:_WaitFrame(match, timeoutSec)
	local deadline = os.clock() + (timeoutSec or 25)

	while os.clock() < deadline do
		for i, frame in ipairs(self.WsQueue) do
			if match(frame) then
				table.remove(self.WsQueue, i)
				return frame
			end
		end
		task.wait(0.05)
	end

	return nil
end

--------------------------------------------------------------
-- chat: create a chat, send a turn, wait for the final candidate
--------------------------------------------------------------

function CharacterAI:_NewChat(characterId)
	local acc = self:_EnsureAccountId()
	if not acc.Status then
		return acc
	end

	local requestId, chatId = uuid(), uuid()

	local sent = self:_WsSend({
		command = "create_chat",
		request_id = requestId,
		payload = {
			chat = {
				chat_id = chatId,
				creator_id = acc.Body,
				visibility = "VISIBILITY_PRIVATE",
				character_id = characterId,
				type = "TYPE_ONE_ON_ONE",
			},
			with_greeting = true,
		},
	})
	if not sent.Status then
		return sent
	end

	local created = self:_WaitFrame(function(f)
		return f.request_id == requestId and (f.command == "create_chat_response" or f.command == "neo_error")
	end)
	if not created then
		return { Status = false, Body = "timed out waiting for create_chat_response" }
	end
	if created.command == "neo_error" then
		return { Status = false, Body = created.comment or "chat creation failed" }
	end

	local greeting = self:_WaitFrame(function(f)
		return f.request_id == requestId and f.command == "add_turn"
	end, 15)

	local greetingText = nil
	if greeting then
		local candidate = greeting.turn.candidates[1]
		greetingText = candidate and candidate.raw_content
	end

	return { Status = true, Body = { ChatId = chatId, Greeting = greetingText } }
end

function CharacterAI:_SendTurn(characterId, chatId, text)
	local acc = self:_EnsureAccountId()
	if not acc.Status then
		return acc
	end

	local requestId, turnId, candidateId = uuid(), uuid(), uuid()

	local sent = self:_WsSend({
		command = "create_and_generate_turn",
		origin_id = "web-next",
		request_id = requestId,
		payload = {
			character_id = characterId,
			num_candidates = 1,
			selected_language = "",
			tts_enabled = false,
			user_name = "",
			previous_annotations = PREV_ANNOTATIONS,
			turn = {
				author = { author_id = acc.Body, is_human = true, name = "" },
				candidates = { { candidate_id = candidateId, raw_content = text } },
				primary_candidate_id = candidateId,
				turn_key = { chat_id = chatId, turn_id = turnId },
			},
		},
	})
	if not sent.Status then
		return sent
	end

	local deadline = os.clock() + 30
	while os.clock() < deadline do
		local frame = self:_WaitFrame(function(f)
			return f.request_id == requestId
		end, deadline - os.clock())

		if not frame then
			break
		end

		if frame.command == "neo_error" then
			return { Status = false, Body = frame.comment or "send failed" }
		end

		if frame.command == "filter_user_input_self_harm" then
			return { Status = false, Body = "message blocked by safety filter", Kind = "filtered" }
		end

		if frame.command == "add_turn" or frame.command == "update_turn" then
			local turn = frame.turn
			if not (turn.author and turn.author.is_human) then
				local candidate = turn.candidates[1]
				if candidate and candidate.is_final then
					return {
						Status = true,
						Body = {
							Text = candidate.raw_content,
							TurnId = turn.turn_key.turn_id,
							ChatId = chatId,
						},
					}
				end
			end
		end
	end

	return { Status = false, Body = "timed out waiting for a reply" }
end

--============================================================--
-- Character - a single result from search/featured/info
--============================================================--

function Character.new(client, raw)
	return setmetatable({ _client = client, _raw = raw }, Character)
end

function Character:GetName()
	return self._raw.participant__name or self._raw.name or ""
end

function Character:GetCreatorName()
	return self._raw.user__username or ""
end

function Character:GetDescription()
	local raw = self._raw
	if raw.title and raw.title ~= "" then
		return raw.title
	end
	if raw.greeting and raw.greeting ~= "" then
		return raw.greeting
	end
	return self:GetName()
end

function Character:GetId()
	return self._raw.external_id
end

function Character:GetImage()
	local fileName = self._raw.avatar_file_name
	if not fileName or fileName == "" then
		return { Status = false, Body = "character has no avatar" }
	end

	local customAsset = getsynasset or getcustomasset
	local cachePath = "CharacterAi/" .. fileName:gsub("%p", "") .. ".png"

	if customAsset and isfile and isfile(cachePath) then
		return { Status = true, Body = customAsset(cachePath) }
	end

	local ok, imageData = pcall(game.HttpGet, game, "https://characterai.io/i/400/static/avatars/" .. fileName)
	if not ok then
		return { Status = false, Body = "couldn't download avatar" }
	end

	if not customAsset then
		return { Status = true, Body = "https://characterai.io/i/400/static/avatars/" .. fileName }
	end

	if isfolder and not isfolder("CharacterAi") then
		makefolder("CharacterAi")
	end
	writefile(cachePath, imageData)

	return { Status = true, Body = customAsset(cachePath) }
end

-- key: any string you pick to identify this conversation (per-player id, etc).
-- Reuses the same chat on repeat calls with the same key; starts a new one otherwise.
function Character:SendMessage(key, text)
	assert(key, "SendMessage: no session key given")
	assert(text and text ~= "", "SendMessage: no text given")

	local client, id = self._client, self:GetId()
	client.Sessions[id] = client.Sessions[id] or {}
	local session = client.Sessions[id][key]

	if not session then
		local created = client:_NewChat(id)
		if not created.Status then
			return created
		end
		session = { ChatId = created.Body.ChatId }
		client.Sessions[id][key] = session
	end

	return client:_SendTurn(id, session.ChatId, text)
end

function Character:ResetChat(key)
	local id = self:GetId()
	if self._client.Sessions[id] then
		self._client.Sessions[id][key] = nil
	end
end

-- that's the whole thing. lumia.
return CharacterAI
