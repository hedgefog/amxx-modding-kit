---
name: amxx-modding-kit-project
description: Best practices for organizing large AMX Mod X projects with multiple plugins sharing entities, weapons, events, and other definitions. Use when creating mod-scale projects that need consistent namespace patterns and shared constants.
---

# AMX Mod X Project Organization

Best practices for large projects with multiple plugins sharing definitions.

---

## Project File Structure

```
mymod/
├── assets/
│   └── addons/
│       └── amxmodx/
│           └── configs/
│               └── assets/
│                   └── mymod.json       # Asset library
├── src/
│   ├── include/
│   │   ├── mymod_const.inc              # Shared constants (entities, events, etc.)
│   │   ├── mymod_internal.inc           # Internal macros (not for external use)
│   │   └── mymod.inc                    # Public API for external plugins
│   └── scripts/
│       ├── core/
│       │   ├── core.sma                 # Main mod plugin
│       │   └── gamerules.sma
│       ├── entities/
│       │   ├── projectile.sma
│       │   └── corpse.sma
│       ├── weapons/
│       │   ├── base.sma                 # Base weapon class
│       │   ├── rifle.sma
│       │   └── pistol.sma
│       ├── player-roles/
│       │   ├── base.sma
│       │   └── survivor.sma
│       └── features/
│           └── infection.sma
└── README.md
```

---

## Include File Organization

### Constants File (`mymod_const.inc`)

```pawn
#if defined _mymod_const_included
  #endinput
#endif
#define _mymod_const_included

/*--------------------------------[ Title ]--------------------------------*/

stock const MYTMOD_TITLE[] = "My Mod";
stock const MYMOD_VERSION[] = "1.0.0";

/*--------------------------------[ Libraries ]--------------------------------*/

stock const MyMod_Library_Core[] = "mymod";
stock const MyMod_Library_Gamerules[] = "mymod_gamerules";
stock const MyMod_Library_Infection[] = "mymod_infection";

/*--------------------------------[ Asset Library ]--------------------------------*/

stock const MyMod_AssetLibrary[] = "mymod";

/*--------------------------------[ Assets ]--------------------------------*/

stock const MyMod_Asset_Player_Model_Survivor[] = "player.survivor.model";
stock const MyMod_Asset_Player_Model_Infected[] = "player.infected.model";
stock const MyMod_Asset_Player_Sound_Hit[] = "player.sounds.hit";
stock const MyMod_Asset_Weapon_Rifle_Model_View[] = "weapons.rifle.models.view";
stock const MyMod_Asset_Weapon_Rifle_Model_Player[] = "weapons.rifle.models.player";
stock const MyMod_Asset_Weapon_Rifle_Model_World[] = "weapons.rifle.models.world";

/*--------------------------------[ Entities ]--------------------------------*/

stock const MyMod_Entity_Projectile[] = "mm_projectile";
stock const MyMod_Entity_Corpse[] = "mm_corpse";
stock const MyMod_Entity_WeaponBox[] = "weaponbox";

/*--------------------------------[ Entity Members ]--------------------------------*/

stock const MyMod_Entity_Projectile_Member_flDamage[] = "flDamage";
stock const MyMod_Entity_Projectile_Member_flSpeed[] = "flSpeed";
stock const MyMod_Entity_Projectile_Member_pTarget[] = "pTarget";

/*--------------------------------[ Entity Methods ]--------------------------------*/

stock const MyMod_Entity_Projectile_Method_Launch[] = "Launch";
stock const MyMod_Entity_Projectile_Method_Explode[] = "Explode";

/*--------------------------------[ Weapons ]--------------------------------*/

stock const MyMod_Weapon_Base[] = "mymod/v100/weapon_base";
stock const MyMod_Weapon_Rifle[] = "mymod/v100/weapon_rifle";
stock const MyMod_Weapon_Pistol[] = "mymod/v100/weapon_pistol";

/*--------------------------------[ Weapon Members ]--------------------------------*/

stock const MyMod_Weapon_Base_Member_flWeight[] = "flWeight";
stock const MyMod_Weapon_Rifle_Member_flChargeTime[] = "flChargeTime";
stock const MyMod_Weapon_Rifle_Member_bSilenced[] = "bSilenced";

/*--------------------------------[ Weapon Methods ]--------------------------------*/

stock const MyMod_Weapon_Rifle_Method_ToggleSilencer[] = "ToggleSilencer";

/*--------------------------------[ Player Roles ]--------------------------------*/

stock const MyMod_PlayerRole_Base[] = "mymod-base";
stock const MyMod_PlayerRole_Survivor[] = "mymod-survivor";
stock const MyMod_PlayerRole_Infected[] = "mymod-infected";

/*--------------------------------[ Role Members ]--------------------------------*/

stock const MyMod_PlayerRole_Base_Member_flSpeed[] = "flSpeed";
stock const MyMod_PlayerRole_Survivor_Member_iKills[] = "iKills";

/*--------------------------------[ Role Methods ]--------------------------------*/

stock const MyMod_PlayerRole_Base_Method_GetMaxSpeed[] = "GetMaxSpeed";
stock const MyMod_PlayerRole_Base_Method_GetMaxHealth[] = "GetMaxHealth";

/*--------------------------------[ Events ]--------------------------------*/

stock const MyMod_Event_PlayerInfected[] = "mymod-player-infected";
stock const MyMod_Event_RoundStarted[] = "mymod-round-started";
stock const MyMod_Event_ConfigLoaded[] = "mymod-config-loaded";

/*--------------------------------[ State Contexts ]--------------------------------*/

stock const MyMod_StateContext_Infection[] = "mymod-infection";

/*--------------------------------[ Shops ]--------------------------------*/

stock const MyMod_Shop_Main[] = "mymod";
stock const MyMod_Shop_Item_Medkit[] = "mm-medkit";
stock const MyMod_Shop_Item_Armor[] = "mm-armor";

/*--------------------------------[ Enums ]--------------------------------*/

enum MyMod_Team {
  MyMod_Team_Unassigned = 0,
  MyMod_Team_Survivors,
  MyMod_Team_Infected,
  MyMod_Team_Spectators
};

enum MyMod_InfectionState {
  MyMod_InfectionState_None,
  MyMod_InfectionState_Infected,
  MyMod_InfectionState_Transformed
};

enum {
  MyMod_WeaponId_Rifle = 3,
  MyMod_WeaponId_Pistol,
  MyMod_WeaponId_Grenade
};

/*--------------------------------[ Dictionary ]--------------------------------*/

stock const MyMod_Dictionary[] = "mymod.txt";
stock const MyMod_DictionaryKey_RoundStart[] = "MM_ROUND_START";
```

### Internal Macros File (`mymod_internal.inc`)

```pawn
#if defined _mymod_internal_included
  #endinput
#endif
#define _mymod_internal_included

#include <mymod_const>

/*--------------------------------[ Common Macros ]--------------------------------*/

#if !defined IS_PLAYER
  #define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#endif

#if !defined BIT
  #define BIT(%1) (1 << (%1))
#endif

/*--------------------------------[ CVar & Command Macros ]--------------------------------*/

#define CVAR(%1) "mymod_" + %1
#define COMMAND(%1) "mymod_" + %1

/*--------------------------------[ Plugin Registration Macros ]--------------------------------*/

#define PLUGIN_NAME(%1) "[My Mod] " + %1
#define ENTITY_PLUGIN(%1) "[Entity] My Mod " + #%1
#define WEAPON_PLUGIN(%1) "[Weapon] My Mod " + #%1
#define ROLE_PLUGIN(%1) "[Role] My Mod " + #%1
#define FEATURE_PLUGIN(%1) "[Feature] My Mod " + #%1

/*--------------------------------[ Namespace Macros ]--------------------------------*/

#define NAMESPACE(%1) MyMod_%1
#define NAMESPACE_FIELD<%1>(%2) NAMESPACE(%1)_%2

/*--------------------------------[ Library Shortcuts ]--------------------------------*/

#define LIBRARY(%1) NAMESPACE_FIELD<Library>(%1)

/*--------------------------------[ Asset Shortcuts ]--------------------------------*/

#define ASSET_LIBRARY NAMESPACE(AssetLibrary)
#define ASSET(%1) NAMESPACE_FIELD<Asset>(%1)

/*--------------------------------[ Entity Shortcuts ]--------------------------------*/

#define ENTITY(%1) NAMESPACE_FIELD<Entity>(%1)
#define ENTITY_DATA<%1>(%2,%3) ENTITY(%2)_%1_%3
#define ENTITY_METHOD<%1>(%2) ENTITY_DATA<Method>(%1,%2)
#define ENTITY_MEMBER<%1>(%2) ENTITY_DATA<Member>(%1,%2)

/*--------------------------------[ Weapon Shortcuts ]--------------------------------*/

#define WEAPON(%1) NAMESPACE_FIELD<Weapon>(%1)
#define WEAPON_DATA<%1>(%2,%3) WEAPON(%2)_%1_%3
#define WEAPON_METHOD<%1>(%2) WEAPON_DATA<Method>(%1,%2)
#define WEAPON_MEMBER<%1>(%2) WEAPON_DATA<Member>(%1,%2)

/*--------------------------------[ Player Role Shortcuts ]--------------------------------*/

#define PLAYER_ROLE(%1) NAMESPACE_FIELD<PlayerRole>(%1)
#define PLAYER_ROLE_DATA<%1>(%2,%3) PLAYER_ROLE(%2)_%1_%3
#define PLAYER_ROLE_METHOD<%1>(%2) PLAYER_ROLE_DATA<Method>(%1,%2)
#define PLAYER_ROLE_MEMBER<%1>(%2) PLAYER_ROLE_DATA<Member>(%1,%2)

/*--------------------------------[ Event Shortcuts ]--------------------------------*/

#define EVENT(%1) NAMESPACE_FIELD<Event>(%1)

/*--------------------------------[ State Shortcuts ]--------------------------------*/

#define STATE_CONTEXT(%1) NAMESPACE_FIELD<StateContext>(%1)

/*--------------------------------[ Shop Shortcuts ]--------------------------------*/

#define SHOP(%1) NAMESPACE_FIELD<Shop>(%1)
#define SHOP_ITEM(%1) NAMESPACE_FIELD<Shop_Item>(%1)

/*--------------------------------[ Dictionary Shortcuts ]--------------------------------*/

#define DICTIONARY NAMESPACE(Dictionary)
#define DICTIONARY_KEY(%1) NAMESPACE_FIELD<DictionaryKey>(%1)
```

---

## Core Plugin vs Game Rules

### Core Plugin (`core.sma`)

The core plugin prepares the game for the mod. It contains **static logic** that doesn't depend on game state, events, or conditions.

**Must Do:**
- **Define library** - Register mod library with `register_library()` so other plugins can check if mod is loaded
- **Register version cvar** - Create version cvar with `FCVAR_SERVER` flag and hook changes to prevent modification
- **Customize game name** - Hook `FM_GetGameDescription` to display mod name instead of base game
- **Load configuration** - Execute mod config files in `plugin_cfg()` and emit event when loaded

**Should Do (If Needed):**
- **Block unwanted entities** - Use `CE_RegisterNullClass()` to disable game entities that conflict with your mod (e.g., `armoury_entity`, `hostage_entity`, `func_buyzone`)
- **Block messages** - Hook messages to suppress default game notifications (win messages, radio, etc.)
- **Block client commands** - Register and block commands that shouldn't work in your mod (e.g., `radio1`, `buy`)
- **Validate required modules** - Check for required libraries with `LibraryExists()` and `set_fail_state()` if missing
- **Load common resources** - Load asset libraries and precache shared resources used across multiple plugins

### Game Rules (`gamerules.sma`)

The game rules plugin defines **dynamic gameplay logic** that depends on game state, entity state, and conditions.

**Typical Responsibilities:**
- **Win/lose conditions** - Check when team wins, round ends, game ends
- **Spawn logic** - Control what happens when players spawn, what equipment they get
- **Round flow** - Handle round start, round end, intermission
- **Team balance** - Manage team assignment, auto-balance
- **Player death handling** - What happens when player dies (drop items, respawn timer, etc.)
- **Score tracking** - Track kills, objectives, team scores
- **Game mode states** - Manage game phases (warmup, active, overtime, etc.)

### Key Difference

| Aspect | Core Plugin | Game Rules |
|--------|-------------|------------|
| Logic type | Static, unconditional | Dynamic, conditional |
| Depends on | Nothing (runs always) | Game state, entity state |
| Purpose | Prepare game environment | Define gameplay behavior |
| Example | Block `armoury_entity` | Give weapons on spawn |

**Should NOT be in either:**
- Entity implementations → `entities/*.sma`
- Weapon implementations → `weapons/*.sma`
- Feature-specific logic → `features/*.sma`

---

## Plugin Independence (Best Practice)

Entities, weapons, and roles should **avoid direct dependencies** on gamerules to remain reusable and work independently.

### Recommended Approach

```
┌─────────────────┐     forwards/events     ┌─────────────────┐
│   Game Rules    │ ───────────────────────>│ Entity/Weapon   │
│                 │                         │                 │
│ (state owner)   │<─────────────────────── │ (subscriber)    │
└─────────────────┘   subscribe via events  └─────────────────┘
```

**Instead of:**
```pawn
// ❌ Direct gamerules dependency - breaks if gamerules not loaded
@Weapon_PrimaryAttack(const this) {
  if (GameRules_GetState() == GameState_Warmup) return;  // Direct call
  // ...
}
```

**Use events/forwards:**
```pawn
// ✅ Subscribe to state changes - works without gamerules
new bool:g_bCanAttack = true;

public plugin_init() {
  // Subscribe to game state changes (if gamerules exists)
  CustomEvent_Subscribe(EVENT(GameStateChanged), "OnGameStateChanged");
}

public OnGameStateChanged(GameState:iNewState) {
  g_bCanAttack = (iNewState != GameState_Warmup);
}

@Weapon_PrimaryAttack(const this) {
  if (!g_bCanAttack) return;  // Uses local state
  // ...
}
```

### When Direct Calls Are Acceptable

Direct gamerules calls are fine when the entity **is part of gamerules logic**:

- Spawner entities that configure game rules
- Trigger entities that end rounds
- Objective entities that track game progress
- Initialization entities that set gamerules variables

```pawn
// ✅ OK - entity IS part of gamerules
@TriggerRescue_Touch(const this, const pPlayer) {
  if (!IS_PLAYER(pPlayer)) return;
  
  GameRules_DispatchWin(TEAM_CT);  // Direct call is appropriate here
}
```

### Benefits

| Approach | Without Gamerules | With Gamerules |
|----------|-------------------|----------------|
| Direct calls | ❌ Crashes/fails | ✅ Works |
| Events/forwards | ✅ Works (default behavior) | ✅ Works (custom behavior) |

This pattern makes entities and weapons **portable** across different mods or usable in standalone testing.

---

## Core Plugin Structure

### Main Mod Plugin (`core.sma`)

```pawn
#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <api_assets>
#include <api_custom_entities>

#include <mymod_internal>

/*--------------------------------[ Forward Pointers ]--------------------------------*/

new g_pfwConfigLoaded;

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  // Load asset library
  Asset_Library_Load(ASSET_LIBRARY);

  // Nullify unwanted CS entities
  CE_RegisterNullClass("armoury_entity");
  CE_RegisterNullClass("weapon_shield");
  CE_RegisterNullClass("game_player_equip");

  // Register version cvar with change hook
  hook_cvar_change(create_cvar(CVAR("version"), MYMOD_VERSION, FCVAR_SERVER), "CvarHook_Version");
}

public plugin_init() {
  register_plugin(MYTMOD_TITLE, MYMOD_VERSION, "Author");

  // Check required libraries
  if (!LibraryExists(LIBRARY(Gamerules), LibType_Library)) {
    set_fail_state("Gamerules library is required!");
  }

  // Create forward
  g_pfwConfigLoaded = CreateMultiForward("MyMod_OnConfigLoaded", ET_IGNORE);

  // Hook game description
  register_forward(FM_GetGameDescription, "FMHook_GetGameDescription");

  // Register inline message hooks
  register_message(get_user_msgid("SendAudio"), "Message_SendAudio");
  register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
}

public plugin_cfg() {
  new szConfigDir[32]; get_configsdir(szConfigDir, charsmax(szConfigDir));
  new szMapName[64]; get_mapname(szMapName, charsmax(szMapName));

  // Execute main config, then map-specific config
  server_cmd("exec %s/mymod.cfg", szConfigDir);
  server_cmd("exec %s/mymod/%s.cfg", szConfigDir, szMapName);
  server_exec();

  // Notify other plugins
  ExecuteForward(g_pfwConfigLoaded);
}

public plugin_natives() {
  register_library(LIBRARY(Core));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public CvarHook_Version(const pCvar) {
  set_pcvar_string(pCvar, MYMOD_VERSION);
}

public FMHook_GetGameDescription() {
  static szGameName[32];
  format(szGameName, charsmax(szGameName), "%s %s", MYTMOD_TITLE, MYMOD_VERSION);
  forward_return(FMV_STRING, szGameName);

  return FMRES_SUPERCEDE;
}

public Message_SendAudio() {
  static szAudio[16]; get_msg_arg_string(2, szAudio, charsmax(szAudio));

  // Block radio messages
  if (equal(szAudio, "%!MRAD_", 7)) return PLUGIN_HANDLED;

  return PLUGIN_CONTINUE;
}

public Message_TextMsg() {
  static szMessage[32]; get_msg_arg_string(2, szMessage, charsmax(szMessage));

  // Block default win messages
  if (equal(szMessage, "#Terrorists_Win")) return PLUGIN_HANDLED;
  if (equal(szMessage, "#CTs_Win")) return PLUGIN_HANDLED;
  if (equal(szMessage, "#Round_Draw")) return PLUGIN_HANDLED;

  return PLUGIN_CONTINUE;
}
```

---

## Macro Expansion Reference

```pawn
// ENTITY(Projectile) expands to:
// -> NAMESPACE_FIELD<Entity>(Projectile)
// -> NAMESPACE(Entity)_Projectile
// -> MyMod_Entity_Projectile

// ENTITY_MEMBER<Projectile>(flDamage) expands to:
// -> ENTITY_DATA<Member>(Projectile,flDamage)
// -> ENTITY(Projectile)_Member_flDamage
// -> MyMod_Entity_Projectile_Member_flDamage

// WEAPON(Rifle) expands to:
// -> NAMESPACE_FIELD<Weapon>(Rifle)
// -> MyMod_Weapon_Rifle

// ASSET(Weapon_Rifle_Model_View) expands to:
// -> NAMESPACE_FIELD<Asset>(Weapon_Rifle_Model_View)
// -> MyMod_Asset_Weapon_Rifle_Model_View
```

---

## When to Use This Pattern

Use namespace constants and macro shortcuts when:
- Multiple plugins share entity/weapon/event definitions
- External plugins need to interact with your mod's entities
- Constants are referenced across more than 2-3 files
- You need consistent naming for documentation/debugging
- Project is large with many plugins and team members

For small projects with 1-3 plugins, simpler patterns may suffice.
