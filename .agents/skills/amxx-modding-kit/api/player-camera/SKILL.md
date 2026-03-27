---
name: amxx-modding-kit-api-player-camera
description: Helps with Player Camera API usage for controlling custom camera views with positioning, targeting, and smooth movement.
---

# Player Camera API (`api_player_camera`)

The Player Camera API provides powerful camera manipulation for implementing third-person views, spectator modes, cinematic cameras, and dynamic camera effects.

> **Reference**: See [README.md](https://github.com/hedgefog/amxx-modding-kit/api/player-camera/README.md) for complete documentation and examples.

---

## Overview

This API allows you to:
- Activate and deactivate custom player cameras
- Control camera offsets, angles, and distances
- Set target entities for camera focus
- Lock camera axes for stable views
- Adjust camera smoothness with damping

---

## Core Functions

### Activate/Deactivate Camera

```pawn
// Enable custom camera for player
PlayerCamera_Activate(pPlayer);

// Disable custom camera
PlayerCamera_Deactivate(pPlayer);

// Check if camera is active
if (PlayerCamera_IsActive(pPlayer)) {
  // Camera is enabled
}
```

### Set Camera Position

```pawn
// Set offset from player
new Float:vecOffset[3] = {0.0, 0.0, 50.0}; // Above player
PlayerCamera_SetOffset(pPlayer, vecOffset);

// Set camera angles
new Float:vecAngles[3] = {15.0, 0.0, 0.0}; // Looking down
PlayerCamera_SetAngles(pPlayer, vecAngles);

// Set distance from player
PlayerCamera_SetDistance(pPlayer, 100.0);
```

### Get Camera Origin

```pawn
new Float:vecCameraOrigin[3];
PlayerCamera_GetOrigin(pPlayer, vecCameraOrigin);
```

---

## Camera Settings

### Axis Lock

Restrict camera movement on specific axes:

```pawn
// Lock pitch and roll, allow yaw rotation
PlayerCamera_SetAxisLock(pPlayer, true, false, true);
```

Parameters: `bLockPitch`, `bLockYaw`, `bLockRoll`

### Target Entity

Focus camera on specific entity:

```pawn
// Camera follows target entity
PlayerCamera_SetTargetEntity(pPlayer, pTargetEntity);
```

### Think Delay

Adjust camera update frequency:

```pawn
// Update every 0.1 seconds (balance performance vs smoothness)
PlayerCamera_SetThinkDelay(pPlayer, 0.1);
```

### Damping (Smoothness)

Control camera movement smoothness:

```pawn
// 0.0 = no movement, 0.5 = smooth, 1.0 = instant
PlayerCamera_SetDamping(pPlayer, 0.5);
```

---

## Common Patterns

### Third-Person Camera

```pawn
ActivateThirdPersonCamera(const pPlayer) {
  PlayerCamera_Activate(pPlayer);
  
  // Position behind and above player
  new Float:vecOffset[3] = {0.0, -50.0, 30.0};
  PlayerCamera_SetOffset(pPlayer, vecOffset);
  
  // Look slightly down
  new Float:vecAngles[3] = {10.0, 0.0, 0.0};
  PlayerCamera_SetAngles(pPlayer, vecAngles);
  
  PlayerCamera_SetDistance(pPlayer, 150.0);
  PlayerCamera_SetDamping(pPlayer, 0.7);
}
```

### Toggle Camera Command

```pawn
public plugin_init() {
  register_clcmd("say /camera", "Command_ToggleCamera");
}

public Command_ToggleCamera(const pPlayer) {
  if (PlayerCamera_IsActive(pPlayer)) {
    PlayerCamera_Deactivate(pPlayer);
    client_print(pPlayer, print_chat, "Camera deactivated");
  } else {
    PlayerCamera_Activate(pPlayer);
    PlayerCamera_SetDistance(pPlayer, 100.0);
    client_print(pPlayer, print_chat, "Camera activated");
  }
  
  return PLUGIN_HANDLED;
}
```

### Spectator Camera

```pawn
SpectatePlayer(const pSpectator, const pTarget) {
  if (!is_user_alive(pTarget)) return;
  
  PlayerCamera_Activate(pSpectator);
  PlayerCamera_SetTargetEntity(pSpectator, pTarget);
  PlayerCamera_SetDistance(pSpectator, 150.0);
  PlayerCamera_SetDamping(pSpectator, 0.5);
  
  client_print(pSpectator, print_chat, "Spectating player");
}
```

### Fixed Angle Camera

```pawn
ActivateFixedCamera(const pPlayer) {
  PlayerCamera_Activate(pPlayer);
  
  // Lock all axes for completely fixed view
  PlayerCamera_SetAxisLock(pPlayer, true, true, true);
  
  // Set specific viewing angle
  new Float:vecAngles[3] = {45.0, 0.0, 0.0};
  PlayerCamera_SetAngles(pPlayer, vecAngles);
  
  PlayerCamera_SetDistance(pPlayer, 200.0);
}
```

### Cinematic Camera

```pawn
ActivateCinematicCamera(const pPlayer, const Float:vecTarget[3]) {
  PlayerCamera_Activate(pPlayer);
  
  // Smooth movement for cinematic feel
  PlayerCamera_SetDamping(pPlayer, 0.3);
  PlayerCamera_SetThinkDelay(pPlayer, 0.05);
  
  // High angle view
  new Float:vecOffset[3] = {0.0, 0.0, 100.0};
  PlayerCamera_SetOffset(pPlayer, vecOffset);
}
```

---

## Forwards

React to camera state changes:

```pawn
// Called when camera is about to activate (can block by returning PLUGIN_HANDLED)
public PlayerCamera_OnActivate(const pPlayer) {
  // Can block activation
}

// Called after camera is activated
public PlayerCamera_OnActivated(const pPlayer) {
  client_print(pPlayer, print_chat, "Camera enabled");
}

// Called when camera is about to deactivate (can block by returning PLUGIN_HANDLED)
public PlayerCamera_OnDeactivate(const pPlayer) {
  // Can block deactivation
}

// Called after camera is deactivated
public PlayerCamera_OnDeactivated(const pPlayer) {
  client_print(pPlayer, print_chat, "Camera disabled");
}
```

---

## Integration Tips

### Disable During Certain Actions

```pawn
public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
  // Disable camera when taking damage
  if (PlayerCamera_IsActive(pPlayer)) {
    PlayerCamera_Deactivate(pPlayer);
  }
  
  return HAM_IGNORED;
}
```

### Auto-Disable on Death

```pawn
public client_death(pPlayer) {
  if (PlayerCamera_IsActive(pPlayer)) {
    PlayerCamera_Deactivate(pPlayer);
  }
}
```

---

## Checklist

- [ ] Activate camera before setting properties
- [ ] Set appropriate damping for smooth movement
- [ ] Use axis lock for stable cinematic views
- [ ] Handle camera deactivation on player death/disconnect
- [ ] Consider performance with think delay setting
