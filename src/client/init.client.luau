--!strict
-- Client Entrypoint for Scrap to Supercar
local SnapController = require(script.controllers.SnapController)
local LiftHighlightController = require(script.controllers.LiftHighlightController)
local ConveyorVisualizer = require(script.controllers.ConveyorVisualizer)

print("[Client] Initializing Scrap to Supercar Client Controllers...")

SnapController.Init()
LiftHighlightController.Init()
ConveyorVisualizer.Init()

print("[Client] All Core Controllers Successfully Initialized!")
