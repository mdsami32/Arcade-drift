# Arcade Drift Racer — First Playable Slice

This is the **Stage 1–9 prototype** described in your spec (Section 61: "Build
the first functional prototype... make this playable before adding advanced
features"). It is not the full 68-section game — that's a multi-month build.
What's here is a real, structured foundation you can open, drive, and expand.

## Requirements
Godot **4.3+** (Forward+ renderer). Open the folder as a project
(`project.godot`) and press Play — `scenes/main/Race.tscn` is the main scene.

I wrote and reviewed every file carefully, but I don't have Godot available
in this sandbox to actually run it, so treat this as a strong first pass:
open it, and if the editor flags anything (a typo, a mismatched node path),
tell me the exact error and I'll fix it immediately.

## What's implemented
- **VehicleController.gd** — arcade driving: gradual acceleration, braking
  that scales with speed, reverse, speed-sensitive steering, a handbrake
  drift with reduced rear grip, gravity/airborne handling, and a light
  visual weight-transfer tilt. (Sections 3, 5–13)
- **AIController.gd** — waypoint-following AI with 4 difficulty presets,
  corner slow-down, and occasional believable mistakes; a rubber-banding
  hook is stubbed for later. (Sections 26–27)
- **CameraController.gd** — smooth chase camera, speed-based FOV increase,
  and collision/landing shake. (Section 18)
- **Track.gd** — procedurally builds an oval circuit (ground, road ribbon,
  10 lit checkpoint gates, AI waypoints, a 4-car spawn grid) so the track
  is fully data-driven — change `radius_x`/`radius_z`/`num_checkpoints` in
  the Inspector and it rebuilds. (Section 29, 57)
- **RaceManager.gd** — countdown, ordered checkpoint/lap validation, live
  race positions, finish detection, hands off to results. (Sections 19,
  24–25, 54–55)
- **HUD.gd / ResultsScreen.gd** — speed, position, lap, timer, countdown,
  and a results screen with a placeholder star/credit/XP reward. (Sections
  40, 43)
- **GameManager.gd** (autoload) — pause state and a credits/XP stub other
  systems can build on. (Section 56)

Controls: WASD/arrows to drive, Space to drift, R to reset to spawn, Esc to
pause. Full remapping already works via Godot's Input Map (see
`project.godot`) — Section 4's requirement.

## What's intentionally NOT built yet
Garage, upgrades, economy/save system, multiple vehicle classes, traffic,
weather/day-night, nitro, championships, world map, and hand-built track
segments (this track is one procedural oval, not the modular
straight/hairpin/jump pieces from Section 29). The architecture is set up
so each of these slots in without rewrites — e.g. vehicle stats are already
`@export` fields ready to move into a `VehicleData.tres` Resource per car.

## Suggested next steps
Tell me which system to build next and I'll do the same treatment on it:
1. VehicleData Resources + a second/third car class (Section 15–16)
2. Garage + upgrade system (Sections 33–35)
3. SaveManager (Section 44)
4. A hand-built (non-oval) track with jumps/hairpins (Section 29–30)
5. Main menu + world map + event unlock flow (Sections 39, 50, 60)
