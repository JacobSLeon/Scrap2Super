--!strict
-- Shared Data Types and Contracts for Scrap to Supercar

export type SubAssemblyCategory = "Engine" | "Chassis" | "Body"

export type CrateRarity = "Common" | "Uncommon" | "Rare" | "Legendary"

export type RGBColor = {
	r: number,
	g: number,
	b: number,
}

export type WorkbenchItem = {
	id: string,
	category: SubAssemblyCategory,
	tier: number,
	gridSlot: number, -- 1 to 16 for 4x4 grid
}

export type HopperCrateItem = {
	id: string,
	rarity: CrateRarity,
	timestamp: number,
}

export type MountedCar = {
	liftId: number,
	engineTier: number?,
	chassisTier: number?,
	bodyTier: number?,
	isComplete: boolean,
	isPureTier: boolean,
	pureTierLevel: number?,
	cashPerSecond: number,
}

export type RepUpgrades = {
	pneumaticLineLevel: number,
	torqueMultiplierLevel: number,
	priorityBrokerLevel: number,
}

export type PlotCustomization = {
	signText: string,
	primaryColor: RGBColor,
	secondaryColor: RGBColor,
}

export type PlayerData = {
	Cash: number,
	LifetimeCash: number,
	ReputationTokens: number,
	RebirthCount: number,
	UnlockedLifts: number,
	HasOverflowHopper: boolean,
	WorkbenchItems: { [string]: WorkbenchItem },
	HopperCrates: { HopperCrateItem },
	Lifts: { [string]: MountedCar }, -- Keyed by liftId string (e.g. "1")
	Upgrades: RepUpgrades,
	Customization: PlotCustomization,
}

export type NPCTradeOffer = {
	npcId: string,
	requestedTier: number,
	offerAmount: number,
	expiresAt: number,
	plotId: number,
}

export type TierDefinition = {
	tier: number,
	name: string,
	category: SubAssemblyCategory,
	baseValue: number,
}

return {}
