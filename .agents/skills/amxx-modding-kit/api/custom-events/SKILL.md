---
name: amxx-modding-kit-api-custom-events
description: Guide for implementing custom events using pub/sub pattern in AMX Mod X. Use when creating event-driven communication between plugins with the Custom Events API.
---

# Custom Events API

Pub/sub event system for decoupled plugin communication with typed parameters.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/custom-events/README.md).

---

## Event Naming Convention

Use `#define` with `EVENT_` prefix:

```pawn
#define EVENT_PLAYER_HIT "myplugin.player.hit"
#define EVENT_ROUND_STARTED "myplugin.round.started"
#define EVENT_ITEM_PURCHASED "myplugin.item.purchased"
```

---

## Registering Events

Register events with typed parameters in `plugin_precache`:

```pawn
public plugin_precache() {
  // Simple event with one parameter
  CustomEvent_Register(EVENT_PLAYER_HIT, CEP_Cell); // pPlayer
  
  // Event with multiple parameters
  CustomEvent_Register(EVENT_DAMAGE_DEALT, CEP_Cell, CEP_Cell, CEP_Float); // pVictim, pAttacker, flDamage
  
  // Event with array parameter
  CustomEvent_Register(EVENT_POSITION_CHANGED, CEP_Cell, CEP_FloatArray, 3); // pEntity, vecOrigin[3]
}
```

### Parameter Types

| Type | Description |
|------|-------------|
| `CEP_Cell` | Integer/entity/boolean |
| `CEP_Float` | Float value |
| `CEP_String` | String |
| `CEP_Array` | Integer array (follow with size) |
| `CEP_FloatArray` | Float array (follow with size) |

---

## Subscribing to Events

Subscribe in `plugin_init`:

```pawn
public plugin_init() {
  CustomEvent_Subscribe(EVENT_PLAYER_HIT, "EventSubscriber_PlayerHit");
  CustomEvent_Subscribe(EVENT_DAMAGE_DEALT, "EventSubscriber_DamageDealt");
}
```

### Subscriber Implementation

Callback naming: `EventSubscriber_{EventName}`

```pawn
public EventSubscriber_PlayerHit(const pPlayer) {
  client_print(0, print_chat, "Player %d was hit!", pPlayer);
}

public EventSubscriber_DamageDealt(const pVictim, const pAttacker, Float:flDamage) {
  log_amx("Damage: %.1f from %d to %d", flDamage, pAttacker, pVictim);
}
```

---

## Emitting Events

### Simple Event

```pawn
CustomEvent_Emit(EVENT_ROUND_STARTED);
```

### Event with Parameters

```pawn
CustomEvent_Emit(EVENT_PLAYER_HIT, pPlayer);
CustomEvent_Emit(EVENT_DAMAGE_DEALT, pVictim, pAttacker, flDamage);
```

### Event with Activator

Set activator entity before emitting for context:

```pawn
CustomEvent_SetActivator(pPlayer);
CustomEvent_Emit(EVENT_PLAYER_HIT, pPlayer);
```

---

## Global Forward

Handle all events in one place using `CustomEvent_OnEmit`:

```pawn
public CustomEvent_OnEmit(const szEvent[], const pActivator) {
  if (equal(szEvent, EVENT_PLAYER_HIT)) {
    new pPlayer = CustomEvent_GetParam(1);
    // Handle hit event...
    // pActivator contains the entity set via CustomEvent_SetActivator
    return PLUGIN_CONTINUE;
  }
  
  return PLUGIN_CONTINUE;
}
```

---

## Common Pattern: Cross-Plugin Communication

```pawn
#define EVENT_PLAYER_INFECTED "myplugin.player.infected"

// Emitter plugin
InfectPlayer(const pPlayer, const pInfector) {
  g_rgbPlayerInfected[pPlayer] = true;
  
  CustomEvent_SetActivator(pPlayer);
  CustomEvent_Emit(EVENT_PLAYER_INFECTED, pPlayer, pInfector);
}

// Subscriber plugin
public plugin_init() {
  CustomEvent_Subscribe(EVENT_PLAYER_INFECTED, "EventSubscriber_PlayerInfected");
}

public EventSubscriber_PlayerInfected(const pPlayer, const pInfector) {
  // React to infection in another plugin...
}
```

---

## Common Pattern: Blocking Events

Return `PLUGIN_HANDLED` from global forward to prevent event propagation:

```pawn
public CustomEvent_OnEmit(const szEvent[], const pActivator) {
  if (equal(szEvent, EVENT_PLAYER_PURCHASE)) {
    new pPlayer = CustomEvent_GetParam(1);
    
    if (!CanPlayerPurchase(pPlayer)) {
      return PLUGIN_HANDLED; // Block event
    }
  }
  
  return PLUGIN_CONTINUE;
}
```

---

## Checklist

- [ ] Define event constants with `#define EVENT_` prefix
- [ ] Register events with typed parameters in `plugin_precache`
- [ ] Subscribe in `plugin_init`
- [ ] Use `EventSubscriber_` prefix for callbacks
- [ ] Set activator before emitting when context matters
