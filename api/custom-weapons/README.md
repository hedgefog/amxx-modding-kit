# 🔫 Custom Weapons API

The **Custom Weapons API** provides a flexible OOP-style framework for managing and creating custom weapons in AMX Mod X. This API allows developers to register weapon classes, implement their behavior through methods, and interact with custom weapons programmatically. Weapons integrate seamlessly with GoldSrc games.

## 🚀 Features

- OOP-style weapon class system with inheritance
- Custom members for storing weapon-specific data
- Custom methods for extending weapon behavior
- Built-in methods for common actions (shoot, reload, deploy)
- Native method hooks for intercepting weapon behavior
- Ammo type registration and management
- Full lifecycle control (create, deploy, holster, drop)

---

## ⚙️ Getting Started

### Registering a New Weapon Class

To create a custom weapon, register a new weapon class using `CW_RegisterClass` in `plugin_precache`.

Let's create a simple handgun:

```pawn
#include <api_custom_weapons>

#define WEAPON_NAME "weapon_9mmhandgun"

public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);
}
```

After registration, you can implement methods to define the weapon's behavior.

### Extending an Existing Class

You can inherit from an existing weapon class to extend its behavior:

```pawn
#define WEAPON_NAME "weapon_glock"
#define BASE_WEAPON "weapon_9mmhandgun"

public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME, BASE_WEAPON);
}
```

This creates `weapon_glock` that inherits all properties and methods from `weapon_9mmhandgun`.

---

## 🛠 Implementing Weapon Methods

### The Create Method

The `Create` method initializes weapon members when an instance is allocated. Use it to set default values.

```pawn
public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
}

@Weapon_Create(const this) {
  CW_CallBaseMethod();

  CW_SetMember(this, CW_Member_iMaxClip, 17);
  CW_SetMember(this, CW_Member_iPrimaryAmmoType, 10);
  CW_SetMember(this, CW_Member_iMaxPrimaryAmmo, 120);
  CW_SetMember(this, CW_Member_iId, 1);
  CW_SetMember(this, CW_Member_iSlot, 1);
  CW_SetMember(this, CW_Member_iPosition, 6);
  CW_SetMemberString(this, CW_Member_szModel, "models/w_9mmhandgun.mdl");
}
```

> [!CAUTION]
> The `Create` method is called during weapon allocation. Do not modify entity variables (`pev`) or invoke engine functions here — use it only for initializing custom weapon members!

> [!CAUTION]
> Always call `CW_CallBaseMethod()` with all method arguments to ensure the parent class executes its logic properly.

**Common Members:**
- `CW_Member_iMaxClip` — Maximum clip size
- `CW_Member_iPrimaryAmmoType` — Primary ammo type ID
- `CW_Member_iMaxPrimaryAmmo` — Maximum primary ammo
- `CW_Member_iSlot` / `CW_Member_iPosition` — HUD slot position
- `CW_Member_szModel` — World model path
- `CW_Member_szIcon` — HUD icon name

### Writing Weapon Logic

Let's implement `Deploy` and `PrimaryAttack` methods:

```pawn
new const g_szWeaponModelV[] = "models/v_9mmhandgun.mdl";
new const g_szWeaponModelP[] = "models/p_9mmhandgun.mdl";
new const g_szShotSound[] = "weapons/pl_gun3.wav";

public plugin_precache() {
  precache_model(g_szWeaponModelV);
  precache_model(g_szWeaponModelP);
  precache_sound(g_szShotSound);

  CW_RegisterClass(WEAPON_NAME);
  
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Deploy, "@Weapon_Deploy");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
}

@Weapon_Create(const this) { /* ... */ }

@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_DefaultDeploy, g_szWeaponModelV, g_szWeaponModelP, 7, "onehanded");
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  static Float:vecSpread[3];
  UTIL_CalculateWeaponSpread(this, UTIL_GetConeVector(3.0), 1, 3.0, 0.1, 0.95, 3.5, vecSpread);

  if (CW_CallNativeMethod(this, CW_Method_DefaultShot, 30.0, 0.75, 0.125, vecSpread, 1)) {
    CW_CallNativeMethod(this, CW_Method_PlayAnimation, 3, 0.71);
    
    new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szShotSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}
```

### Implementing Reload

```pawn
new const g_szReloadSound[] = "items/9mmclip1.wav";

public plugin_precache() {
  /* ... */
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Reload, "@Weapon_Reload");
}

@Weapon_Reload(const this) {
  CW_CallBaseMethod();

  if (CW_CallNativeMethod(this, CW_Method_DefaultReload, 5, 1.68)) {
    new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szReloadSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}
```

---

## 🧩 Custom Members

Custom members allow you to store weapon-specific data:

```pawn
#define m_bSilenced "bSilenced"

@Weapon_Create(const this) {
  CW_CallBaseMethod();
  
  CW_SetMember(this, m_bSilenced, false);
  /* ... */
}

@Weapon_SecondaryAttack(const this) {
  CW_CallBaseMethod();

  new bool:bSilenced = CW_GetMember(this, m_bSilenced);
  CW_SetMember(this, m_bSilenced, !bSilenced);

  // Play silencer toggle animation
  CW_CallNativeMethod(this, CW_Method_PlayAnimation, bSilenced ? 10 : 9, 2.0);
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  new bool:bSilenced = CW_GetMember(this, m_bSilenced);
  new Float:flDamage = bSilenced ? 25.0 : 30.0;

  /* ... shoot logic with flDamage ... */
}
```

---

## 📦 Custom Methods

Custom methods extend weapon behavior beyond built-in methods:

```pawn
#define ToggleSilencer "ToggleSilencer"

public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);

  // Register custom method
  CW_RegisterClassMethod(WEAPON_NAME, ToggleSilencer, "@Weapon_ToggleSilencer");

  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_SecondaryAttack, "@Weapon_SecondaryAttack");
  /* ... */
}

@Weapon_SecondaryAttack(const this) {
  CW_CallBaseMethod();
  
  // Use custom method
  CW_CallMethod(this, ToggleSilencer);
}

@Weapon_ToggleSilencer(const this) {
  new bool:bSilenced = CW_GetMember(this, m_bSilenced);
  CW_SetMember(this, m_bSilenced, !bSilenced);

  CW_CallNativeMethod(this, CW_Method_PlayAnimation, bSilenced ? 10 : 9, 2.0);
}
```

---

## 📞 Calling Methods

### Native Methods

Use `CW_CallNativeMethod` to invoke built-in API methods:

```pawn
// Deploy with models
CW_CallNativeMethod(this, CW_Method_DefaultDeploy, "v_model.mdl", "p_model.mdl", 7, "onehanded");

// Fire bullets
CW_CallNativeMethod(this, CW_Method_DefaultShot, flDamage, flRangeMod, flRate, vecSpread, iShots);

// Reload weapon
CW_CallNativeMethod(this, CW_Method_DefaultReload, iAnim, flDuration);

// Play animation
CW_CallNativeMethod(this, CW_Method_PlayAnimation, iAnim, flDuration);

// Eject brass
CW_CallNativeMethod(this, CW_Method_EjectBrass, iModelIndex, iSoundType);
```

### Custom Methods

Use `CW_CallMethod` to call custom methods:

```pawn
CW_CallMethod(this, "ToggleSilencer");
CW_CallMethod(this, "CustomExplosionEffect", flDamage, flRadius);
```

---

## 🔧 Hooks

Hook into native methods to intercept weapon behavior:

```pawn
public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);
  CW_RegisterClassNativeMethodHook(WEAPON_NAME, CW_Method_PrimaryAttack, "CWHook_Weapon_PrimaryAttack");
}

public CWHook_Weapon_PrimaryAttack(const pWeapon) {
  // Execute custom logic before primary attack
  log_amx("Weapon fired: %d", pWeapon);
}
```

Use the `bPost` parameter to hook after the method executes:

```pawn
CW_RegisterClassNativeMethodHook(WEAPON_NAME, CW_Method_PrimaryAttack, "CWHook_Weapon_PrimaryAttack_Post", true);
```

---

## 🕵️‍♂️ Testing and Debugging

### Console Commands

**Give yourself a weapon:**
```bash
cw_give "weapon_9mmhandgun"
```

> [!NOTE]
> The `cw_give` command requires admin access (ADMIN_CVAR flag).

### Giving via Code

```pawn
// Give weapon to player
new pWeapon = CW_Give(pPlayer, "weapon_9mmhandgun");

// Check if player has the weapon
if (CW_PlayerHasWeapon(pPlayer, "weapon_9mmhandgun")) {
  // Find the weapon entity
  new pWeapon = CW_PlayerFindWeapon(pPlayer, "weapon_9mmhandgun");
}

// Give ammo
CW_GiveAmmo(pPlayer, "9mm", 30);
```

---

## 🔫 Example: Simple 9mm Handgun

Complete example of a Half-Life style handgun:

```pawn
#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_weapons>

#define WEAPON_NAME "weapon_9mmhandgun"

new const g_szWeaponModelV[] = "models/v_9mmhandgun.mdl";
new const g_szWeaponModelP[] = "models/p_9mmhandgun.mdl";
new const g_szWeaponModelW[] = "models/w_9mmhandgun.mdl";
new const g_szShellModel[] = "models/shell.mdl";

new const g_szShotSound[] = "weapons/pl_gun3.wav";
new const g_szReloadStartSound[] = "items/9mmclip1.wav";
new const g_szReloadEndSound[] = "items/9mmclip2.wav";

public plugin_precache() {
  precache_model(g_szWeaponModelV);
  precache_model(g_szWeaponModelP);
  precache_model(g_szWeaponModelW);
  precache_model(g_szShellModel);

  precache_sound(g_szShotSound);
  precache_sound(g_szReloadStartSound);
  precache_sound(g_szReloadEndSound);

  CW_RegisterClass(WEAPON_NAME);
  
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Deploy, "@Weapon_Deploy");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Holster, "@Weapon_Holster");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Idle, "@Weapon_Idle");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Reload, "@Weapon_Reload");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_CompleteReload, "@Weapon_CompleteReload");
}

public plugin_init() {
  register_plugin("9mm Handgun", "1.0.0", "Author");
}

@Weapon_Create(const this) {
  CW_CallBaseMethod();

  CW_SetMemberString(this, CW_Member_szModel, g_szWeaponModelW);
  CW_SetMember(this, CW_Member_iId, 1);
  CW_SetMember(this, CW_Member_iMaxClip, 17);
  CW_SetMember(this, CW_Member_iPrimaryAmmoType, 10);
  CW_SetMember(this, CW_Member_iMaxPrimaryAmmo, 120);
  CW_SetMember(this, CW_Member_iSlot, 1);
  CW_SetMember(this, CW_Member_iPosition, 6);
  CW_SetMemberString(this, CW_Member_szIcon, "fiveseven");
}

@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_DefaultDeploy, g_szWeaponModelV, g_szWeaponModelP, 7, "onehanded");
}

@Weapon_Holster(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_PlayAnimation, 8, 0.8);
}

@Weapon_Idle(const this) {
  CW_CallBaseMethod();

  switch (random(3)) {
    case 0: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 0, 3.8);
    case 1: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 1, 3.8);
    case 2: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 2, 4.3);
  }
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  // Don't allow autofire
  new iShotsFired = CW_GetMember(this, CW_Member_iShotsFired);
  if (iShotsFired > 0) return;

  new Float:vecSpread[3] = {0.01, 0.01, 0.0};

  if (CW_CallNativeMethod(this, CW_Method_DefaultShot, 30.0, 0.75, 0.125, vecSpread, 1)) {
    CW_CallNativeMethod(this, CW_Method_PlayAnimation, 3, 0.71);
    
    new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szShotSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    CW_CallNativeMethod(this, CW_Method_EjectBrass, engfunc(EngFunc_ModelIndex, g_szShellModel), 1);
  }
}

@Weapon_Reload(const this) {
  CW_CallBaseMethod();

  if (CW_CallNativeMethod(this, CW_Method_DefaultReload, 5, 1.68)) {
    new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, g_szReloadStartSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}

@Weapon_CompleteReload(const this) {
  CW_CallBaseMethod();

  new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  emit_sound(pPlayer, CHAN_WEAPON, g_szReloadEndSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
```

---

## 📖 API Reference

See [`api_custom_weapons.inc`](include/api_custom_weapons.inc) and [`api_custom_weapons_const.inc`](include/api_custom_weapons_const.inc) for all available natives and constants.
