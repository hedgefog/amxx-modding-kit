# 🎩 Player Cosmetics API

The **Player Cosmetics API** enables developers to equip players with custom cosmetic items in GoldSrc-based games. This library provides simple functions to add, remove, and manage cosmetic models attached to players.

## 🚀 Features

- **Equip and Unequip Items**: Easily attach or remove cosmetic models from players.
- **State Management**: Check if a player has a specific item equipped.
- **Entity Access**: Retrieve the entity associated with an equipped cosmetic item.

## 📚 Using the Player Cosmetics API

### ⚙️ Equipping a Cosmetic Item

To equip a player with a cosmetic item, use the `PlayerCosmetic_Equip` function.

```pawn
#include <api_player_cosmetics>

public plugin_init() {
  register_plugin("Player Cosmetics Example", "1.0", "Author");
  register_clcmd("say /equip", "Command_EquipCosmetic");
}

public Command_EquipCosmetic(const pPlayer) {
  new iModelIndex = engfunc(EngFunc_ModelIndex, "models/cosmetics/hat.mdl");
  PlayerCosmetic_Equip(pPlayer, iModelIndex);

  client_print(pPlayer, print_chat, "You equipped a cosmetic item!");

  return PLUGIN_HANDLED;
}
```

### 🧩 Unequipping a Cosmetic Item

To remove a cosmetic item from a player, use the `PlayerCosmetic_Unequip` function.

```pawn
if (PlayerCosmetic_Unequip(pPlayer, iModelIndex)) {
  client_print(pPlayer, print_chat, "You unequipped the cosmetic item.");
} else {
  client_print(pPlayer, print_chat, "You don’t have this cosmetic item equipped.");
}
```

### 🔎 Checking if a Player Has an Item Equipped

Use `PlayerCosmetic_IsEquipped` to determine if a player is wearing a specific cosmetic item.

```pawn
if (PlayerCosmetic_IsEquipped(pPlayer, iModelIndex)) {
  client_print(pPlayer, print_chat, "This cosmetic item is equipped.");
} else {
  client_print(pPlayer, print_chat, "This cosmetic item is not equipped.");
}
```

### 🔗 Getting the Entity of an Equipped Cosmetic Item

Retrieve the entity associated with a cosmetic item using `PlayerCosmetic_GetEntity`.

```pawn
new pEntity = PlayerCosmetic_GetEntity(pPlayer, iModelIndex);

if (pEntity != FM_NULLENT) {
  client_print(pPlayer, print_chat, "Cosmetic entity ID: %d", pEntity);
} else {
  client_print(pPlayer, print_chat, "This cosmetic item is not equipped.");
}
```

## 🧩 Example: Cosmetic Toggle

This example demonstrates how to toggle a cosmetic item on or off for a player using a command.

```pawn
#include <api_player_cosmetics>

public plugin_init() {
  register_plugin("Cosmetic Toggle", "1.0", "Author");
  register_clcmd("say /toggle_cosmetic", "Command_ToggleCosmetic");
}

public Command_ToggleCosmetic(const pPlayer) {
  new iModelIndex = engfunc(EngFunc_ModelIndex, "models/cosmetics/hat.mdl");

  if (PlayerCosmetic_IsEquipped(pPlayer, iModelIndex)) {
    PlayerCosmetic_Unequip(pPlayer, iModelIndex);
    client_print(pPlayer, print_chat, "Cosmetic item unequipped.");
  } else {
    PlayerCosmetic_Equip(pPlayer, iModelIndex);
    client_print(pPlayer, print_chat, "Cosmetic item equipped.");
  }

  return PLUGIN_HANDLED;
}
```

---

## 📖 API Reference

See [`api_player_cosmetics.inc`](include/api_player_cosmetics.inc) for all available natives.
