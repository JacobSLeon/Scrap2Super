--!strict
-- DataService: Server-authoritative data manager & session loader
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)

local DataService = {}
local profiles: { [Player]: Types.PlayerData } = {}

local DEFAULT_PROFILE: Types.PlayerData = {
	Cash = 100,
	LifetimeCash = 100,
	ReputationTokens = 0,
	RebirthCount = 0,
	UnlockedLifts = 1,
	HasOverflowHopper = false,
	WorkbenchItems = {},
	HopperCrates = {},
	Lifts = {
		["1"] = {
			liftId = 1,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		},
	},
	Upgrades = {
		pneumaticLineLevel = 0,
		torqueMultiplierLevel = 0,
		priorityBrokerLevel = 0,
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
		print(string.format("[DataService] Saved and cleared data profile for player %s", player.Name))
	end)
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
