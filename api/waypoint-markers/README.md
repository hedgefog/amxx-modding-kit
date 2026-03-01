# 📍 Waypoint Markers API

The **Waypoint Markers API** creates 3D waypoint sprite markers that are always visible to players, even through walls. Markers automatically project onto surfaces when obstructed, scale with distance, and support per-player visibility control.

## 🚀 Features

- **Wall Projection**: Markers project onto surfaces when behind walls
- **Distance Scaling**: Markers maintain a consistent screen size regardless of distance
- **Per-Player Visibility**: Show or hide markers for individual players
- **FOV Awareness**: Markers only render when within the player's field of view
- **Ping Compensation**: Smooth marker positioning with optional latency compensation
- **Lifecycle Events**: React to marker creation and destruction via forwards

## 📚 Usage

### Creating a Marker

Create a waypoint marker with a sprite model:

```pawn
new pMarker = WaypointMarker_Create("sprites/mymod/waypoint.spr", vecOrigin, 1.0, Float:{64.0, 64.0});
```

Parameters:
- `szModel`: Path to the sprite model (must be precached)
- `vecOrigin`: World position of the marker
- `flScale`: Base scale of the sprite (default: `1.0`)
- `rgflSize`: Sprite dimensions as `{width, height}` (default: `{64.0, 64.0}`)

### Controlling Visibility

Markers are hidden by default. Use `WaypointMarker_SetVisible` to show them for specific players:

```pawn
// Show marker for a specific player
WaypointMarker_SetVisible(pMarker, pPlayer, true);

// Hide marker for a specific player
WaypointMarker_SetVisible(pMarker, pPlayer, false);

// Show marker for all players (pass 0 as player)
WaypointMarker_SetVisible(pMarker, 0, true);
```

### Handling Events

React to marker lifecycle events:

```pawn
public WaypointMarker_OnCreated(const pMarker) {
  // A new waypoint marker was created
}

public WaypointMarker_OnDestroy(const pMarker) {
  // A waypoint marker is about to be destroyed
}
```

## 🧩 Example: Objective Marker

```pawn
#include <amxmodx>
#include <fakemeta>

#include <api_waypoint_markers>

new g_pObjectiveMarker;

public plugin_precache() {
  precache_model("sprites/mymod/objective.spr");
}

public plugin_init() {
  register_plugin("Objective Marker", "1.0.0", "Hedgehog Fog");

  new Float:vecObjectiveOrigin[3] = {512.0, 256.0, 128.0};

  g_pObjectiveMarker = WaypointMarker_Create(
    "sprites/mymod/objective.spr",
    vecObjectiveOrigin,
    .flScale = 0.5,
    .rgflSize = Float:{48.0, 48.0}
  );
}

public client_putinserver(pPlayer) {
  // Show the objective marker to the new player
  WaypointMarker_SetVisible(g_pObjectiveMarker, pPlayer, true);
}
```

---

## 📖 API Reference

See [`api_waypoint_markers.inc`](include/api_waypoint_markers.inc) for all available natives and forwards.
