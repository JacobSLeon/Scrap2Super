--!strict
-- LiftService: Mounting sub-assemblies onto hydraulic lifts & vehicle completion
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local PartMeshConfig = require(ReplicatedStorage.Shared.config.PartMeshConfig)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local PartIndexService = require(script.Parent.PartIndexService)

local LiftService = {}

function LiftService.Init()
	print("[LiftService] Initialized hydraulic lift assembly service with 3D model rendering.")
end

local function getLiftBayPart(plotFolder: Folder, liftId: number): Part?
	local hydraulicFolder = plotFolder:FindFirstChild("HydraulicLifts")
	if hydraulicFolder then
		local bay = hydraulicFolder:FindFirstChild("LiftBay_" .. tostring(liftId)) :: Part?
		if bay then return bay end
		local bayAlt = hydraulicFolder:FindFirstChild("Lift_" .. tostring(liftId)) :: Part?
		if bayAlt then return bayAlt end
	end
	return (plotFolder:FindFirstChild("Lift_" .. tostring(liftId)) or plotFolder:FindFirstChild("LiftBay_" .. tostring(liftId))) :: Part?
end

function LiftService.RenderLiftCarVisual(player: Player, liftId: number, car: Types.MountedCar)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local liftBay = getLiftBayPart(plotFolder, liftId)
	if not liftBay then return end

	local existingMounted = liftBay:FindFirstChild("MountedCarVisual")
	if existingMounted then existingMounted:Destroy() end

	local mountedFolder = Instance.new("Folder")
	mountedFolder.Name = "MountedCarVisual"
	mountedFolder.Parent = liftBay

	local baseCF = liftBay.CFrame * CFrame.new(0, 4.2, 0)

	if car.isComplete then
		local carTier = car.pureTierLevel or math.max(car.engineTier or 1, car.chassisTier or 1, car.bodyTier or 1)
		local completeVisual = PartMeshConfig.CreateCompleteCarVisualInstance(carTier, baseCF)
		completeVisual.Name = "CompleteCarMesh"
		completeVisual.Parent = mountedFolder
	else
		if car.chassisTier then
			local chassisVisual = PartMeshConfig.CreateLiftVisualInstance("Chassis", car.chassisTier, baseCF)
			chassisVisual.Name = "ChassisMesh"
			chassisVisual.Parent = mountedFolder
		end

		if car.engineTier then
			local engineVisual = PartMeshConfig.CreateLiftVisualInstance("Engine", car.engineTier, baseCF)
			engineVisual.Name = "EngineMesh"
			engineVisual.Parent = mountedFolder
		end

		if car.bodyTier then
			local bodyVisual = PartMeshConfig.CreateLiftVisualInstance("Body", car.bodyTier, baseCF)
			bodyVisual.Name = "BodyMesh"
			bodyVisual.Parent = mountedFolder
		end
	end

	-- Add Status Billboard Label
	local existingBb = liftBay:FindFirstChild("LiftStatusBillboard")
	if existingBb then existingBb:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LiftStatusBillboard"
	billboard.Size = UDim2.new(0, 180, 0, 45)
	billboard.StudsOffset = Vector3.new(0, 5.0, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 35
	billboard.Adornee = liftBay
	billboard.Parent = liftBay

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = false
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold

	if car.isComplete then
		label.Text = string.format("LIFT #%d [COMPLETE]\n+$%d/s", liftId, car.cashPerSecond)
		label.TextColor3 = Color3.fromRGB(0, 255, 150)
	else
		local statusStr = string.format("LIFT #%d\nEngine: %s | Chassis: %s | Body: %s",
			liftId,
			if car.engineTier then "T" .. car.engineTier else "--",
			if car.chassisTier then "T" .. car.chassisTier else "--",
			if car.bodyTier then "T" .. car.bodyTier else "--"
		)
		label.Text = statusStr
		label.TextColor3 = Color3.fromRGB(255, 210, 60)
	end
	label.Parent = billboard
end

local function getOrCreateAttachment(parentPart: BasePart, name: string, offset: Vector3): Attachment
	local att = parentPart:FindFirstChild(name) :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = name
		att.Position = offset
		att.Parent = parentPart
	else
		att.Position = offset
	end
	return att
end

function LiftService.SetupPlotLiftPrompts(player: Player)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local CarryingService = require(script.Parent.CarryingService)

	for liftId = 1, 6 do
		local liftBay = getLiftBayPart(plotFolder, liftId)
		if liftBay then
			-- Attachment offsets to separate 3D prompt positions
			local engineAtt = getOrCreateAttachment(liftBay, "EngineAtt", Vector3.new(-2.5, 3.5, -2.5))
			local chassisAtt = getOrCreateAttachment(liftBay, "ChassisAtt", Vector3.new(0, 1.5, 0))
			local bodyAtt = getOrCreateAttachment(liftBay, "BodyAtt", Vector3.new(2.5, 3.5, 2.5))

			-- Clear existing prompts from liftBay and attachments
			for _, child in ipairs(liftBay:GetChildren()) do
				if child:IsA("ProximityPrompt") then child:Destroy() end
			end
			for _, att in ipairs({ engineAtt, chassisAtt, bodyAtt }) do
				for _, child in ipairs(att:GetChildren()) do
					if child:IsA("ProximityPrompt") then child:Destroy() end
				end
			end

			local pData = DataService.GetPlayerData(player)
			if not pData then continue end

			if liftId > pData.UnlockedLifts then
				continue
			end

			local car = pData.Lifts[tostring(liftId)]
			local isHolding = CarryingService.IsHolding(player)
			local heldCat, heldTier = CarryingService.GetHeldItem(player)

			if isHolding and heldCat and heldTier then
				-- Context-aware mounting prompt: ONLY attach prompt to target attachment if that slot is empty
				local targetAtt: Attachment? = nil
				local actionText = ""

				if heldCat == "Engine" and (not car or car.engineTier == nil) then
					targetAtt = engineAtt
					actionText = string.format("Install Engine (T%d)", heldTier)
				elseif heldCat == "Chassis" and (not car or car.chassisTier == nil) then
					targetAtt = chassisAtt
					actionText = string.format("Install Chassis (T%d)", heldTier)
				elseif heldCat == "Body" and (not car or car.bodyTier == nil) then
					targetAtt = bodyAtt
					actionText = string.format("Install Body (T%d)", heldTier)
				end

				if targetAtt then
					local mountPrompt = Instance.new("ProximityPrompt")
					mountPrompt.Name = "MountPrompt_" .. heldCat
					mountPrompt.KeyboardKeyCode = Enum.KeyCode.E
					mountPrompt.HoldDuration = 0
					mountPrompt.RequiresLineOfSight = false
					mountPrompt.MaxActivationDistance = 30
					mountPrompt.ObjectText = string.format("Lift #%d", liftId)
					mountPrompt.ActionText = actionText
					mountPrompt.Parent = targetAtt

					mountPrompt.Triggered:Connect(function(triggeringPlayer)
						if triggeringPlayer ~= player then return end
						local success, msg = LiftService.InstallHeldComponent(player, liftId)
						if not success then
							print(string.format("[LiftService] Cannot mount held part to Lift #%d: %s", liftId, msg))
						end
					end)
				end
			else
				-- Hands are empty: Render removal prompts ONLY for currently mounted sub-assemblies
				if car then
					-- Engine Removal [E]
					if car.engineTier then
						local ePrompt = Instance.new("ProximityPrompt")
						ePrompt.Name = "RemovePrompt_Engine"
						ePrompt.KeyboardKeyCode = Enum.KeyCode.E
						ePrompt.ActionText = string.format("Pick Up Engine (T%d)", car.engineTier)
						ePrompt.ObjectText = string.format("Lift #%d", liftId)
						ePrompt.HoldDuration = 0
						ePrompt.RequiresLineOfSight = false
						ePrompt.MaxActivationDistance = 30
						ePrompt.Parent = engineAtt

						ePrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Engine")
						end)
					end

					-- Chassis Removal [E]
					if car.chassisTier then
						local cPrompt = Instance.new("ProximityPrompt")
						cPrompt.Name = "RemovePrompt_Chassis"
						cPrompt.KeyboardKeyCode = Enum.KeyCode.E
						cPrompt.ActionText = string.format("Pick Up Chassis (T%d)", car.chassisTier)
						cPrompt.ObjectText = string.format("Lift #%d", liftId)
						cPrompt.HoldDuration = 0
						cPrompt.RequiresLineOfSight = false
						cPrompt.MaxActivationDistance = 30
						cPrompt.Parent = chassisAtt

						cPrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Chassis")
						end)
					end

					-- Body Removal [E]
					if car.bodyTier then
						local bPrompt = Instance.new("ProximityPrompt")
						bPrompt.Name = "RemovePrompt_Body"
						bPrompt.KeyboardKeyCode = Enum.KeyCode.E
						bPrompt.ActionText = string.format("Pick Up Body (T%d)", car.bodyTier)
						bPrompt.ObjectText = string.format("Lift #%d", liftId)
						bPrompt.HoldDuration = 0
						bPrompt.RequiresLineOfSight = false
						bPrompt.MaxActivationDistance = 30
						bPrompt.Parent = bodyAtt

						bPrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Body")

						bPrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Body")
						end)
					end
				end
			end
		end
	end
end

function LiftService.InstallHeldComponent(player: Player, liftId: number): (boolean, string)
	if not DataService.TryLockPlayer(player) then
		return false, "Action in progress"
	end

	local CarryingService = require(script.Parent.CarryingService)
	local category, tier = CarryingService.GetHeldItem(player)
	if not category or not tier then
		DataService.UnlockPlayer(player)
		return false, "Not holding any part"
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		DataService.UnlockPlayer(player)
		return false, "Player data not found"
	end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		car = {
			liftId = liftId,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			engineState = nil,
			chassisState = nil,
			bodyState = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		}
	end

	if category == "Engine" and car.engineTier ~= nil then DataService.UnlockPlayer(player) return false, "Engine already installed" end
	if category == "Chassis" and car.chassisTier ~= nil then DataService.UnlockPlayer(player) return false, "Chassis already installed" end
	if category == "Body" and car.bodyTier ~= nil then DataService.UnlockPlayer(player) return false, "Body already installed" end

	if category == "Engine" then car.engineTier = tier car.engineState = "Mounted" end
	if category == "Chassis" then car.chassisTier = tier car.chassisState = "Mounted" end
	if category == "Body" then car.bodyTier = tier car.bodyState = "Mounted" end

	local eL = if car.engineTier then PartIndexService.GetPartLevel(player, "Engine", car.engineTier) else 1
	local cL = if car.chassisTier then PartIndexService.GetPartLevel(player, "Chassis", car.chassisTier) else 1
	local bL = if car.bodyTier then PartIndexService.GetPartLevel(player, "Body", car.bodyTier) else 1

	local cashPerSec, isPure, pureLevel = TierBalance.CalculateCarCashPerSec(
		car.engineTier,
		car.chassisTier,
		car.bodyTier,
		data.Upgrades.torqueMultiplierLevel,
		eL,
		cL,
		bL
	)

	car.isComplete = (car.engineTier ~= nil) and (car.chassisTier ~= nil) and (car.bodyTier ~= nil)
	car.isPureTier = isPure
	car.pureTierLevel = pureLevel
	car.cashPerSecond = cashPerSec

	CarryingService.DropHeldItem(player, true)

	DataService.MutatePlayerData(player, function(d)
		d.Lifts[liftKey] = car
	end)

	LiftService.RenderLiftCarVisual(player, liftId, car)
	LiftService.SetupPlotLiftPrompts(player)

	local ConveyorService = require(script.Parent.ConveyorService)
	ConveyorService.RenderAllWorkbenchItems(player)

	DataService.UnlockPlayer(player)
	print(string.format("[LiftService] Player %s mounted held %s T%d onto Lift #%d", player.Name, category, tier, liftId))
	return true, "Success"
end

function LiftService.RemoveSpecificComponent(player: Player, liftId: number, category: Types.SubAssemblyCategory): (boolean, string)
	if not DataService.TryLockPlayer(player) then
		return false, "Action in progress"
	end

	local CarryingService = require(script.Parent.CarryingService)
	if CarryingService.IsHolding(player) then
		DataService.UnlockPlayer(player)
		return false, "Player is already holding a part! Place or mount it first."
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		DataService.UnlockPlayer(player)
		return false, "Player data not found"
	end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		DataService.UnlockPlayer(player)
		return false, "No car on this lift"
	end

	local tierToRemove: number? = nil
	if category == "Engine" then tierToRemove = car.engineTier end
	if category == "Chassis" then tierToRemove = car.chassisTier end
	if category == "Body" then tierToRemove = car.bodyTier end

	if not tierToRemove then
		DataService.UnlockPlayer(player)
		return false, string.format("No %s installed on Lift #%d", category, liftId)
	end

	-- Unmount target category
	if category == "Engine" then car.engineTier = nil car.engineState = nil end
	if category == "Chassis" then car.chassisTier = nil car.chassisState = nil end
	if category == "Body" then car.bodyTier = nil car.bodyState = nil end

	local eL = if car.engineTier then PartIndexService.GetPartLevel(player, "Engine", car.engineTier) else 1
	local cL = if car.chassisTier then PartIndexService.GetPartLevel(player, "Chassis", car.chassisTier) else 1
	local bL = if car.bodyTier then PartIndexService.GetPartLevel(player, "Body", car.bodyTier) else 1

	local cashPerSec, isPure, pureLevel = TierBalance.CalculateCarCashPerSec(
		car.engineTier,
		car.chassisTier,
		car.bodyTier,
		data.Upgrades.torqueMultiplierLevel,
		eL,
		cL,
		bL
	)

	car.isComplete = (car.engineTier ~= nil) and (car.chassisTier ~= nil) and (car.bodyTier ~= nil)
	car.isPureTier = isPure
	car.pureTierLevel = pureLevel
	car.cashPerSecond = cashPerSec

	local isEmpty = (car.engineTier == nil) and (car.chassisTier == nil) and (car.bodyTier == nil)

	DataService.MutatePlayerData(player, function(d)
		if isEmpty then
			d.Lifts[liftKey] = nil
		else
			d.Lifts[liftKey] = car
		end
	end)

	-- Pick up part into player's hands to carry
	CarryingService.PickUpItem(player, category, tierToRemove)

	if isEmpty then
		local plotFolder = PlotService.GetPlayerPlotFolder(player)
		if plotFolder then
			local liftBay = getLiftBayPart(plotFolder, liftId)
			if liftBay then
				local existingMounted = liftBay:FindFirstChild("MountedCarVisual")
				if existingMounted then existingMounted:Destroy() end
				local existingBb = liftBay:FindFirstChild("LiftStatusBillboard")
				if existingBb then existingBb:Destroy() end
			end
		end
	else
		LiftService.RenderLiftCarVisual(player, liftId, car)
	end

	LiftService.SetupPlotLiftPrompts(player)

	local ConveyorService = require(script.Parent.ConveyorService)
	ConveyorService.RenderAllWorkbenchItems(player)

	DataService.UnlockPlayer(player)
	print(string.format("[LiftService] Player %s picked up %s T%d off Lift #%d to carry", player.Name, category, tierToRemove, liftId))
	return true, "Success"
end

function LiftService.RenderAllLiftVisuals(player: Player)
	local data = DataService.GetPlayerData(player)
	if not data then return end

	for liftKey, car in pairs(data.Lifts) do
		local liftId = tonumber(liftKey)
		if liftId then
			LiftService.RenderLiftCarVisual(player, liftId, car)
		end
	end
end

function LiftService.InstallComponent(player: Player, liftId: number, gridSlot: number): (boolean, string, Types.MountedCar?)
	return false, "Direct mounting replaced by physical part carrying", nil
end

function LiftService.RemoveComponent(player: Player, liftId: number): (boolean, string, Types.WorkbenchItem?)
	return false, "Direct unmounting replaced by targeted physical part picking", nil
end

return LiftService

return LiftService
