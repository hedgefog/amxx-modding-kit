#if defined _api_player_effects_included
  #endinput
#endif
#define _api_player_effects_included

#pragma reqlib api_player_effects

#include <api_player_effects_const>

/**
 * Registers a new player effect.
 *
 * @param szId Effect ID
 * @param szInvokeFunction Function to call when effect is applied
 * @param szRevokeFunction Function to call when effect is removed
 * @param szIcon Optional icon name
 * @param irgIconColor Icon color (RGB)
 *
 * @noreturn
 */
native PlayerEffect_Register(const szId[], const szInvokeFunction[], const szRevokeFunction[], const szIcon[] = "", const irgIconColor[3] = {255, 255, 255});

/**
 * Sets or removes a player effect.
 *
 * @param pPlayer Player index
 * @param szId Effect ID
 * @param bValue true to apply, false to remove
 * @param flDuration Duration in seconds, -1.0 for infinite
 * @param bExtend Whether to extend existing duration or replace it
 *
 * @noreturn
 */
native PlayerEffect_Set(const pPlayer, const szId[], bool:bValue, Float:flDuration = -1.0, bool:bExtend = true);

/**
 * Checks if a player has a specific effect.
 *
 * @param pPlayer Player index
 * @param szId Effect ID
 *
 * @return true if player has the effect, false otherwise
 */
native bool:PlayerEffect_Get(const pPlayer, const szId[]);

/**
 * Gets the end time of a player's effect.
 *
 * @param pPlayer Player index
 * @param szId Effect ID
 *
 * @return End time in game time, or -1.0 if infinite
 */
native Float:PlayerEffect_GetEndtime(const pPlayer, const szId[]);

/**
 * Gets the remaining duration of a player's effect.
 *
 * @param pPlayer Player index
 * @param szId Effect ID
 *
 * @return Remaining duration in seconds, or -1.0 if infinite
 */
native Float:PlayerEffect_GetDuration(const pPlayer, const szId[]);
