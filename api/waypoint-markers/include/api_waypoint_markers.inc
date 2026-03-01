/*
  Credits:
    joaquimandrade
*/

#if defined _api_waypoint_markers_included
  #endinput
#endif
#define _api_waypoint_markers_included

#pragma reqlib api_waypoint_markers

/**
 * Creates a waypoint marker entity.
 *
 * @param szModel Sprite model path
 * @param vecOrigin Marker origin
 * @param flScale Marker scale
 * @param rgflSize Marker size (width, height)
 *
 * @return Marker entity index
 */
native WaypointMarker_Create(const szModel[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, Float:flScale = 1.0, const Float:rgflSize[2] = {64.0, 64.0});

/**
 * Sets the visibility of a waypoint marker for a player.
 *
 * @param pMarker Marker entity index
 * @param pPlayer Player index
 * @param bValue Visibility state
 *
 * @noreturn
 */
native WaypointMarker_SetVisible(const pMarker, const pPlayer, bool:bValue);

/**
 * Called when a waypoint marker is created.
 *
 * @param pMarker Marker entity index
 *
 * @noreturn
 */
forward WaypointMarker_OnCreated(const pMarker);

/**
 * Called when a waypoint marker is about to be destroyed.
 *
 * @param pMarker Marker entity index
 *
 * @noreturn
 */
forward WaypointMarker_OnDestroy(const pMarker);
