# Entities

Reusable custom entity implementations built with the Custom Entities API.

## 🔥 Fire Entity

The **Fire Entity** creates dynamic fire that can attach to and spread between entities. Features include damage over time, visual effects (flames, smoke, light), and automatic extinguishing in water.

### Features

- **Damage over time** with customizable damage rate
- **Fire spreading** to nearby entities
- **Visual effects** - flames, smoke particles, and dynamic lighting
- **Attachment** - fire follows and burns attached entities
- **Water interaction** - automatically extinguishes in water
- **Damage stacking prevention** - multiple fires don't stack damage by default

### Basic Usage

```pawn
#include <api_custom_entities>
#include <entity_fire_const>

// Create fire at a position
new Float:vecOrigin[3] = {100.0, 200.0, 50.0};
new pFire = CE_Create(ENTITY_FIRE, vecOrigin);
if (pFire != FM_NULLENT) {
  // Optional: Set custom properties
  CE_SetMember(pFire, Entity_Fire_Member_flDamage, 10.0);
  CE_SetMember(pFire, Entity_Fire_Member_bAllowSpread, true);
  
  // Optional: Set owner for damage attribution
  set_pev(pFire, pev_owner, pPlayer);
  
  dllfunc(DLLFunc_Spawn, pFire);
}
```

### Ignite an Entity

```pawn
IgniteEntity(const pTarget, const pAttacker) {
  new Float:vecOrigin[3];
  pev(pTarget, pev_origin, vecOrigin);
  
  new pFire = CE_Create(ENTITY_FIRE, vecOrigin);
  if (pFire == FM_NULLENT) return;
  
  set_pev(pFire, pev_owner, pAttacker);
  dllfunc(DLLFunc_Spawn, pFire);
  
  // Attach fire to target
  CE_CallMethod(pFire, Entity_Fire_Method_Attach, pTarget);
}
```

### Map Entity Placement

Fire can be placed in maps with the following key-values:

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `damage` | float | Damage per second | CVar `fire_damage` |
| `lifetime` | float | How long fire burns (seconds) | CVar `fire_life_time` |
| `range` | float | Spread range | CVar `fire_spread_range` |
| `spread` | int | Allow spreading (0/1) | 1 |

### Console Variables

| CVar | Default | Description |
|------|---------|-------------|
| `fire_damage` | 5.0 | Base damage per second |
| `fire_spread` | 1 | Enable fire spreading |
| `fire_spread_range` | 16.0 | Distance fire can spread |
| `fire_life_time` | 10.0 | Default fire lifetime |

### Members

| Member | Type | Description |
|--------|------|-------------|
| `flDamage` | float | Damage per second |
| `bAllowSpread` | bool | Can fire spread to other entities |
| `flSpreadRange` | float | Maximum spread distance |
| `bAllowStacking` | bool | Allow damage stacking from multiple fires |

### Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `Attach` | `pTarget` | Attach fire to an entity |
| `Spread` | `pTarget` | Attempt to spread fire to target |
| `CanIgnite` | `pTarget` | Check if target can be ignited |
| `Damage` | `pTarget` | Deal damage to target |
| `CanSpread` | - | Check if fire can spread |

### Behavior Notes

- Fire automatically dies when its attached entity is destroyed
- Fire extinguishes when touching `func_water` entities
- Damage does not stack by default (multiple fires on same entity share damage)
- Fire adjusts its size to match the bounding box of attached entities
- Sound volume scales with fire size
