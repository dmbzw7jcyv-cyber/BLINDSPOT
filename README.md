# BLINDSPOT — playable V1

A three-player asymmetric co-op horror prototype for Roblox, built with Rojo and Luau.
One fixed industrial maze, three power relays, one hostile, one exit. Nobody has enough
information alone: use normal Roblox chat or your existing voice call to coordinate.
There is no custom voice system, progression, shop, persistence, or procedural generation.

The fixed facility is now **23 × 19 cells** (322 × 266 studs), with **214 connected
walkable cells** and eight maintenance closets. Relays B and C sit in the expanded
east and south wings. The Navigator's map scales to the layout and marks closets **H**.

### Hiding closets

Approach a maintenance closet and hold **E** to hide. The server moves the Runner
inside, locks movement, and the flashlight goes dark. Look out through the door slot;
press **E** to leave. The small corner HUD indicates when you are inside.

Break line of sight before entering: if the monster sees you enter within its detection
range, it approaches the doorway and can catch you. Otherwise it searches its last known
position, then returns to patrol. Hiding does not freeze the monster or its Tracker scans.
Only the Runner can enter, and the server validates role, round state, health, distance,
line of sight and occupancy. Death, reset, disconnection and debug role changes release
the closet and restore movement. Debug teleportation also clears hiding.

| Role | What you know | What you do not get |
| --- | --- | --- |
| Runner | First-person world, flashlight, nearby physical hostile, relay prompts | Map, radar, distance/bearing indicators |
| Navigator | Facility plan, live Runner marker, relay locations/status, exit | Monster position, direction, range or radar |
| Tracker | Coarse monster range/bearing from Runner, relative facing angle, danger signal | Layout, walls, routes, relay locations or exit |

The Runner holds **E** at each relay. All three unlock the exit and notify the team.
Enter the exit cell or use its Evacuate prompt to win. Monster contact or Runner death
loses. Results display for eight seconds before the next round.

## Start in Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit) and the
   [Rojo Studio plugin](https://rojo.space/docs/v7/getting-started/installation/).
2. Clone this repository and open a terminal in its root:

   ```sh
   rokit install
   rojo serve
   ```

3. Open a **new empty place** in Studio. Open the Rojo plugin and connect to
   `localhost:34872`, then accept the initial sync. The existing project mappings
   are preserved. No asset import or Toolbox models are required.
4. Press **F5 / Test**. The facility is built by the server at runtime, so the edit
   viewport is intentionally empty. Keep `rojo serve` running while editing sources.
5. Stop and restart Play after server/layout edits. Rojo syncing source does not
   automatically rerun an already-running script.

Alternatively, build a standalone place and open it using **File → Open from File**:

```sh
rojo build -o BLINDSPOT.rbxlx
```

Build artifacts are ignored by Git. Rojo 7.7.0 is pinned in `rokit.toml`.

## Solo debug

Studio with one client starts a solo round after a short connection grace period.
Press **F2** in the game viewport to show/hide the small Studio panel and free the
Runner cursor. **WASD/mouse** moves/looks; **F** toggles the flashlight.

| Control | Effect |
| --- | --- |
| Runner / Navigator / Tracker | Change your role, teleport to its area, clear the previous interface |
| Spawn/Reset Monster | Return hostile to its fixed spawn and resume AI |
| Pause Monster AI / Resume Monster AI | Freeze/resume movement and contact damage |
| Teleport to Runner area | Return to the saved Runner position |
| Teleport to Control Room | Move to the operator room without changing role |
| Reveal Map | Toggle a debug map overlay; intentionally bypasses information separation in Studio |
| Reset Round | Reload characters, reset relays/exit/monster and reassign roles |

Role switching is **solo-only**. When inspecting Navigator/Tracker alone, the saved
Runner position stays in the maze and AI freezes automatically. Switching back to
Runner returns you there; the explicit pause flag is preserved. Normal multiplayer
AI is unaffected by station use. Turning off Reveal Map or changing role removes
the overlay; resetting clears reveal authorization.

Debug controls exist only when `RunService:IsStudio()` is true. The server does not
create a Debug remote in published servers and independently checks Studio on every
debug request. There is no player-controlled debug flag or production role remote.

## Three-player test

1. Stop solo Play.
2. In Studio's testing dropdown, select **Server & Clients**, choose **3** clients,
   then press Play / **F7**. Older Studio layouts label this **Local Server / Start**.
3. Once three players connect, the server sorts UserIds and assigns Runner,
   Navigator, Tracker in that order. Studio test UserIds can be negative, so read
   each window's role header rather than assuming Player1 is Runner.
4. The Runner spawns in the maze; operators spawn in the enclosed control room,
   which has NAVIGATION and TRACKING desks. Each role's display opens automatically.
5. Guide the Runner to A, B, C, then E. Test a win, a monster kill, Reset Character,
   operator disconnection, and the automatic reset. Extra clients wait as observers.
6. End Session to stop all clients. Published servers require three players; two
   Studio clients alone also wait. If a solo session gains a full team, it restarts
   with normal three-role assignment.

See Roblox's [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes)
for the current multi-client controls. Set the published place's player limit to
three if you do not want standby observers (this project does not change cloud settings).

## Structure and authority

The original source mappings in `default.project.json` remain unchanged. The only
added service setting selects Roblox's built-in TextChatService; otherwise a fresh
Rojo place can load legacy chat and produce CoreGuiChatConnections errors in Studio.
See Roblox's [chat migration documentation](https://create.roblox.com/docs/chat/in-experience-text-chat).

```text
src/shared/Config.luau          ReplicatedStorage.Shared: public tuning/audio hooks
src/server/init.server.luau     ServerScriptService.Server: rounds, roles, validation, dispatch
src/server/Facility.luau        Fixed layout, physical facility, relays and exit
src/server/MonsterService.luau  Server-only logical AI and rate-limited pathfinding
src/server/HidingService.luau   Closet occupancy, anchoring and cleanup
src/client/init.client.luau     Camera, flashlight, local hostile, role/debug lifecycle
src/client/Interface.luau       Map, sonar, restrained HUD components
tests/                         Not mapped into the Roblox place
```

Round states: Waiting → Setup → Playing → Won/Lost → Resetting → Setup/Waiting.
The server validates state, role, living character, proximity and line of sight
before accepting a relay or exit prompt. Ready/debug requests are rate-limited.
There are no client remotes to set damage, objectives, roles or monster coordinates.

Map packets go only to Navigator (or an explicit Studio reveal). Scan packets go
only to Tracker, once per second, quantized to five studs and fifteen degrees.
Bearing is north-up (`-Z` north, `+X` east); a separate clockwise angle is relative
to Runner facing. Range uses Roblox **studs**, not an assumed real-world conversion.
Map/nearby-world updates run at 5 Hz. Monster paths compute at most once per 1.25
seconds, with one request in flight, using Roblox PathfindingService. AI has patrol,
search and chase states and checks sight/contact on the server. It never attacks
through a wall. Its position lives in server memory, with a local placeholder
rendered only to a Runner within 75 studs. Navigator never receives that model.

## Validation

Command-line checks:

```sh
rojo build -o BLINDSPOT.rbxlx
rojo sourcemap --output sourcemap.json
luau-compile --null src/server/*.luau src/client/*.luau src/shared/*.luau
node tests/check.mjs
```

The Node check requires Node 22+ and the official [Luau CLI](https://github.com/luau-lang/luau/releases).
Set `LUAU` to the executable path if it is not on PATH. It checks Rojo mappings,
all 214 walkable cells' connectivity, relay/exit/closet reachability, and executes the actual
MonsterService against a small mock to test transitions, kills, occlusion, pause,
reset, path failure, hiding detection/damage, closet lifecycle, and pathfinding rate
limits. Mocks do not validate Roblox physics.

Engine integration scripts, intentionally excluded from the Rojo tree:

- `tests/SoloStudio.luau`: during solo Play, paste into the **Client Command Bar**
  and execute with **Ctrl+Enter**. It resets the round, switches roles, inspects
  actual remote packets, tests prompt rejection/activation, unlock/extraction,
  reset, closet entry/exit/cleanup, and monster death. It teleports the test avatar and pauses AI to isolate
  checks; this is not a balance/playability test.
- `tests/MonsterStudio.luau`: run in the **Server Command Bar** during Play to test
  an isolated AI against the real navmesh and routes to all relays.

For a manual security check, compare all three clients: Runner has neither station
display, Navigator has no hostile/radar, Tracker has no plan/objectives. Switch solo
roles and confirm old UI disappears. Try relay interaction from a non-Runner and
from outside range. Published servers should contain no `BlindspotRemotes.Debug`.

## V1 limits

- Procedural-part gaunt hostile silhouette and concrete/steel corridors with rusted
  supports, conduits, weak amber fixtures and distance fog; no imported assets,
  skeletal animations, custom
  assets, sprint, inventories, matchmaking, or role selection lobby.
- Audio hooks in `Config.Sounds` are empty by default: supply licensed/owned Roblox
  audio IDs for ambient hum and nearby hostile audio. The shipped build is silent;
  there is no copyrighted audio dependency.
- This targets PC keyboard/mouse. Touch/controller UX and accessibility options
  need a later pass. The radar clips contacts beyond 180 studs at its outer ring
  while still showing numeric distance. Solo station inspection assumes north-facing
  Runner for the relative-angle readout.
- Physical walls, terminals, exit and player characters replicate through Workspace
  for Roblox rendering/physics. An exploit client can inspect that geometry and
  reconstruct a map. The role protocol prevents privileged telemetry broadcasts,
  but it is not a full anti-cheat or hidden-world implementation. Character movement
  uses Roblox's normal network ownership; movement/teleport anti-cheat is out of scope.
- Monster movement is server-simulated on a flat navmesh, with a smoothed local
  visual. It has no collision rig or sophisticated hearing system. Search follows
  its last known target and returns to patrol. Difficulty and maze pacing need a
  real three-person communication playtest.
