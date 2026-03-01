#pragma semicolon 1;

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <function_pointer>
#include <lang_util>

#include <api_shops_const>

#define LOG_PREFIX "[Shops]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define ERR_INVALID_FUNCTION "Invalid function %s!"
#define ERR_SHOP_ALREADY_EXISTS "Shop ^"%s^" already exists!"
#define ERR_ITEM_ALREADY_EXISTS "Item ^"%s^" already exists!"
#define ERR_PLAYER_IS_NOT_CONNECTED "Player %d is not connected!"
#define ERR_SHOP_NOT_REGISTERED "Shop ^"%s^" doesn't exist!"
#define ERR_ITEM_NOT_REGISTERED "Item ^"%s^" doesn't exist!"
#define ERR_ITEM_NOT_REGISTERED_IN_SHOP "Item ^"%s^" doesn't exist in shop ^"%s^"!"

#define ERR_CLIENT_SHOP_NOT_REGISTERED "Shop ^"%s^" doesn't exist!"
#define ERR_CLIENT_ITEM_NOT_REGISTERED "Item ^"%s^" doesn't exist!"
#define ERR_CLIENT_ITEM_NOT_REGISTERED_IN_SHOP "Item ^"%s^" doesn't exist in shop ^"%s^"!"

enum LocalizationFlags (<<=1) {
  LocalizationFlag_None = 0,
  LocalizationFlag_Title = 1,
  LocalizationFlag_Description,
};

enum Menu_ItemInfo_Item {
  Menu_ItemInfo_Item_Purchase = 0,
  Menu_ItemInfo_Item_BackToShop = 4
};

enum Menu_PurchaseConfirmation_Item {
  Menu_PurchaseConfirmation_Item_Confirm = 4,
  Menu_PurchaseConfirmation_Item_Cancel = 9
};

new bool:g_bCstrike = false;

new Trie:g_itShopIds = Invalid_Trie;
new g_rgszShopId[SHOPS_MAX_SHOPS][SHOPS_MAX_SHOP_ID_LENGTH];
new g_rgszShopTitle[SHOPS_MAX_SHOPS][SHOPS_MAX_SHOP_TITLE_LENGTH];
new g_rgszShopDescription[SHOPS_MAX_SHOPS][SHOPS_MAX_SHOP_DESCRIPTION_LENGTH];
new g_rgszShopMoneyFormat[SHOPS_MAX_SHOPS][16];
new Shop_Flags:g_rgiShopFlags[SHOPS_MAX_SHOPS];
new Function:g_rgfnShopBalanceGetter[SHOPS_MAX_SHOPS];
new Function:g_rgfnShopBalanceSetter[SHOPS_MAX_SHOPS];
new Function:g_rgfnShopGuardCallback[SHOPS_MAX_SHOPS];
new g_rgrgiShopItems[SHOPS_MAX_SHOPS][SHOPS_MAX_SHOP_ITEMS];
new g_rgrgiShopItemPrice[SHOPS_MAX_SHOPS][SHOPS_MAX_SHOP_ITEMS];
new g_rgiShopItemsNum[SHOPS_MAX_SHOPS];
new LocalizationFlags:g_rgiShopLocalizationFlags[SHOPS_MAX_SHOPS];
new g_iShopsNum = 0;

new Trie:g_itItemIds = Invalid_Trie;
new g_rgszItemId[MAX_ITEMS][SHOPS_MAX_ITEM_ID_LENGTH];
new g_rgszItemTitle[MAX_ITEMS][SHOPS_MAX_ITEM_TITLE_LENGTH];
new g_rgszItemDescription[MAX_ITEMS][SHOPS_MAX_ITEM_DESCRIPTION_LENGTH];
new Function:g_rgfnItemGuardCallback[MAX_ITEMS];
new Function:g_rgfnItemPurchaseCallback[MAX_ITEMS];
new LocalizationFlags:g_rgiItemLocalizationFlags[MAX_ITEMS];
new g_iItemsNum = 0;

new g_rgiPlayerCurrentShopId[MAX_PLAYERS + 1];
new g_rgiPlayerCurrentItemId[MAX_PLAYERS + 1];
new g_rgiPlayerMenu[MAX_PLAYERS + 1];

public plugin_precache() {
  g_itShopIds = TrieCreate();
  g_itItemIds = TrieCreate();
  g_bCstrike = !!cstrike_running();
}

public plugin_init() {
  register_plugin("[API] Shops", "1.0.0", "Hedgehog Fog");

  register_clcmd("shop", "Command_Shop", ADMIN_ALL);
  register_clcmd("shop_purchase", "Command_Purchase", ADMIN_ALL);
}

public plugin_natives() {
  register_library("api_shops");

  register_native("Shop_Register", "Native_RegisterShop");
  register_native("Shop_IsRegistered", "Native_IsShopRegistered");
  register_native("Shop_SetTitle", "Native_SetShopTitle");
  register_native("Shop_SetDescription", "Native_SetShopDescription");
  register_native("Shop_SetFlags", "Native_SetShopFlags");
  register_native("Shop_SetMoneyFormat", "Native_SetShopMoneyFormat");
  register_native("Shop_SetBalanceCallbacks", "Native_SetShopBalanceCallbacks");
  register_native("Shop_SetGuardCallback", "Native_SetShopGuardCallback");
  register_native("Shop_AddItem", "Native_AddShopItem");
  register_native("Shop_HasItem", "Native_ShopHasItem");
  register_native("Shop_GetItemPrice", "Native_GetShopItemPrice");

  register_native("Shop_Item_Register", "Native_RegisterShopItem");
  register_native("Shop_Item_IsRegistered", "Native_IsShopItemRegistered");
  register_native("Shop_Item_SetTitle", "Native_SetShopItemTitle");
  register_native("Shop_Item_SetDescription", "Native_SetShopItemDescription");
  register_native("Shop_Item_SetPurchaseCallback", "Native_SetPurchaseCallback");
  register_native("Shop_Item_SetGuardCallback", "Native_SetShopItemGuardCallback");

  register_native("Shop_Player_OpenShop", "Native_OpenShop");
  register_native("Shop_Player_PurchaseItem", "Native_PurchaseShopItem");
  register_native("Shop_Player_CanPurchaseItem", "Native_CanPlayerPurchaseItem");
  register_native("Shop_Player_GetBalance", "Native_GetPlayerBalance");
}

public plugin_end() {
  TrieDestroy(g_itShopIds);
  TrieDestroy(g_itItemIds);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterShop(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));

  if (Shop_GetId(szShopId) != -1) {
    LOG_FATAL_ERROR(ERR_SHOP_ALREADY_EXISTS, szShopId);
    return;
  }

  Shop_Register(szShopId);
}

public bool:Native_IsShopRegistered(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));

  return Shop_GetId(szShopId) != -1;
}

public Native_SetShopTitle(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szTitle[SHOPS_MAX_SHOP_TITLE_LENGTH]; get_string(2, szTitle, charsmax(szTitle));
  new bool:bLocalizable = bool:get_param(3);

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  Shop_SetTitle(iShopId, szTitle, bLocalizable);
}

public Native_SetShopDescription(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szDescription[SHOPS_MAX_SHOP_DESCRIPTION_LENGTH]; get_string(2, szDescription, charsmax(szDescription));
  new bool:bLocalizable = bool:get_param(3);

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  Shop_SetDescription(iShopId, szDescription, bLocalizable);
}

public Native_SetShopFlags(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new Shop_Flags:iFlags = Shop_Flags:get_param(2);

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  Shop_SetFlags(iShopId, iFlags);
}

public Native_SetShopMoneyFormat(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szFormat[SHOPS_MAX_SHOP_DESCRIPTION_LENGTH]; get_string(2, szFormat, charsmax(szFormat));

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  Shop_SetMoneyFormat(iShopId, szFormat);
}

public Native_AddShopItem(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(2, szItemId, charsmax(szItemId));
  new iPrice = get_param(3);
  
  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  Shop_AddItem(iShopId, iItemId, iPrice);
}

public Native_ShopHasItem(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(2, szItemId, charsmax(szItemId));

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return false;
  }

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return false;
  }

  return Shop_FindItemIndex(iShopId, iItemId) != -1;
}

public Native_GetShopItemPrice(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(2, szItemId, charsmax(szItemId));

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return 0;
  }

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return 0;
  }

  return Shop_GetItemPrice(iShopId, iItemId);
}

public Native_SetShopBalanceCallbacks(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szGetter[64]; get_string(2, szGetter, charsmax(szGetter));
  new szSetter[64]; get_string(3, szSetter, charsmax(szSetter));

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  new Function:fnGetter = get_func_pointer(szGetter, iPluginId);
  if (fnGetter == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERR_INVALID_FUNCTION, szGetter);
    return;
  }

  new Function:fnSetter = get_func_pointer(szSetter, iPluginId);
  if (fnSetter == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERR_INVALID_FUNCTION, szSetter);
    return;
  }

  Shop_SetBalanceCallbacks(iShopId, fnGetter, fnSetter);
}

public Native_SetShopGuardCallback(const iPluginId, const iArgc) {
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(1, szShopId, charsmax(szShopId));
  new szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  new Function:fnGuard = get_func_pointer(szCallback, iPluginId);
  if (fnGuard == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERR_INVALID_FUNCTION, szCallback);
    return;
  }

  Shop_SetGuardCallback(iShopId, fnGuard);
}

public Native_RegisterShopItem(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));

  if (ShopItem_GetId(szItemId) != -1) {
    LOG_FATAL_ERROR(ERR_ITEM_ALREADY_EXISTS, szItemId);
    return;
  }

  ShopItem_Register(szItemId);
}

public bool:Native_IsShopItemRegistered(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));

  return ShopItem_GetId(szItemId) != -1;
}

public Native_SetShopItemTitle(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));
  new szTitle[SHOPS_MAX_ITEM_TITLE_LENGTH]; get_string(2, szTitle, charsmax(szTitle));
  new bool:bLocalizable = bool:get_param(3);

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  ShopItem_SetTitle(iItemId, szTitle, bLocalizable);
}

public Native_SetShopItemDescription(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));
  new szDescription[SHOPS_MAX_ITEM_DESCRIPTION_LENGTH]; get_string(2, szDescription, charsmax(szDescription));
  new bool:bLocalizable = bool:get_param(3);

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  ShopItem_SetDescription(iItemId, szDescription, bLocalizable);
}

public Native_SetPurchaseCallback(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));
  new szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERR_INVALID_FUNCTION, szCallback);
    return;
  }

  ShopItem_SetPurchaseCallback(iItemId, fnCallback);
}

public Native_SetShopItemGuardCallback(const iPluginId, const iArgc) {
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(1, szItemId, charsmax(szItemId));
  new szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  new Function:fnGuard = get_func_pointer(szCallback, iPluginId);
  if (fnGuard == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERR_INVALID_FUNCTION, szCallback);
    return;
  }

  ShopItem_SetGuardCallback(iItemId, fnGuard);
}

public Native_OpenShop(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(2, szShopId, charsmax(szShopId));

  if (!is_user_connected(pPlayer)) {
    LOG_FATAL_ERROR(ERR_PLAYER_IS_NOT_CONNECTED, pPlayer);
    return;
  }

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  @Player_OpenShop(pPlayer, iShopId);
}

public Native_PurchaseShopItem(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(2, szShopId, charsmax(szShopId));
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(3, szItemId, charsmax(szItemId));

  if (!is_user_connected(pPlayer)) {
    LOG_FATAL_ERROR(ERR_PLAYER_IS_NOT_CONNECTED, pPlayer);
    return;
  }

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return;
  }

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return;
  }

  if (Shop_FindItemIndex(iShopId, iItemId) == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED_IN_SHOP, g_rgszItemId[iItemId], g_rgszShopId[iShopId]);
    return;
  }

  @Player_PurchaseItem(pPlayer, iShopId, iItemId);
}

public bool:Native_CanPlayerPurchaseItem(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(2, szShopId, charsmax(szShopId));
  new szItemId[SHOPS_MAX_ITEM_ID_LENGTH]; get_string(3, szItemId, charsmax(szItemId));

  if (!is_user_connected(pPlayer)) {
    LOG_FATAL_ERROR(ERR_PLAYER_IS_NOT_CONNECTED, pPlayer);
    return false;
  }

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return false;
  }

  new iItemId = ShopItem_GetId(szItemId);
  if (iItemId == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED, szItemId);
    return false;
  }

  if (Shop_FindItemIndex(iShopId, iItemId) == -1) {
    LOG_FATAL_ERROR(ERR_ITEM_NOT_REGISTERED_IN_SHOP, g_rgszItemId[iItemId], g_rgszShopId[iShopId]);
    return false;
  }

  return @Player_CanPurchaseItem(pPlayer, iShopId, iItemId);
}

public Native_GetPlayerBalance(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szShopId[SHOPS_MAX_SHOP_ID_LENGTH]; get_string(2, szShopId, charsmax(szShopId));

  if (!is_user_connected(pPlayer)) {
    LOG_FATAL_ERROR(ERR_PLAYER_IS_NOT_CONNECTED, pPlayer);
    return 0;
  }

  new iShopId = Shop_GetId(szShopId);
  if (iShopId == -1) {
    LOG_FATAL_ERROR(ERR_SHOP_NOT_REGISTERED, szShopId);
    return 0;
  }

  return @Player_GetShopBalance(pPlayer, iShopId);
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Shop(const pPlayer) {
  new iArgsNum = read_argc();
  if (iArgsNum < 1) return PLUGIN_HANDLED;

  static szShop[32]; read_argv(1, szShop, charsmax(szShop));

  new iShopId = Shop_GetId(szShop);
  if (iShopId == -1) {
    client_print(pPlayer, print_chat, ERR_CLIENT_SHOP_NOT_REGISTERED, szShop);
    return PLUGIN_HANDLED;
  }

  @Player_OpenShop(pPlayer, iShopId);

  return PLUGIN_HANDLED;
}

public Command_Purchase(const pPlayer) {
  new iArgsNum = read_argc();
  if (iArgsNum < 2) return PLUGIN_HANDLED;

  static szShop[32]; read_argv(1, szShop, charsmax(szShop));
  static szItem[32]; read_argv(2, szItem, charsmax(szItem));

  new iShopId = Shop_GetId(szShop);
  if (iShopId == -1) {
    client_print(pPlayer, print_chat, ERR_CLIENT_SHOP_NOT_REGISTERED, szShop);
    return PLUGIN_HANDLED;
  }

  new iItemId = ShopItem_GetId(szItem);
  if (iItemId == -1) {
    client_print(pPlayer, print_chat, ERR_CLIENT_ITEM_NOT_REGISTERED, szItem);
    return PLUGIN_HANDLED;
  }

  if (Shop_FindItemIndex(iShopId, iItemId) == -1) {
    client_print(pPlayer, print_chat, ERR_CLIENT_ITEM_NOT_REGISTERED_IN_SHOP, g_rgszItemId[iItemId], g_rgszShopId[iShopId]);
    return PLUGIN_HANDLED;
  }

  @Player_PurchaseItem(pPlayer, iShopId, iItemId);

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Player Methods ]--------------------------------*/

bool:@Player_CanPurchaseItem(const &this, const iShopId, const iItemId) {
  if (!Shop_CallGuardCallback(iShopId, this)) return false;
  if (!ShopItem_CallGuardCallback(iItemId, this)) return false;

  new iBalance = @Player_GetShopBalance(this, iShopId);
  new iPrice = Shop_GetItemPrice(iShopId, iItemId);
  
  if (iBalance < iPrice) return false;

  return true;
}

bool:@Player_PurchaseItem(const &this, const iShopId, const iItemId) {
  if (!@Player_CanPurchaseItem(this, iShopId, iItemId)) return false;

  g_rgiPlayerCurrentShopId[this] = iShopId;
  g_rgiPlayerCurrentItemId[this] = iItemId;

  if (ShopItem_CallPurchaseCallback(iItemId, this)) {
    new iBalance = @Player_GetShopBalance(this, iShopId);
    new iPrice = Shop_GetItemPrice(iShopId, iItemId);
    @Player_SetShopBalance(this, iShopId, iBalance - iPrice);
    LOG_INFO("Player ^"%n^" purchased item ^"%s^" from shop ^"%s^".", this, g_rgszItemId[iItemId], g_rgszShopId[iShopId]);
  }

  return true;
}

@Player_ProcessPurchase(const &this, const iShopId, const iItemId) {
  if (g_rgiShopFlags[iShopId] & Shop_Flag_PurchaseConfirmation) {
    @Player_OpenPurchaseConfirmation(this, iShopId, iItemId);
  } else {
    @Player_PurchaseItem(this, iShopId, iItemId);
  }
}

@Player_OpenShop(const &this, const iShopId) {
  if (!Shop_CallGuardCallback(iShopId, this)) return;

  g_rgiPlayerCurrentShopId[this] = iShopId;
  g_rgiPlayerMenu[this] = Shop_CreateMenu(iShopId, this);

  menu_display(this, g_rgiPlayerMenu[this]);
}

@Player_OpenItemInfo(const &this, const iShopId, const iItemId) {
  if (!Shop_CallGuardCallback(iShopId, this)) return;

  g_rgiPlayerCurrentShopId[this] = iShopId;
  g_rgiPlayerCurrentItemId[this] = iItemId;

  g_rgiPlayerMenu[this] = Shop_CreateItemInfoMenu(iShopId, iItemId, this);

  menu_display(this, g_rgiPlayerMenu[this]);
}

@Player_OpenPurchaseConfirmation(const &this, const iShopId, const iItemId) {
  g_rgiPlayerCurrentShopId[this] = iShopId;
  g_rgiPlayerCurrentItemId[this] = iItemId;

  g_rgiPlayerMenu[this] = Shop_CreatePurchaseConfirmationMenu(iShopId, iItemId, this);

  menu_display(this, g_rgiPlayerMenu[this]);
}

@Player_GetShopBalance(const &this, const iShopId) {
  return Shop_CallBalanceGetter(iShopId, this);
}

@Player_SetShopBalance(const &this, const iShopId, const iBalance) {
  Shop_CallBalanceSetter(iShopId, this, iBalance);
}

/*--------------------------------[ Shop Methods ]--------------------------------*/

Shop_Register(const szId[]) {
  new iId;

  if (!TrieGetCell(g_itShopIds, szId, iId)) {
    iId = g_iShopsNum;

    copy(g_rgszShopId[iId], charsmax(g_rgszShopId[]), szId);
    copy(g_rgszShopTitle[iId], charsmax(g_rgszShopTitle[]), "Shop");
    copy(g_rgszShopDescription[iId], charsmax(g_rgszShopDescription[]), "");
    g_rgiShopFlags[iId] = Shop_Flag_None;
    g_rgfnShopBalanceGetter[iId] = get_func_pointer("Callback_Shop_BalanceGetter");
    g_rgfnShopBalanceSetter[iId] = get_func_pointer("Callback_Shop_BalanceSetter");
    g_rgfnShopGuardCallback[iId] = get_func_pointer("Callback_Shop_Guard");
    g_rgszShopMoneyFormat[iId] = "$%d";
    g_rgiShopItemsNum[iId] = 0;
    g_rgiShopLocalizationFlags[iId] = LocalizationFlag_None;

    TrieSetCell(g_itShopIds, szId, iId);

    g_iShopsNum++;
  }

  LOG_INFO("Shop ^"%s^" successfully registered.", szId);

  return iId;
}

Shop_GetId(const szId[]) {
  new iId;
  if (!TrieGetCell(g_itShopIds, szId, iId)) return -1;

  return iId;
}

Shop_SetTitle(const iId, const szTitle[], bool:bLocalizable) {
  copy(g_rgszShopTitle[iId], charsmax(g_rgszShopTitle[]), szTitle);

  if (bLocalizable) {
    g_rgiShopLocalizationFlags[iId] |= LocalizationFlag_Title;
  }
}

Shop_SetDescription(const iId, const szDescription[], bool:bLocalizable) {
  copy(g_rgszShopDescription[iId], charsmax(g_rgszShopDescription[]), szDescription);

  if (bLocalizable) {
    g_rgiShopLocalizationFlags[iId] |= LocalizationFlag_Description;
  }
}

Shop_SetFlags(const iId, Shop_Flags:iFlags) {
  g_rgiShopFlags[iId] = iFlags;
}

Shop_SetMoneyFormat(const iId, const szFormat[]) {
  copy(g_rgszShopMoneyFormat[iId], charsmax(g_rgszShopMoneyFormat[]), szFormat);
}

Shop_SetBalanceCallbacks(const iId, const Function:fnGetter, const Function:fnSetter) {
  g_rgfnShopBalanceGetter[iId] = fnGetter;
  g_rgfnShopBalanceSetter[iId] = fnSetter;
}

Shop_AddItem(const iId, const iItemId, iPrice) {
  if (Shop_FindItemIndex(iId, iItemId) != -1) return;

  new iItem = g_rgiShopItemsNum[iId];

  g_rgrgiShopItems[iId][iItem] = iItemId;
  g_rgrgiShopItemPrice[iId][iItem] = iPrice;

  g_rgiShopItemsNum[iId]++;

  LOG_INFO("Item ^"%s^" successfully added to shop ^"%s^".", g_rgszItemId[iItemId], g_rgszShopId[iId]);
}

Shop_FindItemIndex(const iId, const iItemId) {
  for (new iItem = 0; iItem < g_rgiShopItemsNum[iId]; ++iItem) {
    if (g_rgrgiShopItems[iId][iItem] == iItemId) {
      return iItem;
    }
  }

  return -1;
}

Shop_GetItemPrice(const iId, const iItemId) {
  static iItem; iItem = Shop_FindItemIndex(iId, iItemId);

  if (iItem == -1) return 0;

  return g_rgrgiShopItemPrice[iId][iItem];
}

Shop_SetGuardCallback(const iId, const Function:fnCallback) {
  g_rgfnShopGuardCallback[iId] = fnCallback;
}

Shop_CallBalanceGetter(const iId, const &pPlayer) {
  if (g_rgfnShopBalanceGetter[iId] == Invalid_FunctionPointer) return 0;

  callfunc_begin_p(g_rgfnShopBalanceGetter[iId]);
  callfunc_push_int(pPlayer);

  return callfunc_end();
}

Shop_CallBalanceSetter(const iId, const &pPlayer, const iBalance) {
  if (g_rgfnShopBalanceSetter[iId] == Invalid_FunctionPointer) return;

  callfunc_begin_p(g_rgfnShopBalanceSetter[iId]);
  callfunc_push_int(pPlayer);
  callfunc_push_int(iBalance);
  callfunc_end();
}

Shop_CallGuardCallback(const iId, const &pPlayer) {
  if (g_rgfnShopGuardCallback[iId] == Invalid_FunctionPointer) return true;

  callfunc_begin_p(g_rgfnShopGuardCallback[iId]);
  callfunc_push_int(pPlayer);

  return callfunc_end();
}

Shop_CreateMenu(const iId, const pPlayer = 0) {
  static szMenuTitle[256]; Shop_BuildMenuTitle(iId, pPlayer, szMenuTitle, charsmax(szMenuTitle));

  static iMenu; iMenu = menu_create(szMenuTitle, "Callback_Menu_Shop");

  menu_setprop(iMenu, MPROP_SHOWPAGE, 0);

  static iItemCallback; iItemCallback = menu_makecallback("Callback_MenuItem_Shop");

  for (new iItem = 0; iItem < g_rgiShopItemsNum[iId]; ++iItem) {
    static szItem[72]; Shop_BuildItemMenuTitle(iId, iItem, pPlayer, szItem, charsmax(szItem));

    static iItemId; iItemId = g_rgrgiShopItems[iId][iItem];
    menu_additem(iMenu, szItem, g_rgszItemId[iItemId], _, iItemCallback);
  }

  return iMenu;
}

Shop_CreateItemInfoMenu(const iId, const iItemId, const pPlayer = 0) {
  static iPrice; iPrice = Shop_GetItemPrice(iId, iItemId);
  static szMenuTitle[256]; Shop_BuildItemInfoMenuTitle(iId, iItemId, pPlayer, szMenuTitle, charsmax(szMenuTitle));
  static szPrice[16]; Shop_FormatPrice(iId, iPrice, szPrice, charsmax(szPrice));
  static szPurchaseText[64]; format(szPurchaseText, charsmax(szPurchaseText), "%s for \y%s", iPrice ? "Purchase" : "Get", szPrice);
  static szBackToShopText[64]; format(szBackToShopText, charsmax(szBackToShopText), "Back to \y^"%s^"\w shop", g_rgszShopTitle[iId]);

  static iMenu; iMenu = menu_create(szMenuTitle, "Callback_Menu_ShopItem");

  menu_setprop(iMenu, MPROP_SHOWPAGE, 0);

  for (new Menu_ItemInfo_Item:iItem = Menu_ItemInfo_Item:0; iItem < Menu_ItemInfo_Item; ++iItem) {
    switch (iItem) {
      case Menu_ItemInfo_Item_Purchase: menu_additem(iMenu, szPurchaseText, g_rgszItemId[iItemId], _, menu_makecallback("Callback_MenuItem_ShopItem"));
      case Menu_ItemInfo_Item_BackToShop: menu_additem(iMenu, szBackToShopText, g_rgszShopTitle[iId]);
      default: menu_addblank2(iMenu);
    }
  }

  return iMenu;
}

Shop_CreatePurchaseConfirmationMenu(const iId, const iItemId, const pPlayer = 0) {
  new iPrice = Shop_GetItemPrice(iId, iItemId);

  static szPrice[16]; Shop_FormatPrice(iId, iPrice, szPrice, charsmax(szPrice));
  static szConfirmText[64]; format(szConfirmText, charsmax(szConfirmText), "%s for \y%s", iPrice ? "Purchase" : "Get", szPrice);
  static szMenuTitle[256]; Shop_BuildPurchaseConfirmationMenuTitle(iId, iItemId, pPlayer, szMenuTitle, charsmax(szMenuTitle));

  static iMenu; iMenu = menu_create(szMenuTitle, "Callback_Menu_PurchaseConfirmation");

  menu_setprop(iMenu, MPROP_SHOWPAGE, 0);
  menu_setprop(iMenu, MPROP_PERPAGE, 0);
  menu_setprop(iMenu, MPROP_EXIT, 0);

  for (new Menu_PurchaseConfirmation_Item:iItem = Menu_PurchaseConfirmation_Item:0; iItem < Menu_PurchaseConfirmation_Item; ++iItem) {
    switch (iItem) {
      case Menu_PurchaseConfirmation_Item_Confirm: menu_additem(iMenu, szConfirmText, _, _, menu_makecallback("Callback_MenuItem_ShopItem"));
      case Menu_PurchaseConfirmation_Item_Cancel: menu_additem(iMenu, "Cancel");
      default: menu_addblank2(iMenu);
    }
  }

  return iMenu;
}

Shop_FormatPrice(const iId, const iPrice, szOut[], iLength) {
  if (iPrice) {
    return format(szOut, iLength, g_rgszShopMoneyFormat[iId], iPrice);
  } else {
    return copy(szOut, iLength, "FREE");
  }
}


Shop_BuildMenuTitle(const iShopId, const pPlayer, szOut[], iMaxLength) {
  static iPos; iPos = 0;

  if (g_rgiShopLocalizationFlags[iShopId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszShopTitle[iShopId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszShopTitle[iShopId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "^n\d");

  if (g_rgiShopLocalizationFlags[iShopId] & LocalizationFlag_Description) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszShopDescription[iShopId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszShopDescription[iShopId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "\y");

  return iPos;
}

Shop_BuildItemMenuTitle(const iShopId, const iItem, const pPlayer, szOut[], iMaxLength) {
  static iItemId; iItemId = g_rgrgiShopItems[iShopId][iItem];

  static iPos; iPos = 0;

  if (g_rgiItemLocalizationFlags[iItemId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "\R\y");
  iPos += Shop_FormatPrice(iShopId, g_rgrgiShopItemPrice[iShopId][iItem], szOut[iPos], iMaxLength - iPos);

  return iPos;
}

Shop_BuildItemInfoMenuTitle(const iId, const iItemId, const pPlayer, szOut[], iMaxLength) {
  #pragma unused iId

  static iPos; iPos = 0;

  if (g_rgiItemLocalizationFlags[iItemId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "^n\d");

  if (g_rgiItemLocalizationFlags[iItemId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszItemDescription[iItemId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszItemDescription[iItemId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "\y^n^n");

  return iPos;
}

Shop_BuildPurchaseConfirmationMenuTitle(const iId, const iItemId, const pPlayer, szOut[], iMaxLength) {
  static iPos; iPos = 0;

  static szGetWord[32]; format(szGetWord, charsmax(szGetWord), g_rgrgiShopItemPrice[iId][iItemId] ? "Purchase" : "Get");

  iPos += format(szOut[iPos], iMaxLength - iPos, "\w%s \y^"", szGetWord);

  if (g_rgiItemLocalizationFlags[iItemId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId]);
  }

  iPos += copy(szOut[iPos], iMaxLength - iPos, "^"\w");
  iPos += copy(szOut[iPos], iMaxLength - iPos, " for \y");
  iPos += Shop_FormatPrice(iId, g_rgrgiShopItemPrice[iId][iItemId], szOut[iPos], iMaxLength - iPos);
  iPos += copy(szOut[iPos], iMaxLength - iPos, "\w?");
  iPos += copy(szOut[iPos], iMaxLength - iPos, "^n^n^n");
  iPos += format(szOut[iPos], iMaxLength - iPos, "\wBy pressing the \y^"%s^"\w button:", szGetWord);
  iPos += format(szOut[iPos], iMaxLength - iPos, "^n^t\r- You confirm the %s of \y^"", g_rgrgiShopItemPrice[iId][iItemId] ? "purchase" : "claim");

  if (g_rgiItemLocalizationFlags[iItemId] & LocalizationFlag_Title) {
    iPos += UTIL_GetDictValue(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId], pPlayer);
  } else {
    iPos += copy(szOut[iPos], iMaxLength - iPos, g_rgszItemTitle[iItemId]);
  }

  iPos += format(szOut[iPos], iMaxLength - iPos, "^"^n^t");

  if (g_rgrgiShopItemPrice[iId][iItemId]) {
    static szPrice[16]; Shop_FormatPrice(iId, g_rgrgiShopItemPrice[iId][iItemId], szPrice, charsmax(szPrice));
    iPos += format(szOut[iPos], iMaxLength - iPos, "\r- The amount of \y%s\r will be deducted from your balance", szPrice);
  } else {
    iPos += format(szOut[iPos], iMaxLength - iPos, "\d- This item is \yFREE\d and nothing will be deducted from your balance");
  }

  return iPos;
}

/*--------------------------------[ ShopItem Methods ]--------------------------------*/

ShopItem_Register(const szId[]) {
  new iId;

  if (!TrieGetCell(g_itItemIds, szId, iId)) {
    iId = g_iItemsNum;

    copy(g_rgszItemId[iId], charsmax(g_rgszItemId[]), szId);
    copy(g_rgszItemTitle[iId], charsmax(g_rgszItemTitle[]), szId);
    copy(g_rgszItemDescription[iId], charsmax(g_rgszItemDescription[]), "No description provided for this item.");
    g_rgfnItemGuardCallback[iId] = get_func_pointer("Callback_ShopItem_Guard");
    g_rgfnItemPurchaseCallback[iId] = get_func_pointer("Callback_ShopItem_Purchase");
    g_rgiItemLocalizationFlags[iId] = LocalizationFlag_None;

    TrieSetCell(g_itItemIds, szId, iId);

    g_iItemsNum++;
  }

  LOG_INFO("Shop item ^"%s^" successfully registered.", szId);

  return iId;
}

ShopItem_GetId(const szId[]) {
  new iId;
  if (!TrieGetCell(g_itItemIds, szId, iId)) return -1;

  return iId;
}

ShopItem_SetTitle(const iId, const szTitle[], bool:bLocalizable) {
  copy(g_rgszItemTitle[iId], charsmax(g_rgszItemTitle[]), szTitle);
  if (bLocalizable) {
    g_rgiItemLocalizationFlags[iId] |= LocalizationFlag_Title;
  }
}

ShopItem_SetDescription(const iId, const szDescription[], bool:bLocalizable) {
  copy(g_rgszItemDescription[iId], charsmax(g_rgszItemDescription[]), szDescription);

  if (bLocalizable) {
    g_rgiItemLocalizationFlags[iId] |= LocalizationFlag_Description;
  }
}

ShopItem_SetPurchaseCallback(const iId, const Function:fnCallback) {
  g_rgfnItemPurchaseCallback[iId] = fnCallback;
}

ShopItem_SetGuardCallback(const iId, const Function:fnCallback) {
  g_rgfnItemGuardCallback[iId] = fnCallback;
}

bool:ShopItem_CallPurchaseCallback(const iId, const &pPlayer) {
  if (g_rgfnItemPurchaseCallback[iId] == Invalid_FunctionPointer) return false;

  callfunc_begin_p(g_rgfnItemPurchaseCallback[iId]);
  callfunc_push_int(pPlayer);
  callfunc_push_str(g_rgszItemId[iId], false);
  return bool:callfunc_end();
}

bool:ShopItem_CallGuardCallback(const iId, const &pPlayer) {
  if (g_rgfnItemGuardCallback[iId] == Invalid_FunctionPointer) return true;

  callfunc_begin_p(g_rgfnItemGuardCallback[iId]);
  callfunc_push_int(pPlayer);
  callfunc_push_str(g_rgszItemId[iId], false);
  return bool:callfunc_end();
}

/*--------------------------------[ Shop Callbacks ]--------------------------------*/

public Callback_Shop_BalanceGetter(const pPlayer) {
  if (g_bCstrike) {
    return get_ent_data(pPlayer, "CBasePlayer", "m_iAccount");
  }

  new iCurrentShopId = g_rgiPlayerCurrentShopId[pPlayer];
  LOG_WARNING("Balance getter for shop ^"%s^" is not provided.", g_rgszShopId[iCurrentShopId]);

  return 0;
}

public Callback_Shop_BalanceSetter(const pPlayer, iBalance) {
  if (g_bCstrike) {
    static iMessageId = 0;
    if (!iMessageId) {
      iMessageId = get_user_msgid("Money");
    }

    set_ent_data(pPlayer, "CBasePlayer", "m_iAccount", iBalance);

    message_begin(MSG_ONE, iMessageId, _, pPlayer);
    write_long(iBalance);
    write_byte(1);
    message_end();

    return;
  }

  new iCurrentShopId = g_rgiPlayerCurrentShopId[pPlayer];
  LOG_WARNING("Balance setter for shop ^"%s^" is not provided.", g_rgszShopId[iCurrentShopId]);
}

public Callback_Shop_Guard(const pPlayer) {
  return true;
}

/*--------------------------------[ ShopItem Callbacks ]--------------------------------*/

public Callback_ShopItem_Purchase(const pPlayer) {
  static iCurrentItemId; iCurrentItemId = g_rgiPlayerCurrentItemId[pPlayer];

  static szItemTitle[SHOPS_MAX_ITEM_TITLE_LENGTH];
  if (g_rgiItemLocalizationFlags[iCurrentItemId] & LocalizationFlag_Title) {
    UTIL_GetDictValue(szItemTitle, charsmax(szItemTitle), g_rgszItemTitle[iCurrentItemId], pPlayer);
  } else {
    copy(szItemTitle, charsmax(szItemTitle), g_rgszItemTitle[iCurrentItemId]);
  }

  client_print(pPlayer, print_center, "You have purchased ^"%s^" item from the shop!", szItemTitle);
}

public Callback_ShopItem_Guard(const pPlayer) {
  return true;
}

/*--------------------------------[ Menu Callbacks ]--------------------------------*/

public Callback_Menu_Shop(const pPlayer, const iMenu, const iItem) {
  if (iItem >= 0) {
    new iShopId = g_rgiPlayerCurrentShopId[pPlayer];
    new iItemId = g_rgrgiShopItems[iShopId][iItem];

    if (g_rgiShopFlags[iShopId] & Shop_Flag_ItemPage) {
      @Player_OpenItemInfo(pPlayer, iShopId, iItemId);
    } else {
      @Player_ProcessPurchase(pPlayer, iShopId, iItemId);
    }
  }

  menu_destroy(iMenu);
}

public Callback_Menu_ShopItem(const pPlayer, const iMenu, const iItem) {
  switch (iItem) {
    case Menu_ItemInfo_Item_Purchase: @Player_ProcessPurchase(pPlayer, g_rgiPlayerCurrentShopId[pPlayer], g_rgiPlayerCurrentItemId[pPlayer]);
    case Menu_ItemInfo_Item_BackToShop: @Player_OpenShop(pPlayer, g_rgiPlayerCurrentShopId[pPlayer]);
  }

  menu_destroy(iMenu);
}

public Callback_Menu_PurchaseConfirmation(const pPlayer, const iMenu, const iItem) {
  switch (iItem) {
    case Menu_PurchaseConfirmation_Item_Confirm: @Player_PurchaseItem(pPlayer, g_rgiPlayerCurrentShopId[pPlayer], g_rgiPlayerCurrentItemId[pPlayer]);
    case Menu_PurchaseConfirmation_Item_Cancel: @Player_OpenItemInfo(pPlayer, g_rgiPlayerCurrentShopId[pPlayer], g_rgiPlayerCurrentItemId[pPlayer]);
  }

  menu_destroy(iMenu);
}

/*--------------------------------[ Menu Item Callbacks ]--------------------------------*/

public Callback_MenuItem_Shop(const pPlayer, const iMenu, const iItem) {
  new iShopId = g_rgiPlayerCurrentShopId[pPlayer];

  if (~g_rgiShopFlags[iShopId] & Shop_Flag_ItemPage) {
    if (!@Player_CanPurchaseItem(pPlayer, iShopId, g_rgrgiShopItems[iShopId][iItem])) return ITEM_DISABLED;
  }

  return ITEM_ENABLED;
}

public Callback_MenuItem_ShopItem(const pPlayer, const iMenu, const iItem) {
  if (!@Player_CanPurchaseItem(pPlayer, g_rgiPlayerCurrentShopId[pPlayer], g_rgiPlayerCurrentItemId[pPlayer])) return ITEM_DISABLED;

  return ITEM_ENABLED;
}
