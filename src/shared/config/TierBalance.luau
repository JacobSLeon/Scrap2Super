--!strict
-- Tier Config & Economic Balance for Scrap to Supercar
local Types = require(script.Parent.Parent.types.Types)

local TierBalance = {}

-- Pure Synergy multiplier for completed cars where all 3 assemblies share the same tier level
TierBalance.PURE_SYNERGY_MULTIPLIER = 1.25

-- Rebirth Formula Constant: Rep Earned = floor(sqrt(LifetimeCash / 10000))
TierBalance.REBIRTH_CASH_DENOMINATOR = 10000

-- Sub-Assembly Tier Definitions
TierBalance.TIER_DEFINITIONS = {
	Engine = {
		[1] = { tier = 1, name = "Spark Plug", category = "Engine", baseValue = 10 },
		[2] = { tier = 2, name = "Piston", category = "Engine", baseValue = 25 },
		[3] = { tier = 3, name = "Camshaft", category = "Engine", baseValue = 75 },
		[4] = { tier = 4, name = "Turbo", category = "Engine", baseValue = 250 },
		[5] = { tier = 5, name = "Engine Block", category = "Engine", baseValue = 1000 },
		[6] = { tier = 6, name = "Hyper V8 Engine", category = "Engine", baseValue = 4000 },
	},
	Chassis = {
		[1] = { tier = 1, name = "Brake Pad", category = "Chassis", baseValue = 10 },
		[2] = { tier = 2, name = "Coilover", category = "Chassis", baseValue = 25 },
		[3] = { tier = 3, name = "Axle", category = "Chassis", baseValue = 75 },
		[4] = { tier = 4, name = "Brake/Wheel Kit", category = "Chassis", baseValue = 250 },
		[5] = { tier = 5, name = "Rolling Chassis", category = "Chassis", baseValue = 1000 },
		[6] = { tier = 6, name = "Carbon Monocoque", category = "Chassis", baseValue = 4000 },
	},
	Body = {
		[1] = { tier = 1, name = "Primer", category = "Body", baseValue = 10 },
		[2] = { tier = 2, name = "Quarter Panel", category = "Body", baseValue = 25 },
		[3] = { tier = 3, name = "Hood/Trunk", category = "Body", baseValue = 75 },
		[4] = { tier = 4, name = "Aero Spoiler", category = "Body", baseValue = 250 },
		[5] = { tier = 5, name = "Widebody Shell", category = "Body", baseValue = 1000 },
		[6] = { tier = 6, name = "Hypercar Shell", category = "Body", baseValue = 4000 },
	},
}

-- Cash/sec contribution per sub-assembly tier when mounted on a lift
TierBalance.TIER_CASH_PER_SEC = {
	[1] = 2,
	[2] = 6,
	[3] = 20,
	[4] = 70,
	[5] = 300,
	[6] = 1200,
}

-- Default Crate Rarity Drop Probabilities (Base)
TierBalance.CRATE_DROP_TABLE = {
	Common = { dropWeight = 70, defaultTier = 1 },
	Uncommon = { dropWeight = 20, defaultTier = 2 },
	Rare = { dropWeight = 8, defaultTier = 3 },
	Legendary = { dropWeight = 2, defaultTier = 4 },
}

-- Base Conveyor Belt Spawning Pacing (3.75s base -> 1.5s max level)
TierBalance.BASE_CONVEYOR_SPAWN_INTERVAL = 3.75
TierBalance.MIN_CONVEYOR_SPAWN_INTERVAL = 1.5

-- Black Market Rep Tree Upgrades
TierBalance.UPGRADES = {
	PneumaticLine = {
		maxLevel = 5,
		costPerLevel = 2, -- Rep Tokens
		chanceBonusPerLevel = 0.05, -- +5% higher-tier crate drop chance per level
	},
	TorqueMultiplier = {
		maxLevel = 5,
		costPerLevel = 3, -- Rep Tokens
		incomeBonusPerLevel = 0.10, -- +10% global passive income boost
	},
	PriorityBroker = {
		maxLevel = 5,
		costPerLevel = 4, -- Rep Tokens
		arrivalSpeedBonusPerLevel = 0.20, -- 20% faster NPC arrival
		payoutBonusPerLevel = 0.15, -- +15% trade payout values
	},
	ConveyorSpeed = {
		maxLevel = 5,
		costPerLevel = 2, -- Rep Tokens
		speedReductionPerLevel = 0.45, -- Decreases interval from 3.75s by 0.45s per level down to 1.5s
	},
}

-- Helper Functions
function TierBalance.CalculateConveyorSpawnInterval(upgradeLevel: number): number
	local level = math.clamp(upgradeLevel or 0, 0, 5)
	local interval = TierBalance.BASE_CONVEYOR_SPAWN_INTERVAL - (level * TierBalance.UPGRADES.ConveyorSpeed.speedReductionPerLevel)
	return math.max(TierBalance.MIN_CONVEYOR_SPAWN_INTERVAL, interval)
end
function TierBalance.CalculateRepEarned(lifetimeCash: number): number
	if lifetimeCash < TierBalance.REBIRTH_CASH_DENOMINATOR then
		return 0
	end
	return math.floor(math.sqrt(lifetimeCash / TierBalance.REBIRTH_CASH_DENOMINATOR))
end

function TierBalance.CalculateCarCashPerSec(
	engineTier: number?,
	chassisTier: number?,
	bodyTier: number?,
	torqueMultiplierLevel: number,
	engineLevel: number?,
	chassisLevel: number?,
	bodyLevel: number?
): (number, boolean, number?)
	local eL = engineLevel or 1
	local cL = chassisLevel or 1
	local bL = bodyLevel or 1

	local eMult = 1 + ((eL - 1) * 0.25)
	local cMult = 1 + ((cL - 1) * 0.25)
	local bMult = 1 + ((bL - 1) * 0.25)

	local eVal = if engineTier then ((TierBalance.TIER_CASH_PER_SEC[engineTier] or 0) * eMult) else 0
	local cVal = if chassisTier then ((TierBalance.TIER_CASH_PER_SEC[chassisTier] or 0) * cMult) else 0
	local bVal = if bodyTier then ((TierBalance.TIER_CASH_PER_SEC[bodyTier] or 0) * bMult) else 0

	local isComplete = (engineTier ~= nil) and (chassisTier ~= nil) and (bodyTier ~= nil)
	local isPure = isComplete and (engineTier == chassisTier) and (chassisTier == bodyTier)
	local pureTierLevel = if isPure then engineTier else nil

	local baseTotal = eVal + cVal + bVal
	if isPure then
		baseTotal = baseTotal * TierBalance.PURE_SYNERGY_MULTIPLIER
	end

	-- Apply Torque Multiplier Rep upgrade bonus (+10% per level)
	local globalMultiplier = 1 + (torqueMultiplierLevel * TierBalance.UPGRADES.TorqueMultiplier.incomeBonusPerLevel)
	local finalCashPerSec = math.floor(baseTotal * globalMultiplier)

	return finalCashPerSec, isPure, pureTierLevel
end

function TierBalance.CalculateScrapPayout(category: Types.SubAssemblyCategory, tier: number, level: number?): number
	local defs = TierBalance.TIER_DEFINITIONS[category]
	local base = if defs and defs[tier] then defs[tier].baseValue else 10
	local l = level or 1
	local levelMult = 1 + ((l - 1) * 0.25)
	return math.floor(base * 1.5 * levelMult)
end

return TierBalance
