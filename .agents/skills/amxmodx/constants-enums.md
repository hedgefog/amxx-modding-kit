---
name: amxmodx-constants-enums
description: AMX Mod X constants and enum definition patterns.
globs: "*.sma,*.inc"
---

# Constants & Enums

## Define Constants

```pawn
#define RESPAWN_DELAY 5.0
#define MISFIRE_DELAY 10.0
#define MISFIRE_MAX_SHAKING 0.25

#define SHIELD_WIDTH 36.0
#define SHIELD_HEIGHT 48.0
```

## Enums

### Named Enums

```pawn
enum PlayerAttribute {
  PlayerAttribute_Resistance = 0,
  PlayerAttribute_Power
};

enum EntityRelationship {
  EntityRelationship_None = 0,
  EntityRelationship_Shared,
  EntityRelationship_Team,
  EntityRelationship_Owner
};
```

### Anonymous Enums (for IDs)

```pawn
enum {
  WeaponId_Snowball = 1,
  WeaponId_Slingshot = 3,
  WeaponId_FireworksBox = 4
};
```

### Enum for Menu Items

```pawn
enum TeamMenu_Item {
  TeamMenu_Item_First,
  TeamMenu_Item_Second,
  TeamMenu_Item_Third
};
```

> **Note**: For large projects with namespace prefixes (`MyMod_*` pattern), see [amxx-modding-kit-project](mdc:.agent/skills/amxx-modding-kit-project/SKILL.md).

## Task ID Constants

Define `TASKID_*` constants with high enough step between values to avoid collision:

```pawn
#define TASKID_RESPAWN 100
#define TASKID_ACTIVATE_VISION 200
#define TASKID_REMOVE_EFFECT 300
```

## Best Practices

1. **Use descriptive enum names** with `EnumName_Value` pattern
2. **Use anonymous enums** for simple ID collections
3. **Use enums for menu items** to avoid index mistakes
4. **Space TASKID constants** by at least `MAX_PLAYERS + 1` for player tasks or max entities for entity tasks
