---
name: amxx-modding-kit-api-shops
description: Guide for Shops API usage creating in-game shops with items, custom balance systems, and access control.
---

# Shops API

Flexible system for creating and managing in-game shops with custom balance handlers, access control, and dynamic menus.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/shops/README.md).

---

## Naming Conventions

Use `#define` for shop and item identifiers:

```pawn
#define SHOP_EQUIPMENT "equipment-shop"
#define SHOP_VIP "vip-shop"

#define ITEM_MEDKIT "medkit"
#define ITEM_ARMOR "armor"
#define ITEM_WEAPON "weapon"
```

---

## Shop Registration

### Create a Shop

```pawn
public plugin_init() {
  Shop_Register(SHOP_EQUIPMENT);
  
  // Set shop properties
  Shop_SetTitle(SHOP_EQUIPMENT, "Equipment Shop");
  Shop_SetDescription(SHOP_EQUIPMENT, "Buy weapons and gear");
  Shop_SetMoneyFormat(SHOP_EQUIPMENT, "$%d");
}
```

### Shop Flags

```pawn
// Show item info page before purchase
Shop_SetFlags(SHOP_EQUIPMENT, Shop_Flag_ItemPage);

// Require purchase confirmation
Shop_SetFlags(SHOP_EQUIPMENT, Shop_Flag_PurchaseConfirmation);

// Combine flags
Shop_SetFlags(SHOP_EQUIPMENT, Shop_Flag_ItemPage | Shop_Flag_PurchaseConfirmation);
```

---

## Item Registration

### Register Item

```pawn
public plugin_init() {
  // Register item (once)
  Shop_Item_Register(ITEM_MEDKIT);
  Shop_Item_SetTitle(ITEM_MEDKIT, "Health Potion");
  Shop_Item_SetDescription(ITEM_MEDKIT, "Restores 50 health points");
  
  // Set purchase callback
  Shop_Item_SetPurchaseCallback(ITEM_MEDKIT, "Callback_ShopItem_Purchase");
}

public Callback_ShopItem_Purchase(const pPlayer) {
  new Float:flHealth; pev(pPlayer, pev_health, flHealth);
  set_pev(pPlayer, pev_health, floatmin(flHealth + 50.0, 100.0));
  
  client_print(pPlayer, print_chat, "You feel healthier!");
}
```

### Add Item to Shop

```pawn
// Add item with price
Shop_AddItem(SHOP_EQUIPMENT, ITEM_MEDKIT, 500);

// Same item can be added to multiple shops with different prices
Shop_AddItem(SHOP_VIP, ITEM_MEDKIT, 300); // Discounted
```

---

## Guard Callbacks

### Shop Guard

Control who can access the shop:

```pawn
public plugin_init() {
  Shop_Register(SHOP_VIP);
  Shop_SetGuardCallback(SHOP_VIP, "Callback_Shop_Guard");
}

public Callback_Shop_Guard(const pPlayer) {
  // Only allow VIP players
  if (~get_user_flags(pPlayer) & ADMIN_RESERVATION) {
    client_print(pPlayer, print_chat, "VIP access required!");
    return false;
  }
  
  return true;
}
```

### Item Guard

Control who can purchase specific items:

```pawn
public plugin_init() {
  Shop_Item_Register(ITEM_ARMOR);
  Shop_Item_SetGuardCallback(ITEM_ARMOR, "Callback_ShopItem_Guard");
}

public Callback_ShopItem_Guard(const pPlayer) {
  // Must be alive
  if (!is_user_alive(pPlayer)) return false;
  
  // Must not already have armor
  new Float:flArmor; pev(pPlayer, pev_armorvalue, flArmor);
  if (flArmor >= 100.0) {
    client_print(pPlayer, print_chat, "You already have full armor!");
    return false;
  }
  
  return true;
}
```

---

## Custom Balance System

Replace default game money with custom balance:

```pawn
new g_rgiPlayerCoins[MAX_PLAYERS + 1];

public plugin_init() {
  Shop_Register(SHOP_COINS);
  Shop_SetBalanceCallbacks(SHOP_COINS, "Callback_Shop_GetBalance", "Callback_Shop_SetBalance");
  Shop_SetMoneyFormat(SHOP_COINS, "%d COINS");
}

public Callback_Shop_GetBalance(const pPlayer) {
  return g_rgiPlayerCoins[pPlayer];
}

public Callback_Shop_SetBalance(const pPlayer, const iBalance) {
  g_rgiPlayerCoins[pPlayer] = iBalance;
}
```

---

## Opening Shops

### Via Command

```pawn
public plugin_init() {
  register_clcmd("say /shop", "Command_Shop");
}

public Command_Shop(const pPlayer) {
  Shop_Player_OpenShop(pPlayer, SHOP_EQUIPMENT);
  return PLUGIN_HANDLED;
}
```

### Override Buy Menu

```pawn
public plugin_init() {
  // Override O key (buyequip) to open custom shop
  register_clcmd("buyequip", "Command_BuyEquip");
}

public Command_BuyEquip(const pPlayer) {
  Shop_Player_OpenShop(pPlayer, SHOP_EQUIPMENT);
  return PLUGIN_HANDLED;
}
```

---

## Common Patterns

### Complete Shop Setup

```pawn
#define SHOP_MOD "mod-shop"
#define ITEM_MEDKIT "medkit"
#define ITEM_ARMOR "armor"
#define ITEM_WEAPON "weapon"

public plugin_init() {
  // Register shop
  Shop_Register(SHOP_MOD);
  Shop_SetTitle(SHOP_MOD, "Mod Shop");
  Shop_SetDescription(SHOP_MOD, "Purchase equipment");
  Shop_SetFlags(SHOP_MOD, Shop_Flag_ItemPage);
  Shop_SetGuardCallback(SHOP_MOD, "Callback_Shop_Guard");
  
  // Register items
  RegisterShopItem(ITEM_MEDKIT, "Medkit", "Restores health", "Callback_ShopItem_Medkit_Purchase", "Callback_ShopItem_Medkit_Guard", 200);
  RegisterShopItem(ITEM_ARMOR, "Armor", "Adds protection", "Callback_ShopItem_Armor_Purchase", "Callback_ShopItem_Armor_Guard", 500);
  RegisterShopItem(ITEM_WEAPON, "Weapon", "Primary weapon", "Callback_ShopItem_Weapon_Purchase", _, 1000);
  
  register_clcmd("say /shop", "Command_Shop");
}

RegisterShopItem(const szId[], const szTitle[], const szDesc[], const szPurchase[], const szGuard[] = "", iPrice) {
  Shop_Item_Register(szId);
  Shop_Item_SetTitle(szId, szTitle);
  Shop_Item_SetDescription(szId, szDesc);
  Shop_Item_SetPurchaseCallback(szId, szPurchase);
  
  if (szGuard[0]) {
    Shop_Item_SetGuardCallback(szId, szGuard);
  }
  
  Shop_AddItem(SHOP_MOD, szId, iPrice);
}

public Callback_Shop_Guard(const pPlayer) {
  if (!is_user_alive(pPlayer)) {
    client_print(pPlayer, print_chat, "You must be alive to shop!");
    return false;
  }
  return true;
}

public Callback_ShopItem_Medkit_Guard(const pPlayer) {
  new Float:flHealth; pev(pPlayer, pev_health, flHealth);
  new Float:flMaxHealth; pev(pPlayer, pev_max_health, flMaxHealth);
  return flHealth < flMaxHealth;
}

public Callback_ShopItem_Medkit_Purchase(const pPlayer) {
  new Float:flMaxHealth; pev(pPlayer, pev_max_health, flMaxHealth);
  set_pev(pPlayer, pev_health, flMaxHealth);
  client_print(pPlayer, print_chat, "Health restored!");
}

public Callback_ShopItem_Armor_Guard(const pPlayer) {
  new Float:flArmor; pev(pPlayer, pev_armorvalue, flArmor);
  return flArmor < 100.0;
}

public Callback_ShopItem_Armor_Purchase(const pPlayer) {
  set_pev(pPlayer, pev_armorvalue, 100.0);
  client_print(pPlayer, print_chat, "Armor equipped!");
}

public Callback_ShopItem_Weapon_Purchase(const pPlayer) {
  give_item(pPlayer, "weapon_ak47");
  client_print(pPlayer, print_chat, "Weapon received!");
}

public Command_Shop(const pPlayer) {
  Shop_Player_OpenShop(pPlayer, SHOP_MOD);
  return PLUGIN_HANDLED;
}
```

### Round-Based Shop Access

```pawn
public Callback_Shop_Guard(const pPlayer) {
  if (!is_user_alive(pPlayer)) return false;
  
  // Only allow during freeze period
  if (!Round_IsFreezePeriod()) {
    client_print(pPlayer, print_chat, "Shop only available during freeze time!");
    return false;
  }
  
  return true;
}
```

### Role-Based Items

```pawn
public Callback_ShopItem_ZombieItem_Guard(const pPlayer) {
  if (!PlayerRole_Player_HasRole(pPlayer, ROLE_ZOMBIE)) {
    client_print(pPlayer, print_chat, "Zombies only!");
    return false;
  }
  return true;
}
```

---

## Checklist

- [ ] Register shop in `plugin_init`
- [ ] Register items with callbacks
- [ ] Add items to shops with prices
- [ ] Implement guard callbacks for access control
- [ ] Set money format for custom balance
- [ ] Consider using `Shop_Flag_ItemPage` for item descriptions
- [ ] Override `buyequip` for default key binding
