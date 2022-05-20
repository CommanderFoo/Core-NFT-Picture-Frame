-- This inventory has been modified to load NFTs from a players wallet.

local ASSETS = require(script:GetCustomProperty("InventoryAssets"))
local INVENTORY = script:GetCustomProperty("Inventory")
local PICTURE_FRAME = script:GetCustomProperty("PictureFrame")

local API = {}

API.PLAYERS = {}
API.INVENTORIES = {}
API.ACTIVE = {

	slot = nil,
	slotIcon = nil,
	slotCount = nil,
	slotIndex = nil,
	inventory = nil,
	hasItem = false

}

-- Server

function API.RegisterInventory(inventory)
	API.INVENTORIES[inventory.id] = inventory
end

function API.CreatePlayerInventory(player)
	local inventory = World.SpawnAsset(INVENTORY, { networkContext = NetworkContextType.NETWORKED })

	inventory:Assign(player)
	inventory.name = player.name

	API.PLAYERS[player.id] = inventory
	API.RegisterInventory(inventory)
end

function API.LoadPlayerInventory(player, root)
	local inventory = API.PLAYERS[player.id]
	local count = 0
	local tokens = nil
	local set_collection = root:GetCustomProperty("UseNFTCollection")

	Task.Wait()
	
	if(string.len(set_collection) > 1) then
		tokens = Blockchain.GetTokens({
			
			contractAddress = set_collection

		})
	else
		tokens = Blockchain.GetTokens({

			playerId = player.id

		})
	end

	if(tokens) then
		Task.Wait()
		
		local results = tokens:GetResults()

		for index, token in ipairs(results) do
			if(count == inventory.slotCount) then
				break
			end

			inventory:AddItem(PICTURE_FRAME, {

				customProperties = {

					ContractAddress = token.contractAddress,
					TokenId = token.tokenId

				}

			})

			count = count + 1
		end

		if(count < inventory.slotCount and tokens.hasMoreResults) then
			local results = tokens:GetMoreResults()

			for index, token in ipairs(results) do
				if(count == inventory.slotCount) then
					break
				end

				inventory:AddItem(PICTURE_FRAME, {

					customProperties = {

						ContractAddress = token.contractAddress,
						TokenId = token.tokenId

					}

				})

				count = count + 1
			end
		end
	end
end

function API.RemovePlayerInventory(player)
	API.INVENTORIES[API.PLAYERS[player.id].id] = nil
	API.PLAYERS[player.id]:Destroy()
	API.PLAYERS[player.id] = nil
end

function API.MoveItemHandler(fromInventoryId, toInventoryId, fromSlotIndex, toSlotIndex)
	local fromInventory = API.INVENTORIES[fromInventoryId]
	local toInventory = API.INVENTORIES[toInventoryId]

	if fromInventory ~= nil and toInventory ~= nil then
		if fromInventory == toInventory then
			if fromInventory:CanMoveFromSlot(fromSlotIndex, toSlotIndex) then
				fromInventory:MoveFromSlot(fromSlotIndex, toSlotIndex)
			end
		else
			local fromItem = fromInventory:GetItem(fromSlotIndex)
			local toItem = toInventory:GetItem(toSlotIndex)

			local fromItemAssetId = fromItem.itemAssetId
			local fromItemCount = fromItem.count

			if toItem ~= nil then
				local toItemAssetId = toItem.itemAssetId
				local toItemCount = toItem.count
				local skipFromItem = false

				if toItemAssetId == fromItemAssetId then
					local total = toItemCount + fromItemCount

					if total > toItem.maximumStackCount then
						if toItemCount == toItem.maximumStackCount then
							toItemCount = toItem.maximumStackCount
							fromItemCount = total - toItem.maximumStackCount
						else
							toItemCount = total - toItem.maximumStackCount
							fromItemCount = toItem.maximumStackCount
						end
					else
						skipFromItem = true
						fromItemCount = total
					end
				end

				fromInventory:RemoveFromSlot(fromSlotIndex)
				toInventory:RemoveFromSlot(toSlotIndex)

				if not skipFromItem then
					fromInventory:AddItem(toItemAssetId, { count = toItemCount, slot = fromSlotIndex })
				end
			else
				fromInventory:RemoveFromSlot(fromSlotIndex)
			end

			toInventory:AddItem(fromItemAssetId, { count = fromItemCount, slot = toSlotIndex })
		end
	end
end

function API.RemoveItemHandler(inventoryId, slotIndex)
	local inventory = API.INVENTORIES[inventoryId]

	if inventory ~= nil then
		if inventory:CanRemoveFromSlot(slotIndex) then
			inventory:RemoveFromSlot(slotIndex)
		end
	end
end

-- Client

function API.ClearDraggedItem(reset_inventory_item)
	if(reset_inventory_item and Object.IsValid(API.ACTIVE.slot)) then
		API.ACTIVE.slot.opacity = 1
		API.hide_proxy()
	end

	API.ACTIVE.slot = nil
	API.ACTIVE.slotIcon = nil
	API.ACTIVE.slotCount = nil
	API.ACTIVE.slotIndex = nil
	API.ACTIVE.inventory = nil
	API.ACTIVE.hasItem = false
end

function API.hide_proxy()
	API.PROXY.visibility = Visibility.FORCE_OFF
end

function API.SetDragProxy(proxy)
	API.PROXY = proxy
	API.PROXY_ICON = proxy:FindChildByName("Icon")
	API.PROXY_COUNT = API.PROXY_ICON:FindChildByName("Count")
end

function API.EnableCursor()
	UI.SetCanCursorInteractWithUI(true)
	UI.SetCursorVisible(true)
end

function API.DisableCursor()
	UI.SetCanCursorInteractWithUI(false)
	UI.SetCursorVisible(false)
end

function API.OnSlotPressedEvent(button, inventory, slot, slotIndex)
	local icon = slot:FindChildByName("Icon")
	local isHidden = icon.visibility == Visibility.FORCE_OFF and true or false
	local count = icon:FindChildByName("Count")

	-- Has item already.
	if API.ACTIVE.hasItem then
		
		-- No icon, so this is an empty slot, and dropping it into it.
		if isHidden then
			local item = API.ACTIVE.inventory:GetItem(API.ACTIVE.slotIndex)
			local address = item:GetCustomProperty("ContractAddress")
			local tokenId = item:GetCustomProperty("TokenId")

			if(_G.tokens ~= nil and _G.tokens[address .. tokenId]) then
				icon:SetBlockchainToken(_G.tokens[address .. tokenId])
			end

			icon.visibility = Visibility.FORCE_ON
			API.ACTIVE.slot.opacity = 1
			API.ACTIVE.slotIcon.visibility = Visibility.FORCE_OFF
			count.text = API.ACTIVE.slotCount.text
			API.ACTIVE.slotCount.text = "0"

		-- Slot contains existing item
		else
			local item = API.ACTIVE.inventory:GetItem(API.ACTIVE.slotIndex)
            local toItem = inventory:GetItem(slotIndex)

            if(item ~= nil and toItem ~= nil and item.itemAssetId == toItem.itemAssetId and toItem.count == toItem.maximumStackCount) then
                API.ACTIVE.slot.opacity = 1
            else
                local tmpImg = icon:GetImage()
                local tmpCount = count.text

                icon:SetImage(API.ACTIVE.slotIcon:GetImage())
                count.text = API.ACTIVE.slotCount.text
                API.ACTIVE.slotIcon:SetImage(tmpImg)
                API.ACTIVE.slotCount.text = tmpCount
                API.ACTIVE.slot.opacity = 1

                tmpCount = nil
                tmpImg = nil
            end
		end

		Events.BroadcastToServer("inventory.moveitem", API.ACTIVE.inventory.id, inventory.id, API.ACTIVE.slotIndex, slotIndex)
		Events.Broadcast("inventory.item.dropped")
		API.ClearDraggedItem()
		API.PROXY.visibility = Visibility.FORCE_OFF

	-- No item, pick up from clicked slot.
	elseif not isHidden then
		local item = inventory:GetItem(slotIndex)
		local address = item:GetCustomProperty("ContractAddress")
		local tokenId = item:GetCustomProperty("TokenId")

		API.PROXY.visibility = Visibility.FORCE_ON
		API.ACTIVE.hasItem = true

		if(_G.tokens ~= nil and _G.tokens[address .. tokenId]) then
			API.PROXY_ICON:SetBlockchainToken(_G.tokens[address .. tokenId])
		end
	
		API.PROXY_COUNT.text = tostring(inventory:GetItem(slotIndex).count)
		slot.opacity = .6
		API.ACTIVE.slot = slot
		API.ACTIVE.slotIcon = icon
		API.ACTIVE.slotCount = count
		API.ACTIVE.slotIndex = slotIndex
		API.ACTIVE.inventory = inventory
		Events.Broadcast("inventory.item.picked", inventory:GetItem(slotIndex))
	end
end

-- Shared

function API.FindLookupItemByKey(key)
	for i, dataItem in pairs(ASSETS) do
		if key == dataItem.key then
			return dataItem
		end
	end
end

function API.FindLookupItemByAssetId(item)
	for i, dataItem in pairs(ASSETS) do
		local id = CoreString.Split(dataItem.asset, ":")

		if id == item.itemAssetId then
			return dataItem
		end
	end
end

function API.RemoveItemSlotPressed()
	if API.ACTIVE.hasItem and API.ACTIVE.inventory ~= nil then
		Events.BroadcastToServer("inventory.removeitem", API.ACTIVE.inventory.id, API.ACTIVE.slotIndex)
		API.ACTIVE.slot.opacity = 1
		API.ACTIVE.slotIcon.visibility = Visibility.FORCE_OFF
		API.ClearDraggedItem()
		API.PROXY.visibility = Visibility.FORCE_OFF
	end
end

-- Events

if Environment.IsServer() then
	Events.Connect("inventory.moveitem", API.MoveItemHandler)
	Events.Connect("inventory.removeitem", API.RemoveItemHandler)
else
	Events.Connect("inventory.removeitem", API.RemoveItemSlotPressed)
end

return API