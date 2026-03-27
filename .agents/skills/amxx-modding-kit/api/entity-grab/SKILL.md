---
name: amxx-modding-kit-api-entity-grab
description: Helps with Entity Grab API usage for attaching, carrying, and throwing entities.
---

# Entity Grab API (`api_entity_grab`)

The Entity Grab API provides a system for attaching entities to players, enabling "grab and carry" mechanics with automatic movement and collision handling.

> **Reference**: See [README.md](https://github.com/hedgefog/amxx-modding-kit/api/entity-grab/README.md) for complete documentation and examples.

---

## Overview

This API allows you to:
- Attach any entity to a player for carrying
- Handle entity movement and orientation automatically
- Implement grab, carry, and throw mechanics

---

## Core Functions

### Attach Entity to Player

```pawn
// Attach entity at specified distance from player
EntityGrab_Player_AttachEntity(pPlayer, pEntity, flDistance);
```

Parameters:
- `pPlayer`: The player index
- `pEntity`: The entity to grab
- `flDistance`: Distance in units from player to hold the entity

### Detach Entity from Player

```pawn
// Release the currently grabbed entity
EntityGrab_Player_DetachEntity(pPlayer);
```

### Query Grabbed Entity

```pawn
// Get entity currently attached to player
new pGrabbedEntity = EntityGrab_Player_GetAttachedEntity(pPlayer);
if (pGrabbedEntity != FM_NULLENT) {
  // Player is holding something
}
```

---

## Implementation Pattern

### Basic Grab System

```pawn
#include <api_entity_grab>

new g_pTrace;

public plugin_precache() {
  g_pTrace = create_tr2();
}

public plugin_end() {
  free_tr2(g_pTrace);
}
```

### Find Entity to Grab

```pawn
@Player_FindEntityToGrab(const &pPlayer, Float:flRange) {
  static Float:vecSrc[3]; ExecuteHamB(Ham_Player_GetGunPosition, pPlayer, vecSrc);
  static Float:vecAngles[3]; pev(pPlayer, pev_v_angle, vecAngles);
  
  static Float:vecEnd[3];
  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecEnd);
  xs_vec_add_scaled(vecSrc, vecEnd, flRange, vecEnd);
  
  engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, pPlayer, g_pTrace);
  
  static pHit; pHit = get_tr2(g_pTrace, TR_pHit);
  
  // Try hull trace if line trace missed
  if (pHit == FM_NULLENT) {
    engfunc(EngFunc_TraceHull, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, pPlayer, g_pTrace);
    pHit = get_tr2(g_pTrace, TR_pHit);
  }
  
  if (pHit == FM_NULLENT) return FM_NULLENT;
  if (!IsGrabbableEntity(pHit)) return FM_NULLENT;
  
  return pHit;
}
```

### Handle Input

```pawn
public HamHook_Player_PreThink(const pPlayer) {
  if (!is_user_alive(pPlayer)) return HAM_IGNORED;
  
  static iButtons; iButtons = pev(pPlayer, pev_button);
  static iOldButtons; iOldButtons = pev(pPlayer, pev_oldbuttons);
  
  // Toggle grab with USE key
  if (iButtons & IN_USE && ~iOldButtons & IN_USE) {
    static pGrabbed; pGrabbed = EntityGrab_Player_GetAttachedEntity(pPlayer);
    
    if (pGrabbed == FM_NULLENT) {
      // Try to grab entity in front of player
      static pEntity; pEntity = @Player_FindEntityToGrab(pPlayer, 64.0);
      if (pEntity != FM_NULLENT) {
        EntityGrab_Player_AttachEntity(pPlayer, pEntity, 48.0);
      }
    } else {
      // Release grabbed entity
      EntityGrab_Player_DetachEntity(pPlayer);
    }
  }
  
  return HAM_HANDLED;
}
```

---

## Common Patterns

### Throw Grabbed Entity

```pawn
ThrowGrabbedEntity(const pPlayer, Float:flThrowForce) {
  new pEntity = EntityGrab_Player_GetAttachedEntity(pPlayer);
  if (pEntity == FM_NULLENT) return;
  
  // Calculate throw direction
  static Float:vecVelocity[3]; pev(pPlayer, pev_velocity, vecVelocity);
  static Float:vecDirection[3]; pev(pPlayer, pev_v_angle, vecDirection);
  angle_vector(vecDirection, ANGLEVECTOR_FORWARD, vecDirection);
  
  // Add player velocity + throw force
  xs_vec_add_scaled(vecVelocity, vecDirection, flThrowForce, vecVelocity);
  
  // Detach and apply velocity
  EntityGrab_Player_DetachEntity(pPlayer);
  set_pev(pEntity, pev_velocity, vecVelocity);
}

// Usage in PreThink
if (iButtons & IN_ATTACK && ~iOldButtons & IN_ATTACK) {
  ThrowGrabbedEntity(pPlayer, 500.0);
}
```

### Check if Entity is Grabbable

```pawn
bool:IsGrabbableEntity(const pEntity) {
  if (pEntity == FM_NULLENT) return false;
  if (IS_PLAYER(pEntity)) return false;
  
  // Check solid type
  if (pev(pEntity, pev_solid) < SOLID_BBOX) return false;
  
  // Check classname for allowed types
  static szClassname[32]; pev(pEntity, pev_classname, szClassname, charsmax(szClassname));
  
  if (equal(szClassname, "prop")) return true;
  if (equal(szClassname, "item_crate")) return true;
  
  return false;
}
```

### Adjust Grab Distance

```pawn
// Scroll wheel to adjust distance
if (iButtons & IN_FORWARD) {
  new pEntity = EntityGrab_Player_GetAttachedEntity(pPlayer);
  if (pEntity != FM_NULLENT) {
    // Re-attach with new distance
    EntityGrab_Player_DetachEntity(pPlayer);
    EntityGrab_Player_AttachEntity(pPlayer, pEntity, flNewDistance);
  }
}
```

---

## Integration with Custom Entities

```pawn
// In custom entity plugin
@Entity_CanPickup(const this, const pPlayer) {
  // Prevent pickup while grabbed
  if (EntityGrab_Player_GetAttachedEntity(pPlayer) != FM_NULLENT) {
    return false;
  }
  
  return CE_CallBaseMethod(pPlayer);
}
```

---

## Checklist

- [ ] Initialize trace handle in `plugin_precache`
- [ ] Free trace handle in `plugin_end`
- [ ] Check `FM_NULLENT` before operations
- [ ] Validate entity is grabbable before attaching
- [ ] Handle grab/release in player PreThink hook
- [ ] Consider throw mechanic for complete implementation
