# 🎭 Player Roles API

The **Player Roles API** is an OOP-style API for defining, assigning, and managing player roles in GoldSrc-based games. Roles are implemented as cellclasses with methods and members, allowing you to encapsulate logic, extend behaviors.
The API can be used not only for roles itself, but also for other purposes, such as customization of player logic in OOP-style to provide custom methods and members.

---

## 🚀 Features

- **OOP Role Logic**: Define roles as class and implement custom methods for assign, unassign, and custom actions.
- **Assignment Groups**: Ensure only one role per group can be assigned to a player at a time (e.g., only one "hat_color" or "player_class" role per player).
- **Multiple Roles**: Assign multiple roles from different groups to a player simultaneously.
- **Role Inheritance**: Create hierarchies - child roles inherit methods from their parent roles.
- **Dynamic Members**: Add, set, and query custom members for each role instance.
- **Flexible Methods**: Register and call custom methods for roles, enabling advanced behaviors.

---

## ⚙️ Registering Roles and Groups

Define your roles and organize them into groups. You can also set up parent-child relationships for inheritance.

```pawn
#include <api_player_roles>

public plugin_precache() {
  // Register color roles
  PlayerRole_Register("red");
  PlayerRole_Register("blue");

  // Register class roles
  PlayerRole_Register("support");
  PlayerRole_Register("offense");
  PlayerRole_Register("defence");

  // Register a commander role that inherits from support
  PlayerRole_Register("commander", "support");

  // Registering zombie roles that inherit from base_zombie
  PlayerRole_Register("base_zombie");
  PlayerRole_Register("fast_zombie", "base_zombie");
  PlayerRole_Register("poison_zombie", "base_zombie");
}
```

---

## 🧩 Implementing and Registering Methods

Implement native methods (like assign/unassign) using `PlayerRole_ImplementMethod`. For custom logic, register new methods with `PlayerRole_RegisterMethod`.

```pawn
public plugin_precache() {
  // Implement assign/unassign logic for "support"
  PlayerRole_ImplementMethod("support", PlayerRole_Method_Assign, "@Support_Assign");
  PlayerRole_ImplementMethod("support", PlayerRole_Method_Unassign, "@Support_Unassign");

  // Register a custom method "Heal" for "medic"
  PlayerRole_RegisterMethod("medic", "Heal", "@Medic_Heal");
}

@Support_Assign(pPlayer) {
  client_print(pPlayer, print_chat, "You are now support!");
}

@Support_Unassign(pPlayer) {
  client_print(pPlayer, print_chat, "You are no longer support.");
}

@Medic_Heal(pPlayer) {
  // Custom healing logic
  set_user_health(pPlayer, get_user_health(pPlayer) + 25);
  client_print(pPlayer, print_chat, "You have been healed!");
}
```

You can call base methods in inherited roles using `PlayerRole_Player_CallBaseMethod(pPlayer)`.

---

## 📚 Setting and Using Members

Add custom members to a role instance for storing state or configuration.

```pawn
public plugin_precache() {
  PlayerRole_ImplementMethod("commander", PlayerRole_Method_Assign, "@Commander_Assign");
}

@Commander_Assign(pPlayer) {
  // Set a custom member "iLevel" for the commander role
  PlayerRole_Player_SetMember(pPlayer, "commander", "iLevel", 5);

  // Add a string member
  PlayerRole_Player_SetMemberString(pPlayer, "commander", "szTitle", "General");

  client_print(pPlayer, print_chat, "You are now a commander! Level: %d", PlayerRole_Player_GetMember(pPlayer, "commander", "iLevel"));
}

// Later, retrieve the member value
public SomeFunction(pPlayer) {
  new iLevel = PlayerRole_Player_GetMember(pPlayer, "commander", "iLevel");
  new szTitle[32]; PlayerRole_Player_GetMemberString(pPlayer, "commander", "szTitle", szTitle, charsmax(szTitle));

  client_print(pPlayer, print_chat, "Commander title: %s, level: %d", szTitle, iLevel);
}
```

---

## 🤙 Calling Custom Methods

Invoke custom methods for a player's role using `PlayerRole_Player_CallMethod`.

```pawn
// Call the "Heal" method for the "medic" role
PlayerRole_Player_CallMethod(pPlayer, "medic", "Heal");
```

---

## ⛓️ Assigning and Unassigning Roles

Assign or remove roles for players. Role methods will be called automatically.

```pawn
// Assign the "support" role to a player in the "player_class" group
PlayerRole_Player_AssignRole(pPlayer, "support", "player_class");

// Unassign the "support" role from a player
PlayerRole_Player_UnassignRole(pPlayer, "support");
```

Assigning a role with a specific group will automatically unassign any previous role from that same group.
If no group is provided, the role acts independently of others (unless it shares a parent role).

---

## 🕵️ Checking and Querying Roles

Check if a player has a specific role or a role within a group.

```pawn
if (PlayerRole_Player_HasRole(pPlayer, "support")) {
  // Player is support (checks inheritance)
}

if (PlayerRole_Player_HasExactRole(pPlayer, "support")) {
  // Player has exactly the "support" role (no inheritance check)
}

if (PlayerRole_Player_HasRoleGroup(pPlayer, "color")) {
  // Player has a role in the "color" group
}

// Get the current role a player has in a group
new szRole[PLAYER_ROLE_MAX_LENGTH];
if (PlayerRole_Player_GetRoleByGroup(pPlayer, "color", szRole, charsmax(szRole))) {
  client_print(pPlayer, print_chat, "Your color role: %s", szRole);
}
```

---

## 🛠 Implementing Methods

Once a role is registered, you can define its behavior by implementing methods. The API provides methods to trigger custom logic when a role is assigned or unassigned.

### Implementing the `Assign` Method

The `Assign` method is called when a role is assigned to a player. The `Unassign` method is called when a role is unassigned.

```pawn
#include <amxmodx>

#include <api_player_roles>

public plugin_precache() {
  PlayerRole_Register("zombie");
  PlayerRole_ImplementMethod("zombie", PlayerRole_Method_Assign, "@Zombie_Assign");
}

@Zombie_Assign(const pPlayer) {
  PlayerRole_Player_SetMember(pPlayer, "zombie", "flPower", 100.0);
  client_print(pPlayer, print_chat, "You are now a zombie! Power: %f", PlayerRole_Player_GetMember(pPlayer, "zombie", "flPower"));
}
```

---

## 🔧 Advanced Usage

### Role Hierarchies

Roles can inherit from other roles, allowing for more complex behavior trees.

```pawn
PlayerRole_Register("medic", "support");
```

New `medic` role inherits from `support` role. This means the `medic` has same methods as `support` and can override them if needed.

### Role Inheritance

You can inherit roles from other roles, allowing for more complex behavior trees. New role will inherit all methods from the parent role.
Player can not have multiple roles with the same parent role, so assigning a role with the same parent role as the existing role will unassign the existing role before.

```pawn
public plugin_precache() {
  PlayerRole_Register("base_zombie");
  PlayerRole_Register("fast_zombie", "base_zombie");
  PlayerRole_Register("poison_zombie", "base_zombie");
}
```

```pawn
  // Assign "fast_zombie" role
  PlayerRole_Player_AssignRole(pPlayer, "fast_zombie");

  // Assign "poison_zombie" role ("fast_zombie" role will be unassigned)
  PlayerRole_Player_AssignRole(pPlayer, "poison_zombie");
```

### Assignment Groups

**Assignment Groups** are used to provide unique identifier to assigned roles.

When you assign a role with a **Assignment Group**, the system checks if the player already has a role in that group and unassigns it before assigning the new one. This allows for flexible, dynamic grouping without rigid registration.

**Example scenarios:**

```pawn
// Assign "red" as a "color"
PlayerRole_Player_AssignRole(pPlayer, "red", "hat_color");

// Later, assign "blue" as a "color" -> "red" is automatically unassigned
PlayerRole_Player_AssignRole(pPlayer, "blue", "hat_color");
```

You can use this to enforce exclusivity dynamically:
- Group `"hat_color"`: enforce one color at a time.
- Group `"player_class"`: enforce one class at a time.

A player can have `"red"` (group `"hat_color"`) and `"medic"` (group `"player_class"`) simultaneously. However, assigning `"engineer"` to `"player_class"` group will replace `"medic"`, which assigned to the same `"player_class"` group.

## 🧩 Registering Custom Methods

The API allows you to register custom methods for roles. These methods can be called from other plugins.

**Registering custom method:**

```pawn
#include <amxmodx>

#include <api_player_roles>

public plugin_precache() {
  PlayerRole_Register("zombie");
  PlayerRole_RegisterMethod("zombie", "Growl", "@Zombie_Growl");
}

@Zombie_Growl(const pPlayer) {
  client_print(pPlayer, print_center, "Grrrrrrr!");
}
```

**Calling methods:**

```pawn
if (PlayerRole_Player_HasRole(pPlayer, "zombie")) {
  PlayerRole_Player_CallMethod(pPlayer, "zombie", "Growl");
}
```

---
## 📖 API Reference

See [`api_player_roles.inc`](include/api_player_roles.inc) and [`api_player_roles_const.inc`](include/api_player_roles_const.inc) for all available natives and constants.
