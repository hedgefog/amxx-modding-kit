#if defined _api_player_model_included
  #endinput
#endif
#define _api_player_model_included

#pragma reqlib api_player_model

/**
 * Gets the player's custom model name.
 *
 * @param pPlayer Player index
 * @param szOut Output buffer
 * @param iLen Maximum length
 *
 * @noreturn
 */
native PlayerModel_Get(const pPlayer, szOut[], iLen);

/**
 * Gets the player's current actual model name.
 *
 * @param pPlayer Player index
 * @param szOut Output buffer
 * @param iLen Maximum length
 *
 * @noreturn
 */
native PlayerModel_GetCurrent(const pPlayer, szOut[], iLen);

/**
 * Gets the player's custom model entity index.
 *
 * @param pPlayer Player index
 *
 * @return Entity index, or -1 if none
 */
native PlayerModel_GetEntity(const pPlayer);

/**
 * Checks if a player has a custom model set.
 *
 * @param pPlayer Player index
 *
 * @return true if player has a custom model, false otherwise
 */
native bool:PlayerModel_HasCustom(const pPlayer);

/**
 * Sets a custom model for a player.
 *
 * @param pPlayer Player index
 * @param szModel Model path or name
 *
 * @noreturn
 */
native PlayerModel_Set(const pPlayer, const szModel[]);

/**
 * Updates the player's model based on internal state.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerModel_Update(const pPlayer);

/**
 * Updates the player's model animation.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerModel_UpdateAnimation(const pPlayer);

/**
 * Resets the player's model to default.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerModel_Reset(const pPlayer);

/**
 * Sets a specific sequence for the player's custom model.
 *
 * @param pPlayer Player index
 * @param szSequence Sequence name
 *
 * @noreturn
 */
native PlayerModel_SetSequence(const pPlayer, const szSequence[]);

/**
 * Precaches a player animation.
 *
 * @param szAnimation Animation name
 *
 * @noreturn
 */
native PlayerModel_PrecacheAnimation(const szAnimation[]);
