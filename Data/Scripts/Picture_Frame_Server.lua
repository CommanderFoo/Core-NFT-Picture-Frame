local ROOT = script:GetCustomProperty("Root"):WaitForObject()
local CREATOR_STORAGE_KEY = ROOT:GetCustomProperty("CreatorStorageKey")

local changes = {}
local has_changes = false

if(CREATOR_STORAGE_KEY.isAssigned) then
	local function save_to_concurrent_storage(data)
		for key, entry in pairs(changes) do
			data[key] = entry
		end

		return data
	end

	function Tick()
		Task.Wait(5)

		if not has_changes or Storage.HasPendingSetConcurrentCreatorData(CREATOR_STORAGE_KEY) then
			return
		end

		Storage.SetConcurrentCreatorData(CREATOR_STORAGE_KEY, save_to_concurrent_storage)
		
		changes = {}
		has_changes = false
	end

	Storage.ConnectToConcurrentCreatorDataChanged(CREATOR_STORAGE_KEY, function(key, data)
		for _, player in ipairs(Game.GetPlayers()) do
			player:SetPrivateNetworkedData("frames", data)
		end
	end)

	Game.playerJoinedEvent:Connect(function(player)
		local data = Storage.GetConcurrentCreatorData(CREATOR_STORAGE_KEY)

		player:SetPrivateNetworkedData("frames", data)
	end)
end

local function save_to_storage(player, address, token_id, frame_id)
	local key = CoreString.Split(frame_id, ":")

	changes[key] = { player, address, token_id}
	has_changes = true
end

Events.Connect("frame.set", function(address, token_id, frame, player_name)
	save_to_storage(player_name, address, token_id, frame:GetObject().parent.id)

	for _, player in ipairs(Game.GetPlayers()) do
		if(player.name ~= player_name) then
			Events.BroadcastToPlayer(player, "frame.set", address, token_id, frame)
		end
	end
end)