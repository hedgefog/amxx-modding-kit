#if defined _api_entity_selection_included
 #endinput
#endif
#define _api_entity_selection_included

#pragma reqlib api_entity_selection

#include <api_entity_selection_const>

/**
 * Creates a new entity selection context for a player.
 *
 * @note The created context must be destroyed using EntitySelection_Destroy.
 *
 * @param pPlayer The player handle for whom the selection context is created.
 *
 * @return A handle to the created entity selection context.
 */
native Selection:EntitySelection_Create(const pPlayer = FM_NULLENT);

/**
 * Destroys an entity selection context and releases associated resources.
 *
 * @param selection  The entity selection handle.
 *
 * @noreturn
 */
native EntitySelection_Destroy(&Selection:selection);

/**
 * Starts the entity selection process, allowing entities to be selected.
 *
 * @param selection  The entity selection handle.
 *
 * @noreturn
 */
native EntitySelection_Start(const &Selection:selection);

/**
 * Ends the entity selection process, finalizing the selection.
 *
 * @param selection The entity selection handle.
 *
 * @noreturn
 */
native EntitySelection_End(const &Selection:selection);


/**
 * Checks if the entity selection process is currently active.
 *
 * @param selection The entity selection handle.
 *
 * @return True if the selection process is active, false otherwise.
 */
native bool:EntitySelection_IsStarted(const &Selection:selection);

/**
 * Sets flags for the entity selection context, allowing customization of selection behavior.
 *
 * @param selection The entity selection handle.
 * @param iFlags The flags to set for the selection context.
 *
 * @noreturn
 */
native EntitySelection_SetFlags(const &Selection:selection, Selection_Flags:iFlags);

/**
 * Sets the time interval between selection updates (think time).
 *
 * @param selection The entity selection handle.
 * @param flThinkTime The time in seconds between selection updates.
 *
 * @noreturn
 */
native EntitySelection_SetThinkTime(const &Selection:selection, Float:flThinkTime);

/**
 * Gets the current flags set for the entity selection context.
 * @param selection The entity selection handle.
 *
 * @return The current flags for the selection context.
 */
native Selection_Flags:EntitySelection_GetFlags(const &Selection:selection);

/**
 * Sets the callback function to be called every tick during the selection process.
 *
 * @param selection The entity selection handle.
 * @param szCallback The name of the callback function to be called.
 *
 * @noreturn
 */
native EntitySelection_SetThinkCallback(const &Selection:selection, const szCallback[]);

/**
 * Sets a custom filter callback to determine which entities can be selected.
 *
 * @param selection The entity selection handle.
 * @param szCallback The name of the callback function to be used as a filter.
 *
 * @noreturn
 */
native EntitySelection_SetFilterCallback(const &Selection:selection, const szCallback[]);

/**
 * Sets the color for the selection highlight.
 *
 * @param selection The entity selection handle.
 * @param rgiColor An array of RGB values for the selection color.
 *
 * @noreturn
 */
native EntitySelection_SetColor(const &Selection:selection, const rgiColor[3]);

/**
 * Gets the color of the selection highlight.
 *
 * @param selection The entity selection handle.
 * @param rgiColor An array to store the RGB values of the selection color.
 *
 * @noreturn
 */
native EntitySelection_GetColor(const &Selection:selection, rgiColor[3]);

/**
 * Sets the brightness level for the selection highlight.
 *
 * @param selection The entity selection handle.
 * @param iBrightness The brightness level (0-255).
 *
 * @noreturn
 */
native EntitySelection_SetBrightness(const &Selection:selection, iBrightness);

/**
 * Gets the brightness level of the selection highlight.
 *
 * @param selection The entity selection handle.
 *
 * @return The brightness level (0-255).
 */
native EntitySelection_GetBrightness(const &Selection:selection);

/**
 * Gets the currently selected entity at the specified index.
 *
 * @param selection The entity selection handle.
 * @param iIndex The index of the selected entity to retrieve.
 *
 * @return The entity index at the specified position, or FM_NULLENT if no entity is selected.
 */
native EntitySelection_GetEntity(const &Selection:selection, iIndex);

/**
 * Gets the number of entities currently selected.
 *
 * @param selection The entity selection handle.
 *
 * @return The number of entities selected.
 */
native EntitySelection_GetSize(const &Selection:selection);

/**
 * Gets the player associated with the entity selection context.
 *
 * @param selection The entity selection handle.
 *
 * @return The player handle associated with the selection context.
 */
native EntitySelection_GetPlayer(const &Selection:selection);

/**
 * Sets the player associated with the entity selection context.
 *
 * @param selection The entity selection handle.
 * @param pPlayer The player handle to associate with the selection.
 *
 * @noreturn
 */
native EntitySelection_SetPlayer(const &Selection:selection, const pPlayer);

/**
 * Sets the pointer entity for the selection context.
 *
 * @param selection The entity selection handle.
 * @param pPointer The entity index to set as the pointer.
 *
 * @noreturn
 */
native EntitySelection_SetPointerEntity(const &Selection:selection, const pPointer);

/**
 * Gets the current pointer entity for the selection context.
 *
 * @param selection The entity selection handle.
 *
 * @return The entity index of the pointer entity, or FM_NULLENT if no pointer is set.
 */
native EntitySelection_GetPointerEntity(const &Selection:selection);

/**
 * Sets the cursor position in the selection context.
 *
 * @param selection The entity selection handle.
 * @param vecOrigin The position to set as the cursor position.
 *
 * @noreturn
 */
native EntitySelection_SetCursorPos(const &Selection:selection, const Float:vecOrigin[]);

/**
 * Gets the current cursor position in the selection context.
 *
 * @param selection The entity selection handle.
 * @param vecOut An array to store the cursor position.
 *
 * @noreturn
 */
native EntitySelection_GetCursorPos(const &Selection:selection, Float:vecOut[]);

/**
 * Gets the start position of the selection area.
 *
 * @param selection The entity selection handle.
 * @param vecOut An array to store the start position of the selection area.
 *
 * @noreturn
 */
native EntitySelection_GetStartPos(const &Selection:selection, Float:vecOut[]);

/**
 * Gets the end position of the selection area.
 * @param selection The entity selection handle.
 * @param vecOut An array to store the end position of the selection area.
 *
 * @noreturn
 */
native EntitySelection_GetEndPos(const &Selection:selection, Float:vecOut[]);

/**
 * Gets the cursor yaw angle for the selection context.
 *
 * @param selection The entity selection handle.
 *
 * @return The cursor yaw angle in degrees.
 */
native Float:EntitySelection_GetCursorYaw(const &Selection:selection);

/**
 * Sets the cursor yaw angle for the selection context.
 *
 * @param selection The entity selection handle.
 * @param flYaw The yaw angle in degrees.
 *
 * @noreturn
 */
native EntitySelection_SetCursorYaw(const &Selection:selection, Float:flYaw);
