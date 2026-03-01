#if defined _api_shops_const_included
  #endinput
#endif
#define _api_shops_const_included

#define SHOPS_MAX_SHOP_ID_LENGTH 32
#define SHOPS_MAX_SHOP_TITLE_LENGTH 64
#define SHOPS_MAX_SHOP_DESCRIPTION_LENGTH 80
#define SHOPS_MAX_ITEM_ID_LENGTH 32
#define SHOPS_MAX_ITEM_TITLE_LENGTH 64
#define SHOPS_MAX_ITEM_DESCRIPTION_LENGTH 128
#define SHOPS_MAX_SHOPS 16
#define SHOPS_MAX_SHOP_ITEMS 32
#define MAX_ITEMS (SHOPS_MAX_SHOPS * SHOPS_MAX_SHOP_ITEMS)

enum Shop_Flags (<<=1) {
  Shop_Flag_None = 0,
  Shop_Flag_PurchaseConfirmation = 1,
  Shop_Flag_ItemPage,
};
