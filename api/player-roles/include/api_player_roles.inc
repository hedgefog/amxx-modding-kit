#if defined _api_player_roles_included
  #endinput
#endif
#define _api_player_roles_included

#pragma reqlib api_player_roles

#include <api_player_roles_const>

/**
 * Registers a new player role.
 *
 * @param szRoleId Role ID
 * @param szParentRole Parent role ID
 *
 * @noreturn
 */
native PlayerRole_Register(const szRoleId[], const szParentRole[] = "");

/**
 * Checks if a player role is registered.
 *
 * @param szRoleId Role ID
 *
 * @return true if registered, false otherwise
 */
native bool:PlayerRole_IsRegistered(const szRoleId[]);

/**
 * Registers a new method for a player role.
 *
 * @param szRoleId Role ID
 * @param szMethod Method name
 * @param szCallback Callback function name
 *
 * @noreturn
 */
native PlayerRole_RegisterMethod(const szRoleId[], const szMethod[], const szCallback[], any:...);

/**
 * Registers a new virtual method for a player role.
 *
 * @param szRoleId Role ID
 * @param szMethod Method name
 * @param szCallback Callback function name
 *
 * @noreturn
 */
native PlayerRole_RegisterVirtualMethod(const szRoleId[], const szMethod[], const szCallback[], any:...);

/**
 * Implements a native method for a player role.
 *
 * @param szRoleId Role ID
 * @param iMethod Method to implement
 * @param szCallback Callback function name
 *
 * @noreturn
 */
native PlayerRole_ImplementMethod(const szRoleId[], PlayerRole_Method:iMethod, const szCallback[]);

/**
 * Registers a hook for a native method of a player role.
 *
 * @param szRoleId Role ID
 * @param iMethod Method to hook
 * @param szCallback Callback function name
 *
 * @noreturn
 */
native PlayerRole_RegisterNativeMethodHook(const szRoleId[], PlayerRole_Method:iMethod, const szCallback[], any:...);

/**
 * Checks if a role is or inherits from another role.
 *
 * @param szRoleId Role ID
 * @param szOtherRoleId Other role ID to check against
 * @param bExact If true, checks for exact match only
 *
 * @return true if the role matches, false otherwise
 */
native bool:PlayerRole_Is(const szRoleId[], const szOtherRoleId[], bool:bExact = false);

/**
 * Assigns a role to a player.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szGroup Role group name
 *
 * @noreturn
 */
native PlayerRole_Player_AssignRole(const pPlayer, const szRoleId[], const szGroup[] = "");

/**
 * Unassigns a role from a player.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param bExact If true, unassigns exact role only
 *
 * @noreturn
 */
native PlayerRole_Player_UnassignRole(const pPlayer, const szRoleId[], bool:bExact = false);

/**
 * Unassigns all roles from a player.
 *
 * @param pPlayer Player index
 *
 * @noreturn
 */
native PlayerRole_Player_UnassignRoles(const pPlayer);

/**
 * Unassigns all roles in a group from a player.
 *
 * @param pPlayer Player index
 * @param szGroup Role group name
 *
 * @noreturn
 */
native PlayerRole_Player_UnassignRoleGroup(const pPlayer, const szGroup[]);

/**
 * Checks if a player has a specific role (including inherited).
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 *
 * @return true if player has the role, false otherwise
 */
native bool:PlayerRole_Player_HasRole(const pPlayer, const szRoleId[]);

/**
 * Checks if a player has the exact role (no inheritance check).
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 *
 * @return true if player has the exact role, false otherwise
 */
native bool:PlayerRole_Player_HasExactRole(const pPlayer, const szRoleId[]);

/**
 * Checks if a player has any role in a group.
 *
 * @param pPlayer Player index
 * @param szGroup Role group name
 *
 * @return true if player has a role in the group, false otherwise
 */
native bool:PlayerRole_Player_HasRoleGroup(const pPlayer, const szGroup[]);

/**
 * Gets the role assigned to a player in a specific group.
 *
 * @param pPlayer Player index
 * @param szGroup Role group name
 * @param szRole Output buffer for role ID
 * @param iLen Maximum buffer length
 *
 * @noreturn
 */
native PlayerRole_Player_GetRoleByGroup(const pPlayer, const szGroup[], szRole[], iLen);

/**
 * Checks if the current role context has a member.
 *
 * @param szMember Member name
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_This_HasMember(const szMember[]);

/**
 * Gets a member value from the current role context.
 *
 * @param szMember Member name
 *
 * @return Member value
 */
native any:PlayerRole_This_GetMember(const szMember[]);

/**
 * Sets a member value in the current role context.
 *
 * @param szMember Member name
 * @param value Value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_This_SetMember(const szMember[], any:value, bool:bReplace = true);

/**
 * Deletes a member from the current role context.
 *
 * @param szMember Member name
 *
 * @noreturn
 */
native PlayerRole_This_DeleteMember(const szMember[]);

/**
 * Gets a vector member from the current role context.
 *
 * @param szMember Member name
 * @param vecOut Output vector
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_This_GetMemberVec(const szMember[], Float:vecOut[3]);

/**
 * Sets a vector member in the current role context.
 *
 * @param szMember Member name
 * @param vecValue Vector value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_This_SetMemberVec(const szMember[], const Float:vecValue[], bool:bReplace = true);

/**
 * Gets a string member from the current role context.
 *
 * @param szMember Member name
 * @param szOut Output buffer
 * @param iLen Maximum buffer length
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_This_GetMemberString(const szMember[], szOut[], iLen);

/**
 * Sets a string member in the current role context.
 *
 * @param szMember Member name
 * @param szValue String value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_This_SetMemberString(const szMember[], const szValue[], bool:bReplace = true);

/**
 * Calls a method on the current role context.
 *
 * @param szMethod Method name
 *
 * @return Method return value
 */
native any:PlayerRole_This_CallMethod(const szMethod[], any:...);

/**
 * Calls the base method of the current role context.
 *
 * @return Method return value
 */
native any:PlayerRole_This_CallBaseMethod(any:...);

/**
 * Gets the caller plugin id of the current role context.
 *
 * @return Plugin id
 */
native PlayerRole_This_CallerPlugin();

/**
 * Checks if a player's role has a member.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_Player_HasMember(const pPlayer, const szRoleId[], const szMember[]);

/**
 * Gets a member value from a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 *
 * @return Member value
 */
native any:PlayerRole_Player_GetMember(const pPlayer, const szRoleId[], const szMember[]);

/**
 * Sets a member value on a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 * @param value Value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_Player_SetMember(const pPlayer, const szRoleId[], const szMember[], any:value, bool:bReplace = true);

/**
 * Deletes a member from a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 *
 * @noreturn
 */
native PlayerRole_Player_DeleteMember(const pPlayer, const szRoleId[], const szMember[]);

/**
 * Gets a vector member from a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 * @param vecOut Output vector
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_Player_GetMemberVec(const pPlayer, const szRoleId[], const szMember[], Float:vecOut[3]);

/**
 * Sets a vector member on a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 * @param vecValue Vector value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_Player_SetMemberVec(const pPlayer, const szRoleId[], const szMember[], const Float:vecValue[], bool:bReplace = true);

/**
 * Gets a string member from a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 * @param szOut Output buffer
 * @param iLen Maximum buffer length
 *
 * @return true if member exists, false otherwise
 */
native bool:PlayerRole_Player_GetMemberString(const pPlayer, const szRoleId[], const szMember[], szOut[], iLen);

/**
 * Sets a string member on a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMember Member name
 * @param szValue String value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native PlayerRole_Player_SetMemberString(const pPlayer, const szRoleId[], const szMember[], const szValue[], bool:bReplace = true);

/**
 * Calls a method on a player's role.
 *
 * @param pPlayer Player index
 * @param szRoleId Role ID
 * @param szMethod Method name
 *
 * @return Method return value
 */
native any:PlayerRole_Player_CallMethod(const pPlayer, const szRoleId[], const szMethod[], any:...);
