# V1 validation — 2026-09-23

## Expanded map and closets follow-up

The fixed map is now 23×19 cells, with 214 connected walkable cells and eight closets.
Passed Rojo build, source mappings, official Luau compilation and CLI behavior tests.
Added CLI assertions for closet occupancy, dead-character rejection, anchoring,
exit/reset cleanup, hiding detection/damage suppression and exposed contact.

Reran the full solo integration suite in Studio: packet separation, objective
validation, closet entry, flashlight off, safe exit, role-switch cleanup, reset
cleanup, all three relays, extraction, round reset and authoritative monster loss
passed. Reran the real navmesh suite: chase/contact and routes to every relay and
every closet entrance passed. Tests use scripted movement; multiplayer balance and
human communication pacing on the larger map still need a playtest.

## Original V1 checks

Passed with Rojo 7.7.0 and the official Luau CLI:

- Place build and source map; original server/client/shared mappings preserved.
- All production and test Luau files compile.
- All 86 walkable cells form one connected component, including A/B/C/exit/hostile spawn.
- Actual MonsterService in a CLI engine mock: patrol/chase/search, pause/reset,
  occluded attacks, close contact, path failure and pathfinding interval.

Passed in Roblox Studio on this machine:

- Solo integration script: Runner receives no map/radar; Navigator receives map
  only; Tracker receives scan only; solo role switching clears old interfaces.
- Station camera exits first person correctly.
- Non-Runner and distant prompt attempts rejected.
- Actual relay prompts activate all three objectives and unlock the exit.
- Extraction wins; round reset clears relays and relocks exit.
- Server monster contact kills Runner and produces Lost.
- Real PathfindingService chase/contact and paths to each relay.
- Server & Clients with three clients assigns one of each role; each window shows
  its intended HUD/map/radar. This was a smoke test, not a full three-human match.
- Built-in modern chat selected in the built place; subsequent solo startup did
  not reproduce the legacy CoreGuiChatConnections error seen in the first build.

The final requested visual pass replaces bright centered text with muted corner
HUD text, adds concrete/steel supports and conduits, amber fixtures/fog, and a gaunt
multi-part local monster. It compiles and builds, and Studio starts its server.
Final visual inspection was interrupted when the user stopped Computer Use with
Escape. Repeat the two Studio test scripts after pulling, particularly the real
navmesh check for the new corridor supports. No public-server playtest was run.

Audio remains an empty, documented asset hook. Geometry in Workspace is inspectable
by exploit clients; role-scoped telemetry does not constitute full anti-cheat.
