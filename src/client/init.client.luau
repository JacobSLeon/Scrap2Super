--!strict
-- Client Entrypoint for Scrap to Supercar
local controllers = script.Parent:WaitForChild("controllers")

local SnapController = require(controllers:WaitForChild("SnapController"))
local LiftHighlightController = require(controllers:WaitForChild("LiftHighlightController"))
local ConveyorVisualizer = require(controllers:WaitForChild("ConveyorVisualizer"))
local DialogUIController = require(controllers:WaitForChild("DialogUIController"))
local HUDController = require(controllers:WaitForChild("HUDController"))
local PartIndexUIController = require(controllers:WaitForChild("PartIndexUIController"))

print("[Client] Initializing Scrap to Supercar Client Controllers...")

SnapController.Init()
LiftHighlightController.Init()
ConveyorVisualizer.Init()
DialogUIController.Init()
HUDController.Init()
PartIndexUIController.Init()

print("[Client] All Core Controllers & ScreenGui HUD Successfully Initialized!")
