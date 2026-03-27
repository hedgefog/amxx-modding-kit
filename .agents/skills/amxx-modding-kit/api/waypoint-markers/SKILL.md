---
name: amxx-modding-kit-api-waypoint-markers
description: Guide for Waypoint Markers API creating 3D waypoint sprites visible through walls with per-player visibility.
---

# Waypoint Markers API

3D waypoint sprites that project onto walls, scale with distance, and support per-player visibility.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/waypoint-markers/README.md).

---

## Creating Markers

### Basic Creation

```pawn
new Float:vecOrigin[3] = {512.0, 256.0, 128.0};

new pMarker = WaypointMarker_Create(
  "sprites/mymod/waypoint.spr",  // Sprite path (must be precached)
  vecOrigin,                      // World position
  1.0,                            // Scale (default: 1.0)
  Float:{64.0, 64.0}             // Sprite size {width, height}
);
```

### With Named Parameters

```pawn
new pMarker = WaypointMarker_Create(
  "sprites/mymod/objective.spr",
  vecOrigin,
  .flScale = 0.5,
  .rgflSize = Float:{48.0, 48.0}
);
```

---

## Controlling Visibility

Markers are hidden by default. Show them for specific players:

```pawn
// Show for specific player
WaypointMarker_SetVisible(pMarker, pPlayer, true);

// Hide for specific player
WaypointMarker_SetVisible(pMarker, pPlayer, false);

// Show for ALL players (pass 0)
WaypointMarker_SetVisible(pMarker, 0, true);
```

---

## Forwards

### On Created

```pawn
public WaypointMarker_OnCreated(const pMarker) {
  // Marker was created
}
```

### On Destroy

```pawn
public WaypointMarker_OnDestroy(const pMarker) {
  // Marker is about to be destroyed
}
```

---

## Common Pattern: Objective Marker

```pawn
new g_pObjectiveMarker;

public plugin_precache() {
  precache_model("sprites/mymod/objective.spr");
}

public plugin_init() {
  register_plugin("Objective Marker", "1.0", "Author");
}

SetObjective(const Float:vecOrigin[3]) {
  // Remove old marker if exists
  if (g_pObjectiveMarker) {
    engfunc(EngFunc_RemoveEntity, g_pObjectiveMarker);
  }
  
  // Create new marker
  g_pObjectiveMarker = WaypointMarker_Create(
    "sprites/mymod/objective.spr",
    vecOrigin,
    .flScale = 0.5
  );
  
  // Show to all players
  WaypointMarker_SetVisible(g_pObjectiveMarker, 0, true);
}

public client_putinserver(pPlayer) {
  // Show objective to new player
  if (g_pObjectiveMarker) {
    WaypointMarker_SetVisible(g_pObjectiveMarker, pPlayer, true);
  }
}
```

---

## Common Pattern: Team-Based Markers

```pawn
new g_pTeamMarkers[4]; // Per team

CreateTeamMarker(iTeam, const Float:vecOrigin[3]) {
  g_pTeamMarkers[iTeam] = WaypointMarker_Create(
    "sprites/mymod/team_marker.spr",
    vecOrigin
  );
  
  // Show only to team members
  for (new i = 1; i <= MaxClients; ++i) {
    if (!is_user_connected(i)) continue;
    if (get_user_team(i) == iTeam) {
      WaypointMarker_SetVisible(g_pTeamMarkers[iTeam], i, true);
    }
  }
}

public client_putinserver(pPlayer) {
  new iTeam = get_user_team(pPlayer);
  if (g_pTeamMarkers[iTeam]) {
    WaypointMarker_SetVisible(g_pTeamMarkers[iTeam], pPlayer, true);
  }
}
```

---

## Common Pattern: Player Tracking Marker

```pawn
new g_rgpPlayerMarkers[MAX_PLAYERS + 1];

public client_putinserver(pPlayer) {
  // Create marker that follows player
  new Float:vecOrigin[3];
  pev(pPlayer, pev_origin, vecOrigin);
  
  g_rgpPlayerMarkers[pPlayer] = WaypointMarker_Create(
    "sprites/mymod/player_marker.spr",
    vecOrigin,
    .flScale = 0.3
  );
}

public client_disconnected(pPlayer) {
  if (g_rgpPlayerMarkers[pPlayer]) {
    engfunc(EngFunc_RemoveEntity, g_rgpPlayerMarkers[pPlayer]);
    g_rgpPlayerMarkers[pPlayer] = 0;
  }
}

// Update marker position in Think/PreThink
UpdateMarkerPosition(pPlayer) {
  if (!g_rgpPlayerMarkers[pPlayer]) return;
  
  new Float:vecOrigin[3];
  pev(pPlayer, pev_origin, vecOrigin);
  vecOrigin[2] += 40.0; // Above head
  
  engfunc(EngFunc_SetOrigin, g_rgpPlayerMarkers[pPlayer], vecOrigin);
}
```

---

## Checklist

- [ ] Precache sprite in `plugin_precache`
- [ ] Create marker with appropriate scale and size
- [ ] Set visibility for relevant players
- [ ] Handle new players joining (show existing markers)
- [ ] Clean up markers when no longer needed
- [ ] Use forwards for marker lifecycle events
