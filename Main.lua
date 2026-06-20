--[[
	DISCLAIMER:

	I am not affiliated with Character.AI.
	This is just a project I made for fun.

	This script uses an API made through web scraping,
	which is a technique used to extract data from websites.

	This script is not endorsed, supported, or made by
	the official Character.AI team.

	Official Character.AI site:
	https://character.ai/
]]

getfenv().YourToken = ""; -- Paste your Character.AI token here
getfenv().WaitAnswer = true;

--[[
	IMPORTANT:

	- If "YourToken" is empty, the script logs in as a guest.

	- Why you should use a token:
		- Guests can only send a limited amount of messages.
		- Guests cannot search for characters.
		- With a token, you can use Character.AI properly.

	- Setting "WaitAnswer" to true makes the script wait for the bot's
	  response before sending another message.

	- Setting "WaitAnswer" to false makes the script respond faster,
	  but it may flood the chat with messages.
]]

--[[
	HOW TO GET YOUR CHARACTER.AI TOKEN:

	You can find the steps here:
	https://github.com/LumiaDevJacob/CharacterAI#how-to-get-my-characterai-token

	GitHub Repository:
	https://github.com/LumiaDevJacob/CharacterAI
]]

loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiaDevJacob/CharacterAI/main/Examples/CharHub.lua", true))();
