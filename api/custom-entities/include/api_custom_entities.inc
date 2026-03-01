#if defined _api_custom_entities_included
  #endinput
#endif
#define _api_custom_entities_included

#pragma reqlib api_custom_entities

#include <api_custom_entities_const>

/**
 * Register entity
 *
 * @param szClassname Name of an entity
 * @param szBase Name of a parent entity
 * @param bAbstract Abstract flag
 *
 * @return Handle of the registered entity
 */
native CE:CE_RegisterClass(const szClassname[], const szBase[] = "", bool:bAbstract = false);

/**
 * Extends native game entity with custom entities functionality
 *
 * @param szClassname Name of an entity
 *
 * @return Handle of the registered entity
 */
native CE:CE_ExtendClass(const szClassname[]);

/**
 * Create a copy of a entity class with a new name and base class
 *
 * @param szClassname Name of an entity
 * @param szOriginalClass Name of a entity to fork
 * @param szBase Name of a base entity (should be child of original base class)
 *
 * @return Handle of the registered entity
 */
native CE:CE_ForkClass(const szClassname[], const szOriginalClass[], const szBase[] = "");

/**
 * Extend entity
 *
 * @param szAlias Name of an alias
 * @param szClassname Name of an entity
 *
 * @return Handle of the registered entity
 */
native CE:CE_RegisterClassAlias(const szAlias[], const szClassname[]);

/**
  *
  * @note Null classes are usefull to block game entities from being created
  *
  * Register null entity class
  * @param szClassname Name of an entity
  *
  * @noreturn
  */
native CE_RegisterNullClass(const szClassname[]);

/**
 * Checks if a entity class is registered
 *
 * @param szClassname Name of an entity
 *
 * @return Result true/false
 */
native bool:CE_IsClassRegistered(const szClassname[]);

/**
 * Spawn entity
 *
 * @param szClassname Entity class
 * @param vecOrigin Spawn origin
 * @param bTemp Mark entity as an temporary entity
 *
 * @return Entity index, FM_NULLENT on failure
 */
native CE_Create(const szClassname[], const Float:vecOrigin[] = {0.0, 0.0, 0.0}, bool:bTemp = true);

/**
 * Register new hook for entity class
 *
 * @param method Function handle
 * @param szClassname Entity class
 * @param szCallback Callback
 */
native CE_RegisterClassNativeMethodHook(const szClassname[], CE_Method:method, const szCallback[], bool:bPost = false);

/**
 * Gets the return value of the current method
 *
 * @return Method return value
 */
native any:CE_GetMethodReturn();

/**
 * Sets the return value of the current method
 *
 * @param value Return value to set
 *
 * @noreturn
 */
native CE_SetMethodReturn(any:value);

/**
 * Registers a key-value member binding for an entity class
 *
 * @param szClassname Entity class
 * @param szKey Key name
 * @param szMember Member name
 * @param iType Member type
 *
 * @noreturn
 */
native CE_RegisterClassKeyMemberBinding(const szClassname[], const szKey[], const any:szMember[], CEMemberType:iType);

/**
 * Removes a key-value member binding for an entity class
 *
 * @param szClassname Entity class
 * @param szKey Key name
 * @param szMember Member name
 *
 * @noreturn
 */
native CE_RemoveClassKeyMemberBinding(const szClassname[], const szKey[], const any:szMember[]);

/**
 * Implements a native method for entity class.
 *
 * @param szClassname Entity class
 * @param iMethod Method to implement
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_ImplementClassMethod(const szClassname[], CE_Method:iMethod, const szCallback[]);

/**
 * Registers a new method for entity class.
 *
 * @param szClassname Entity class
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterClassMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Registers a new virtual method for entity class.
 *
 * @param szClassname Entity class
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterClassVirtualMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Gets handle of entity by name
 *
 * @param szClassname Entity class
 *
 * @return Handle of the registered entity or -1 otherwise
 */
native CE:CE_GetClassHandle(const szClassname[]);

/**
 * Gets handle of entity by index
 *
 * @param pEntity Entity index
 *
 * @return Handle of the entity or -1 otherwise
 */
native CE:CE_GetHandle(const pEntity);

/**
 * Checks if entity is an instance of specific custom entity 
 *
 * @param pEntity Entity index
 * @param szTargetName Name of target entity to check
 *
 * @return Result true/false
 */
native bool:CE_IsInstanceOf(const pEntity, const szTargetName[]);

/**
 * Checks if entity has member
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native bool:CE_HasMember(const pEntity, const any:szMember[]);

/**
 * Deletes member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native CE_DeleteMember(const pEntity, const any:szMember[]);

/**
 * Gets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 *
 * @return Member value
 */
native any:CE_GetMember(const pEntity, const any:szMember[]);

/**
 * Sets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param value Value to set
 */
native CE_SetMember(const pEntity, const any:szMember[], any:value, bool:bReplace = true);

/**
 * Gets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecOut Output vector
 */
native bool:CE_GetMemberVec(const pEntity, const any:szMember[], Float:vecOut[3]);

/**
 * Sets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecValue Vector to set
 */
native CE_SetMemberVec(const pEntity, const any:szMember[], const Float:vecValue[], bool:bReplace = true);

/**
 * Gets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szOut Buffer to copy the value
 * @param iLen Maximum size of buffer
 */
native bool:CE_GetMemberString(const pEntity, const any:szMember[], szOut[], iLen);

/**
 * Sets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szValue String value to set
 */
native CE_SetMemberString(const pEntity, const any:szMember[], const szValue[], bool:bReplace = true);

/**
 * Call a entity method.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallMethod(const pEntity, const szMethod[], any:...);

/**
 * Call a base entity method.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallBaseMethod(any:...);

/**
 * Call a native entity method.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallNativeMethod(const pEntity, const CE_Method:method, any:...);

/**
 * Gets the id of the plugin that called the native
 *
 * @return Plugin id
 */
native CE_GetCallerPlugin();

/**
 * Sets the think method for an entity
 *
 * @param pEntity Entity index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CE_SetThink(const pEntity, const szMethod[], const szClassname[] = "");

/**
 * Sets the touch method for an entity
 *
 * @param pEntity Entity index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CE_SetTouch(const pEntity, const szMethod[], const szClassname[] = "");

/**
 * Sets the use method for an entity
 *
 * @param pEntity Entity index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CE_SetUse(const pEntity, const szMethod[], const szClassname[] = "");

/**
 * Sets the blocked method for an entity
 *
 * @param pEntity Entity index
 * @param szMethod Method name
 * @param szClassname Classname filter
 *
 * @noreturn
 */
native CE_SetBlocked(const pEntity, const szMethod[], const szClassname[] = "");

/**
 * Finds an entity by custom classname
 *
 * @param szClassname Entity class
 * @param pEntity Start entity index
 * @param bExact If true, exact match is required
 *
 * @return Entity index, or -1 if not found
 */
native CE_Find(const szClassname[], const pEntity = -1, bool:bExact = false);
