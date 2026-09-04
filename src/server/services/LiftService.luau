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
	billboard.Size = UDim2.new(0, 180, 0, 55)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = liftBay
	billboard.Parent = liftBay

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne

	if car.isComplete then
		label.Text = string.format("[Lift #%d: COMPLETE]\n+$%d / sec", liftId, car.cashPerSecond)
		label.TextColor3 = Color3.fromRGB(0, 255, 120)
	else
		local statusStr = string.format("[Lift #%d]\nE: %s | C: %s | B: %s",
			liftId,
			if car.engineTier then "T" .. car.engineTier else "--",
			if car.chassisTier then "T" .. car.chassisTier else "--",
			if car.bodyTier then "T" .. car.bodyTier else "--"
		)
		label.Text = statusStr
		label.TextColor3 = Color3.fromRGB(255, 200, 50)
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
			-- Attachment offsets to separate 3D prompt positions (prevents layering/overlap)
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
				local targetParent: Instance = liftBay
				if heldCat == "Engine" then targetParent = engineAtt
				elseif heldCat == "Chassis" then targetParent = chassisAtt
				elseif heldCat == "Body" then targetParent = bodyAtt
				end

				local mountPrompt = Instance.new("ProximityPrompt")
				mountPrompt.Name = "MountPrompt"
				mountPrompt.KeyboardKeyCode = Enum.KeyCode.F
				mountPrompt.HoldDuration = 0
				mountPrompt.RequiresLineOfSight = false
				mountPrompt.MaxActivationDistance = 30
				mountPrompt.ObjectText = string.format("Hydraulic Press / Lift #%d", liftId)
				mountPrompt.ActionText = string.format("Mount Held %s (T%d) [F]", heldCat, heldTier)
				mountPrompt.Parent = targetParent

				mountPrompt.Triggered:Connect(function(triggeringPlayer)
					if triggeringPlayer ~= player then return end
					local success, msg = LiftService.InstallHeldComponent(player, liftId)
					if not success then
						print(string.format("[LiftService] Cannot mount held part to Lift #%d: %s", liftId, msg))
					end
				end)
			else
				if not car or (car.engineTier == nil and car.chassisTier == nil and car.bodyTier == nil) then
					local emptyPrompt = Instance.new("ProximityPrompt")
					emptyPrompt.Name = "EmptyLiftPrompt"
					emptyPrompt.KeyboardKeyCode = Enum.KeyCode.F
					emptyPrompt.HoldDuration = 0
					emptyPrompt.RequiresLineOfSight = false
					emptyPrompt.MaxActivationDistance = 30
					emptyPrompt.ObjectText = string.format("Hydraulic Press / Lift #%d", liftId)
					emptyPrompt.ActionText = string.format("Mount Held Part [F] (Lift #%d)", liftId)
					emptyPrompt.Parent = liftBay

					emptyPrompt.Triggered:Connect(function(triggeringPlayer)
						if triggeringPlayer ~= player then return end
						print(string.format("[LiftService] Lift #%d is empty.", liftId))
					end)
				else
					-- Engine Prompt [F]
					if car.engineTier then
						local fPrompt = Instance.new("ProximityPrompt")
						fPrompt.Name = "RemovePrompt_Engine"
						fPrompt.KeyboardKeyCode = Enum.KeyCode.F
						fPrompt.ActionText = string.format("Pick Up Engine (T%d) [F]", car.engineTier)
						fPrompt.ObjectText = string.format("Lift #%d - Engine Bay", liftId)
						fPrompt.HoldDuration = 0
						fPrompt.RequiresLineOfSight = false
						fPrompt.MaxActivationDistance = 30
						fPrompt.UIOffset = Vector2.new(-30, 0)
						fPrompt.Parent = engineAtt

						fPrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Engine")
						end)
					end

					-- Chassis Prompt [G]
					if car.chassisTier then
						local key = if car.engineTier then Enum.KeyCode.G else Enum.KeyCode.F
						local keyStr = if key == Enum.KeyCode.G then "[G]" else "[F]"

						local gPrompt = Instance.new("ProximityPrompt")
						gPrompt.Name = "RemovePrompt_Chassis"
						gPrompt.KeyboardKeyCode = key
						gPrompt.ActionText = string.format("Pick Up Chassis (T%d) %s", car.chassisTier, keyStr)
						gPrompt.ObjectText = string.format("Lift #%d - Chassis", liftId)
						gPrompt.HoldDuration = 0
						gPrompt.RequiresLineOfSight = false
						gPrompt.MaxActivationDistance = 30
						gPrompt.UIOffset = Vector2.new(0, 30)
						gPrompt.Parent = chassisAtt

						gPrompt.Triggered:Connect(function(triggeringPlayer)
							if triggeringPlayer ~= player then return end
							LiftService.RemoveSpecificComponent(player, liftId, "Chassis")
						end)
					end

					-- Body Prompt [H]
					if car.bodyTier then
						local key = if car.engineTier or car.chassisTier then Enum.KeyCode.H else Enum.KeyCode.F
						local keyStr = if key == Enum.KeyCode.H then "[H]" else "[F]"

						local hPrompt = Instance.new("ProximityPrompt")
						hPrompt.Name = "RemovePrompt_Body"
						hPrompt.KeyboardKeyCode = key
						hPrompt.ActionText = string.format("Pick Up Body (T%d) %s", car.bodyTier, keyStr)
						hPrompt.ObjectText = string.format("Lift #%d - Body Shell", liftId)
						hPrompt.HoldDuration = 0
						hPrompt.RequiresLineOfSight = false
						hPrompt.MaxActivationDistance = 30
						hPrompt.UIOffset = Vector2.new(30, 0)
						hPrompt.Parent = bodyAtt

						hPrompt.Triggered:Connect(function(triggeringPlayer)
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
	local CarryingService = require(script.Parent.CarryingService)
	local category, tier = CarryingService.GetHeldItem(player)
	if not category or not tier then
		return false, "Not holding any part"
	end

	local data = DataService.GetPlayerData(player)
	if not data then return false, "Player data not found" end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		car = {
			liftId = liftId,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		}
	end

	if category == "Engine" and car.engineTier ~= nil then return false, "Engine already installed" end
	if category == "Chassis" and car.chassisTier ~= nil then return false, "Chassis already installed" end
	if category == "Body" and car.bodyTier ~= nil then return false, "Body already installed" end

	if category == "Engine" then car.engineTier = tier end
	if category == "Chassis" then car.chassisTier = tier end
	if category == "Body" then car.bodyTier = tier end

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

	print(string.format("[LiftService] Player %s mounted held %s T%d onto Lift #%d", player.Name, category, tier, liftId))
	return true, "Success"
end

function LiftService.RemoveSpecificComponent(player: Player, liftId: number, category: Types.SubAssemblyCategory): (boolean, string)
	local CarryingService = require(script.Parent.CarryingService)
	if CarryingService.IsHolding(player) then
		return false, "Player is already holding a part! Place or mount it first."
	end

	local data = DataService.GetPlayerData(player)
	if not data then return false, "Player data not found" end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then return false, "No car on this lift" end

	local tierToRemove: number? = nil
	if category == "Engine" then tierToRemove = car.engineTier end
	if category == "Chassis" then tierToRemove = car.chassisTier end
	if category == "Body" then tierToRemove = car.bodyTier end

	if not tierToRemove then
		return false, string.format("No %s installed on Lift #%d", category, liftId)
	end

	-- Unmount target category
	if category == "Engine" then car.engineTier = nil end
	if category == "Chassis" then car.chassisTier = nil end
	if category == "Body" then car.bodyTier = nil end

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
