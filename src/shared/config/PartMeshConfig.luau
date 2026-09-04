--!strict
-- PartMeshConfig: Individual 3D Car Parts & Auto-Scaling for Workbench Slots (Tiers 1-6)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(script.Parent.Parent.types.Types)

export type PartMeshInfo = {
	templateName: string,
	primaryColor: Color3,
	material: Enum.Material,
	targetSize: Vector3,
}

local PartMeshConfig = {}

-- Visual Mapping for (Category, Tier) to Individual Car Parts
local PART_MAP: { [Types.SubAssemblyCategory]: { [number]: PartMeshInfo } } = {
	Engine = {
		[1] = { templateName = "EnginePart_Piston", primaryColor = Color3.fromRGB(150, 110, 70), material = Enum.Material.CorrodedMetal, targetSize = Vector3.new(2, 2, 2) },
		[2] = { templateName = "EnginePart_Piston", primaryColor = Color3.fromRGB(190, 190, 200), material = Enum.Material.Metal, targetSize = Vector3.new(2, 2, 2) },
		[3] = { templateName = "EnginePart_Piston", primaryColor = Color3.fromRGB(220, 50, 50), material = Enum.Material.SmoothPlastic, targetSize = Vector3.new(2.2, 2.2, 2.2) },
		[4] = { templateName = "EnginePart_Turbocharger", primaryColor = Color3.fromRGB(50, 180, 250), material = Enum.Material.Metal, targetSize = Vector3.new(2.2, 2.2, 2.2) },
		[5] = { templateName = "EnginePart_Turbocharger", primaryColor = Color3.fromRGB(240, 200, 30), material = Enum.Material.Foil, targetSize = Vector3.new(2.4, 2.4, 2.4) },
		[6] = { templateName = "EnginePart_Turbocharger", primaryColor = Color3.fromRGB(220, 30, 240), material = Enum.Material.ForceField, targetSize = Vector3.new(2.5, 2.5, 2.5) },
	},
	Chassis = {
		[1] = { templateName = "ChassisPart_BrakeDisk", primaryColor = Color3.fromRGB(140, 140, 150), material = Enum.Material.CorrodedMetal, targetSize = Vector3.new(2, 1, 2) },
		[2] = { templateName = "ChassisPart_BrakeDisk", primaryColor = Color3.fromRGB(255, 120, 30), material = Enum.Material.DiamondPlate, targetSize = Vector3.new(2, 1, 2) },
		[3] = { templateName = "ChassisPart_WheelRim", primaryColor = Color3.fromRGB(40, 40, 45), material = Enum.Material.Metal, targetSize = Vector3.new(2.2, 1.2, 2.2) },
		[4] = { templateName = "ChassisPart_WheelRim", primaryColor = Color3.fromRGB(230, 190, 40), material = Enum.Material.Foil, targetSize = Vector3.new(2.2, 1.2, 2.2) },
		[5] = { templateName = "ChassisPart_WheelRim", primaryColor = Color3.fromRGB(50, 200, 250), material = Enum.Material.Metal, targetSize = Vector3.new(2.4, 1.4, 2.4) },
		[6] = { templateName = "ChassisPart_WheelRim", primaryColor = Color3.fromRGB(0, 255, 255), material = Enum.Material.Neon, targetSize = Vector3.new(2.5, 1.4, 2.5) },
	},
	Body = {
		[1] = { templateName = "BodyPart_ExhaustPipe", primaryColor = Color3.fromRGB(150, 100, 60), material = Enum.Material.CorrodedMetal, targetSize = Vector3.new(2, 1.5, 2) },
		[2] = { templateName = "BodyPart_ExhaustPipe", primaryColor = Color3.fromRGB(60, 130, 200), material = Enum.Material.Metal, targetSize = Vector3.new(2, 1.5, 2) },
		[3] = { templateName = "RacingSpoiler", primaryColor = Color3.fromRGB(220, 40, 40), material = Enum.Material.SmoothPlastic, targetSize = Vector3.new(2.2, 1.2, 2.2) },
		[4] = { templateName = "RacingSpoiler", primaryColor = Color3.fromRGB(40, 200, 100), material = Enum.Material.Glass, targetSize = Vector3.new(2.2, 1.2, 2.2) },
		[5] = { templateName = "RacingSpoiler", primaryColor = Color3.fromRGB(240, 220, 50), material = Enum.Material.Foil, targetSize = Vector3.new(2.4, 1.2, 2.4) },
		[6] = { templateName = "RacingSpoiler", primaryColor = Color3.fromRGB(255, 0, 128), material = Enum.Material.ForceField, targetSize = Vector3.new(2.5, 1.2, 2.5) },
	},
}

function PartMeshConfig.GetMeshInfo(category: Types.SubAssemblyCategory, tier: number): PartMeshInfo
	local categoryMap = PART_MAP[category]
	if categoryMap and categoryMap[tier] then
		return categoryMap[tier]
	end
	return {
		templateName = "EnginePart_Piston",
		primaryColor = Color3.fromRGB(150, 150, 150),
		material = Enum.Material.SmoothPlastic,
		targetSize = Vector3.new(2, 2, 2),
	}
end

local function getTierHighlightColor(tier: number): Color3
	if tier == 1 then return Color3.fromRGB(150, 100, 50) end
	if tier == 2 then return Color3.fromRGB(0, 180, 255) end
	if tier == 3 then return Color3.fromRGB(180, 0, 255) end
	if tier == 4 then return Color3.fromRGB(255, 180, 0) end
	if tier == 5 then return Color3.fromRGB(0, 255, 180) end
	return Color3.fromRGB(255, 0, 128)
end

local function getWorkbenchTemplateInstance(templateName: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local partMeshes = assets and assets:FindFirstChild("PartMeshes")
	if partMeshes then
		return partMeshes:FindFirstChild(templateName)
	end
	return nil
end

function PartMeshConfig.CreateVisualInstance(category: Types.SubAssemblyCategory, tier: number, targetCFrame: CFrame): Instance
	local info = PartMeshConfig.GetMeshInfo(category, tier)
	local template = getWorkbenchTemplateInstance(info.templateName)

	local instance: Instance? = nil

	if template then
		local cloned = template:Clone()
		for _, desc in ipairs(cloned:GetDescendants()) do
			if desc:IsA("SurfaceAppearance") or desc:IsA("Script") or desc:IsA("LocalScript") then
				desc:Destroy()
			end
		end

		if cloned:IsA("Model") then
			-- Auto-scale model so it fits cleanly inside workbench grid slot
			local currentSize = cloned:GetExtentsSize()
			local maxExtent = math.max(currentSize.X, currentSize.Y, currentSize.Z)
			if maxExtent > 0 then
				local scaleFactor = math.clamp(2.4 / maxExtent, 0.05, 5)
				cloned:ScaleTo(scaleFactor)
			end

			cloned:PivotTo(targetCFrame)
			for _, part in ipairs(cloned:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.Color = info.primaryColor
					part.Material = info.material
				end
			end
			instance = cloned
		elseif cloned:IsA("BasePart") then
			cloned.Size = info.targetSize
			cloned.CFrame = targetCFrame
			cloned.Anchored = true
			cloned.CanCollide = false
			cloned.Color = info.primaryColor
			cloned.Material = info.material
			instance = cloned
		elseif cloned:IsA("Folder") or cloned:IsA("Instance") then
			local firstPart = cloned:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				local offset = targetCFrame.Position - firstPart.Position
				for _, part in ipairs(cloned:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CFrame = part.CFrame + offset
						part.Anchored = true
						part.CanCollide = false
						part.Color = info.primaryColor
						part.Material = info.material
					end
				end
				instance = cloned
			end
		end
	end

	if not instance then
		local fallback = Instance.new("Part")
		fallback.Name = string.format("%s_T%d_Visual", category, tier)
		fallback.Size = info.targetSize
		fallback.CFrame = targetCFrame
		fallback.Color = info.primaryColor
		fallback.Material = info.material
		fallback.Anchored = true
		fallback.CanCollide = false
		fallback.TopSurface = Enum.SurfaceType.Smooth
		fallback.BottomSurface = Enum.SurfaceType.Smooth
		instance = fallback
	end

	local targetPart: BasePart? = nil
	if instance:IsA("BasePart") then
		targetPart = instance
	elseif instance:IsA("Model") or instance:IsA("Folder") then
		targetPart = instance:FindFirstChildWhichIsA("BasePart", true)
	end

	if targetPart then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = getTierHighlightColor(tier)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0.2
		highlight.Parent = instance

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 160, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = targetPart
		billboard.Parent = targetPart

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = string.format("[%s - Tier %d]", category, tier)
		label.TextColor3 = getTierHighlightColor(tier)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = billboard
	end

	return instance
end

function PartMeshConfig.CreateLiftVisualInstance(category: Types.SubAssemblyCategory, tier: number, targetCFrame: CFrame): Instance
	local customParts = ReplicatedStorage:FindFirstChild("CustomParts")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local partMeshes = assets and assets:FindFirstChild("PartMeshes")

	local templateName = string.format("%s_T%d", category, tier)
	local liftTemplateName = string.format("Lift%s_T%d", category, tier)

	local template: Instance? = nil
	if customParts then
		template = customParts:FindFirstChild(liftTemplateName) or customParts:FindFirstChild(templateName)
	end
	if not template and partMeshes then
		template = partMeshes:FindFirstChild(liftTemplateName) or partMeshes:FindFirstChild(templateName)
	end

	local info = PartMeshConfig.GetMeshInfo(category, tier)

	if template then
		local cloned = template:Clone()
		for _, desc in ipairs(cloned:GetDescendants()) do
			if desc:IsA("SurfaceAppearance") or desc:IsA("Script") or desc:IsA("LocalScript") then
				desc:Destroy()
			end
		end

		if cloned:IsA("Model") then
			cloned:PivotTo(targetCFrame)
			for _, part in ipairs(cloned:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
			return cloned
		elseif cloned:IsA("BasePart") then
			cloned.CFrame = targetCFrame
			cloned.Anchored = true
			cloned.CanCollide = false
			return cloned
		elseif cloned:IsA("Folder") or cloned:IsA("Instance") then
			local firstPart = cloned:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				local offset = targetCFrame.Position - firstPart.Position
				for _, part in ipairs(cloned:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CFrame = part.CFrame + offset
						part.Anchored = true
						part.CanCollide = false
					end
				end
				return cloned
			end
		end
	end

	-- Procedural Fallback Part for Hydraulic Lift
	local fallback = Instance.new("Part")
	fallback.Name = string.format("Lift%s_T%d_Visual", category, tier)
	fallback.Size = if category == "Chassis" then Vector3.new(4.5, 1, 7) elseif category == "Engine" then Vector3.new(2.5, 2.5, 2.5) else Vector3.new(5, 2, 8)
	fallback.CFrame = targetCFrame
	fallback.Color = info.primaryColor
	fallback.Material = info.material
	fallback.Anchored = true
	fallback.CanCollide = false
	return fallback
end

function PartMeshConfig.CreateCompleteCarVisualInstance(tier: number, targetCFrame: CFrame): Instance
	local customParts = ReplicatedStorage:FindFirstChild("CustomParts")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local partMeshes = assets and assets:FindFirstChild("PartMeshes")

	local carNames = {
		string.format("ExampleCar_T%d", tier),
		string.format("Car_T%d", tier),
		string.format("LiftCar_T%d", tier),
		string.format("FullCar_T%d", tier),
	}

	local template: Instance? = nil
	if customParts then
		for _, name in ipairs(carNames) do
			template = customParts:FindFirstChild(name)
			if template then break end
		end
	end
	if not template and partMeshes then
		for _, name in ipairs(carNames) do
			template = partMeshes:FindFirstChild(name)
			if template then break end
		end
	end

	if template then
		local cloned = template:Clone()
		for _, desc in ipairs(cloned:GetDescendants()) do
			if desc:IsA("SurfaceAppearance") or desc:IsA("Script") or desc:IsA("LocalScript") then
				desc:Destroy()
			end
		end

		if cloned:IsA("Model") then
			cloned:PivotTo(targetCFrame)
			for _, part in ipairs(cloned:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
			return cloned
		elseif cloned:IsA("BasePart") then
			cloned.CFrame = targetCFrame
			cloned.Anchored = true
			cloned.CanCollide = false
			return cloned
		end
	end

	-- Fallback if no single complete car model exists for this tier:
	local fallbackModel = Instance.new("Model")
	fallbackModel.Name = string.format("CompleteCar_T%d_Visual", tier)

	local chassis = PartMeshConfig.CreateLiftVisualInstance("Chassis", tier, targetCFrame)
	chassis.Name = "Chassis"
	chassis.Parent = fallbackModel

	local engine = PartMeshConfig.CreateLiftVisualInstance("Engine", tier, targetCFrame * CFrame.new(0, 1.2, -1.5))
	engine.Name = "Engine"
	engine.Parent = fallbackModel

	local body = PartMeshConfig.CreateLiftVisualInstance("Body", tier, targetCFrame * CFrame.new(0, 1.8, 0))
	body.Name = "Body"
	body.Parent = fallbackModel

	return fallbackModel
end

return PartMeshConfig
