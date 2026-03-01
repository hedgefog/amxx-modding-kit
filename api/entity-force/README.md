# 💥 Entity Force API

The **Entity Force API** provides a physics-like force system for GoldSrc entities. It supports force accumulation, directional pushes, bounding box-based repulsion, and momentum transfer between entities.

## 🚀 Features

- **Force Accumulation**: Add multiple forces before applying them in a single frame
- **Directional Pushes**: Push entities away from a point, entity, or bounding box
- **Momentum Transfer**: Transfer velocity between entities on collision
- **Force Flags**: Control force behavior with add, set, and overlap modes
- **Climb Prevention**: Automatically prevents players from climbing after being pushed
- **Event Hooks**: React to force additions and applications via forwards

## 📚 Usage

### Adding and Applying Force

Forces are accumulated per-entity and applied automatically each frame. You can also add and apply manually:

```pawn
// Add a force vector to an entity
new Float:vecForce[3] = {0.0, 0.0, 500.0}; // Push upward
EntityForce_Add(pEntity, vecForce);

// Forces are applied automatically on the next think/frame
// Or apply immediately:
EntityForce_Apply(pEntity);
```

### Force Flags

Use flags to control how forces are combined:

```pawn
// Add: accumulates with existing force (default)
EntityForce_Add(pEntity, vecForce, EntityForce_Flag_None);

// Set: replaces the current velocity on affected axes
EntityForce_Add(pEntity, vecForce, EntityForce_Flag_Set);

// Overlap: only affects axes where the force is non-zero
EntityForce_Add(pEntity, vecForce, EntityForce_Flag_Overlap);
```

### Pushing From a Point or Entity

Push an entity away from a specific origin or another entity:

```pawn
// Push away from an explosion origin
new Float:vecExplosionOrigin[3] = {100.0, 200.0, 0.0};
EntityForce_AddFromOrigin(pEntity, vecExplosionOrigin, 500.0);

// Push away from another entity
EntityForce_AddFromEntity(pEntity, pPusher, 300.0);
```

### Bounding Box Repulsion

Push entities out of a bounding box area with depth-based force scaling:

```pawn
new Float:vecMin[3] = {-64.0, -64.0, -64.0};
new Float:vecMax[3] = {64.0, 64.0, 64.0};

EntityForce_AddFromBBox(pEntity, vecMin, vecMax, 200.0);
```

### Momentum Transfer

Transfer velocity from one entity to another, simulating collision physics:

```pawn
// Transfer 80% of source's momentum to target
EntityForce_TransferMomentum(pSource, pTarget, 0.8);
```

### Clearing Forces

Remove all accumulated forces before they are applied:

```pawn
EntityForce_Clear(pEntity);
```

### Responding to Force Events

Use forwards to react when forces are added or applied:

```pawn
public EntityForce_OnForceAdd(const pEntity, const Float:vecForce[3], EntityForce_Flags:iFlags) {
  // A force was added to an entity
}

public EntityForce_OnForceApply(const pEntity, const Float:vecForce[3]) {
  // Accumulated forces were applied to an entity
}
```

## 🧩 Example: Explosion Push

```pawn
#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_entity_force>

public plugin_init() {
  register_plugin("Explosion Command", "1.0.0", "Hedgehog Fog");

  register_clcmd("say /boom", "Command_Boom");
}

public Command_Boom(const pPlayer) {
  new Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);

  // Push all nearby players away from the explosion
  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!is_user_alive(pTarget)) continue;

    new Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
    new Float:flDistance = xs_vec_distance(vecOrigin, vecTargetOrigin);

    if (flDistance > 512.0) continue;

    new Float:flForce = 800.0 * (1.0 - (flDistance / 512.0));
    EntityForce_AddFromOrigin(pTarget, vecOrigin, flForce);
  }

  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/zerogxplode.spr");
  }

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_EXPLOSION);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_short(iModelIndex);
  write_byte(100);
  write_byte(15);
  write_byte(TE_EXPLFLAG_NONE);
  message_end();

  return PLUGIN_HANDLED;
}
```

---

## 📖 API Reference

See [`api_entity_force.inc`](include/api_entity_force.inc) and [`api_entity_force_const.inc`](include/api_entity_force_const.inc) for all available natives, forwards, and constants.
