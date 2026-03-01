#if defined _api_assets_included
  #endinput
#endif
#define _api_assets_included

#pragma reqlib api_assets

#include <api_assets_const>

/**
 * Loads a library of assets
 *
 * @param szLibrary Library name
 *
 * @noreturn
 */
native Asset_Library_Load(const szLibrary[]);

/**
 * Precaches an entire asset library
 *
 * @param szLibrary Library name
 *
 * @noreturn
 */
native Asset_Library_Precache(const szLibrary[]);

/**
 * Checks if a library of assets is loaded
 *
 * @param szLibrary Library name
 *
 * @return true if loaded, false otherwise
 */
native bool:Asset_Library_IsLoaded(const szLibrary[]);

/**
  * Precache assets.
  *
  * @note Precache single asset resource: 
  *   Asset_Precache(const szLibrary[], const szAsset[] szPath[], iMaxLength)
  *
  * @note Precache array of asset resources:
  *   Asset_Precache(const szLibrary[], const szAsset[] rgszPath[][], iSize, iMaxLength)
  *
  * @note Precache array of asset resources and return the size:
  *   Asset_Precache(const szLibrary[], const szAsset[] rgszPath[][], iSize, iMaxLength, &iTotalSize)
  *
  * @param szLibrary Library name
  * @param szAsset Asset name
  *
  * @return Unique engine cache id of the resource
*/
native Asset_Type:Asset_Precache(const szLibrary[], const szAsset[], szPath[] = "", iMaxLength = 0);

/**
  * Get the size of a precached asset list.
  * @param szLibrary Library name
  * @param szAsset Asset name
  *
  * @return Size of the asset list, or 0 if the asset is not precached. Returns 1 for single asset
*/
native Asset_GetListSize(const szLibrary[], const szAsset[]);

/**
  * Get the model index of a precached model asset.
  * @param szLibrary Library name
  * @param szAsset Asset name
  *
  * @return Model index of the asset, or model index of error model if the asset is not precached
*/
native Asset_GetModelIndex(const szLibrary[], const szAsset[], iIndex = 0);

/**
  * Get the path of a precached asset.
  * @param szLibrary Library name
  * @param szAsset Asset name
  * @param szPath Output path of the asset
  * @param iMaxLength Maximum length of the output path
  *
  * @return true if the asset is precached, false otherwise
*/
native Asset_GetPath(const szLibrary[], const szAsset[], szPath[], iMaxLength, iIndex = 0);

/**
  * Get the type of a precached asset.
  * @param szLibrary Library name
  * @param szAsset Asset name
  *
  * @return Asset type of the asset, or Asset_Type_Invalid if the asset is not precached
*/
native Asset_Type:Asset_GetType(const szLibrary[], const szAsset[]);

/**
  * Check if an asset is precached.
  * @param szLibrary Library name
  * @param szAsset Asset name
  *
  * @return true if the asset is precached, false otherwise
*/
native bool:Asset_IsPrecached(const szLibrary[], const szAsset[]);

/**
 * Gets an integer value from an asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index
 *
 * @return Integer value
 */
native Asset_GetInteger(const szLibrary[], const szAsset[], iIndex = 0);

/**
 * Gets a float value from an asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index
 *
 * @return Float value
 */
native Float:Asset_GetFloat(const szLibrary[], const szAsset[], iIndex = 0);

/**
 * Gets a boolean value from an asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index
 *
 * @return Boolean value
 */
native bool:Asset_GetBool(const szLibrary[], const szAsset[], iIndex = 0);

/**
 * Gets a string value from an asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param szOut Output string buffer
 * @param iMaxLength Maximum length of the string buffer
 * @param iIndex Asset list index
 *
 * @return true if string was copied, false otherwise
 */
native bool:Asset_GetString(const szLibrary[], const szAsset[], szOut[], iMaxLength, iIndex = 0);

/**
 * Gets a vector value from an asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param vecOut Output vector
 * @param iIndex Asset list index
 *
 * @return true if vector was copied, false otherwise
 */
native bool:Asset_GetVector(const szLibrary[], const szAsset[], Float:vecOut[], iIndex = 0);

/**
 * Emits a sound using an asset
 *
 * @param pEntity Entity index
 * @param iChannel Channel index
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index, ASSET_INDEX_RANDOM for random index
 * @param flVolume Volume multiplier
 * @param flAttenuation Attenuation multiplier
 * @param iFlags Flags
 * @param iPitch Pitch multiplier
 *
 * @noreturn
 */
native Asset_EmitSound(const pEntity, iChannel, const szLibrary[], const szAsset[], iIndex = ASSET_INDEX_RANDOM, Float:flVolume = VOL_NORM, Float:flAttenuation = ATTN_NORM, iFlags = 0, iPitch = PITCH_NORM);

/**
 * Emits an ambient sound using an asset
 *
 * @param pEntity Entity index
 * @param vecOrigin Origin
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index, ASSET_INDEX_RANDOM for random index
 * @param flVolume Volume multiplier
 * @param flAttenuation Attenuation multiplier
 * @param iFlags Flags
 * @param iPitch Pitch multiplier
 *
 * @noreturn
 */
native Asset_EmitAmbientSound(const pEntity, const Float:vecOrigin[], const szLibrary[], const szAsset[], iIndex = ASSET_INDEX_RANDOM, Float:flVolume = VOL_NORM, Float:flAttenuation = ATTN_NORM, iFlags = 0, iPitch = PITCH_NORM);

/**
 * Sets the model of an entity using an asset
 *
 * @param pEntity Entity index
 * @param vecOrigin Origin
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index, ASSET_INDEX_RANDOM for random index
 *
 * @noreturn
 */
native Asset_SetModel(const pEntity, const szLibrary[], const szAsset[], iIndex = ASSET_INDEX_RANDOM);

/**
 * Plays a client-side sound using an asset
 *
 * @param pPlayer Player index
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index, ASSET_INDEX_RANDOM for random index
 *
 * @noreturn
 */
native Asset_PlayClientSound(const pPlayer, const szLibrary[], const szAsset[], iIndex = ASSET_INDEX_RANDOM);

/**
 * Gets the duration of a sound asset
 *
 * @param szLibrary Library name
 * @param szAsset Asset name
 * @param iIndex Asset list index
 *
 * @return Sound duration in seconds
 */
native Float:Asset_GetSoundDuration(const szLibrary[], const szAsset[], iIndex);

stock Asset_PrecacheList(const szLibrary[], const szAsset[], rgszPaths[][], iSize, iMaxLength) {
  Asset_Precache(szLibrary, szAsset);
  return Asset_GetPathsList(szLibrary, szAsset, rgszPaths, iSize, iMaxLength);
}

stock Asset_GetPathsList(const szLibrary[], const szAsset[], rgszPaths[][], iSize, iMaxLength) {
  iSize = min(iSize, Asset_GetListSize(szLibrary, szAsset));
  for (new i = 0; i < iSize; ++i) Asset_GetPath(szLibrary, szAsset, rgszPaths[i], iMaxLength, i);
  return iSize;
}
