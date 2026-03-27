---
name: amxx-modding-kit-api-player-roles
description: Guide for Player Roles API usage implementing OOP-style player role management with inheritance, groups, and custom methods.
---

# Player Roles API

OOP-style system for defining, assigning, and managing player roles with inheritance, groups, and custom methods/members.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/player-roles/README.md).

---

## Naming Conventions

### Role and Group Constants

Use `#define` with `ROLE_` and `ROLE_GROUP_` prefixes:

```pawn
#define ROLE_SURVIVOR "survivor"
#define ROLE_ZOMBIE "zombie"
#define ROLE_FAST_ZOMBIE "fast_zombie"

#define ROLE_GROUP_SPECIES "species"
#define ROLE_GROUP_CLASS "class"
```

### Member and Method Constants

```pawn
new const m_flPower[] = "flPower";
new const m_szVariant[] = "szVariant";

new const Growl[] = "Growl";
new const GetSpeed[] = "GetSpeed";
```

---

## Role Registration

### Basic Registration

```pawn
public plugin_precache() {
  // Register standalone roles
  PlayerRole_Register(ROLE_SURVIVOR);
  PlayerRole_Register(ROLE_ZOMBIE);
}
```

### Registration with Inheritance

```pawn
public plugin_precache() {
  // Base zombie role
  PlayerRole_Register(ROLE_ZOMBIE);
  
  // Specialized zombies inherit from base
  PlayerRole_Register(ROLE_FAST_ZOMBIE, ROLE_ZOMBIE);
  PlayerRole_Register(ROLE_TANK_ZOMBIE, ROLE_ZOMBIE);
  PlayerRole_Register(ROLE_POISON_ZOMBIE, ROLE_ZOMBIE);
}
```

### Method Implementation

```pawn
public plugin_precache() {
  PlayerRole_Register(ROLE_ZOMBIE);
  
  // Implement native methods
  PlayerRole_ImplementMethod(ROLE_ZOMBIE, PlayerRole_Method_Assign, "@Zombie_Assign");
  PlayerRole_ImplementMethod(ROLE_ZOMBIE, PlayerRole_Method_Unassign, "@Zombie_Unassign");
  
  // Register custom methods
  PlayerRole_RegisterMethod(ROLE_ZOMBIE, Growl, "@Zombie_Growl");
  PlayerRole_RegisterVirtualMethod(ROLE_ZOMBIE, GetSpeed, "@Zombie_GetSpeed");
}
```

---

## Method Implementations

### Assign Method

```pawn
@Zombie_Assign(const pPlayer) {
  // Call base method if inheriting
  PlayerRole_This_CallBaseMethod();
  
  // Initialize role members
  PlayerRole_This_SetMember(m_flPower, 100.0);
  PlayerRole_This_SetMemberString(m_szVariant, "standard");
  
  // Apply role effects
  PlayerModel_Set(pPlayer, g_szZombieModel);
  PlayerModel_Update(pPlayer);
  
  client_print(pPlayer, print_chat, "You are now a zombie!");
}
```

### Unassign Method

```pawn
@Zombie_Unassign(const pPlayer) {
  PlayerRole_This_CallBaseMethod();
  
  // Remove role effects
  PlayerModel_Reset(pPlayer);
  
  client_print(pPlayer, print_chat, "You are no longer a zombie.");
}
```

### Custom Method

```pawn
@Zombie_Growl(const pPlayer) {
  emit_sound(pPlayer, CHAN_VOICE, g_szGrowlSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  client_print(pPlayer, print_center, "Grrrrrrr!");
}

Float:@Zombie_GetSpeed(const pPlayer) {
  return 280.0;
}
```

---

## Role Assignment

### Basic Assignment

```pawn
// Assign role to player
PlayerRole_Player_AssignRole(pPlayer, ROLE_ZOMBIE);

// Unassign role
PlayerRole_Player_UnassignRole(pPlayer, ROLE_ZOMBIE);

// Unassign all roles
PlayerRole_Player_UnassignRoles(pPlayer);
```

### Assignment with Groups

Groups enforce mutual exclusivity - only one role per group:

```pawn
// Assign role in specific group
PlayerRole_Player_AssignRole(pPlayer, ROLE_ZOMBIE, ROLE_GROUP_SPECIES);

// Later, assigning different role in same group auto-unassigns previous
PlayerRole_Player_AssignRole(pPlayer, ROLE_SURVIVOR, ROLE_GROUP_SPECIES);
// Zombie is automatically unassigned

// Unassign all roles in a group
PlayerRole_Player_UnassignRoleGroup(pPlayer, ROLE_GROUP_SPECIES);
```

### Inheritance Auto-Exclusivity

Roles with same parent are mutually exclusive:

```pawn
// Assign FastZombie (inherits from Zombie)
PlayerRole_Player_AssignRole(pPlayer, ROLE_FAST_ZOMBIE);

// Assign TankZombie - FastZombie is automatically unassigned
// (both inherit from Zombie)
PlayerRole_Player_AssignRole(pPlayer, ROLE_TANK_ZOMBIE);
```

---

## Role Queries

### Check Role Assignment

```pawn
// Check if player has role (includes inheritance)
if (PlayerRole_Player_HasRole(pPlayer, ROLE_ZOMBIE)) {
  // Player has Zombie, FastZombie, TankZombie, etc.
}

// Check exact role (no inheritance check)
if (PlayerRole_Player_HasExactRole(pPlayer, ROLE_FAST_ZOMBIE)) {
  // Player has exactly FastZombie
}
```

### Check Role Group

```pawn
if (PlayerRole_Player_HasRoleGroup(pPlayer, ROLE_GROUP_SPECIES)) {
  new szRole[PLAYER_ROLE_MAX_LENGTH];
  PlayerRole_Player_GetRoleByGroup(pPlayer, ROLE_GROUP_SPECIES, szRole, charsmax(szRole));
  
  client_print(pPlayer, print_chat, "Your species role: %s", szRole);
}
```

---

## Role Members

### Set Members

```pawn
// From within role method (uses This_ variant)
@Zombie_Assign(const pPlayer) {
  PlayerRole_This_SetMember(m_flPower, 100.0);
  PlayerRole_This_SetMemberString(m_szVariant, "alpha");
}

// From outside role method
PlayerRole_Player_SetMember(pPlayer, ROLE_ZOMBIE, m_flPower, 150.0);
PlayerRole_Player_SetMemberString(pPlayer, ROLE_ZOMBIE, m_szVariant, "beta");
```

### Get Members

```pawn
// From within role method
new Float:flPower = PlayerRole_This_GetMember(m_flPower);

// From outside
new Float:flPower = PlayerRole_Player_GetMember(pPlayer, ROLE_ZOMBIE, m_flPower);

new szVariant[32];
PlayerRole_Player_GetMemberString(pPlayer, ROLE_ZOMBIE, m_szVariant, szVariant, charsmax(szVariant));
```

---

## Calling Methods

### Call Custom Methods

```pawn
// Call method if player has role
if (PlayerRole_Player_HasRole(pPlayer, ROLE_ZOMBIE)) {
  PlayerRole_Player_CallMethod(pPlayer, ROLE_ZOMBIE, Growl);
  
  new Float:flSpeed = PlayerRole_Player_CallMethod(pPlayer, ROLE_ZOMBIE, GetSpeed);
}
```

### Call Base Method (In Inherited Roles)

```pawn
@FastZombie_Assign(const pPlayer) {
  // Call parent (Zombie) Assign method first
  PlayerRole_This_CallBaseMethod();
  
  // Then add FastZombie-specific logic
  PlayerRole_This_SetMember(m_flSpeedBonus, 50.0);
}
```

---

## Common Patterns

### Spawn-Based Role Assignment

```pawn
public HamHook_Player_Spawn_Post(const pPlayer) {
  if (!is_user_alive(pPlayer)) return HAM_IGNORED;
  
  // Assign role based on team
  switch (get_user_team(pPlayer)) {
    case 1: PlayerRole_Player_AssignRole(pPlayer, ROLE_SURVIVOR, ROLE_GROUP_SPECIES);
    case 2: PlayerRole_Player_AssignRole(pPlayer, ROLE_ZOMBIE, ROLE_GROUP_SPECIES);
  }
  
  return HAM_HANDLED;
}
```

### Role-Based Speed

```pawn
public HamHook_Player_GetMaxSpeed(const pPlayer) {
  if (PlayerRole_Player_HasRole(pPlayer, ROLE_ZOMBIE)) {
    new Float:flSpeed = PlayerRole_Player_CallMethod(pPlayer, ROLE_ZOMBIE, GetSpeed);
    SetHamReturnFloat(flSpeed);
    return HAM_OVERRIDE;
  }
  
  return HAM_IGNORED;
}
```

### Reset on Disconnect

```pawn
public client_disconnected(pPlayer) {
  PlayerRole_Player_UnassignRoles(pPlayer);
}
```

---

## Complete Role Plugin Structure

```pawn
#pragma semicolon 1

#include <amxmodx>

#include <api_player_roles>

/*--------------------------------[ Constants ]--------------------------------*/

#define ROLE "Test"
#define GetMaxSpeed "GetMaxSpeed"
#define GetMaxHealth "GetMaxHealth"

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  PlayerRole_Register(ROLE);

  PlayerRole_ImplementMethod(ROLE, PlayerRole_Method_Assign, "@Role_Assign");
  PlayerRole_ImplementMethod(ROLE, PlayerRole_Method_Unassign, "@Role_Unassign");

  PlayerRole_RegisterVirtualMethod(ROLE, GetMaxSpeed, "@Role_GetMaxSpeed");
  PlayerRole_RegisterVirtualMethod(ROLE, GetMaxHealth, "@Role_GetMaxHealth");
}

public plugin_init() {
  register_plugin("[Role] Test", "1.0.0", "Author");
}
/*--------------------------------[ Methods ]--------------------------------*/

@Role_Assign(const pPlayer) {}

@Role_Unassign(const pPlayer) {}

Float:@Role_GetMaxSpeed(const pPlayer) {
  return 250.0;
}

Float:@Role_GetMaxHealth(const pPlayer) {
  return 100.0;
}
```

---

## Best Practices Checklist

- [ ] Register roles in `plugin_precache`
- [ ] Use inheritance for shared behavior
- [ ] Use groups for mutual exclusivity
- [ ] Use `This_` variants inside role methods
- [ ] Call `PlayerRole_This_CallBaseMethod()` in inherited roles
- [ ] Reset roles on player disconnect
- [ ] Define constants with `#define ROLE_` prefix
