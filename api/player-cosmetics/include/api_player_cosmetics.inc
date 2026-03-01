#if defined _api_player_cosmetics_included
  #endinput
#endif
#define _api_player_cosmetics_included

#pragma reqlib api_player_cosmetics

/**
 * Equip a player with a cosmetic item.
 *
 * @param pPlayer The player to equip the item to.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return The cosmetic entity index, or FM_NULLENT on failure.
 */
native PlayerCosmetic_Equip(const pPlayer, iModelIndex);

/**
 * Unequip a cosmetic item from a player.
 *
 * @param pPlayer The player to unequip the item from.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return True if the item was successfully unequipped, false otherwise.
 */
native bool:PlayerCosmetic_Unequip(const pPlayer, iModelIndex);

/**
 * Check if a player has equipped a specific cosmetic item.
 *
 * @param pPlayer The player to check.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return True if the player has the item equipped, false otherwise.
 */
native bool:PlayerCosmetic_IsEquipped(const pPlayer, iModelIndex);

/**
 * Get the entity of the equipped cosmetic item for a player.
 *
 * @param pPlayer The player whose equipped item entity to get.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return The entity of the equipped cosmetic item, or FM_NULLENT if not equipped.
 */
native PlayerCosmetic_GetEntity(const pPlayer, iModelIndex);
