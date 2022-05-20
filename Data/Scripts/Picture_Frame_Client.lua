local INVENTORY_API = require(script:GetCustomProperty("InventoryAPI"))

local ROOT = script:GetCustomProperty("Root"):WaitForObject()
local PICTURE_FRAMES = ROOT:GetCustomProperty("PictureFrames"):WaitForObject()

while(_G.tokens == nil) do
	Task.Wait()
end

local current_frame = nil

local function clear_outline()
	if(current_frame ~= nil) then
		current_frame.parent:FindDescendantByName("Outline"):SetSmartProperty("Enabled", false)
	end
end

local function show_outline()
	if(current_frame ~= nil) then
		current_frame.parent:FindDescendantByName("Outline"):SetSmartProperty("Enabled", true)
	end
end

function Tick()
	local forward = Game.GetLocalPlayer():GetViewWorldRotation() * Vector3.FORWARD
	local start = Game.GetLocalPlayer():GetViewWorldPosition()
	local fin = start + forward * 2000
	local hit = World.Boxcast(start, fin, Vector3.New(100, 100, 100), {
		
		ignorePlayers = true
	
	})

	if(hit) then
		--CoreDebug.DrawBox(hit:GetImpactPosition(), Vector3.New(100, 100, 100))

		if(hit.other.name == "Frame") then
			if(current_frame ~= nil and current_frame ~= hit.other) then
				clear_outline()
			else
				current_frame = hit.other
				show_outline()
			end
		elseif(current_frame ~= nil) then
			clear_outline()
			current_frame = nil
		end
	end
end

local function on_action_pressed(player, action)
	if(action == "Shoot" and current_frame ~= nil) then
		if(INVENTORY_API.ACTIVE.hasItem) then
			local item = INVENTORY_API.ACTIVE.inventory:GetItem(INVENTORY_API.ACTIVE.slotIndex)
			local address = item:GetCustomProperty("ContractAddress")
			local tokenId = item:GetCustomProperty("TokenId")

			current_frame.parent:FindDescendantByType("UIContainer").visibility = Visibility.INHERIT
	
			if(_G.tokens ~= nil and _G.tokens[address .. tokenId]) then
				current_frame.parent:FindDescendantByName("Picture"):SetBlockchainToken(_G.tokens[address .. tokenId])
				current_frame.parent:FindDescendantByName("Info").text = _G.tokens[address .. tokenId].name
				Events.BroadcastToServer("frame.set", address, tokenId, current_frame:GetReference(), player.name)
			end

			INVENTORY_API.RemoveItemSlotPressed()
		else
			Events.Broadcast("inventory.open")
		end
	end
end

local function update_frame(key, entry)
	for index, frame in ipairs(PICTURE_FRAMES:GetChildren()) do
		if(string.find(frame.id, key)) then
			Task.Spawn(function()
				local token = Blockchain.GetToken(entry[2], entry[3])

				if(token) then
					_G.tokens[entry[2] .. entry[3]] = token
					frame:FindDescendantByType("UIContainer").visibility = Visibility.INHERIT
					frame:FindDescendantByName("Picture"):SetBlockchainToken(token)
					frame:FindDescendantByName("Info").text = token.name
				end
			end) 
		end
	end
end

local function update_frames(player, key)
	if(key == "frames") then
		local data = player:GetPrivateNetworkedData(key)

		if(data ~= nil) then
			for key, entry in pairs(data) do
				update_frame(key, entry)
			end
		end
	end
end

Input.actionPressedEvent:Connect(on_action_pressed)

Events.Connect("frame.set", function(address, tokenId, frame)
	if(_G.tokens ~= nil and _G.tokens[address .. tokenId]) then
		frame:GetObject().parent:FindDescendantByType("UIContainer").visibility = Visibility.INHERIT
		frame:GetObject().parent:FindDescendantByName("Picture"):SetBlockchainToken(_G.tokens[address .. tokenId])
		frame:GetObject().parent:FindDescendantByName("Info").text = _G.tokens[address .. tokenId].name
	end
end)

Game.GetLocalPlayer().privateNetworkedDataChangedEvent:Connect(update_frames)
update_frames(Game.GetLocalPlayer(), "frames")