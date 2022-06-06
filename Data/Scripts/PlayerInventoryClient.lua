local API = require(script:GetCustomProperty("InventoryAPI"))
local TWEEN = require(script:GetCustomProperty("Tween"))
local QUEUE = require(script:GetCustomProperty("Queue"))

local SLOTS = script:GetCustomProperty("Slots"):WaitForObject()
local PLAYER_INVENTORY = script:GetCustomProperty("PlayerInventory"):WaitForObject()

local localPlayer = Game.GetLocalPlayer()
local inventory = nil
local tween = nil
local is_open = false

local fetchingTokens = false
local tokenQueue = QUEUE:new() ---type Queue
local elapsedTime = 0
local canFetchTokens = false

_G.tokens = {}

local function on_change(c)
	PLAYER_INVENTORY.x = c.x
end

local function on_complete()
	tween = nil
end

local function open_inventory()
	API.EnableCursor()

	tween = TWEEN:new(1.2, { x = PLAYER_INVENTORY.x }, { x = -50 }, TWEEN.Easings.Out_Elastic, on_change, on_complete)
	is_open = true

	Events.Broadcast("inventory.opened")
end

local function close_inventory()
	API.ClearDraggedItem(true)
	API.DisableCursor()

	tween = TWEEN:new(.6, { x = PLAYER_INVENTORY.x }, { x = 450 }, TWEEN.Easings.In_Quint, on_change, on_complete)
	is_open = false

	Events.Broadcast("inventory.closed")
end

local function InventoryChanged(inv, slot)
	local item = inv:GetItem(slot)
	local childIcon = SLOTS:GetChildren()[slot]:FindChildByName("Icon")
	local childCount = childIcon:FindChildByName("Count")

	if item ~= nil then
		local address = item:GetCustomProperty("ContractAddress")
		local tokenId = item:GetCustomProperty("TokenId")

		if(_G.tokens[address .. tokenId] == nil) then
			tokenQueue:push({

				address = address,
				tokenId = tokenId,
				childIcon = childIcon,

			})
		elseif(_G.tokens[address .. tokenId] ~= nil) then
			childIcon:SetBlockchainToken(_G.tokens[address .. tokenId])
			childIcon.visibility = Visibility.FORCE_ON
		end
	else
		childIcon.visibility = Visibility.FORCE_OFF
	end
end

local function ConnectSlotEvents()
	for index, slot in ipairs(SLOTS:GetChildren()) do
		local button = slot:FindChildByName("Button")
		local icon = slot:FindChildByName("Icon")

		if(button ~= nil and icon ~= nil and button.isInteractable) then
			button.pressedEvent:Connect(API.OnSlotPressedEvent, inventory, slot, index)
		end
	end
end

local function on_action_pressed(player, action)
	if(action == "Open / Close Inventory") then
		if(is_open) then
			close_inventory()
		else
			open_inventory()
		end
	end
end

local function LoadTokens()
	local token1 = tokenQueue:pop()
	local token2 = tokenQueue:pop()

	fetchingTokens = true

	print("----------FETCH-----------")

	if(token1 ~= nil) then
		pcall(function()
			local token = Blockchain.GetToken(token1.address, token1.tokenId)

			if(token) then
				_G.tokens[token1.address .. token1.tokenId] = token

				token1.childIcon:SetBlockchainToken(_G.tokens[token1.address .. token1.tokenId])
				token1.childIcon.visibility = Visibility.FORCE_ON
		
				print("Fetched: ", _G.tokens[token1.address .. token1.tokenId].name, elapsedTime)
			end
		end)
	end

	if(token2 ~= nil) then
		pcall(function()
			local token = Blockchain.GetToken(token2.address, token2.tokenId)

			if(token) then
				_G.tokens[token2.address .. token2.tokenId] = token

				token2.childIcon:SetBlockchainToken(_G.tokens[token2.address .. token2.tokenId])
				token2.childIcon.visibility = Visibility.FORCE_ON

				print("Fetched: ", _G.tokens[token2.address .. token2.tokenId].name, elapsedTime)
			end
		end)
	end

	elapsedTime = 0
	Task.Wait(8)
	fetchingTokens = false
end

while inventory == nil do
	inventory = localPlayer:GetInventories()[1]
	Task.Wait()
end

for i, item in pairs(inventory:GetItems()) do
	InventoryChanged(inventory, i)
end

function Tick(dt)
	if(tween ~= nil) then
		tween:tween(dt)
	end

	elapsedTime = elapsedTime + dt

	if(canFetchTokens and not fetchingTokens and not tokenQueue:is_empty()) then
		Task.Spawn(LoadTokens)
	end
end

inventory.changedEvent:Connect(InventoryChanged)
Input.actionPressedEvent:Connect(on_action_pressed)

ConnectSlotEvents()

Events.Connect("inventory.open", open_inventory)
Events.Connect("FetchTokens", function()
	canFetchTokens = true
end)