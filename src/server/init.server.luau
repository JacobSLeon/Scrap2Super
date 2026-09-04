--!strict
-- Server Entrypoint for Scrap to Supercar
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent:WaitForChild("services")

local DataService = require(services:WaitForChild("DataService"))
local PlotService = require(services:WaitForChild("PlotService"))
local EconomyService = require(services:WaitForChild("EconomyService"))
local LiftService = require(services:WaitForChild("LiftService"))
local HopperService = require(services:WaitForChild("HopperService"))
local ConveyorService = require(services:WaitForChild("ConveyorService"))
local NPCService = require(services:WaitForChild("NPCService"))
local CustomizationService = require(services:WaitForChild("CustomizationService"))
local PartIndexService = require(services:WaitForChild("PartIndexService"))
local CarryingService = require(services:WaitForChild("CarryingService"))
local ScrapDisposalService = require(services:WaitForChild("ScrapDisposalService"))

print("[Server] Initializing Scrap to Supercar Server Services...")

-- Ensure Remotes folder exists
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local remotesFolder = sharedFolder:FindFirstChild("remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "remotes"
	remotesFolder.Parent = sharedFolder
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local rf = remotesFolder:FindFirstChild(name)
	if not rf then
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotesFolder
	end
	return rf :: RemoteFunction
end

local function getOrCreateBindableEvent(name: string): BindableEvent
	local be = remotesFolder:FindFirstChild(name)
	if not be then
		be = Instance.new("BindableEvent")
		be.Name = name
		be.Parent = remotesFolder
	end
	return be :: BindableEvent
end

local requestMergeRF = getOrCreateRemoteFunction("RequestMerge")
local installComponentRF = getOrCreateRemoteFunction("InstallComponent")
local removeComponentRF = getOrCreateRemoteFunction("RemoveComponent")
local claimCrateRF = getOrCreateRemoteFunction("ClaimCrate")
local withdrawHopperCrateRF = getOrCreateRemoteFunction("WithdrawHopperCrate")
local acceptNPCOfferRF = getOrCreateRemoteFunction("AcceptNPCOffer")
local updateSignboardRF = getOrCreateRemoteFunction("UpdateSignboard")
local updateGaragePaintRF = getOrCreateRemoteFunction("UpdateGaragePaint")
local requestRebirthRF = getOrCreateRemoteFunction("RequestRebirth")
local purchaseUpgradeRF = getOrCreateRemoteFunction("PurchaseUpgrade")
local getPartIndexRF = getOrCreateRemoteFunction("GetPartIndex")

local toggleLiftHighlightBE = getOrCreateBindableEvent("ToggleLiftHighlight")

-- Service Initializations (PlotService first so player plots are assigned)
DataService.Init()
PlotService.Init()
PartIndexService.Init()
CarryingService.Init()
ScrapDisposalService.Init()
EconomyService.Init()
LiftService.Init()
HopperService.Init()
ConveyorService.Init()
NPCService.Init()
CustomizationService.Init()

getPartIndexRF.OnServerInvoke = function(player: Player)
	local data = DataService.GetPlayerData(player)
	return if data then data.PartIndex else {}
end

game:GetService("Players").PlayerAdded:Connect(function(player)
	task.wait(0.5)
	ConveyorService.RenderAllWorkbenchItems(player)
	LiftService.SetupPlotLiftPrompts(player)
	LiftService.RenderAllLiftVisuals(player)
	ScrapDisposalService.SetupPlotScrapPrompts(player)
end)

-- Network Handlers
requestMergeRF.OnServerInvoke = function(player: Player, slotA: any, slotB: any)
	return false, "Workbench merging has been replaced by Part Index duplicate leveling!", nil
end

installComponentRF.OnServerInvoke = function(player: Player, liftId: any, gridSlot: any)
	if typeof(liftId) ~= "number" or typeof(gridSlot) ~= "number" then
		return false, "Invalid arguments", nil
	end
	return LiftService.InstallComponent(player, liftId, gridSlot)
end

removeComponentRF.OnServerInvoke = function(player: Player, liftId: any)
	if typeof(liftId) ~= "number" then
		return false, "Invalid argument: liftId must be number", nil
	end
	return LiftService.RemoveComponent(player, liftId)
end

claimCrateRF.OnServerInvoke = function(player: Player, crateId: any)
	if typeof(crateId) ~= "string" then
		return false, "Invalid argument: crateId must be string", nil
	end
	return ConveyorService.ClaimCrate(player, crateId)
end

withdrawHopperCrateRF.OnServerInvoke = function(player: Player, crateId: any)
	if typeof(crateId) ~= "string" then
		return false, "Invalid argument: crateId must be string", nil
	end
	return HopperService.WithdrawCrate(player, crateId)
end

acceptNPCOfferRF.OnServerInvoke = function(player: Player, npcId: any, liftId: any)
	if typeof(npcId) ~= "string" or typeof(liftId) ~= "number" then
		return false, "Invalid arguments", 0
	end
	return NPCService.AcceptOffer(player, npcId, liftId)
end

updateSignboardRF.OnServerInvoke = function(player: Player, newText: any)
	if typeof(newText) ~= "string" then
		return false, "Invalid argument: text must be string"
	end
	return CustomizationService.UpdateSignboard(player, newText)
end

updateGaragePaintRF.OnServerInvoke = function(player: Player, primary: any, secondary: any)
	if typeof(primary) ~= "table" or typeof(secondary) ~= "table" then
		return false
	end
	return CustomizationService.UpdateGaragePaint(player, primary, secondary)
end

requestRebirthRF.OnServerInvoke = function(player: Player)
	return EconomyService.Rebirth(player)
end

purchaseUpgradeRF.OnServerInvoke = function(player: Player, upgradeName: any)
	if typeof(upgradeName) ~= "string" then
		return false, "Invalid argument: upgradeName must be string", 0
	end
	return EconomyService.PurchaseUpgrade(player, upgradeName)
end

print("[Server] All Core Services & Remotes Successfully Initialized!")
