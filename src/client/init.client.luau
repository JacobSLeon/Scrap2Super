--!strict
-- Client Entrypoint for Scrap to Supercar
local SnapController = require(script.controllers.SnapController)
local LiftHighlightController = require(script.controllers.LiftHighlightController)
local ConveyorVisualizer = require(script.controllers.ConveyorVisualizer)
local DialogUIController = require(script.controllers.DialogUIController)
local HUDController = require(script.controllers.HUDController)

print("[Client] Initializing Scrap to Supercar Client Controllers...")

SnapController.Init()
LiftHighlightController.Init()
ConveyorVisualizer.Init()
DialogUIController.Init()
HUDController.Init()

print("[Client] All Core Controllers & ScreenGui HUD Successfully Initialized!")
