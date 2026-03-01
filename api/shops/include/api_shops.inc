#if defined _api_shops_included
  #endinput
#endif
#define _api_shops_included

#pragma reqlib api_shops

#include <api_shops_const>

/**
 * Registers a new shop.
 *
 * @param szId Shop ID
 *
 * @noreturn
 */
native Shop_Register(const szId[]);

/**
 * Checks if a shop is registered.
 *
 * @param szId Shop ID
 *
 * @return true if registered, false otherwise
 */
native bool:Shop_IsRegistered(const szId[]);

/**
 * Sets the title for a shop.
 *
 * @param szId Shop ID
 * @param szTitle Shop title
 * @param bLocalizable Whether the title is a language key
 *
 * @noreturn
 */
native Shop_SetTitle(const szId[], const szTitle[], bool:bLocalizable = false);

/**
 * Sets the description for a shop.
 *
 * @param szId Shop ID
 * @param szDescription Shop description
 * @param bLocalizable Whether the description is a language key
 *
 * @noreturn
 */
native Shop_SetDescription(const szId[], const szDescription[], bool:bLocalizable = false);

/**
 * Sets the flags for a shop.
 *
 * @param szId Shop ID
 * @param iFlags Shop flags
 *
 * @noreturn
 */
native Shop_SetFlags(const szId[], Shop_Flags:iFlags);
/**
 * Sets the money format string for a shop.
 *
 * @param szId Shop ID
 * @param szFormat Format string (e.g. "$%d")
 *
 * @noreturn
 */
native Shop_SetMoneyFormat(const szId[], const szFormat[]);

/**
 * Sets the balance getter/setter callbacks for a shop.
 *
 * @param szId Shop ID
 * @param szGetterCallback Callback to get player balance
 * @param szSetterCallback Callback to set player balance
 *
 * @noreturn
 */
native Shop_SetBalanceCallbacks(const szId[], const szGetterCallback[], const szSetterCallback[]);

/**
 * Sets the guard callback for a shop.
 *
 * @param szId Shop ID
 * @param szCallback Guard callback function name
 *
 * @noreturn
 */
native Shop_SetGuardCallback(const szId[], const szCallback[]);

/**
 * Adds an item to a shop.
 *
 * @param szId Shop ID
 * @param szItemId Item ID
 * @param iPrice Item price
 *
 * @noreturn
 */
native Shop_AddItem(const szId[], const szItemId[], iPrice);

/**
 * Checks if a shop has a specific item.
 *
 * @param szId Shop ID
 * @param szItemId Item ID
 *
 * @return true if item exists, false otherwise
 */
native Shop_HasItem(const szId[], const szItemId[]);

/**
 * Gets the price of a shop item.
 *
 * @param szId Shop ID
 * @param szItemId Item ID
 *
 * @return Item price
 */
native Shop_GetItemPrice(const szId[], const szItemId[]);

/**
 * Registers a new shop item.
 *
 * @param szId Item ID
 *
 * @noreturn
 */
native Shop_Item_Register(const szId[]);

/**
 * Checks if a shop item is registered.
 *
 * @param szId Item ID
 *
 * @return true if registered, false otherwise
 */
native bool:Shop_Item_IsRegistered(const szId[]);

/**
 * Sets the title for a shop item.
 *
 * @param szId Item ID
 * @param szTitle Item title
 * @param bLocalizable Whether the title is a language key
 *
 * @noreturn
 */
native Shop_Item_SetTitle(const szId[], const szTitle[], bool:bLocalizable = false);

/**
 * Sets the description for a shop item.
 *
 * @param szId Item ID
 * @param szDescription Item description
 * @param bLocalizable Whether the description is a language key
 *
 * @noreturn
 */
native Shop_Item_SetDescription(const szId[], const szDescription[], bool:bLocalizable = false);

/**
 * Sets the purchase callback for a shop item.
 *
 * @param szId Item ID
 * @param szCallback Purchase callback function name
 *
 * @noreturn
 */
native Shop_Item_SetPurchaseCallback(const szId[], const szCallback[]);

/**
 * Sets the guard callback for a shop item.
 *
 * @param szId Item ID
 * @param szCallback Guard callback function name
 *
 * @noreturn
 */
native Shop_Item_SetGuardCallback(const szId[], const szCallback[]);

/**
 * Opens a shop menu for a player.
 *
 * @param pPlayer Player index
 * @param szShopId Shop ID
 *
 * @noreturn
 */
native Shop_Player_OpenShop(const pPlayer, const szShopId[]);

/**
 * Purchases a shop item for a player.
 *
 * @param pPlayer Player index
 * @param szShopId Shop ID
 * @param szItemId Item ID
 *
 * @noreturn
 */
native Shop_Player_PurchaseItem(const pPlayer, const szShopId[], const szItemId[]);

/**
 * Checks if a player can purchase a shop item.
 *
 * @param pPlayer Player index
 * @param szShopId Shop ID
 * @param szItemId Item ID
 *
 * @return true if player can purchase, false otherwise
 */
native bool:Shop_Player_CanPurchaseItem(const pPlayer, const szShopId[], const szItemId[]);

/**
 * Gets a player's balance for a specific shop.
 *
 * @param pPlayer Player index
 * @param szShopId Shop ID
 *
 * @return Player's balance
 */
native Shop_Player_GetBalance(const pPlayer, const szShopId[]);
