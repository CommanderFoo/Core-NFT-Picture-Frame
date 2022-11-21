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
				slot = slot

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

local function LoadToken()
	local current = tokenQueue:pop()

	fetchingTokens = true

	if(current ~= nil) then
		local status, err = pcall(function()
			local token = Blockchain.GetToken(current.address, current.tokenId)

			if(token) then
				_G.tokens[current.address .. current.tokenId] = token

				current.childIcon:SetBlockchainToken(token)
				current.childIcon.visibility = Visibility.FORCE_ON

				print(string.format("Success: Token %s for slot %s. Time took %s", current.tokenId, current.slot, elapsedTime))
			end
		end)

		if(not status) then
			local _, e = CoreString.Split(err, "failed:")

			print(string.format("Fail: Token %s for slot %s. Time took %s. Error: %s", current.tokenId, current.slot, elapsedTime, e))
		end
	end

	elapsedTime = 0
	Task.Wait(4)
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
		Task.Spawn(LoadToken)
	end
end

inventory.changedEvent:Connect(InventoryChanged)
Input.actionPressedEvent:Connect(on_action_pressed)

ConnectSlotEvents()

Events.Connect("inventory.open", open_inventory)
Events.Connect("FetchTokens", function()
	Task.Wait()
	canFetchTokens = true
end)