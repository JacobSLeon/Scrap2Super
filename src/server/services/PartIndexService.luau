--!strict
-- PartIndexService: Server-authoritative Part Index manager & Leveling logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local DataService = require(script.Parent.DataService)

local PartIndexService = {}
local DUPLICATES_PER_LEVEL = 3

function PartIndexService.Init()
	print("[PartIndexService] Initialized Part Index & Leveling Service.")
end

function PartIndexService.RecordPartAcquired(player: Player, category: Types.SubAssemblyCategory, tier: number): (boolean, Types.PartIndexEntry?)
	local data = DataService.GetPlayerData(player)
	if not data then return false, nil end

	local key = string.format("%s_T%d", category, tier)
	local entry = data.PartIndex and data.PartIndex[key]
	if not entry then
		entry = {
			category = category,
			tier = tier,
			level = 1,
			duplicatesCount = 0,
			discovered = false,
		}
	end

	entry.discovered = true
	entry.duplicatesCount = entry.duplicatesCount + 1

	local leveledUp = false
	if entry.duplicatesCount >= DUPLICATES_PER_LEVEL then
		entry.level = entry.level + 1
		entry.duplicatesCount = 0
		leveledUp = true
		print(string.format("[PartIndexService] Player %s leveled up %s Tier %d to Level %d!", player.Name, category, tier, entry.level))
	end

	DataService.MutatePlayerData(player, function(d)
		if not d.PartIndex then d.PartIndex = {} end
		d.PartIndex[key] = entry
	end)

	return leveledUp, entry
end

function PartIndexService.GetPartLevel(player: Player, category: Types.SubAssemblyCategory, tier: number): number
	local data = DataService.GetPlayerData(player)
	if not data or not data.PartIndex then return 1 end

	local key = string.format("%s_T%d", category, tier)
	local entry = data.PartIndex[key]
	return if entry then entry.level else 1
end

function PartIndexService.GetLevelMultiplier(level: number): number
	return 1 + ((level - 1) * 0.25)
end

return PartIndexService
