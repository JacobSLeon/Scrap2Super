--!strict
-- SnapController: In-world 3D raycast snapping for 4x4 Workbench grid nodes
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SnapController = {}
local camera = Workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local isDragging = false
local currentSelectedSlot: number? = nil

function SnapController.Init()
	print("[SnapController] Initialized 3D workbench raycast snapping controller.")
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			SnapController.OnInputDown()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			SnapController.OnInputUp()
		end
	end)
end

function SnapController.OnInputDown()
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	
	local workbenchFolder = Workspace:FindFirstChild("WorkbenchGrid")
	if not workbenchFolder then return end
	raycastParams.FilterDescendantsInstances = { workbenchFolder }

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result and result.Instance then
		local slotNum = result.Instance:GetAttribute("SlotNumber")
		if typeof(slotNum) == "number" then
			isDragging = true
			currentSelectedSlot = slotNum
			print(string.format("[SnapController] Selected Workbench Slot %d", slotNum))
		end
	end
end

function SnapController.OnInputUp()
	if isDragging then
		isDragging = false
		currentSelectedSlot = nil
	end
end

return SnapController
