#if defined _api_custom_weapons_included
  #endinput
#endif
#define _api_custom_weapons_included

#pragma reqlib api_custom_weapons

#include <api_custom_weapons_const>

/**
 * Register weapon
 *
 * @param szClassname Name of an weapon
 * @param szBase Name of a parent weapon
 * @param bAbstract Abstract flag
 *
 * @return Handle of the registered weapon
 */
native CW:CW_RegisterClass(const szClassname[], const szBase[] = "", bool:bAbstract = false);

/**
 * Create a copy of a weapon class with a new name and base class
 *
 * @param szClassname Name of an weapon
 * @param szOriginalClass Name of a weapon to fork
 * @param szBase Name of a base weapon (should be child of original base class)
 *
 * @return Handle of the registered weapon
 */
native CW:CW_ForkClass(const szClassname[], const szOriginalClass[], const szBase[] = "");

/**
 * Extend weapon
 *
 * @param szAlias Name of an alias
 * @param szClassname Name of an weapon
 *
 * @return Handle of the registered weapon
 */
native CW:CW_RegisterClassAlias(const szAlias[], const szClassname[]);

/**
 * Checks if a weapon class is registered
 *
 * @param szClassname Name of an weapon
 *
 * @return Result true/false
 */
native bool:CW_IsClassRegistered(const szClassname[]);

/**
 * Register new hook for weapon class
 *
 * @param method Function handle
 * @param szClassname Weapon class
 * @param szCallback Callback
 */
native CW_RegisterClassMethodHook(const szClassname[], CW_Method:method, const szCallback[], bool:bPost = false);

/**
 * Gets the return value of the current method
 *
 * @return Method return value
 */
native any:CW_GetMethodReturn();

/**
 * Sets the return value of the current method
 *
 * @param value Return value to set
 *
 * @noreturn
 */
native CW_SetMethodReturn(any:value);

/**
 * Implements a native method for weapon class.
 *
 * @param szClassname Weapon class
 * @param iMethod Method to implement
 * @param szCallback Callback
 *
 * @noreturn
*/
native CW_ImplementClassMethod(const szClassname[], CW_Method:iMethod, const szCallback[]);

/**
 * Registers a new method for weapon class.
 *
 * @param szClassname Weapon class
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CW_RegisterClassMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Registers a new virtual method for weapon class.
 *
 * @param szClassname Weapon class
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CW_RegisterClassVirtualMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Gets handle of weapon by name
 *
 * @param szClassname Weapon class
 *
 * @return Handle of the registered weapon or -1 otherwise
 */
native CW:CW_GetClassHandle(const szClassname[]);

/**
 * Gets handle of weapon by index
 *
 * @param pWeapon Weapon index
 *
 * @return Handle of the weapon or -1 otherwise
 */
native CW:CW_GetHandle(const pWeapon);

/**
 * Checks if weapon is an instance of specific custom weapon 
 *
 * @param pWeapon Weapon index
 * @param szClassname Name of target weapon to check
 *
 * @return Result true/false
 */
native bool:CW_IsInstanceOf(const pWeapon, const szClassname[]);

/**
 * Checks if weapon has member
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 */
native bool:CW_HasMember(const pWeapon, const any:szMember[]);

/**
 * Deletes member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 */
native CW_DeleteMember(const pWeapon, const any:szMember[]);

/**
 * Gets member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 *
 * @return Member value
 */
native any:CW_GetMember(const pWeapon, const any:szMember[]);

/**
 * Sets member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 * @param value Value to set
 */
native CW_SetMember(const pWeapon, const any:szMember[], any:value, bool:bReplace = true);

/**
 * Gets vector member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 * @param vecOut Output vector
 */
native bool:CW_GetMemberVec(const pWeapon, const any:szMember[], Float:vecOut[3]);

/**
 * Sets vector member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 * @param vecValue Vector to set
 */
native CW_SetMemberVec(const pWeapon, const any:szMember[], const Float:vecValue[], bool:bReplace = true);

/**
 * Gets string member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 * @param szOut Buffer to copy the value
 * @param iLen Maximum size of buffer
 */
native bool:CW_GetMemberString(const pWeapon, const any:szMember[], szOut[], iLen);

/**
 * Sets string member of an weapon
 *
 * @param pWeapon Weapon index
 * @param szMember Member name
 * @param szValue String value to set
 */
native CW_SetMemberString(const pWeapon, const any:szMember[], const szValue[], bool:bReplace = true);

/**
 * Call a weapon method.
 *
 * @param pWeapon Weapon index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CW_CallMethod(const pWeapon, const szMethod[], any:...);

/**
 * Call a base weapon method.
 *
 * @param pWeapon Weapon index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CW_CallBaseMethod(any:...);

/**
 * Call a native weapon method.
 *
 * @param pWeapon Weapon index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CW_CallNativeMethod(const pWeapon, const CW_Method:method, any:...);

/**
 * Gets the id of the plugin that called the native
 *
 * @return Plugin id
 */
native CW_GetCallerPlugin();

/**
 * Sets the think method for a weapon
 *
 * @param pWeapon Weapon index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CW_SetThink(const pWeapon, const szMethod[], const szClassname[] = "");

/**
 * Sets the touch method for a weapon
 *
 * @param pWeapon Weapon index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CW_SetTouch(const pWeapon, const szMethod[], const szClassname[] = "");

/**
 * Creates a custom weapon entity
 *
 * @param szClassname Weapon class
 *
 * @return Weapon entity index, or -1 on failure
 */
native CW_Create(const szClassname[]);

/**
 * Gives a custom weapon to a player
 *
 * @param pPlayer Player index
 * @param szClassname Weapon class
 * @param bDropOther Whether to drop the current weapon in the same slot
 *
 * @return Weapon entity index, or -1 on failure
 */
native CW_Give(const pPlayer, const szClassname[], bool:bDropOther = false);

/**
 * Checks if a player has a specific custom weapon
 *
 * @param pPlayer Player index
 * @param szClassname Weapon class
 *
 * @return true if player has the weapon, false otherwise
 */
native bool:CW_PlayerHasWeapon(const pPlayer, const szClassname[]);

/**
 * Finds a specific custom weapon in the player's inventory
 *
 * @param pPlayer Player index
 * @param szClassname Weapon class
 *
 * @return Weapon entity index, or -1 if not found
 */
native CW_PlayerFindWeapon(const pPlayer, const szClassname[]);

/**
 * Gives ammo to a player by ammo name
 *
 * @param pPlayer Player index
 * @param szName Ammo name
 * @param iAmount Amount of ammo
 *
 * @noreturn
 */
native CW_GiveAmmo(const pPlayer, const szName[], iAmount);

/**
 * Registers a new ammo type
 *
 * @param szName Ammo name
 * @param iAmmoType Engine ammo type index
 * @param iMaxAmount Maximum amount, -1 for unlimited
 * @param szGroup Ammo group name
 *
 * @noreturn
 */
native CW_Ammo_Register(const szName[], iAmmoType, iMaxAmount = -1, const szGroup[] = "");

/**
 * Checks if an ammo type is registered
 *
 * @param szName Ammo name
 *
 * @return true if registered, false otherwise
 */
native bool:CW_Ammo_IsRegistered(const szName[]);

/**
 * Gets the engine ammo type index
 *
 * @param szName Ammo name
 *
 * @return Ammo type index
 */
native CW_Ammo_GetType(const szName[]);

/**
 * Gets the maximum ammo amount
 *
 * @param szName Ammo name
 *
 * @return Maximum ammo amount
 */
native CW_Ammo_GetMaxAmount(const szName[]);

/**
 * Gets a metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 *
 * @return Metadata value
 */
native any:CW_Ammo_GetMetadata(const szName[], const szKey[]);

/**
 * Sets a metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 * @param value Value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native CW_Ammo_SetMetadata(const szName[], const szKey[], any:value, bool:bReplace = true);

/**
 * Gets a string metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 * @param szOut Output buffer
 * @param iLen Maximum buffer length
 *
 * @noreturn
 */
native CW_Ammo_GetMetadataString(const szName[], const szKey[], szOut[], iLen);

/**
 * Sets a string metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 * @param szValue String value to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native CW_Ammo_SetMetadataString(const szName[], const szKey[], const szValue[], bool:bReplace = true);

/**
 * Gets a vector metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 * @param vecOut Output vector
 *
 * @noreturn
 */
native CW_Ammo_GetMetadataVector(const szName[], const szKey[], Float:vecOut[3]);

/**
 * Sets a vector metadata value for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 * @param vecValue Vector to set
 * @param bReplace Whether to replace existing value
 *
 * @noreturn
 */
native CW_Ammo_SetMetadataVector(const szName[], const szKey[], const Float:vecValue[], bool:bReplace = true);

/**
 * Deletes a metadata value from a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 *
 * @noreturn
 */
native CW_Ammo_DeleteMetadata(const szName[], const szKey[]);

/**
 * Checks if a metadata key exists for a registered ammo type
 *
 * @param szName Ammo name
 * @param szKey Metadata key
 *
 * @return true if key exists, false otherwise
 */
native bool:CW_Ammo_HasMetadata(const szName[], const szKey[]);

/**
 * Registers a hook for an ammo type
 *
 * @param szName Ammo name
 * @param hook Hook type
 * @param szCallback Callback function name
 * @param bPost Whether this is a post hook
 *
 * @noreturn
 */
native CW_Ammo_RegisterHook(const szName[], const CW_AmmoHook:hook, const szCallback[], bool:bPost = false);

/**
 * Gets the number of ammo types in a group
 *
 * @param szGroup Ammo group name
 *
 * @return Number of ammo types in the group
 */
native CW_AmmoGroup_GetSize(const szGroup[]);

/**
 * Gets the ammo ID at a specific index in a group
 *
 * @param szGroup Ammo group name
 * @param iIndex Index in the group
 * @param szId Output buffer
 * @param iLen Buffer length
 *
 * @return true on success, false otherwise
 */
native bool:CW_AmmoGroup_GetAmmoId(const szGroup[], iIndex, szId[], iLen);

/**
 * Gets the ammo type at a specific index in a group
 *
 * @param szGroup Ammo group name
 * @param iIndex Index in the group
 *
 * @return Ammo type index
 */
native CW_AmmoGroup_GetAmmoType(const szGroup[], iIndex);

/**
 * Gets the ammo in a group by its engine type
 *
 * @param szGroup Ammo group name
 * @param iAmmoType Engine ammo type
 * @param szAmmo Output buffer for ammo name
 * @param iLen Buffer length
 *
 * @return Ammo index, or -1 if not found
 */
native CW_AmmoGroup_GetAmmoByType(const szGroup[], iAmmoType, szAmmo[] = "", iLen = 0);

/**
 * Sets the player animation
 *
 * @param pPlayer Player index
 * @param iPlayerAnim Player animation type
 *
 * @noreturn
 */
native CW_SetPlayerAnimation(const pPlayer, PLAYER_ANIM:iPlayerAnim);

/**
 * Loads custom materials from a file
 *
 * @param szPath Path to the materials file
 *
 * @noreturn
 */
native CW_LoadCustomMaterials(const szPath[]);
