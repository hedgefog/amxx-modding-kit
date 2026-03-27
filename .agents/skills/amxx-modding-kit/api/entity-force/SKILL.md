---
name: amxx-modding-kit-api-entity-force
description: Helps with Entity Force API usage for applying forces to entities including pushing, momentum transfer, and physics simulation.
---

# Entity Force API (`api_entity_force`)

The Entity Force API provides physics-based force application to entities, supporting pushing, momentum transfer, and advanced force calculations.

> **Reference**: See [api_entity_force.inc](https://github.com/hedgefog/amxx-modding-kit/api/entity-force/include/api_entity_force.inc) for all available natives.

---

## Overview

This API allows you to:
- Add directional forces to entities
- Push entities from other entities or origins
- Transfer momentum between entities
- Apply forces with various modes and flags

---

## Core Functions

### Add Direct Force

```pawn
// Add force vector to entity
new Float:vecForce[3] = {0.0, 0.0, 500.0}; // Upward force
EntityForce_Add(pEntity, vecForce);
```

### Apply Accumulated Forces

```pawn
// Forces are accumulated and applied together
EntityForce_Add(pEntity, vecForce1);
EntityForce_Add(pEntity, vecForce2);
EntityForce_Apply(pEntity); // Apply all accumulated forces
```

### Clear Forces

```pawn
// Clear all pending forces without applying
EntityForce_Clear(pEntity);
```

---

## Force Sources

### Push from Entity

```pawn
// Push target entity away from source entity
EntityForce_AddFromEntity(pTarget, pSourceEntity, flForce);
```

### Push from Origin

```pawn
// Push entity away from a point
new Float:vecExplosionOrigin[3] = {100.0, 200.0, 50.0};
EntityForce_AddFromOrigin(pEntity, vecExplosionOrigin, 500.0);
```

### Push from Bounding Box

For more complex push calculations based on overlap depth:

```pawn
// Push entity based on overlap with a bounding box
EntityForce_AddFromBBox(
  pEntity,
  vecAbsMin,           // BBox min corner
  vecAbsMax,           // BBox max corner
  flForce,             // Force magnitude
  EntityForce_Flag_None,
  0.0,                 // Min depth ratio
  1.0,                 // Max depth ratio
  0.0,                 // Soft min (gradual force start)
  1.0                  // Soft max (gradual force end)
);
```

---

## Momentum Transfer

Transfer velocity/momentum from one entity to another:

```pawn
// Transfer momentum from projectile to target
EntityForce_TransferMomentum(pProjectile, pTarget, 1.0); // Full transfer

// Partial transfer (knockback effect)
EntityForce_TransferMomentum(pProjectile, pTarget, 0.5); // 50% transfer
```

---

## Force Flags

Use flags to modify force application behavior:

```pawn
enum EntityForce_Flags {
  EntityForce_Flag_None = 0,
  EntityForce_Flag_Set,            // Replace existing forces
  EntityForce_Flag_Overlap,        // Overlap mode
  EntityForce_Flag_ForceSetOutOfSoft,
  EntityForce_Flag_Launch,         // Launch entity
  EntityForce_Flag_Attack          // Attack impulse
};
```

### Examples

```pawn
// Set force (replace existing)
EntityForce_Add(pEntity, vecForce, EntityForce_Flag_Set);

// Launch entity upward
new Float:vecLaunch[3] = {0.0, 0.0, 800.0};
EntityForce_Add(pEntity, vecLaunch, EntityForce_Flag_Launch);
```

---

## Common Patterns

### Explosion Knockback

```pawn
CreateExplosion(const Float:vecOrigin[3], Float:flRadius, Float:flForce) {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_alive(pPlayer)) continue;
    
    static Float:vecPlayerOrigin[3]; pev(pPlayer, pev_origin, vecPlayerOrigin);
    static Float:flDistance; flDistance = get_distance_f(vecOrigin, vecPlayerOrigin);
    
    if (flDistance > flRadius) continue;
    
    // Scale force by distance
    static Float:flScaledForce; flScaledForce = flForce * (1.0 - (flDistance / flRadius));
    
    EntityForce_AddFromOrigin(pPlayer, vecOrigin, flScaledForce);
    EntityForce_Apply(pPlayer);
  }
}
```

### Projectile Impact Knockback

```pawn
@Projectile_Touch(const this, const pTarget) {
  CE_CallBaseMethod(pTarget);
  
  if (IS_PLAYER(pTarget)) {
    // Transfer projectile momentum to target
    EntityForce_TransferMomentum(this, pTarget, 0.3);
    EntityForce_Apply(pTarget);
  }
}
```

### Push Zone

```pawn
@TriggerPush_Touch(const this, const pTarget) {
  static Float:vecPushDir[3]; pev(this, pev_movedir, vecPushDir);
  static Float:flSpeed; pev(this, pev_speed, flSpeed);
  
  static Float:vecForce[3];
  xs_vec_mul_scalar(vecPushDir, flSpeed, vecForce);
  
  EntityForce_Add(pTarget, vecForce);
  EntityForce_Apply(pTarget);
}
```

---

## Forwards

Hook into force events:

```pawn
// Called when force is added to entity
public EntityForce_OnForceAdd(const pEntity, const Float:vecForce[3], EntityForce_Flags:iFlags) {
  // Modify or block force...
}

// Called when forces are applied
public EntityForce_OnForceApply(const pEntity, const Float:vecForce[3]) {
  // React to force application...
}
```

---

## Checklist

- [ ] Use `EntityForce_Add` to accumulate forces
- [ ] Call `EntityForce_Apply` to apply accumulated forces
- [ ] Use `EntityForce_AddFromOrigin` for explosion-style knockback
- [ ] Use `EntityForce_TransferMomentum` for projectile impacts
- [ ] Scale forces by distance for realistic explosions
