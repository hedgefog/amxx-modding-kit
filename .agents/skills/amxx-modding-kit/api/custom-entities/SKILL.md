---
name: amxx-modding-kit-api-custom-entities
description: Guide for implementing custom entities using OOP-style patterns in AMX Mod X. Use when creating projectiles, pickups, NPCs, or any custom game entity with the Custom Entities API.
---

# Custom Entities API

OOP-style entity system for creating reusable entity classes with methods, members, and inheritance.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/custom-entities/README.md).

---

## Naming Conventions

### Member Constants

Use `m_` prefix with Hungarian notation type prefix:

```pawn
// Format: m_{Type}{Name}
new const m_flDamage[] = "flDamage";     // float - damage amount
new const m_flSpeed[] = "flSpeed";       // float - movement speed
new const m_pTarget[] = "pTarget";       // pointer - target entity
new const m_bGuided[] = "bGuided";       // bool - auto-guidance enabled
new const m_iType[] = "iType";           // int - entity type
```

### Method Constants

Use PascalCase name only (no prefix):

```pawn
new const Launch[] = "Launch";
new const Explode[] = "Explode";
new const CanTakeDamage[] = "CanTakeDamage";
```

---

## Class Registration

```pawn
public plugin_precache() {
  // Precache resources BEFORE registration
  precache_model(g_szModel);
  precache_sound(g_szExplodeSound);
  
  // Register class with optional preset base class
  CE_RegisterClass(ENTITY_NAME);
  // Or extend: CE_RegisterClass(ENTITY_NAME, CE_Class_BaseItem);
  
  // Implement base methods (override virtual methods)
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Create, "@Entity_Create");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Spawn, "@Entity_Spawn");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Touch, "@Entity_Touch");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Think, "@Entity_Think");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Killed, "@Entity_Killed");
  
  // Register custom methods
  CE_RegisterClassMethod(ENTITY_NAME, Launch, "@Entity_Launch", CE_Type_Cell);
  
  // Bind map key-values to members
  CE_RegisterClassKeyMemberBinding(ENTITY_NAME, "damage", m_flDamage, CEMemberType_Float);
}
```

---

## Members Usage

### Get Member

```pawn
static szModel[64]; CE_GetMemberString(this, CE_Member_szModel, szModel, charsmax(szModel));
static Float:vecMins[3]; CE_GetMemberVec(this, CE_Member_vecMins, vecMins);
new Float:flDamage = CE_GetMember(this, m_flDamage);
new iType = CE_GetMember(this, m_iType);
```

### Set Member

```pawn
CE_SetMemberString(this, CE_Member_szModel, g_szModel);
CE_SetMemberVec(this, CE_Member_vecMins, Float:{-8.0, -8.0, 0.0});
CE_SetMember(this, m_flDamage, 50.0);
CE_SetMember(this, m_iType, 1);
```

### Conditions

When you need to get float member value in conditions or for other inline operations you should explicitly provide `Float:` tag to make sure compiler will use correct type.

```pawn
if (Float:CE_GetMember(this, m_flNextUpdate) <= get_gametime()) {
  // Do something
}
```

---

## Method Implementation

### Create Method (Constructor)

Set up default member values. **Never modify pev/engine data here.**

```pawn
@Entity_Create(const this) {
  CE_CallBaseMethod();
  
  // Set built-in members
  CE_SetMemberString(this, CE_Member_szModel, g_szModel);
  CE_SetMemberVec(this, CE_Member_vecMins, Float:{-8.0, -8.0, 0.0});
  CE_SetMemberVec(this, CE_Member_vecMaxs, Float:{8.0, 8.0, 16.0});
  
  // Set custom members
  CE_SetMember(this, m_flDamage, 50.0);
  CE_SetMember(this, m_flSpeed, 1000.0);
  
  // ❌ WRONG: Don't use set_pev/engfunc here
  // set_pev(this, pev_movetype, MOVETYPE_FLY);
}
```

### Spawn Method

Configure engine properties after entity is fully created:

```pawn
@Entity_Spawn(const this) {
  CE_CallBaseMethod();
  
  set_pev(this, pev_movetype, MOVETYPE_FLY);
  set_pev(this, pev_solid, SOLID_BBOX);
  set_pev(this, pev_nextthink, get_gametime() + 0.1);
}
```

### Think Method

Recurring logic with static variables for performance:

```pawn
@Entity_Think(const this) {
  static Float:flSpeed; flSpeed = CE_GetMember(this, m_flSpeed);
  static pOwner; pOwner = pev(this, pev_owner);
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
  
  // Entity logic...
  
  CE_CallBaseMethod();
  set_pev(this, pev_nextthink, get_gametime() + 0.1);
}
```

### Touch Method

Handle collisions:

```pawn
@Entity_Touch(const this, const pTarget) {
  CE_CallBaseMethod(pTarget);
  
  if (pev(pTarget, pev_solid) < SOLID_BBOX) return;
  
  static pOwner; pOwner = pev(this, pev_owner);
  static Float:flDamage; flDamage = CE_GetMember(this, m_flDamage);
  
  if (IS_PLAYER(pTarget)) {
    ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_GENERIC);
  }
  
  ExecuteHamB(Ham_Killed, this, 0, 0);
}
```

### Killed Method

Handle entity destruction:

```pawn
@Entity_Killed(const this, const pKiller) {
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
  
  // Play explosion effect
  emit_sound(this, CHAN_BODY, g_szExplodeSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  
  CE_CallBaseMethod(pKiller);
}
```

---

## Creating Entities

```pawn
new pEntity = CE_Create(ENTITY_NAME, vecOrigin);
if (pEntity != FM_NULLENT) {
  CE_SetMember(pEntity, m_flDamage, 100.0);
  set_pev(pEntity, pev_owner, pPlayer);
  dllfunc(DLLFunc_Spawn, pEntity);
}
```

---

## Calling Methods

```pawn
// Call custom method
CE_CallMethod(pEntity, Launch, pTarget);

// Call method and get return value
new bool:bCanDamage = CE_CallMethod(pEntity, CanTakeDamage, pAttacker);
```

---

## Calling Parent Methods

Always call `CE_CallBaseMethod()` to invoke parent implementation:

```pawn
@Entity_TakeDamage(const this, const pInflictor, const pAttacker, Float:flDamage, iDamageBits) {
  if (!CE_CallMethod(this, CanTakeDamage, pInflictor, pAttacker)) return;
  
  CE_CallBaseMethod(pInflictor, pAttacker, flDamage, iDamageBits);
}
```

---

## Entity Hooks (External Plugins)

Listen to entity events from other plugins:

```pawn
public plugin_init() {
  CE_RegisterClassNativeMethodHook(ENTITY_NAME, CE_Method_Spawn, "CEHook_Projectile_Spawn");
  CE_RegisterClassNativeMethodHook(ENTITY_NAME, CE_Method_Spawn, "CEHook_Projectile_Spawn_Post", true);
}

public CEHook_Projectile_Spawn(const pEntity) {
  // React to entity spawn (pre-hook)...
}

public CEHook_Projectile_Spawn_Post(const pEntity) {
  // React after entity spawn (post-hook)...
}
```

Hook callback naming: `CEHook_{EntityName}_{Method}` (add `_Post` suffix for post-hooks)

```pawn
public CEHook_Projectile_Touch(const pProjectile, const pToucher)
public CEHook_ItemPickup_Spawn(const pEntity)
```

---

## Check Entity Type

```pawn
// Check if entity is instance of specific class (includes inherited classes)
if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
  // Entity is of this type or inherits from it
}

// Get entity classname
new szClassname[32];
pev(pEntity, pev_classname, szClassname, charsmax(szClassname));
```

---

## Suppress Unwanted Entities

Use `CE_RegisterNullClass` to suppress map/game entities that you don't need:

```pawn
public plugin_precache() {
  // Suppress CS-specific entities when creating custom game mode
  CE_RegisterNullClass("armoury_entity");
  CE_RegisterNullClass("weapon_shield");
  CE_RegisterNullClass("game_player_equip");
  CE_RegisterNullClass("player_weaponstrip");
  CE_RegisterNullClass("hostage_entity");
  CE_RegisterNullClass("func_buyzone");
}
```

---

## Entity Class Aliases

Use `CE_RegisterClassAlias` to replace map entities with custom implementations:

```pawn
public plugin_precache() {
  // Replace HL2 entities with custom implementations
  CE_RegisterClassAlias("item_healthkit", ENTITY(HealthKit));
  CE_RegisterClassAlias("item_battery", ENTITY(Armor));
  
  // Replace CS entities
  CE_RegisterClassAlias("func_vip_safetyzone", ENTITY(EndRoundTrigger));
}
```

---

## Complete Entity Plugin Structure

```pawn
#pragma semicolon 1

#include <amxmodx>

#include <api_custom_entities>

/*--------------------------------[ Constants ]--------------------------------*/

#define ENTITY_NAME "test"
#define Test "Test"

/*--------------------------------[ Assets ]--------------------------------*/

new const g_szModel[] = "models/w_security.mdl";

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  precache_model(g_szModel);

  CE_RegisterClass(ENTITY_NAME);
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Create, "@Entity_Create");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Spawn, "@Entity_Spawn");

  CE_RegisterClassMethod(ENTITY_NAME, Test, "@Entity_Test", CE_Type_Cell);
}

public plugin_init() {
  register_plugin("[Entity] Test", "1.0.0", "Author");
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Create(const this) {
  CE_CallBaseMethod();

  CE_SetMemberVec(this, CE_Member_vecMins, Float:{-4.0, -4.0, -4.0});
  CE_SetMemberVec(this, CE_Member_vecMaxs, Float:{4.0, 4.0, 4.0});
  CE_SetMemberString(this, CE_Member_szModel, g_szModel);
}

@Entity_Spawn(const this) {
  CE_CallBaseMethod();

  set_pev(this, pev_solid, SOLID_BBOX);
  set_pev(this, pev_movetype, MOVETYPE_TOSS);
}

@Entity_Test(const this, iParam) {
  log_amx("Entity test method called with param: %d", iParam);

  return true;
}
```

---

## Best Practices Checklist

- [ ] Precache resources BEFORE `CE_RegisterClass`
- [ ] Use `Create` for member initialization only
- [ ] Use `Spawn` for engine/pev modifications
- [ ] Check `FM_NULLENT` after `CE_Create`
- [ ] Call `dllfunc(DLLFunc_Spawn, pEntity)` after creating entity
- [ ] Use static variables in Think/Touch for performance
- [ ] Define member constants with `m_` prefix and Hungarian notation
- [ ] Define method constants with PascalCase only (no prefix)
- [ ] Use `CE_RegisterNullClass` to suppress unwanted entities
- [ ] Use `CE_RegisterClassAlias` to replace map entities with custom implementations or provide extra classname for existing class