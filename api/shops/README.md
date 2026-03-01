# 🛒 Shops API

The **Shops API** provides a flexible and extensible system for creating, customizing, and managing in-game shops and items in AmxModX mods. It supports advanced features such as custom balance logic, access control, and dynamic menus.

---

## 🚀 Features

- Register and manage multiple independent shops
- Register items once and add them to any number of shops with different prices
- Fully customizable shop menu appearance and behavior
- Flexible money format for displaying prices and balances
- Integrate custom logic for player balance retrieval and updates
- Guard callbacks for advanced access control to shops and items
- Per-item purchase and guard callbacks for custom item logic
- Dynamic price setting and retrieval for each item
- Player API for opening shops, purchasing items, and checking balances

---

## ⚙️ Implementing a Shop

### Registering a  Shop
To create a new shop, use `Shop_Register` with a unique string ID:

```pawn
Shop_Register("my-shop");
```

You can also specify shop properties:
```pawn
Shop_SetTitle("my-shop", "My Shop");
Shop_SetDescription("my-shop", "Welcome to my shop!");
Shop_SetMoneyFormat("my-shop", "%d USD");
```

### Registering an Item

Register an item once and add it to any shop:

```pawn
Shop_Item_Register("my-item");
Shop_Item_SetTitle("my-item", "My Item");
Shop_Item_SetDescription("my-item", "This is my item!");
```

### Implementing Purchase Logic

Assign a callback to handle item purchases:

```amxxpawn
Shop_Item_SetPurchaseCallback("my-item", "@MyItem_Purchase");

@MyItem_Purchase(const pPlayer) {
  give_item(pPlayer, "weapon_ak47");
}
```

#### Protect item with guard
Use `Shop_Item_SetGuardCallback` to provide function that will be called when a player tries to purchase an item:

```pawn
Shop_Item_SetGuardCallback("my-item", "@MyItem_Guard");
```

Implement function `@MyItem_Guard`:

```pawn
@MyItem_Guard(const pPlayer) {
  // Don't allow dead players to purchase the item
  if (!is_user_alive(pPlayer)) return false;

  return true;
}
```

### Adding Items to the Shop
Use `Shop_AddItem` function to add an item to the shop:

```pawn
Shop_AddItem("my-shop", "my-item", ITEM_PRICE);
```

## 🧪 Testing your Shop

Run the game and write `shop my-shop` to console to open your shop. It will open the shop menu with all added items.

## 🦸 Advanced Usage

### Custom Balance Handler

The `Shop API` allows you to customize the balance handler by providing your own implementation. This is useful if you want to make integration with custom balance system instead of using the default one provided by the game. For `Counter-Strike` it uses game money by default.

Use `Shop_SetBalanceCallbacks` function to provide your own balance setter and getter functions:

```pawn
Shop_SetBalanceCallbacks("my-shop", "@MyShop_BalanceGet", "@MyShop_BalanceSet")
```

Implement functions `@MyShop_BalanceGet` and `@MyShop_BalanceSet`:

```pawn
@MyShop_BalanceGet(const pPlayer) {
  return MyCustomSystem_GetBalance(pPlayer);
}

@MyShop_BalanceSet(const pPlayer, const iBalance) {
  MyCustomSystem_SetBalance(pPlayer, iBalance);
}
```

### Customizing Shop Menu

It's possible to customize the shop menu appearance and behavior by setting specific flags. For example you can add item info page by set flag `Shop_Flag_ItemPage`, so when you choose item from menu the info page will be shown instead of instant purchase:

```pawn
Shop_SetFlags("my-shop", Shop_Flag_ItemPage);
```

To provide extra confirmation before purchase, you can use the `Shop_Flag_PurchaseConfirmation` flag:

```pawn
Shop_SetFlags("my-shop", Shop_Flag_PurchaseConfirmation);
```

You can combine multiple flags by using bitwise OR operator:

```pawn
Shop_SetFlags("my-shop", Shop_Flag_ItemPage | Shop_Flag_PurchaseConfirmation);
```

## ✨ Tips

- Override the native `buyequip` command to open your shop. By default this commmand is binded to `O` key, so players can use shop menu by pressing `O` key without need to rebind it or using custom menus.

  ```pawn
  public plugin_init() {
    // ...

    register_clcmd("buyequip", "Command_Shop");
  }

  public Command_Shop(const pPlayer) {
    Shop_Player_OpenShop(pPlayer, "my-shop");
  }
  ```

---

## 🧩 Example: Secret Shop

```pawn
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_shops>

#define SECRET_SHOP "secret-shop"
#define SHOP_ITEM_HEALING "healing-potion"

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

new g_rgiPlayerCoins[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("Secret Shop", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

  Shop_Register(SECRET_SHOP);
  Shop_SetTitle(SECRET_SHOP, "Secret Shop");
  Shop_SetDescription(SECRET_SHOP, "This is a secret shop. How did you find it?");
  Shop_SetFlags(SECRET_SHOP, Shop_Flag_ItemPage | Shop_Flag_PurchaseConfirmation);
  Shop_SetBalanceCallbacks(SECRET_SHOP, "@SecretShop_GetBalance", "@SecretShop_SetBalance");
  Shop_SetGuardCallback(SECRET_SHOP, "@SecretShop_Guard");
  Shop_SetMoneyFormat(SECRET_SHOP, "%d COINS");

  Shop_Item_Register(SHOP_ITEM_HEALING);
  Shop_Item_SetTitle(SHOP_ITEM_HEALING, "Healing Potion");
  Shop_Item_SetDescription(SHOP_ITEM_HEALING, "Fully restore your health.");
  Shop_Item_SetPurchaseCallback(SHOP_ITEM_HEALING, "@HealingPotionItem_Purchase");
  Shop_Item_SetGuardCallback(SHOP_ITEM_HEALING, "@HealingPotionItem_Guard");

  Shop_AddItem(SECRET_SHOP, SHOP_ITEM_HEALING, 100);
}

public client_connect(pPlayer) {
  g_rgiPlayerCoins[pPlayer] = 0;
}

public HamHook_Player_Killed_Post(const pPlayer, const pKiller) {
  if (IS_PLAYER(pKiller)) {
    // Add 100 coins to the killer's balance
    g_rgiPlayerCoins[pKiller] += 100;
  }
}

@SecretShop_Guard(const pPlayer) {
  // Allow using shop only for players with `b` flag
  if (~get_user_flags(pPlayer) & ADMIN_RESERVATION) return false;

  return true;
}

@SecretShop_GetBalance(const pPlayer) {
  return g_rgiPlayerCoins[pPlayer];
}

@SecretShop_SetBalance(const pPlayer, const iMoney) {
  g_rgiPlayerCoins[pPlayer] = iMoney;
}

@HealingPotionItem_Purchase(const pPlayer) {
  static Float:flMaxHealth; pev(pPlayer, pev_max_health, flMaxHealth);

  set_pev(pPlayer, pev_health, flMaxHealth);

  client_print(pPlayer, print_chat, "You have been healed!");
}

@HealingPotionItem_Guard(const pPlayer) {
  if (!is_user_alive(pPlayer)) return false;

  static Float:flHealth; pev(pPlayer, pev_health, flHealth);
  static Float:flMaxHealth; pev(pPlayer, pev_max_health, flMaxHealth);

  return flHealth < flMaxHealth;
}
```

---

## 📖 API Reference

See [`api_shops.inc`](include/api_shops.inc) and [`api_shops_const.inc`](include/api_shops_const.inc) for all available natives and constants.
