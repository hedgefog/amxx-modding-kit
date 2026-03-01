// This is a beta version, some functions may be unstable. Use at your own risk.

#if defined _api_player_viewrange_included
  #endinput
#endif
#define _api_player_viewrange_included

#pragma reqlib api_player_viewrange

/**
 * Gets the player's view range.
 *
 * @param pPlayer Player index
 *
 * @return View range
 */
native Float:PlayerViewRange_Get(const pPlayer);

/**
 * Sets the player's view range.
 *
 * @param pPlayer Player index
 * @param flValue View range value
 *
 * @noreturn
 */
native PlayerViewRange_Set(const pPlayer, Float:flValue);

/**
 * Updates the player's view range state.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerViewRange_Update(const pPlayer);

/**
 * Resets the player's view range to default.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerViewRange_Reset(const pPlayer);

/**
 * Called when cheating is detected for a player.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
forward PlayerViewRange_OnCheatingDetected(const pPlayer);

/**
 * Called when a player's view range changes.
 *
 * @param pPlayer Player index
 * @param flValue New view range
 *
 * @noreturn
 */
forward PlayerViewRange_OnChange(const pPlayer, Float:flValue);
