--!strict
-- Tier Config & Economic Balance for Scrap to Supercar
local Types = require(script.Parent.Parent.types.Types)

local TierBalance = {}

-- Pure Synergy multiplier for completed cars where all 3 assemblies share the same tier level
TierBalance.PURE_SYNERGY_MULTIPLIER = 1.25

-- Rebirth Formula Constant: Rep Earned = floor(sqrt(LifetimeCash / 10000))
TierBalance.REBIRTH_CASH_DENOMINATOR = 10000

-- Sub-Assembly Tier Definitions
TierBalance.TIER_DEFINITIONS: { [Types.SubAssemblyCategory]: { [number]: Types.TierDefinition } } = {
	Engine = {
		[1] = { tier = 1, name = "Spark Plug", category = "Engine", baseValue = 10 },
		[2] = { tier = 2, name = "Piston", category = "Engine", baseValue = 25 },
		[3] = { tier = 3, name = "Camshaft", category = "Engine", baseValue = 75 },
		[4] = { tier = 4, name = "Turbo", category = "Engine", baseValue = 250 },
		[5] = { tier = 5, name = "Engine Block", category = "Engine", baseValue = 1000 },
	},
	Chassis = {
		[1] = { tier = 1, name = "Brake Pad", category = "Chassis", baseValue = 10 },
		[2] = { tier = 2, name = "Coilover", category = "Chassis", baseValue = 25 },
		[3] = { tier = 3, name = "Axle", category = "Chassis", baseValue = 75 },
		[4] = { tier = 4, name = "Brake/Wheel Kit", category = "Chassis", baseValue = 250 },
		[5] = { tier = 5, name = "Rolling Chassis", category = "Chassis", baseValue = 1000 },
	},
	Body = {
		[1] = { tier = 1, name = "Primer", category = "Body", baseValue = 10 },
		[2] = { tier = 2, name = "Quarter Panel", category = "Body", baseValue = 25 },
		[3] = { tier = 3, name = "Hood/Trunk", category = "Body", baseValue = 75 },
		[4] = { tier = 4, name = "Aero Spoiler", category = "Body", baseValue = 250 },
		[5] = { tier = 5, name = "Widebody Shell", category = "Body", baseValue = 1000 },
	},
}

-- Cash/sec contribution per sub-assembly tier when mounted on a lift
TierBalance.TIER_CASH_PER_SEC: { [number]: number } = {
	[1] = 2,
	[2] = 6,
	[3] = 20,
	[4] = 70,
	[5] = 300,
}

-- Default Crate Rarity Drop Probabilities (Base)
TierBalance.CRATE_DROP_TABLE: { [Types.CrateRarity]: { dropWeight: number, defaultTier: number } } = {
	Common = { dropWeight = 70, defaultTier = 1 },
	Uncommon = { dropWeight = 20, defaultTier = 2 },
	Rare = { dropWeight = 8, defaultTier = 3 },
	Legendary = { dropWeight = 2, defaultTier = 4 },
}

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
}

-- Helper Functions
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
	torqueMultiplierLevel: number
): (number, boolean, number?)
	local eVal = if engineTier then (TierBalance.TIER_CASH_PER_SEC[engineTier] or 0) else 0
	local cVal = if chassisTier then (TierBalance.TIER_CASH_PER_SEC[chassisTier] or 0) else 0
	local bVal = if bodyTier then (TierBalance.TIER_CASH_PER_SEC[bodyTier] or 0) else 0

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

return TierBalance
