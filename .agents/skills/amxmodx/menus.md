---
name: amxmodx-menus
description: AMX Mod X menu creation, callbacks, and menu system patterns.
globs: "*.sma,*.inc"
---

# Menus

## Menu Callbacks

Menu callbacks have **fixed signatures** defined by the engine.

### Naming Convention

```pawn
// Single menu plugin - use Callback_Menu
public Callback_Menu(const pPlayer, const iMenu, const iItem)

// Multi-menu plugin - use Callback_Menu_{MenuName}
public Callback_Menu_Shop(const pPlayer, const iMenu, const iItem)
public Callback_Menu_Team(const pPlayer, const iMenu, const iItem)
public Callback_Menu_Settings(const pPlayer, const iMenu, const iItem)

// Menu item callback (for menu_makecallback)
public Callback_MenuItem_{Name}(const pPlayer, const iMenu, const iItem)
```

### Basic Menu Callback

```pawn
public Callback_Menu(const pPlayer, const iMenu, const iItem) {
  if (iItem < 0) return PLUGIN_HANDLED; // Menu cancelled
  
  // Handle menu selection
  return PLUGIN_HANDLED;
}
```

### Menu Item Callback

Menu item callbacks control whether items are enabled/disabled:

```pawn
// Returns ITEM_IGNORE, ITEM_ENABLED, or ITEM_DISABLED
public Callback_MenuItem_TeamOption(const pPlayer, const iMenu, const iItem) {
  // Example: disable option if player is dead
  if (!is_user_alive(pPlayer)) {
    return ITEM_DISABLED;
  }
  
  return ITEM_IGNORE; // Use default behavior
}
```

---

## Menu System Pattern

Use `Create{Name}Menu` for menu creation with `Callback_Menu_{Name}` handler. Use an `enum` for menu items:

```pawn
enum TeamMenu_Item {
  TeamMenu_Item_First,
  TeamMenu_Item_Second,
  TeamMenu_Item_Third
};

new g_iTeamMenu;

public plugin_init() {
  g_iTeamMenu = CreateTeamMenu();
}

CreateTeamMenu() {
  new iMenu = menu_create("Team Menu", "Callback_Menu_Team");

  for (new TeamMenu_Item:iItem = TeamMenu_Item:0; iItem < TeamMenu_Item; ++iItem) {
    switch (iItem) {
      case TeamMenu_Item_First: menu_additem(iMenu, "Option 1");
      case TeamMenu_Item_Second: menu_additem(iMenu, "Option 2");
      case TeamMenu_Item_Third: menu_additem(iMenu, "Option 3");
    }
  }

  return iMenu;
}

OpenTeamMenu(const pPlayer) {
  menu_display(pPlayer, g_iTeamMenu, 0);
}

public Callback_Menu_Team(const pPlayer, const iMenu, const iItem) {
  if (iItem < 0) return PLUGIN_HANDLED; // Menu cancelled
  
  switch (iItem) {
    case TeamMenu_Item_First: { /* Handle option 1 */ }
    case TeamMenu_Item_Second: { /* Handle option 2 */ }
    case TeamMenu_Item_Third: { /* Handle option 3 */ }
  }

  return PLUGIN_HANDLED;
}
```

---

## Dynamic Menu Pattern

For menus with dynamic content that changes per-player:

```pawn
OpenShopMenu(const pPlayer) {
  new iMenu = menu_create("Shop", "Callback_Menu_Shop");
  
  // Add items dynamically based on player state
  new iMoney = cs_get_user_money(pPlayer);
  
  static szItem[64];
  for (new i = 0; i < g_iShopItemsNum; ++i) {
    new iPrice = g_rgiShopPrices[i];
    formatex(szItem, charsmax(szItem), "%s \y[$%d]", g_rgszShopNames[i], iPrice);
    
    // Pass item index as info
    new szInfo[8];
    num_to_str(i, szInfo, charsmax(szInfo));
    
    // Disable if player can't afford
    menu_additem(iMenu, szItem, szInfo, (iMoney >= iPrice) ? 0 : (1 << 26));
  }
  
  menu_display(pPlayer, iMenu, 0);
}

public Callback_Menu_Shop(const pPlayer, const iMenu, const iItem) {
  if (iItem < 0) {
    menu_destroy(iMenu); // Destroy dynamic menu
    return PLUGIN_HANDLED;
  }
  
  // Get item info (index we stored)
  static szInfo[8];
  menu_item_getinfo(iMenu, iItem, _, szInfo, charsmax(szInfo));
  new iShopItem = str_to_num(szInfo);
  
  // Process purchase
  PurchaseItem(pPlayer, iShopItem);
  
  menu_destroy(iMenu); // Destroy dynamic menu
  return PLUGIN_HANDLED;
}
```

---

## Menu with Item Callbacks

Use `menu_makecallback` for dynamic item states:

```pawn
CreateWeaponMenu() {
  new iMenu = menu_create("Weapons", "Callback_Menu_Weapon");
  
  menu_additem(iMenu, "AK-47", "1", 0, menu_makecallback("Callback_MenuItem_Weapon"));
  menu_additem(iMenu, "M4A1", "2", 0, menu_makecallback("Callback_MenuItem_Weapon"));
  menu_additem(iMenu, "AWP", "3", 0, menu_makecallback("Callback_MenuItem_Weapon"));
  
  return iMenu;
}

public Callback_MenuItem_Weapon(const pPlayer, const iMenu, const iItem) {
  static szInfo[8];
  menu_item_getinfo(iMenu, iItem, _, szInfo, charsmax(szInfo));
  new iWeaponId = str_to_num(szInfo);
  
  // Disable if player already has this weapon
  if (PlayerHasWeapon(pPlayer, iWeaponId)) {
    return ITEM_DISABLED;
  }
  
  return ITEM_ENABLED;
}
```

---

## Menu Properties

```pawn
// Set menu properties
menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);        // Show exit button
menu_setprop(iMenu, MPROP_PERPAGE, 7);             // Items per page
menu_setprop(iMenu, MPROP_BACKNAME, "Back");       // Back button text
menu_setprop(iMenu, MPROP_NEXTNAME, "Next");       // Next button text
menu_setprop(iMenu, MPROP_EXITNAME, "Exit");       // Exit button text
menu_setprop(iMenu, MPROP_TITLE, "New Title");     // Change title
menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\y");     // Number color
```

---

## Menu Item States

| Constant | Value | Description |
|----------|-------|-------------|
| `ITEM_IGNORE` | 0 | Use default state |
| `ITEM_ENABLED` | 1 | Force enable item |
| `ITEM_DISABLED` | 2 | Force disable item (grayed out) |

---

## Best Practices

1. **Use `Callback_Menu_{Name}` prefix** for menu handlers
2. **Use `Callback_MenuItem_{Name}` prefix** for item callbacks
3. **Use enum for menu items** to avoid index mistakes in switch
4. **Always check `iItem < 0`** for cancelled menus
5. **Destroy dynamic menus** in callback with `menu_destroy`
6. **Store static menus globally** - create once in `plugin_init`
7. **Use item info** to pass data to callback (not item index)
