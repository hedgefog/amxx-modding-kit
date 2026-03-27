---
name: amxx-modding-kit-api-custom-weapons
description: Guide for implementing custom weapons using OOP-style patterns in AMX Mod X. Use when creating new weapons or extending existing ones with the Custom Weapons API.
---

# Custom Weapons API

OOP-style weapon system for creating and extending weapons with custom behavior.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/custom-weapons/README.md).

---

## Naming Conventions

### Member Constants

Use `m_` prefix with Hungarian notation type prefix:

```pawn
// Format: m_{Type}{Name}
new const m_flChargeTime[] = "flChargeTime";   // float - charge start time
new const m_bSilenced[] = "bSilenced";         // bool - silencer attached
new const m_iFireMode[] = "iFireMode";         // int - current fire mode
new const m_pTarget[] = "pTarget";             // pointer - locked target
```

### Method Constants

Use PascalCase name only (no prefix):

```pawn
new const SetPower[] = "SetPower";
new const ToggleSilencer[] = "ToggleSilencer";
new const StartCharge[] = "StartCharge";
```

---

## Class Registration

```pawn
public plugin_precache() {
  // Precache resources BEFORE registration
  precache_model(g_szModelV);
  precache_model(g_szModelP);
  precache_model(g_szModelW);
  precache_sound(g_szShotSound);
  
  // Register new weapon class
  CW_RegisterClass(WEAPON_NAME);
  // Or extend existing: CW_RegisterClass(WEAPON_NAME, "weapon_ak47");
  
  // Implement base methods (override virtual methods)
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Deploy, "@Weapon_Deploy");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Reload, "@Weapon_Reload");
  
  // Register custom methods
  CW_RegisterClassMethod(WEAPON_NAME, SetPower, "@Weapon_SetPower", CW_Type_Cell);
}
```

---

## Members Usage

### Get Member

```pawn
static szModel[64]; CW_GetMemberString(this, CW_Member_szModel, szModel, charsmax(szModel));
static Float:vecSpread[3]; CW_GetMemberVec(this, m_vecSpread, vecSpread);
new Float:flChargeTime = CW_GetMember(this, m_flChargeTime);
new iFireMode = CW_GetMember(this, m_iFireMode);
```

### Set Member

```pawn
CW_SetMemberString(this, CW_Member_szModel, g_szModelW);
CW_SetMemberVec(this, m_vecSpread, Float:{0.02, 0.02, 0.0});
CW_SetMember(this, m_flChargeTime, 0.0);
CW_SetMember(this, m_iFireMode, 1);
```

### Conditions

When you need to get float member value in conditions or for other inline operations you should explicitly provide `Float:` tag to make sure compiler will use correct type.

```pawn
if (Float:CW_GetMember(this, m_flNextUpdate) <= get_gametime()) {
  // Do something
}
```

---

## Method Implementation

### Create Method (Constructor)

Set weapon properties. **Never modify engine data here.**

```pawn
@Weapon_Create(const this) {
  CW_CallBaseMethod();
  
  // Built-in members
  CW_SetMemberString(this, CW_Member_szModel, g_szModelW);
  CW_SetMember(this, CW_Member_iId, WEAPON_ID);
  CW_SetMember(this, CW_Member_iMaxClip, 30);
  CW_SetMember(this, CW_Member_iSlot, WEAPON_SLOT);
  CW_SetMember(this, CW_Member_iPosition, WEAPON_POSITION);
  
  // Custom members
  CW_SetMember(this, m_flChargeTime, 0.0);
  CW_SetMember(this, m_bSilenced, false);
  
  // ❌ WRONG: Don't use engine functions here
  // set_pev(this, pev_dmg, 50.0);
}
```

### Deploy Method

Handle weapon draw:

```pawn
@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  
  // Use native method for default deploy behavior
  CW_CallNativeMethod(this, CW_Method_DefaultDeploy, g_szModelV, g_szModelP, ANIM_DRAW, "rifle");
}
```

### PrimaryAttack Method

Handle shooting:

```pawn
@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();
  
  static Float:vecSpread[3]; vecSpread = Float:{0.02, 0.02, 0.0};
  
  // DefaultShot returns true if shot was fired
  if (CW_CallNativeMethod(this, CW_Method_DefaultShot, 25.0, 1.0, 0.1, vecSpread, 1)) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szShotSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}
```

### Reload Method

Handle reloading:

```pawn
@Weapon_Reload(const this) {
  CW_CallBaseMethod();

  if (CW_CallNativeMethod(this, CW_Method_DefaultReload, ANIM_RELOAD, 2.5)) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szReloadSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}
```

### Think Method

Recurring logic with static variables for performance:

```pawn
@Weapon_Think(const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static Float:flChargeTime; flChargeTime = CW_GetMember(this, m_flChargeTime);
  
  // Weapon logic...
  
  CW_CallBaseMethod();
}
```

---

## Creating Weapons

### Give to Player

```pawn
// Give weapon to player
new pWeapon = CW_Give(pPlayer, WEAPON_NAME);
if (pWeapon != FM_NULLENT) {
  CW_SetMember(pWeapon, m_flChargeTime, 0.0);
}
```

### Create Entity

```pawn
// Create weapon entity (for world placement)
new pWeapon = CW_Create(WEAPON_NAME);
if (pWeapon != FM_NULLENT) {
  engfunc(EngFunc_SetOrigin, pWeapon, vecOrigin);
  dllfunc(DLLFunc_Spawn, pWeapon);
}
```

### Check Player Has Weapon

```pawn
if (CW_PlayerHasWeapon(pPlayer, WEAPON_NAME)) {
  // Player has this weapon
}

// Get weapon entity from player inventory
new pWeapon = CW_PlayerFindWeapon(pPlayer, WEAPON_NAME);
if (pWeapon != FM_NULLENT) {
  // Found weapon entity
}
```

---

## Calling Methods

```pawn
// Call custom method
CW_CallMethod(pWeapon, SetPower, 100.0);
CW_CallMethod(pWeapon, StartCharge);

// Call native method with parameters
CW_CallNativeMethod(pWeapon, CW_Method_DefaultDeploy, g_szModelV, g_szModelP, ANIM_DRAW, "rifle");
```

---

## Calling Parent Methods

Always call `CW_CallBaseMethod()` to invoke parent implementation:

```pawn
@Weapon_PrimaryAttack(const this) {
  if (!CW_CallMethod(this, CanFire)) return;
  
  CW_CallBaseMethod();
  
  // Additional logic after parent method
  PlayMuzzleFlash(this);
}
```

---

## Getting Player from Weapon

**Important**: There is no `CW_GetPlayer` native. Use engine data access:

```pawn
new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
```

---

## Weapon Hooks (External Plugins)

Listen to weapon events from other plugins:

```pawn
public plugin_init() {
  CW_RegisterClassNativeMethodHook(WEAPON_NAME, CW_Method_PrimaryAttack, "CWHook_Rifle_PrimaryAttack");
}

public CWHook_Rifle_PrimaryAttack(const this) {
  // React to weapon fire...
  return CW_HANDLED;
}
```

Hook callback naming: `CWHook_{WeaponName}_{Method}`

```pawn
public CWHook_Rifle_PrimaryAttack(const this)
public CWHook_Shotgun_Reload(const this)
```

---

## Ammo System

### Register Ammo Type

```pawn
public plugin_precache() {
  CW_Ammo_Register("rifle_ammo", CSW_AK47, 90); // name, engine type, max amount
}
```

### Give Ammo to Player

```pawn
CW_GiveAmmo(pPlayer, "rifle_ammo", 30);
```

---

## Best Practices Checklist

- [ ] Precache resources BEFORE `CW_RegisterClass`
- [ ] Use `Create` for member initialization only
- [ ] Use `Deploy` for setting view/player models
- [ ] Check `FM_NULLENT` after `CW_Create` or `CW_Give`
- [ ] Use `CW_CallNativeMethod` for built-in behaviors
- [ ] Get player with `get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer")`
- [ ] Use static variables in Think for performance
- [ ] Define member constants with `m_` prefix and Hungarian notation
- [ ] Define method constants with PascalCase only (no prefix)
