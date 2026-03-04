# 🔫 Custom Weapons API

The **Custom Weapons API** provides a flexible framework for managing and creating custom weapons. This API allows developers to register, give, manipulate, and interact with custom weapons, defining their behavior through hooks and methods. This API uses OOP-style logic and integrates seamlessly with GoldSrc games.

## ⚙️ Implementing a Custom Weapon

### 📚 Registering a New Weapon Class

To implement a custom weapon, the first thing you need to do is register a new weapon class using the `CW_RegisterClass` native function. This can be done in the `plugin_precache` function.

Let's create a simple handgun weapon:

```pawn
#include <api_custom_weapons>

#define WEAPON_NAME "weapon_9mmhandgun"

public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);
}
```

In this example, `CW_RegisterClass` is used to register a weapon named `weapon_9mmhandgun`. After registration, you can implement methods to define its behavior.

### 🔗 Extending an Existing Weapon

You can inherit properties from an existing weapon by specifying the base weapon during registration.

```pawn
#include <api_custom_weapons>

#define WEAPON_NAME "weapon_glock"
#define BASE_WEAPON "weapon_9mmhandgun"

public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME, BASE_WEAPON);
}
```

This example creates `weapon_glock`, inheriting properties and logic from `weapon_9mmhandgun`.

## 🛠 Implementing Weapon Methods

Once a weapon is registered, you can define its behavior by implementing methods. The API provides hooks for actions like firing, reloading, and deploying.

### Implementing the Create Method

The `Create` method initializes the weapon's properties, similar to a constructor.

```pawn
public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);

  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
}

@Weapon_Create(const this) {
  CW_CallBaseMethod(); // Calling the base Create method

  CW_SetMember(this, CW_Member_iMaxClip, 30); // Set max clip size
  CW_SetMember(this, CW_Member_iPrimaryAmmoType, 10); // Set primary ammo type
}
```

In the implementation of the `Create` method, the `CW_CallBaseMethod()` call allows us to invoke the base `Create` method of the parent class, allowing it to handle its own allocation logic before executing custom logic. Make sure to include this call in every implemented or overridden method unless you need to fully rewrite the implementation.

> [!CAUTION]
>
> The `Create` method is called during weapon initialization. Modifying entity variables or invoking engine functions on the weapon within this method may lead to unexpected results. Use this method only for initializing custom weapon members!

> [!CAUTION]
>
> When calling `CW_CallBaseMethod`, you need to pass all method arguments to ensure the base method receives the necessary context for its operations.

Natives like `CW_SetMember` and `CW_SetMemberString` are used to set members/properties for the weapon instance. Constants such as `CW_Member_*` are used to specify the property names. For example, `CW_Member_iMaxClip` sets the maximum number of bullets in a clip, `CW_Member_iPrimaryAmmoType` sets the primary ammo type ID, and `CW_Member_szModel` sets the world model of the weapon.

### 💡 Writing Logic for the Weapon

Our weapon is registered with basic properties, but we still need to add logic for actions like shooting, reloading, and deploying. Let's implement `PrimaryAttack` method in the same way we implemented `Create`:

```pawn
public plugin_precache() {
  /* ... */

  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  static Float:vecSpread[3];
  UTIL_CalculateWeaponSpread(this, UTIL_GetConeVector(3.0), 1, 3.0, 0.1, 0.95, 3.5, vecSpread);

  if (CW_CallNativeMethod(this, CW_Method_DefaultShot, 30.0, 0.75, 0.125, vecSpread, 1)) {
    CW_CallNativeMethod(this, CW_Method_PlayAnimation, 3, 0.71);
  }
}
```

In this example, the `@Weapon_PrimaryAttack` function contains logic for primary attack of the weapon. The `CW_ImplementClassMethod` function is used to override this native method.

### 📥 Implementing Reload

You can customize the reload behavior of a weapon by implementing the `Reload` method.

```pawn
public plugin_precache() {
  /* ... */

  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Reload, "@Weapon_Reload");
}

@Weapon_Reload(const this) {
  CW_CallBaseMethod();

  if (CW_CallNativeMethod(this, CW_Method_DefaultReload, 5, 1.68)) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    emit_sound(pPlayer, CHAN_WEAPON, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}
```

The `Reload` method handles the reloading process. Again, `CW_ImplementClassMethod` registers the reload method for use with the weapon.

## 💡 Working with Class Members and States

The API provides functions to manage weapon class members, allowing you to dynamically get and set various properties.

### Getting and Setting Weapon Members

You can store and retrieve custom data for your weapon using `CW_GetMember` and `CW_SetMember` natives. Here's an example:

```pawn
public plugin_precache() {
  /* ... */
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
}

@Weapon_Create(const this) {
  CW_CallBaseMethod();

  CW_SetMember(this, CW_Member_iMaxClip, 7);
  CW_SetMember(this, CW_Member_iPrimaryAmmoType, 10);
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  new iClip = CW_GetMember(this, CW_Member_iClip);
  if (iClip > 0) {
    // Fire logic
  }
}
```

In this example, `CW_SetMember` is used to define the maximum number of bullets in a clip and the primary ammo type. Later, `CW_GetMember` retrieves the current number of bullets during the primary attack.

## 📞 Calling Methods

### Native Methods

Use `CW_CallNativeMethod` to invoke built-in API methods, such as `DefaultShot` or `DefaultReload`.



**Syntax:**
```pawn
CW_CallNativeMethod(this, CW_Method_Type, ...);
```

**Example:**
```pawn
CW_CallNativeMethod(this, CW_Method_DefaultShot, 30.0, 0.75, 0.125, vecSpread, 1);
```

In this case, `CW_Method_DefaultShot` is the native method being called to handle the shooting logic.

### Custom Methods

Use `CW_CallMethod` to call custom methods that you or others have implemented within the API.

**Syntax:**
```pawn
CW_CallMethod(this, "CustomMethodName", ...);
```

**Example:**
```pawn
CW_CallMethod(this, "CustomExplosionEffect", flDamage, flRadius);
```

### 🎯 Managing Custom Weapon Actions

The API also allows you to define custom methods and hook them into your weapon. For example, you can create custom behavior when the weapon is deployed:

```pawn
public plugin_precache() {
  /* ... */
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Deploy, "@Weapon_Deploy");
}

@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_DefaultDeploy, "models/v_9mmhandgun.mdl", "models/p_9mmhandgun.mdl", 7, "onehanded");
}
```

The `Deploy` method sets up the player and weapon models when the weapon is deployed, configuring the player's animation. And once again, don’t forget to register the method with `CW_ImplementClassMethod`.

## 🔧 Advanced Usage

### Registering Custom Methods

If your weapon needs additional methods, you can register them using `CW_RegisterClassMethod` or `CW_RegisterClassVirtualMethod`.

```pawn
public plugin_precache() {
  CW_RegisterClass(WEAPON_NAME);
  CW_RegisterClassMethod(WEAPON_NAME, "CustomMethod", "@Weapon_CustomMethod");
}

@Weapon_CustomMethod(const this) {
  // Custom method logic here
}
```

In this advanced usage example, `CustomMethod` is registered and implemented for your custom weapon, allowing you to extend the API with your own functionality.

### Handling Callbacks and Hooks

You can also hook into specific events or methods of a weapon class:

```pawn
public plugin_precache() {
  CW_RegisterClassNativeMethodHook(WEAPON_NAME, CW_Method_Think, "CWHook_Weapon_PrimaryAttack");
}

public CWHook_Weapon_PrimaryAttack(const pWeapon) {
  // Do something
}
```

Here, `CW_RegisterClassNativeMethodHook` attaches a callback to the weapon’s `Think` method, letting you execute custom logic every server tick.


### 🕵️‍♂️ Testing and Debugging

> How can I give myself a custom weapon during testing?

There are a few ways to do it!

#### Giving a Weapon Using the Console

You can give yourself a custom weapon using the console command `cw_give <classname>`. The `<classname>` parameter is the name of the registered weapon class. For example, to give yourself the `weapon_9mmhandgun`:

```bash
cw_give "weapon_9mmhandgun"
```

> [!NOTE]
>
> The `cw_give` command requires admin access (ADMIN_CVAR flag).


## 🔫 Example: Simple 9mm handgun

Example of simple handgun from Half-Life.

```pawn
#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <combat_util>

#include <api_custom_weapons>

#define PLUGIN "[Weapon] 9mm Handgun"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define WEAPON_NAME "weapon_9mmhandgun"
#define WEAPON_ID 1
#define WEAPON_AMMO_ID 10
#define WEAPON_SLOT_ID 1
#define WEAPON_SLOT_POS 6
#define WEAPON_CLIP_SIZE 7
#define WEAPON_ICON "fiveseven"
#define WEAPON_DAMAGE 30.0
#define WEAPON_RANGE_MODIFIER 0.75
#define WEAPON_RATE 0.125
#define WEAPON_RELOAD_DURATION 1.68

new const g_szHudTxt[] = "sprites/weapon_9mmhandgun.txt";

new const g_szWeaponModelV[] = "models/v_9mmhandgun.mdl";
new const g_szWeaponModelP[] = "models/p_9mmhandgun.mdl";
new const g_szWeaponModelW[] = "models/w_9mmhandgun.mdl";
new const g_szShellModel[] = "models/shell.mdl";

new const g_szShotSound[] = "weapons/pl_gun3.wav";
new const g_szReloadStartSound[] = "items/9mmclip1.wav";
new const g_szReloadEndSound[] = "items/9mmclip2.wav";

public plugin_precache() {
  precache_generic(g_szHudTxt);

  precache_model(g_szWeaponModelV);
  precache_model(g_szWeaponModelP);
  precache_model(g_szWeaponModelW);
  precache_model(g_szShellModel);

  precache_sound(g_szShotSound);
  precache_sound(g_szReloadStartSound);
  precache_sound(g_szReloadEndSound);

  CW_RegisterClass(WEAPON_NAME);
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Idle, "@Weapon_Idle");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Reload, "@Weapon_Reload");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_CompleteReload, "@Weapon_CompleteReload");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Deploy, "@Weapon_Deploy");
  CW_ImplementClassMethod(WEAPON_NAME, CW_Method_Holster, "@Weapon_Holster");
}

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Weapon_Create(const this) {
  CW_CallBaseMethod();

  CW_SetMemberString(this, CW_Member_szModel, g_szWeaponModelW);
  CW_SetMember(this, CW_Member_iId, WEAPON_ID);
  CW_SetMember(this, CW_Member_iMaxClip, WEAPON_CLIP_SIZE);
  CW_SetMember(this, CW_Member_iPrimaryAmmoType, WEAPON_AMMO_ID);
  CW_SetMember(this, CW_Member_iMaxPrimaryAmmo, 120);
  CW_SetMember(this, CW_Member_iSlot, WEAPON_SLOT_ID);
  CW_SetMember(this, CW_Member_iPosition, WEAPON_SLOT_POS);
  CW_SetMemberString(this, CW_Member_szIcon, WEAPON_ICON);
}

@Weapon_Idle(const this) {
  CW_CallBaseMethod();

  switch (random(3)) {
  case 0: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 0, 61.0 / 16.0);
  case 1: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 1, 61.0 / 16.0);
  case 2: CW_CallNativeMethod(this, CW_Method_PlayAnimation, 2, 61.0 / 14.0);
  }
}

@Weapon_PrimaryAttack(const this) {
  CW_CallBaseMethod();

  static iShotsFired; iShotsFired = CW_GetMember(this, CW_Member_iShotsFired);

  // Don't allow autofire
  if (iShotsFired > 0) return;

  static Float:vecSpread[3]; UTIL_CalculateWeaponSpread(this, UTIL_GetConeVector(3.0), iShotsFired, 3.0, 0.1, 0.95, 3.5, vecSpread);

  if (CW_CallNativeMethod(this, CW_Method_DefaultShot, WEAPON_DAMAGE, WEAPON_RANGE_MODIFIER, WEAPON_RATE, vecSpread, 1)) {
  CW_CallNativeMethod(this, CW_Method_PlayAnimation, 3, 0.71);
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  emit_sound(pPlayer, CHAN_WEAPON, g_szShotSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

  CW_CallNativeMethod(this, CW_Method_EjectBrass, engfunc(EngFunc_ModelIndex, g_szShellModel), 1);
  }
}

@Weapon_Reload(const this) {
  CW_CallBaseMethod();

  if (CW_CallNativeMethod(this, CW_Method_DefaultReload, 5, WEAPON_RELOAD_DURATION)) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  emit_sound(pPlayer, CHAN_WEAPON, g_szReloadStartSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }
}

@Weapon_CompleteReload(const this) {
  CW_CallBaseMethod();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  emit_sound(pPlayer, CHAN_WEAPON, g_szReloadEndSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_DefaultDeploy, g_szWeaponModelV, g_szWeaponModelP, 7, "onehanded");
}

Float:@Weapon_GetMaxSpeed(const this) {
  return 250.0;
}

@Weapon_Holster(const this) {
  CW_CallBaseMethod();
  CW_CallNativeMethod(this, CW_Method_PlayAnimation, 8, 16.0 / 20.0);
}
```

---

## 📖 API Reference

See [`api_custom_weapons.inc`](include/api_custom_weapons.inc) and [`api_custom_weapons_const.inc`](include/api_custom_weapons_const.inc) for all available natives and constants.
