--!strict
-- HopperService: 50-Slot Overflow Crate Inventory handling
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Types = require(ReplicatedStorage.Shared.types.Types)
local DataService = require(script.Parent.DataService)

local HopperService = {}
local MAX_HOPPER_CAPACITY = 50

function HopperService.Init()
	print("[HopperService] Initialized 50-slot crate hopper service.")
end

function HopperService.StoreCrate(player: Player, rarity: Types.CrateRarity): boolean
	local data = DataService.GetPlayerData(player)
	if not data then
		return false
	end

	if not data.HasOverflowHopper then
		return false
	end

	if #data.HopperCrates >= MAX_HOPPER_CAPACITY then
		print(string.format("[HopperService] Hopper full for player %s (50/50 slots occupied)", player.Name))
		return false
	end

	local newCrate: Types.HopperCrateItem = {
		id = HttpService:GenerateGUID(false),
		rarity = rarity,
		timestamp = os.time(),
	}

	DataService.MutatePlayerData(player, function(d)
		table.insert(d.HopperCrates, newCrate)
	end)

	print(string.format("[HopperService] Stored %s crate in hopper for %s (Total: %d)", rarity, player.Name, #data.HopperCrates + 1))
	return true
end

function HopperService.WithdrawCrate(player: Player, crateId: string): (boolean, string, Types.WorkbenchItem?)
	if not DataService.TryLockPlayer(player) then
		return false, "Action in progress", nil
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		DataService.UnlockPlayer(player)
		return false, "Player data not found", nil
	end

	-- Find open workbench slot (1 to 16)
	local openSlot: number? = nil
	for i = 1, 16 do
		if data.WorkbenchItems[tostring(i)] == nil then
			openSlot = i
			break
		end
	end

	if not openSlot then
		DataService.UnlockPlayer(player)
		return false, "Workbench grid is full (16/16 slots occupied)", nil
	end

	-- Find crate in hopper
	local crateIndex: number? = nil
	local targetCrate: Types.HopperCrateItem? = nil
	for index, crate in ipairs(data.HopperCrates) do
		if crate.id == crateId then
			crateIndex = index
			targetCrate = crate
			break
		end
	end

	if not crateIndex or not targetCrate then
		DataService.UnlockPlayer(player)
		return false, "Crate not found in hopper", nil
	end

	-- Unbox crate into sub-assembly item
	local categories: { Types.SubAssemblyCategory } = { "Engine", "Chassis", "Body" }
	local randomCategory = categories[math.random(1, #categories)]
	local tierLevel = 1
	if targetCrate.rarity == "Uncommon" then tierLevel = 2 end
	if targetCrate.rarity == "Rare" then tierLevel = 3 end
	if targetCrate.rarity == "Legendary" then tierLevel = 4 end

	local newItem: Types.WorkbenchItem = {
		id = HttpService:GenerateGUID(false),
		category = randomCategory,
		tier = tierLevel,
		gridSlot = openSlot,
		state = "Workbench",
	}

	DataService.MutatePlayerData(player, function(d)
		table.remove(d.HopperCrates, crateIndex)
		d.WorkbenchItems[tostring(openSlot)] = newItem
	end)

	local ConveyorService = require(script.Parent.ConveyorService)
	ConveyorService.RenderWorkbenchItemVisual(player, openSlot, newItem)

	DataService.UnlockPlayer(player)
	print(string.format("[HopperService] Player %s unboxed %s Tier %d item from hopper to Workbench Slot %d", player.Name, randomCategory, tierLevel, openSlot))
	return true, "Success", newItem
end

return HopperService
