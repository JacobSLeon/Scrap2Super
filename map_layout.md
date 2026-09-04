# Map & World Layout Specification: The Chop Shop District

## 1. World Theme & Footprint
- **Setting:** Industrial wharf / dockside warehouse district ("The Chop Shop District").
- **Aesthetic:** Low-poly industrial. Smooth surfaces, clean bevels, high-contrast hazard striping, and ambient neon/fluorescent lighting.
- **Dimensions:** 450 × 350 studs total walkable space.
- **Capacity:** 6 identical, modular player plots.

---

## 2. Spatial Layout & Roadway
The map uses a symmetrical layout with 3 plots facing North and 3 plots facing South across a central public avenue.

[ Plot 1 ]        [ Plot 2 ]        [ Plot 3 ]
   (Warehouse)      (Warehouse)       (Warehouse)
        |                 |                 |
 =======+=================+=================+=======
                   MAIN ROADWAY
          [ Central Car Meet / NPC Plaza ]
 =======+=================+=================+=======
        |                 |                 |
   [ Plot 4 ]        [ Plot 5 ]        [ Plot 6 ]
   (Warehouse)      (Warehouse)       (Warehouse)

- **Central Roadway:** 120-stud-wide asphalt avenue connecting all 6 garages.
- **Car Meet Plaza:** Central island featuring street lamps, decorative palm trees, and a rotating "Top Showroom Car" showcase pedestal.
- **NPC Route:** NPCs spawn at road ends and walk along sidewalk paths directly to plot entrance doors.
- **Perimeter:** Fully enclosed with stacked shipping containers, industrial back-walls, and chain-link fencing.

---

## 3. Individual Plot Specification (Instanced × 6)
Each plot occupies a **90 × 110 stud** footprint, divided into three internal zones:

### Zone A: Forecourt & Entrance (Front 25 studs)
- Concrete apron connecting the garage bay door directly to the roadway sidewalk.
- Roll-up industrial shutter frame.
- Overhead **Signboard Gantry** supporting a custom `TextLabel`.
- NPC Buyer Waiting Pad located to the right of the bay door.

### Zone B: Active Workshop Floor (Center 55 studs)
- Polished industrial concrete floor with perimeter hazard striping.
- **Left Wall (Logistics Lane):**
  - 60-stud elevated conveyor belt leading from a rear ceiling chute toward the front.
  - Terminal end features the Industrial Shredder chute and a mount point for the 50-Slot Overflow Crate Hopper.
- **Center (Assembly Workbench):**
  - 16 × 16 stud heavy-duty workbench equipped with 3D snapping grid nodes.
- **Right Wall (Hydraulic Lift Bays):**
  - Space for 6 parallel Hydraulic Lifts (Bay 1 unlocked by default; Bays 2–6 locked by rebirth pad triggers).
  - Unlocked lifts feature dual hydraulic cylinders, yellow lift arms, and attachment projection markers.

### Zone C: Rear Office & Paint Booth (Rear 30 studs)
- **Paint Booth:** Glass-enclosed chamber with overhead ventilation pipes and an interaction terminal for Primary/Secondary color selection.
- **Decorations:** Racks of tires, rolling toolboxes, and engine hoists placed along walls without obstructing player walking paths.

---

## 4. Collision & Navigation Constraints
- All curbs, workbench borders, and thresholds must utilize invisible angled wedge parts (`Transparency = 1`) to ensure smooth character movement across mobile, gamepad, and PC.
- Garages maintain open bay sightlines so players walking down the road can view neighbors' active builds and lifts.