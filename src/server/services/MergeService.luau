--!strict
-- MergeService: Server-authoritative 3-item workbench part merging logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local DataService = require(script.Parent.DataService)

local MergeService = {}

function MergeService.Init()
	print("[MergeService] Initialized 3-item workbench merging service.")
end

function MergeService.MergeThreeItems(player: Player, targetSlot: number): (boolean, string, Types.WorkbenchItem?, { number }?)
	local data = DataService.GetPlayerData(player)
	if not data then
		return false, "Player data not found", nil, nil
	end

	local targetKey = tostring(targetSlot)
	local targetItem = data.WorkbenchItems[targetKey]
	if not targetItem then
		return false, "Target slot is empty", nil, nil
	end

	if targetItem.tier >= 6 then
		return false, "Item is already at maximum tier level (Tier 6)", nil, nil
	end

	-- Find all matching slots on workbench (EXACT SAME category AND EXACT SAME tier)
	local matchingSlots: { number } = {}
	for slotNum = 1, 16 do
		local item = data.WorkbenchItems[tostring(slotNum)]
		if item and item.category == targetItem.category and item.tier == targetItem.tier then
			table.insert(matchingSlots, slotNum)
		end
	end

	if #matchingSlots < 3 then
		return false, string.format("Need 3 matching %s (T%d) items to combine (currently have %d/3)", targetItem.category, targetItem.tier, #matchingSlots), nil, nil
	end

	-- Select 2 other matching slots to consume
	local clearedSlots: { number } = {}
	local count = 0
	for _, slotNum in ipairs(matchingSlots) do
		if slotNum ~= targetSlot then
			table.insert(clearedSlots, slotNum)
			count = count + 1
			if count >= 2 then break end
		end
	end

	local newTier = targetItem.tier + 1
	local mergedItem: Types.WorkbenchItem = {
		id = targetItem.id,
		category = targetItem.category,
		tier = newTier,
		gridSlot = targetSlot,
	}

	DataService.MutatePlayerData(player, function(d)
		for _, clearedSlot in ipairs(clearedSlots) do
			d.WorkbenchItems[tostring(clearedSlot)] = nil
		end
		d.WorkbenchItems[targetKey] = mergedItem
	end)

	print(string.format("[MergeService] Player %s combined 3x %s (T%d) -> 1x %s (T%d) on Slot %d", player.Name, targetItem.category, targetItem.tier, targetItem.category, newTier, targetSlot))
	return true, "Success", mergedItem, clearedSlots
end

function MergeService.MergeItems(player: Player, slotA: number, slotB: number): (boolean, string, Types.WorkbenchItem?)
	local success, msg, mergedItem = MergeService.MergeThreeItems(player, slotB)
	return success, msg, mergedItem
end

return MergeService
