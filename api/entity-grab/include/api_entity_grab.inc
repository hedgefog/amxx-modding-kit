#if defined _api_entity_grab_included
  #endinput
#endif
#define _api_entity_grab_included

#pragma reqlib api_entity_grab

/**
 * Attaches an entity to a player
 *
 * @param pPlayer Player index
 * @param pEntity Entity index
 * @param flDistance Attachment distance
 *
 * @return true if attached, false otherwise
 */
native bool:EntityGrab_Player_AttachEntity(const pPlayer, const pEntity, Float:flDistance);

/**
 * Detaches the currently attached entity from a player
 *
 * @param pPlayer Player index
 *
 * @return true if detached, false otherwise
 */
native bool:EntityGrab_Player_DetachEntity(const pPlayer);

/**
 * Gets the entity currently attached to a player
 *
 * @param pPlayer Player index
 *
 * @return Entity index, or -1 if none
 */
native EntityGrab_Player_GetAttachedEntity(const pPlayer);
