--!strict
-- MergeService: Server-authoritative 4x4 workbench part merging logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local DataService = require(script.Parent.DataService)

local MergeService = {}

function MergeService.Init()
	print("[MergeService] Initialized workbench merging listener.")
end

function MergeService.MergeItems(player: Player, slotA: number, slotB: number): (boolean, string, Types.WorkbenchItem?)
	if slotA == slotB then
		return false, "Cannot merge item with itself", nil
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		return false, "Player data not found", nil
	end

	local keyA = tostring(slotA)
	local keyB = tostring(slotB)

	local itemA = data.WorkbenchItems[keyA]
	local itemB = data.WorkbenchItems[keyB]

	if not itemA or not itemB then
		return false, "One or both slots are empty", nil
	end

	if itemA.category ~= itemB.category then
		return false, "Items must belong to the same category to merge", nil
	end

	if itemA.tier ~= itemB.tier then
		return false, "Items must be of the same tier level to merge", nil
	end

	if itemB.tier >= 5 then
		return false, "Item is already at maximum tier level (Tier 5)", nil
	end

	local newTier = itemB.tier + 1
	local mergedItem: Types.WorkbenchItem = {
		id = itemB.id,
		category = itemB.category,
		tier = newTier,
		gridSlot = slotB,
	}

	DataService.MutatePlayerData(player, function(d)
		d.WorkbenchItems[keyA] = nil
		d.WorkbenchItems[keyB] = mergedItem
	end)

	print(string.format("[MergeService] Player %s merged %s (Slot %d + %d -> Tier %d)", player.Name, itemA.category, slotA, slotB, newTier))
	return true, "Success", mergedItem
end

return MergeService
