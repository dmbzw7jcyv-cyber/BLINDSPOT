# V1 validation — 2026-09-23

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
