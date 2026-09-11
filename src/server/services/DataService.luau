--!strict
-- DataService: Server-authoritative data manager & session loader
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)

local DataService = {}
local profiles: { [Player]: Types.PlayerData } = {}
local playerActionLocks: { [Player]: boolean } = {}

local function createDefaultPartIndex(): { [string]: Types.PartIndexEntry }
	local index = {}
	local categories: { Types.SubAssemblyCategory } = { "Engine", "Chassis", "Body" }
	for _, cat in ipairs(categories) do
		for tier = 1, 6 do
			local key = string.format("%s_T%d", cat, tier)
			index[key] = {
				category = cat,
				tier = tier,
				level = 1,
				duplicatesCount = 0,
				discovered = false,
			}
		end
	end
	return index
end

local DEFAULT_PROFILE: Types.PlayerData = {
	Cash = 1000,
	LifetimeCash = 1000,
	ReputationTokens = 0,
	RebirthCount = 0,
	UnlockedLifts = 6,
	HasOverflowHopper = true,
	WorkbenchItems = {},
	HopperCrates = {},
	Lifts = {
		["1"] = { liftId = 1, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
		["2"] = { liftId = 2, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
		["3"] = { liftId = 3, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
		["4"] = { liftId = 4, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
		["5"] = { liftId = 5, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
		["6"] = { liftId = 6, engineTier = nil, chassisTier = nil, bodyTier = nil, isComplete = false, isPureTier = false, pureTierLevel = nil, cashPerSecond = 0 },
	},
	PartIndex = createDefaultPartIndex(),
	Upgrades = {
		pneumaticLineLevel = 0,
		torqueMultiplierLevel = 0,
		priorityBrokerLevel = 0,
		conveyorSpeedLevel = 0,
	},
	Customization = {
		signText = "Chop Shop",
		primaryColor = { r = 0.2, g = 0.2, b = 0.2 },
		secondaryColor = { r = 0.9, g = 0.6, b = 0.1 },
	},
}

local function deepCopy<T>(t: T): T
	if typeof(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t :: any) do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function onPlayerAdded(player: Player)
	if not profiles[player] then
		profiles[player] = deepCopy(DEFAULT_PROFILE)
		print(string.format("[DataService] Successfully initialized profile for player %s (UserId: %d)", player.Name, player.UserId))
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	
	-- Handle players already connected prior to DataService initialization (fixes Studio Playtest race condition)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
		playerActionLocks[player] = nil
		print(string.format("[DataService] Saved and cleared data profile for player %s", player.Name))
	end)
end

function DataService.TryLockPlayer(player: Player): boolean
	if playerActionLocks[player] then
		return false
	end
	playerActionLocks[player] = true
	return true
end

function DataService.UnlockPlayer(player: Player)
	playerActionLocks[player] = nil
end

function DataService.GetPlayerData(player: Player): Types.PlayerData?
	return profiles[player]
end

function DataService.MutatePlayerData(player: Player, mutator: (data: Types.PlayerData) -> ()): boolean
	local data = profiles[player]
	if not data then
		warn(string.format("[DataService] Attempted mutation on missing profile for %s", player.Name))
		return false
	end
	mutator(data)
	return true
end

return DataService
