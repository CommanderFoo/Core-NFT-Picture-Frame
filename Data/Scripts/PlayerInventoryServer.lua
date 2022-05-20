local API = require(script:GetCustomProperty("InventoryAPI"))
local ROOT = script:GetCustomProperty("Root"):WaitForObject()

local function OnPlayerJoined(player)
	API.CreatePlayerInventory(player)
	API.LoadPlayerInventory(player, ROOT)
end

local function OnPlayerLeft(player)
	API.RemovePlayerInventory(player)
end

Game.playerJoinedEvent:Connect(OnPlayerJoined)
Game.playerLeftEvent:Connect(OnPlayerLeft)