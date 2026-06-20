local HttpService = game:GetService("HttpService")

local requestFunction =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local CharacterAI = {}
CharacterAI.__index = CharacterAI
CharacterAI.Version = "2.0.0-lumia"
CharacterAI.Credits = "Jacobb5214 for Lumia"
CharacterAI.Repository = "https://github.com/LumiaDevJacob/CharacterAI"
CharacterAI.GlobalSabes = {}
CharacterAI.StatsEnabled = false
CharacterAI.StatsWebhook = ""

local TokenGlobal = nil
local ActiveSession = nil

local function Status(ok, body)
    return {
        Status = ok == true,
        Body = body
    }
end

local function Warn(message)
    warn("[Lumia CharacterAI] " .. tostring(message))
end

local function AssertValue(value, message)
    if not value then
        error("[Lumia CharacterAI] " .. tostring(message), 2)
    end
end

local function NewGuid()
    return HttpService:GenerateGUID(false)
end

local function UrlEncode(value)
    return HttpService:UrlEncode(tostring(value or ""))
end

local function RoundInteractions(number)
    number = tonumber(number) or 0
    if number >= 1000000 then
        return tostring(math.floor(number / 1000000)) .. "m"
    elseif number >= 1000 then
        return tostring(math.floor(number / 1000)) .. "k"
    end
    return tostring(number)
end

local function SafeDecode(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if ok then
        return decoded
    end

    local lastObject = text:match("%b{}")
    for object in text:gmatch("%b{}") do
        lastObject = object
    end

    if lastObject then
        ok, decoded = pcall(function()
            return HttpService:JSONDecode(lastObject)
        end)
        if ok then
            return decoded
        end
    end

    return nil
end

local function GetBody(response)
    if type(response) ~= "table" then
        return nil
    end
    return response.Body or response.body or response.ResponseBody
end

local function GetStatusCode(response)
    if type(response) ~= "table" then
        return 0
    end
    return tonumber(response.StatusCode or response.Status or response.status_code or response.status) or 0
end

local function MakeHeaders(includeToken)
    local headers = {
        ["Accept"] = "application/json, text/plain, */*",
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Character.AI"
    }

    if includeToken and TokenGlobal and TokenGlobal ~= "" then
        headers["Authorization"] = "Token " .. TokenGlobal
    end

    return headers
end

function CharacterAI:HTTPRequest(url, method, body, includeToken)
    AssertValue(url, "No URL provided")
    AssertValue(method, "No method provided")

    if not requestFunction then
        return Status(false, "No supported request function found. Your environment needs request/syn.request/http_request.")
    end

    local options = {
        Url = url,
        Method = method,
        Headers = MakeHeaders(includeToken ~= false)
    }

    if body ~= nil then
        options.Body = type(body) == "string" and body or HttpService:JSONEncode(body)
    end

    local ok, response = pcall(function()
        return requestFunction(options)
    end)

    if not ok then
        return Status(false, "Request failed: " .. tostring(response))
    end

    local code = GetStatusCode(response)
    local responseBody = GetBody(response) or ""

    if code >= 200 and code < 300 then
        local decoded = SafeDecode(responseBody)
        if decoded ~= nil then
            return Status(true, decoded)
        end
        return Status(true, responseBody)
    end

    return Status(false, "HTTP " .. tostring(code) .. ": " .. tostring(responseBody))
end

local function TryGet(obj, ...)
    local current = obj
    for _, key in ipairs({...}) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return current
end

local function NormalizeCharacter(raw)
    raw = type(raw) == "table" and raw or {}

    if raw.character_id and not raw.external_id then
        raw.external_id = raw.character_id
    end
    if raw.character_name and not raw.participant__name then
        raw.participant__name = raw.character_name
    end
    if raw.character_avatar_uri and not raw.avatar_file_name then
        raw.avatar_file_name = raw.character_avatar_uri
    end
    if raw.name and not raw.participant__name then
        raw.participant__name = raw.name
    end

    return raw
end

local function ExtractCharacters(body)
    if type(body) ~= "table" then
        return {}
    end

    if type(body.characters) == "table" then
        return body.characters
    end

    if type(body.chats) == "table" then
        return body.chats
    end

    if type(body.Body) == "table" then
        return ExtractCharacters(body.Body)
    end

    return body
end

local function AddFunctionsToCharacter(character, session)
    character = NormalizeCharacter(character)

    function character:GetName()
        return self.participant__name or self.name or self.title or self.character_name or "Unknown Character"
    end

    function character:GetCreatorName()
        return self.user__username or self.participant__user__username or self.creator_username or self.creator or "Unknown"
    end

    function character:GetInteractions(round)
        local interactions = self.participant__num_interactions or self.num_interactions or self.num_interactions_last_day or 0
        if round == true then
            return RoundInteractions(interactions)
        end
        return tonumber(interactions) or 0
    end

    function character:GetDescription()
        return self.title or self.description or self.greeting or self.participant__name or ""
    end

    function character:GetImage()
        local image = self.avatar_file_name or self.character_avatar_uri
        if not image or image == "" then
            return Status(false, "No avatar found")
        end

        if tostring(image):sub(1, 4) == "http" or tostring(image):sub(1, 10) == "rbxassetid:" then
            return Status(true, image)
        end

        local url = "https://characterai.io/i/400/static/avatars/" .. tostring(image)

        local canCache = isfile and writefile and (getsynasset or getcustomasset)
        if canCache then
            local folder = "LumiaCharacterAI"
            local safeName = (self:GetName() .. "_" .. self:GetCreatorName()):gsub("[^%w_]", "")
            local path = folder .. "/" .. safeName .. ".png"

            if not isfolder(folder) then
                pcall(makefolder, folder)
            end

            if not isfile(path) then
                local ok, data = pcall(function()
                    return game:HttpGet(url)
                end)
                if ok and data then
                    pcall(writefile, path, data)
                end
            end

            if isfile(path) then
                local asset = (getsynasset or getcustomasset)(path)
                return Status(true, asset)
            end
        end

        return Status(true, url)
    end

    function character:NewChat(key)
        return session:NewChat(self.external_id, key)
    end

    function character:DeleteChat(key)
        if not self.external_id then
            return false
        end
        if CharacterAI.GlobalSabes[self.external_id] then
            CharacterAI.GlobalSabes[self.external_id][key] = nil
        end
        return true
    end

    function character:SendMessage(key, text)
        AssertValue(key, "No chat key provided")
        AssertValue(text, "No message text provided")

        if not self.external_id then
            return Status(false, "This character has no external_id")
        end

        if not CharacterAI.GlobalSabes[self.external_id] or not CharacterAI.GlobalSabes[self.external_id][key] then
            local created = self:NewChat(key)
            if created.Status == false then
                return created
            end
        end

        local chatInfo = CharacterAI.GlobalSabes[self.external_id][key]
        return session:SendMessage(self.external_id, chatInfo.chat_id or chatInfo.history, chatInfo.internal, text)
    end

    return character
end

local function AddFunctionsToList(list, session)
    local output = {}
    if type(list) ~= "table" then
        return output
    end

    for key, item in pairs(list) do
        if type(item) == "table" then
            output[key] = AddFunctionsToCharacter(item, session)
        end
    end

    return output
end

local function AddFunctionsToCategoryMap(map, session)
    local output = {}
    if type(map) ~= "table" then
        return output
    end

    for category, list in pairs(map) do
        if type(list) == "table" then
            output[category] = AddFunctionsToList(list, session)
        end
    end

    return output
end

local function GetWebSocketConnector()
    if WebSocket and WebSocket.connect then
        return WebSocket.connect
    end
    if syn and syn.websocket and syn.websocket.connect then
        return syn.websocket.connect
    end
    if websocket and websocket.connect then
        return websocket.connect
    end
    return nil
end

local function WsSend(socket, text)
    if not socket then
        return false
    end
    if socket.Send then
        socket:Send(text)
        return true
    end
    if socket.send then
        socket:send(text)
        return true
    end
    return false
end

local function WsClose(socket)
    if not socket then
        return
    end
    pcall(function()
        if socket.Close then socket:Close() end
    end)
    pcall(function()
        if socket.close then socket:close() end
    end)
end

function CharacterAI:OpenChatSocket()
    if self.ChatSocket then
        return true
    end

    if not TokenGlobal or TokenGlobal == "" then
        return false, "A token is required for WebSocket chat"
    end

    local connector = GetWebSocketConnector()
    if not connector then
        return false, "No WebSocket connector found. Live replies need WebSocket.connect/syn.websocket.connect."
    end

    local cookie = 'HTTP_AUTHORIZATION="Token ' .. TokenGlobal .. '"'
    if self.EdgeRollout and self.EdgeRollout ~= "" then
        cookie = "edge_rollout=" .. tostring(self.EdgeRollout) .. "; " .. cookie
    end

    local socket
    local ok, result = pcall(function()
        return connector("wss://neo.character.ai/ws/", {
            Headers = {
                Cookie = cookie
            }
        })
    end)

    if ok and result then
        socket = result
    else
        ok, result = pcall(function()
            return connector("wss://neo.character.ai/ws/", cookie)
        end)
        if ok and result then
            socket = result
        else
            ok, result = pcall(function()
                return connector("wss://neo.character.ai/ws/")
            end)
            if ok and result then
                socket = result
            else
                return false, "Failed to open Character.AI WebSocket: " .. tostring(result)
            end
        end
    end

    self.ChatSocket = socket
    return true
end

function CharacterAI:WaitForSocketMessage(commandPayload, timeoutSeconds, wantsFinal)
    local socketOk, socketErr = self:OpenChatSocket()
    if not socketOk then
        return Status(false, socketErr)
    end

    timeoutSeconds = timeoutSeconds or 45
    local startTime = os.clock()
    local done = false
    local finalMessage = nil
    local messages = {}
    local connection

    local function handleMessage(message)
        local text = tostring(message)
        if text == "{}" then
            pcall(function()
                WsSend(self.ChatSocket, "{}")
            end)
            return
        end

        local decoded = SafeDecode(text) or text
        table.insert(messages, decoded)

        if wantsFinal == false then
            finalMessage = decoded
            done = true
            return
        end

        if type(decoded) == "table" then
            local turn = decoded.turn or TryGet(decoded, "push", "pub", "data", "turn")
            local candidate = TryGet(turn, "candidates", 1)
            if candidate and candidate.is_final == true and TryGet(turn, "author", "is_human") ~= true then
                finalMessage = decoded
                done = true
                return
            end

            if decoded.chat or decoded.error or decoded.command then
                finalMessage = decoded
                done = true
                return
            end
        end
    end

    if self.ChatSocket.OnMessage and self.ChatSocket.OnMessage.Connect then
        connection = self.ChatSocket.OnMessage:Connect(handleMessage)
    elseif self.ChatSocket.onmessage then
        self.ChatSocket.onmessage = handleMessage
    end

    local sent = WsSend(self.ChatSocket, commandPayload)
    if not sent then
        if connection then connection:Disconnect() end
        return Status(false, "WebSocket object does not support Send/send")
    end

    while not done and os.clock() - startTime < timeoutSeconds do
        task.wait(0.05)
    end

    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end

    if not done then
        return Status(false, "Timed out waiting for Character.AI WebSocket response")
    end

    return Status(true, finalMessage or messages)
end

function CharacterAI:ExtractReply(response)
    local body = response.Body or response
    local turn = TryGet(body, "turn") or TryGet(body, "push", "pub", "data", "turn")
    local candidate = TryGet(turn, "candidates", 1)
    local text = candidate and (candidate.raw_content or candidate.text)

    if text and text ~= "" then
        return text
    end

    local oldReply = TryGet(body, "replies", 1, "text")
    if oldReply then
        return oldReply
    end

    return nil
end

function CharacterAI:GetEdgeRollout()
    local res = self:HTTPRequest("https://character.ai/", "GET", nil, false)
    return res.Status == true
end

function CharacterAI:VerifyToken(token)
    if not token or token == "" then
        return Status(false, "No token provided")
    end

    local res = self:HTTPRequest("https://plus.character.ai/chat/user/", "GET", nil, true)
    if res.Status == false then
        return res
    end

    if type(res.Body) == "table" and res.Body.user then
        self.User = res.Body.user
        self.UserId = TryGet(res.Body, "user", "user", "id") or TryGet(res.Body, "user", "id")
        self.Username = TryGet(res.Body, "user", "user", "username") or TryGet(res.Body, "user", "name") or "User"
        return Status(true, res.Body)
    end

    return Status(false, "Invalid token response")
end


local function GetExecutorName()
    local ok, name = pcall(function()
        if identifyexecutor then
            return identifyexecutor()
        end
        return "unknown"
    end)

    if ok and name then
        return tostring(name)
    end

    return "unknown"
end

local function MakeStatFields(eventName, details, session)
    local Players = game:GetService("Players")
    local fields = {
        {
            name = "event",
            value = tostring(eventName),
            inline = true
        },
        {
            name = "version",
            value = tostring(CharacterAI.Version),
            inline = true
        },
        {
            name = "guest",
            value = tostring(session and session.Guest == true),
            inline = true
        },
        {
            name = "placeId",
            value = tostring(game.PlaceId or 0),
            inline = true
        },
        {
            name = "players",
            value = tostring(#Players:GetPlayers()),
            inline = true
        },
        {
            name = "executor",
            value = GetExecutorName(),
            inline = true
        }
    }

    if type(details) == "table" then
        for key, value in pairs(details) do
            if key ~= "token" and key ~= "message" and key ~= "username" and key ~= "userId" and key ~= "jobId" then
                table.insert(fields, {
                    name = tostring(key):sub(1, 256),
                    value = tostring(value):sub(1, 1024),
                    inline = true
                })
            end
        end
    end

    return fields
end

function CharacterAI:SetStats(options)
    options = options or {}

    local env = getfenv and getfenv() or {}
    self.StatsEnabled = options.StatsEnabled == true or env.LumiaStatsEnabled == true
    self.StatsWebhook = tostring(options.StatsWebhook or env.LumiaStatsWebhook or "")

    CharacterAI.StatsEnabled = self.StatsEnabled
    CharacterAI.StatsWebhook = self.StatsWebhook

    return self.StatsEnabled == true and self.StatsWebhook ~= ""
end

function CharacterAI:SendStat(eventName, details)
    if self.StatsEnabled ~= true then
        return false
    end

    local webhook = tostring(self.StatsWebhook or "")
    if webhook == "" or webhook == "PUT_YOUR_DISCORD_WEBHOOK_HERE" then
        return false
    end

    if not requestFunction then
        return false
    end

    local payload = {
        username = "Lumia Stats",
        embeds = {
            {
                title = "Lumia event",
                description = "Project statistics",
                color = 5793266,
                fields = MakeStatFields(eventName, details, self),
                footer = {
                    text = "Jacobb5214 for Lumia"
                }
            }
        }
    }

    local ok = pcall(function()
        requestFunction({
            Url = webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    return ok
end

function CharacterAI.new(token, options)
    local self = setmetatable({}, CharacterAI)
    ActiveSession = self
    CharacterAI.GlobalSabes = {}

    self.Options = options or {}
    self.Guest = not token or token == ""
    self.User = nil
    self.UserId = 0
    self.Username = "Guest"
    self.ChatSocket = nil
    self.EdgeRollout = nil
    self.StatsEnabled = false
    self.StatsWebhook = ""
    self:SetStats(options)

    TokenGlobal = token

    if self.Guest then
        Warn("No token set. Add your token in Main.lua for chat.")
    else
        local verified = self:VerifyToken(token)
        if verified.Status == false then
            Warn("Token check failed: " .. tostring(verified.Body))
        else
            self:OpenChatSocket()
        end
    end

    Warn("Loaded Lumia CharacterAI v" .. self.Version .. " | " .. self.Credits)
    self:SendStat("session_started", {
        status = self.Guest and "guest" or "token"
    })
    return self
end

function CharacterAI:printTable(tbl)
    if type(tbl) ~= "table" then
        print(tostring(tbl))
        return
    end

    local function printHelper(t, indent)
        local pad = string.rep(" ", indent)
        for k, v in pairs(t) do
            if type(v) == "table" then
                print(pad .. "[" .. tostring(k) .. "] = {")
                printHelper(v, indent + 2)
                print(pad .. "},")
            else
                print(pad .. "[" .. tostring(k) .. "] = " .. tostring(v) .. ",")
            end
        end
    end

    print("{")
    printHelper(tbl, 2)
    print("}")
end

function CharacterAI:SplitText(text)
    AssertValue(text, "No text provided")
    local words = string.split(tostring(text), " ")
    local parts = {}
    local index = 1
    parts[index] = { Tamano = 0, Texto = {} }

    for _, word in ipairs(words) do
        parts[index].Tamano = parts[index].Tamano + #word
        table.insert(parts[index].Texto, word)
        if parts[index].Tamano > 150 then
            index = index + 1
            parts[index] = { Tamano = 0, Texto = {} }
        end
    end

    return parts
end

function CharacterAI:IsOnline()
    local res = self:HTTPRequest("https://character.ai/", "GET", nil, false)
    return res.Status == true
end

function CharacterAI:GlobalHistoryReset()
    CharacterAI.GlobalSabes = {}
    return true
end

function CharacterAI:GetCategories()
    local res = self:HTTPRequest("https://neo.character.ai/recommendation/v1/discovery_tags", "GET", nil, true)
    if res.Status == true then
        return res
    end
    return self:HTTPRequest("https://plus.character.ai/chat/character/categories/", "GET", nil, true)
end

function CharacterAI:GetMainPageCharacters()
    local curated = self:HTTPRequest("https://plus.character.ai/chat/curated_categories/characters/", "GET", nil, true)
    if curated.Status == true and type(curated.Body) == "table" and type(curated.Body.characters_by_curated_category) == "table" then
        return Status(true, AddFunctionsToCategoryMap(curated.Body.characters_by_curated_category, self))
    end

    local featured = self:GetFeaturedCharacters()
    if featured.Status == true and type(featured.Body) == "table" and next(featured.Body) ~= nil then
        return Status(true, { Featured = featured.Body })
    end

    return Status(true, { Featured = {} })
end

function CharacterAI:GetFeaturedCharacters()
    local res = self:HTTPRequest("https://neo.character.ai/recommendation/v1/featured", "GET", nil, true)
    if res.Status == true then
        return Status(true, AddFunctionsToList(ExtractCharacters(res.Body), self))
    end
    return Status(true, {})
end

function CharacterAI:GetRecommendedCharacters()
    if self.Guest then
        return Status(true, {})
    end

    local res = self:HTTPRequest("https://neo.character.ai/recommendation/v1/user", "GET", nil, true)
    if res.Status == true then
        return Status(true, AddFunctionsToList(ExtractCharacters(res.Body), self))
    end
    return Status(true, {})
end

function CharacterAI:GetUserCharacters()
    if self.Guest then
        return Status(true, {})
    end

    local res = self:HTTPRequest("https://neo.character.ai/character/v1/get_characters_created_by_user", "GET", nil, true)
    if res.Status == true then
        return Status(true, AddFunctionsToList(ExtractCharacters(res.Body), self))
    end
    return Status(true, {})
end

function CharacterAI:GetRecentCharacters()
    if self.Guest then
        return Status(true, {})
    end

    local res = self:HTTPRequest("https://neo.character.ai/chats/recent/", "GET", nil, true)
    if res.Status == true then
        return Status(true, AddFunctionsToList(ExtractCharacters(res.Body), self))
    end
    return Status(true, {})
end

function CharacterAI:SearchCharacters(query)
    AssertValue(query, "No query provided")
    self:SendStat("search_used")

    local url = "https://neo.character.ai/search/v1/character?query=" .. UrlEncode(query) .. "&sortedBy=relevant"
    local res = self:HTTPRequest(url, "GET", nil, true)
    if res.Status == true then
        return Status(true, AddFunctionsToList(ExtractCharacters(res.Body), self))
    end
    return res
end

function CharacterAI:GetCharacterByExternalId(externalCharacterId)
    AssertValue(externalCharacterId, "No external character id provided")

    local res = self:HTTPRequest("https://neo.character.ai/character/v1/get_character_info", "POST", {
        external_id = externalCharacterId,
        lang = "en"
    }, true)

    if res.Status == true then
        local character = res.Body.character or res.Body
        return Status(true, AddFunctionsToCharacter(character, self))
    end

    local fallback = self:HTTPRequest("https://plus.character.ai/chat/character/", "POST", {
        external_id = externalCharacterId
    }, true)

    if fallback.Status == true then
        local character = fallback.Body.character or fallback.Body
        return Status(true, AddFunctionsToCharacter(character, self))
    end

    return res
end

function CharacterAI:GetUserInfo()
    return self:HTTPRequest("https://plus.character.ai/chat/user/", "GET", nil, true)
end

function CharacterAI:NewChat(characterId, key)
    AssertValue(characterId, "No character id provided")
    key = key or "default"

    if not CharacterAI.GlobalSabes[characterId] then
        CharacterAI.GlobalSabes[characterId] = {}
    end

    local recent = self:HTTPRequest("https://neo.character.ai/chats/recent/" .. UrlEncode(characterId), "GET", nil, true)
    local chatId = TryGet(recent.Body, "chats", 1, "chat_id")

    if not chatId then
        chatId = NewGuid()
        if self.UserId == 0 then
            self.UserId = 1
        end

        local payload = {
            command = "create_chat",
            request_id = NewGuid(),
            payload = {
                chat = {
                    chat_id = chatId,
                    creator_id = tostring(self.UserId),
                    visibility = "VISIBILITY_PRIVATE",
                    character_id = characterId,
                    type = "TYPE_ONE_ON_ONE"
                },
                with_greeting = true
            },
            origin_id = "Android"
        }

        local wsRes = self:WaitForSocketMessage(HttpService:JSONEncode(payload), 30, false)
        if wsRes.Status == false then
            local old = self:HTTPRequest("https://beta.character.ai/chat/history/create/", "POST", {
                character_external_id = characterId
            }, true)

            if old.Status == true then
                chatId = old.Body.external_id or TryGet(old.Body, "history", "external_id") or chatId
            else
                return Status(false, "Could not create chat. " .. tostring(wsRes.Body))
            end
        end
    end

    CharacterAI.GlobalSabes[characterId][key] = {
        chat_id = chatId,
        history = chatId,
        internal = characterId
    }

    return Status(true, {
        external_id = chatId,
        chat_id = chatId,
        participants = {
            {
                is_human = false,
                user = {
                    username = characterId
                }
            }
        }
    })
end

function CharacterAI:SendMessageNeo(characterId, chatId, text)
    AssertValue(characterId, "No character id provided")
    AssertValue(chatId, "No chat id provided")
    AssertValue(text, "No message text provided")

    local turnId = NewGuid()
    local username = self.Username or "User"
    local userId = tostring(self.UserId or 1)

    local payload = {
        command = "create_and_generate_turn",
        request_id = NewGuid(),
        payload = {
            num_candidates = 1,
            tts_enabled = true,
            selected_language = "",
            character_id = characterId,
            user_name = username,
            turn = {
                turn_key = {
                    turn_id = turnId,
                    chat_id = chatId
                },
                author = {
                    author_id = userId,
                    is_human = true,
                    name = username
                },
                candidates = {
                    {
                        candidate_id = turnId,
                        raw_content = text
                    }
                },
                primary_candidate_id = turnId
            },
            previous_annotations = {
                boring = 0,
                not_boring = 0,
                inaccurate = 0,
                not_inaccurate = 0,
                repetitive = 0,
                not_repetitive = 0,
                out_of_character = 0,
                not_out_of_character = 0,
                bad_memory = 0,
                not_bad_memory = 0,
                long = 0,
                not_long = 0,
                short = 0,
                not_short = 0,
                ends_chat_early = 0,
                not_ends_chat_early = 0,
                funny = 0,
                not_funny = 0,
                interesting = 0,
                not_interesting = 0,
                helpful = 0,
                not_helpful = 0
            }
        },
        origin_id = "Android"
    }

    local res = self:WaitForSocketMessage(HttpService:JSONEncode(payload), 60, true)
    if res.Status == false then
        return res
    end

    local reply = self:ExtractReply(res)
    if not reply then
        return Status(false, "No reply text found in Character.AI response")
    end

    return Status(true, {
        replies = {
            {
                text = reply
            }
        },
        raw = res.Body
    })
end

function CharacterAI:SendMessageLegacy(characterId, chatId, internalId, text)
    return self:HTTPRequest("https://beta.character.ai/chat/streaming/", "POST", {
        history_external_id = chatId,
        character_external_id = characterId,
        text = text,
        tgt = internalId or characterId,
        ranking_method = "random",
        staging = false
    }, true)
end

function CharacterAI:SendMessage(characterId, chatId, internalId, text)
    self:SendStat("message_sent")

    local neo = self:SendMessageNeo(characterId, chatId, text)
    if neo.Status == true then
        self:SendStat("reply_success", { mode = "neo" })
        return neo
    end

    local legacy = self:SendMessageLegacy(characterId, chatId, internalId, text)
    if legacy.Status == true then
        self:SendStat("reply_success", { mode = "legacy" })
        return legacy
    end

    self:SendStat("reply_failed")
    return Status(false, "Neo chat failed: " .. tostring(neo.Body) .. " | Legacy fallback failed: " .. tostring(legacy.Body))
end

return CharacterAI
