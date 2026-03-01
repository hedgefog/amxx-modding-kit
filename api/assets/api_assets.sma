#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <json>

#include <api_assets_const>

#define LOG_PREFIX "[Assets]"
#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define ERR_LIBRARY_NOT_FOUND "Library ^"%s^" does not exist."
#define ERR_LIBRARY_LOAD_FAILED "Failed to load library ^"%s^"."
#define ERR_ASSET_NOT_FOUND "Asset ^"%s^" not found in library ^"%s^"."
#define ERR_ASSET_NOT_PRECACHED "Asset ^"%s^" in library ^"%s^" is not precached."
#define ERR_ASSET_TYPE_MISMATCH "Asset ^"%s^" in library ^"%s^" is not a ^"%s^"."
#define ERR_ASSET_VARIABLE "Asset ^"%s^" in library ^"%s^" is a variable."

#define ASSET_MAX_DATA_SIZE MAX_RESOURCE_PATH_LENGTH

#define TYPE_KEY "@type"
#define VALUE_KEY "@value"

new g_szErrorModel[MAX_RESOURCE_PATH_LENGTH];
new g_szErrorSound[MAX_RESOURCE_PATH_LENGTH];

new Trie:g_itLibraries = Invalid_Trie;

new g_rgszAssetId[ASSETS_MAX_ASSETS][ASSETS_MAX_ASSET_ID_LENGTH];
new Asset_Type:g_rgiAssetType[ASSETS_MAX_ASSETS];
new any:g_rgrgAssetValue[ASSETS_MAX_ASSETS][ASSET_MAX_DATA_SIZE];
new g_rgbAssetPrecached[ASSETS_MAX_ASSETS];
new g_rgiAssetCacheId[ASSETS_MAX_ASSETS];
new g_iAssetsNum = 0;

new bool:g_bPrecache = true;

public plugin_precache() {
  g_itLibraries = TrieCreate();

  new pCvarErrorModel = register_cvar("assets_error_model", "sprites/bubble.spr");
  new pCvarErrorSound = register_cvar("assets_error_sound", "common/null.wav");

  get_pcvar_string(pCvarErrorModel, g_szErrorModel, charsmax(g_szErrorModel));
  get_pcvar_string(pCvarErrorSound, g_szErrorSound, charsmax(g_szErrorSound));

  precache_model(g_szErrorModel);
  precache_sound(g_szErrorSound);
}

public plugin_init() {
  g_bPrecache = false;

  register_plugin("[API] Assets", "1.0.0", "Hedgehog Fog");
}

public plugin_natives() {
  register_library("api_assets");

  register_native("Asset_Library_Load", "Native_LoadLibrary");
  register_native("Asset_Library_IsLoaded", "Native_IsLibraryLoaded");
  register_native("Asset_Library_Precache", "Native_PrecacheLibrary");
  register_native("Asset_Precache", "Native_PrecacheAsset");
  register_native("Asset_GetListSize", "Native_GetAssetListSize");
  register_native("Asset_GetModelIndex", "Native_GetAssetModelIndex");
  register_native("Asset_GetPath", "Native_GetAssetPath");
  register_native("Asset_GetType", "Native_GetAssetType");
  register_native("Asset_IsPrecached", "Native_IsAssetPrecached");
  register_native("Asset_GetString", "Native_GetAssetString");
  register_native("Asset_GetInteger", "Native_GetAssetInteger");
  register_native("Asset_GetFloat", "Native_GetAssetFloat");
  register_native("Asset_GetBool", "Native_GetAssetBool");
  register_native("Asset_GetVector", "Native_GetAssetVector");
  register_native("Asset_EmitSound", "Native_EmitSound");
  register_native("Asset_EmitAmbientSound", "Native_EmitAmbientSound");
  register_native("Asset_SetModel", "Native_SetModel");
  register_native("Asset_PlayClientSound", "Native_PlayClientSound");
  register_native("Asset_GetSoundDuration", "Native_GetSoundDuration");
}

public plugin_end() {
  new TrieIter:iLibrariesIterator = TrieIterCreate(g_itLibraries);

  while (!TrieIterEnded(iLibrariesIterator)) {
    new Trie:itAssets; TrieIterGetCell(iLibrariesIterator, itAssets);
    if (itAssets != Invalid_Trie) TrieDestroy(itAssets);
    TrieIterNext(iLibrariesIterator);
  }

  TrieIterDestroy(iLibrariesIterator);

  TrieDestroy(g_itLibraries);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_LoadLibrary(const iPluginId, const iArgc) {
  new szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));

  if (!Libary_IsLoaded(szLibrary)) {
    Library_Load(szLibrary);
  }
}

public Native_PrecacheLibrary(const iPluginId, const iArgc) {
  new TrieIter:iLibrariesIterator = TrieIterCreate(g_itLibraries);

  while (!TrieIterEnded(iLibrariesIterator)) {
    new szLibrary[ASSETS_MAX_ASSET_ID_LENGTH]; TrieIterGetKey(iLibrariesIterator, szLibrary, charsmax(szLibrary));

    new Trie:itAssets; TrieIterGetCell(iLibrariesIterator, itAssets);
    if (itAssets != Invalid_Trie) {
      new TrieIter:iAssetsIterator = TrieIterCreate(itAssets);

      while (!TrieIterEnded(iAssetsIterator)) {
        new szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; TrieIterGetKey(iAssetsIterator, szAsset, charsmax(szAsset));
        Library_PrecacheAsset(szLibrary, szAsset);
        TrieIterNext(iAssetsIterator);
      }

      TrieIterDestroy(iAssetsIterator);
    }

    TrieIterNext(iLibrariesIterator);
  }

  TrieIterDestroy(iLibrariesIterator);
}

public Native_IsLibraryLoaded(const iPluginId, const iArgc) {
  new szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));

  return Libary_IsLoaded(szLibrary);
}

public Asset_Type:Native_PrecacheAsset(const iPluginId, const iArgc) {
  if (!g_bPrecache) {
    LOG_ERROR("Cannot precache assets after precache phase is over.", 0);
    return Asset_Type_Invalid;
  }

  new szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  new szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));

  new iAssetId = Library_PrecacheAsset(szLibrary, szAsset);

  // If array - use the first asset in the array
  if (iAssetId != -1 && g_rgiAssetType[iAssetId] == Asset_Type_Array) {
    if (!g_rgrgAssetValue[iAssetId][0]) {
      return Asset_Type_Invalid;
    }

    iAssetId = g_rgrgAssetValue[iAssetId][0] ? g_rgrgAssetValue[iAssetId][1] : -1;
  }

  if (iAssetId == -1) return Asset_Type_Invalid;

  if (g_rgiAssetType[iAssetId] == Asset_Type_Sound) {
    set_string(3, g_rgrgAssetValue[iAssetId][1], get_param(4));
  } else {
    set_string(3, g_rgrgAssetValue[iAssetId], get_param(4));
  }

  return g_rgiAssetType[iAssetId];
}

public Native_GetAssetListSize(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset);
  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return 0;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Array) return 1;

  return g_rgrgAssetValue[iAssetId][0];
}

public Native_GetAssetModelIndex(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return engfunc(EngFunc_ModelIndex, g_szErrorModel);
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Model) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "model");
    return engfunc(EngFunc_ModelIndex, g_szErrorModel);
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return engfunc(EngFunc_ModelIndex, g_szErrorModel);
  }

  return engfunc(EngFunc_ModelIndex, g_rgrgAssetValue[iAssetId]);
}

public Native_GetAssetPath(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(5);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);

    set_string(3, "", get_param(4));

    return false;
  }

  if (g_rgiAssetType[iAssetId] == Asset_Type_Variable) {
    LOG_ERROR(ERR_ASSET_VARIABLE, szAsset, szLibrary);
    return false;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);

    switch (g_rgiAssetType[iAssetId]) {
      case Asset_Type_Generic: set_string(3, "", get_param(4));
      case Asset_Type_Model: set_string(3, g_szErrorModel, get_param(4));
      case Asset_Type_Sound: set_string(3, g_szErrorSound, get_param(4));
      default: set_string(3, "", get_param(4));
    }
    
    return false;
  }

  if (g_rgiAssetType[iAssetId] == Asset_Type_Sound) {
    set_string(3, g_rgrgAssetValue[iAssetId][1], get_param(4));
  } else {
    set_string(3, g_rgrgAssetValue[iAssetId], get_param(4));
  }

  return true;
}

public Asset_Type:Native_GetAssetType(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return Asset_Type_Invalid;

  return g_rgiAssetType[iAssetId];
}

public Native_IsAssetPrecached(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset);
  if (iAssetId == -1) return false;

  return g_rgbAssetPrecached[iAssetId];
}

public bool:Native_GetAssetString(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(5);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return false;

  if (g_rgiAssetType[iAssetId] != Asset_Type_Variable) {
    if (g_rgiAssetType[iAssetId] == Asset_Type_Sound) {
      set_string(3, g_rgrgAssetValue[iAssetId][1], get_param(4));
    } else {
      set_string(3, g_rgrgAssetValue[iAssetId], get_param(4));
    }

    return true;
  }

  if (g_rgrgAssetValue[iAssetId][0] != Asset_Variable_Type_String) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "string");
    return false;
  }

  set_string(3, g_rgrgAssetValue[iAssetId][1], get_param(4));

  return true;
}

public Native_GetAssetInteger(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return 0;

  if (g_rgiAssetType[iAssetId] != Asset_Type_Variable) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "variable");
    return 0;
  }

  if (g_rgrgAssetValue[iAssetId][0] != Asset_Variable_Type_Integer) {
    if (g_rgrgAssetValue[iAssetId][0] == Asset_Variable_Type_Float) {
      return floatround(g_rgrgAssetValue[iAssetId][1], floatround_floor);
    }

    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "integer");
    return 0;
  }

  return g_rgrgAssetValue[iAssetId][1];
}

public Float:Native_GetAssetFloat(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return 0.0;

  if (g_rgiAssetType[iAssetId] != Asset_Type_Variable) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "variable");
    return 0.0;
  }

  if (g_rgrgAssetValue[iAssetId][0] != Asset_Variable_Type_Float) {
    if (g_rgrgAssetValue[iAssetId][0] == Asset_Variable_Type_Integer) {
      return float(g_rgrgAssetValue[iAssetId][1]);
    }

    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "float");
    return 0.0;
  }

  return g_rgrgAssetValue[iAssetId][1];
}

public bool:Native_GetAssetBool(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return false;

  if (g_rgiAssetType[iAssetId] != Asset_Type_Variable) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "variable");
    return false;
  }

  if (g_rgrgAssetValue[iAssetId][0] != Asset_Variable_Type_Bool) {
    if (g_rgrgAssetValue[iAssetId][0] == Asset_Variable_Type_Integer) {
      return !!g_rgrgAssetValue[iAssetId][1];
    }

    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "boolean");
    return false;
  }

  return g_rgrgAssetValue[iAssetId][1];
}

public bool:Native_GetAssetVector(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(4);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);
  if (iAssetId == -1) return false;

  if (g_rgiAssetType[iAssetId] != Asset_Type_Variable) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "variable");
    return false;
  }

  if (g_rgrgAssetValue[iAssetId][0] != Asset_Variable_Type_Vector) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "vector");
    return false;
  }

  static Float:vecValue[3];
  vecValue[0] = g_rgrgAssetValue[iAssetId][1];
  vecValue[1] = g_rgrgAssetValue[iAssetId][2];
  vecValue[2] = g_rgrgAssetValue[iAssetId][3];

  set_array_f(3, vecValue, 3);

  return true;
}

public bool:Native_EmitSound(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static iChannel; iChannel = get_param(2);
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(3, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(4, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(5);
  static Float:flVolume; flVolume = get_param_f(6);
  static Float:flAttenuation; flAttenuation = get_param_f(7);
  static iFlags; iFlags = get_param(8);
  static iPitch; iPitch = get_param(9);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);

  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return false;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Sound) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "sound");
    return false;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return false;
  }

  engfunc(EngFunc_EmitSound, pEntity, iChannel, g_rgrgAssetValue[iAssetId][1], flVolume, flAttenuation, iFlags, iPitch);

  return true;
}

public bool:Native_EmitAmbientSound(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static Float:vecPos[3]; get_array_f(2, vecPos, 3);
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(3, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(4, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(5);
  static Float:flVolume; flVolume = get_param_f(6);
  static Float:flAttenuation; flAttenuation = get_param_f(7);
  static iFlags; iFlags = get_param(8);
  static iPitch; iPitch = get_param(9);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);

  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return false;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Sound) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "sound");
    return false;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return false;
  }

  engfunc(EngFunc_EmitAmbientSound, pEntity, vecPos, g_rgrgAssetValue[iAssetId][1], flVolume, flAttenuation, iFlags, iPitch);

  return true;
}

public bool:Native_SetModel(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(2, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(3, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(4);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);

  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return false;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Model) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "model");
    return false;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return false;
  }

  engfunc(EngFunc_SetModel, pEntity, g_rgrgAssetValue[iAssetId]);

  return true;
}

public bool:Native_PlayClientSound(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  if (is_user_bot(pPlayer)) return true;

  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(2, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(3, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(4);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);

  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return false;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Sound) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "sound");
    return false;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return false;
  }

  client_cmd(pPlayer, "spk ^"%s^"", g_rgrgAssetValue[iAssetId][1]);

  return true;
}

public Float:Native_GetSoundDuration(const iPluginId, const iArgc) {
  static szLibrary[ASSETS_MAX_LIBRARY_ID_LENGTH]; get_string(1, szLibrary, charsmax(szLibrary));
  static szAsset[ASSETS_MAX_ASSET_ID_LENGTH]; get_string(2, szAsset, charsmax(szAsset));
  static iIndex; iIndex = get_param(3);

  static iAssetId; iAssetId = Library_GetAssetId(szLibrary, szAsset, iIndex);

  if (iAssetId == -1) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szLibrary);
    return 0.0;
  }

  if (g_rgiAssetType[iAssetId] != Asset_Type_Sound) {
    LOG_ERROR(ERR_ASSET_TYPE_MISMATCH, szAsset, szLibrary, "sound");
    return 0.0;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    LOG_ERROR(ERR_ASSET_NOT_PRECACHED, szAsset, szLibrary);
    return 0.0;
  }

  return g_rgrgAssetValue[iAssetId][0];
}

/*--------------------------------[ Library Methods ]--------------------------------*/

Trie:Library_Load(const szId[]) {
  new szPath[MAX_RESOURCE_PATH_LENGTH];
  get_configsdir(szPath, charsmax(szPath));
  format(szPath, charsmax(szPath), "%s/assets/%s.json", szPath, szId);

  if (!file_exists(szPath)) {
    LOG_ERROR(ERR_LIBRARY_NOT_FOUND, szId);
    return Invalid_Trie;
  }

  new JSON:jsonDoc = json_parse(szPath, true);

  if (jsonDoc == Invalid_JSON) return Invalid_Trie;

  if (json_get_type(jsonDoc) != JSONObject) {
    LOG_ERROR("Library ^"%s^" is not a valid JSON object.", szId);
    json_free(jsonDoc);
    return Invalid_Trie;
  }

  new Trie:itLibrary = TrieCreate();
  TrieSetCell(g_itLibraries, szId, itLibrary);

  Library_AddAssetsFromJson(szId, jsonDoc);

  return itLibrary;
}

Library_AddAssetsFromJson(const szId[], JSON:jsonDoc, const szPrefix[] = "") {
  new szAsset[256];
  
  new Trie:itLibrary; itLibrary = Library_GetTrie(szId);

  new iAssetsNum = json_object_get_count(jsonDoc);

  for (new iAsset = 0; iAsset < iAssetsNum; iAsset++) {
    json_object_get_name(jsonDoc, iAsset, szAsset, charsmax(szAsset));
    if (szAsset[0] == '@') continue;

    if (!equal(szPrefix, NULL_STRING)) {
      format(szAsset, charsmax(szAsset), "%s.%s", szPrefix, szAsset);
    }

    new JSON:jsonAsset = json_object_get_value_at(jsonDoc, iAsset);

    new iAssetId = Asset_Create(szAsset, jsonAsset);

    if (iAssetId == -1) {
      if (json_get_type(jsonAsset) == JSONObject) {
        Library_AddAssetsFromJson(szId, jsonAsset, szAsset);
        json_free(jsonAsset);
      } else {
        LOG_ERROR("Failed to load asset ^"%s^" in library ^"%s^".", szAsset, szId);
      }
    } else {
      TrieSetCell(itLibrary, szAsset, iAssetId);
    }

    json_free(jsonAsset);
  }
}

bool:Libary_IsLoaded(const szId[]) {
  return TrieKeyExists(g_itLibraries, szId);
}

Trie:Library_GetTrie(const szId[], bool:bLoad = false) {
  static Trie:itLibrary;
  if (!TrieGetCell(g_itLibraries, szId, itLibrary) && bLoad) {
    itLibrary = Library_Load(szId);
  }

  if (itLibrary == Invalid_Trie) return Invalid_Trie;

  return itLibrary;
}

Library_GetAssetId(const szId[], const szAsset[], iIndex = -1) {
  static Trie:itLibrary; itLibrary = Library_GetTrie(szId);

  if (itLibrary == Invalid_Trie) return -1;

  static iAssetId;
  if (!TrieGetCell(itLibrary, szAsset, iAssetId)) return -1;

  if (g_rgiAssetType[iAssetId] == Asset_Type_Array && iIndex != -1) {      
    if (iIndex == -2) iIndex = random(g_rgrgAssetValue[iAssetId][0]);
    return g_rgrgAssetValue[iAssetId][iIndex + 1];
  }

  return iAssetId;
}

Library_PrecacheAsset(const szId[], const szAsset[]) {
  new Trie:itLibrary = Library_GetTrie(szId, true);

  if (itLibrary == Invalid_Trie) {
    LOG_ERROR(ERR_LIBRARY_LOAD_FAILED, szId);
    return -1;
  }

  new iAssetId;
  if (!TrieGetCell(itLibrary, szAsset, iAssetId)) {
    LOG_ERROR(ERR_ASSET_NOT_FOUND, szAsset, szId);
    return -1;
  }

  if (!g_rgbAssetPrecached[iAssetId]) {
    if (g_rgiAssetType[iAssetId] == Asset_Type_Array) {
      new iNestedAssetsNum = g_rgrgAssetValue[iAssetId][0];
      for (new iAssetIndex = 0; iAssetIndex < iNestedAssetsNum; iAssetIndex++) {
        new iNestedAssetId = g_rgrgAssetValue[iAssetId][1 + iAssetIndex];
        g_rgiAssetCacheId[iNestedAssetId] = Asset_PrecacheResource(iNestedAssetId);
        g_rgbAssetPrecached[iNestedAssetId] = true;
      }

      g_rgiAssetCacheId[iAssetId] = 0;
    } else {
      g_rgiAssetCacheId[iAssetId] = Asset_PrecacheResource(iAssetId);
    }

    LOG_INFO("Precached asset ^"%s^" in library ^"%s^".", szAsset, szId);

    g_rgbAssetPrecached[iAssetId] = true;
  }

  return iAssetId;
}

/*--------------------------------[ Asset Methods ]--------------------------------*/

Asset_Create(const szId[], &JSON:jsonAsset, Asset_Type:iType = Asset_Type_Invalid) {
  if (g_iAssetsNum >= ASSETS_MAX_ASSETS) {
    LOG_ERROR("Maximum number of assets reached (%d).", ASSETS_MAX_ASSETS);
    return -1;
  }

  if (iType == Asset_Type_Invalid) {
    // Loading typed object
    if (json_get_type(jsonAsset) == JSONObject && json_object_has_value(jsonAsset, VALUE_KEY)) {
      if (json_object_has_value(jsonAsset, TYPE_KEY)) {
        new szType[32]; json_object_get_string(jsonAsset, TYPE_KEY, szType, charsmax(szType));
        iType = GetAssetTypeByTypeKey(szType);
      }

      new JSON:jsonValue = json_object_get_value(jsonAsset, VALUE_KEY);

      new iId = Asset_Create(szId, jsonValue, iType);

      json_free(jsonValue);

      return iId;
    }

    iType = ResolveAssetTypeByJsonValue(jsonAsset);
  }

  if (iType == Asset_Type_Invalid) return -1;

  new iId = g_iAssetsNum;
  copy(g_rgszAssetId[iId], charsmax(g_rgszAssetId[]), szId);

  g_rgiAssetType[iId] = iType;
  g_rgiAssetCacheId[iId] = 0;
  g_rgbAssetPrecached[iId] = iType == Asset_Type_Variable;

  g_iAssetsNum++;

  switch (iType) {
    case Asset_Type_Variable: {
      if (!ReadVariableValueFromJson(jsonAsset, g_rgrgAssetValue[iId])) {
        LOG_ERROR("Failed to read variable value for asset ^"%s^".", szId);
        return -1;
      }
    }
    case Asset_Type_Array: {
      new iArraySize = json_array_get_count(jsonAsset);

      g_rgrgAssetValue[iId][0] = iArraySize;

      for (new i = 0; i < iArraySize; i++) {
        new JSON:jsonNestedAsset = json_array_get_value(jsonAsset, i);
        new iNestedAssetId = Asset_Create(szId, jsonNestedAsset);
        json_free(jsonNestedAsset);

        if (iNestedAssetId == -1) {
          LOG_ERROR("Asset ^"%s^" at index %d has invalid value!", szId, i);
          continue;
        }

        if (g_rgiAssetType[iNestedAssetId] == Asset_Type_Array) {
          // Flatten nested array
          for (new j = 0; j < g_rgrgAssetValue[iNestedAssetId][0]; j++) {
            g_rgrgAssetValue[iId][i + 1 + j] = g_rgrgAssetValue[iNestedAssetId][j + 1];
          }

          // Invalidate nested asset
          g_rgiAssetType[iNestedAssetId] = Asset_Type_Invalid;
        } else {
          g_rgrgAssetValue[iId][i + 1] = iNestedAssetId;
        }
      }
    }
    case Asset_Type_Sound: {
      g_rgrgAssetValue[iId][0] = 0.0;
      json_get_string(jsonAsset, g_rgrgAssetValue[iId][1], charsmax(g_rgrgAssetValue[]) - 1);
    }
    default: {
      json_get_string(jsonAsset, g_rgrgAssetValue[iId], charsmax(g_rgrgAssetValue[]));
    }
  }

  return iId;
}

Asset_PrecacheResource(const iId) {
  switch (g_rgiAssetType[iId]) {
    case Asset_Type_Generic: {
      if (equal(g_rgrgAssetValue[iId], NULL_STRING)) return 0;

      if (!file_exists(g_rgrgAssetValue[iId], true)) {
        LOG_ERROR("Generic asset ^"%s^" does not exist.", g_rgrgAssetValue[iId]);
        copy(g_rgrgAssetValue[iId], charsmax(g_rgrgAssetValue[]), NULL_STRING);
        return 0;
      }

      return precache_generic(g_rgrgAssetValue[iId]);
    }
    case Asset_Type_Model: {
      if (equal(g_rgrgAssetValue[iId], NULL_STRING)) return 0;

      if (!file_exists(g_rgrgAssetValue[iId], true)) {
        LOG_ERROR("Model ^"%s^" does not exist, using error model.", g_rgrgAssetValue[iId]);
        copy(g_rgrgAssetValue[iId], charsmax(g_rgrgAssetValue[]), g_szErrorModel);
        return precache_model(g_szErrorModel);
      }

      return precache_model(g_rgrgAssetValue[iId]);
    }
    case Asset_Type_Sound: {
      if (equal(g_rgrgAssetValue[iId][1], NULL_STRING)) return 0;

      new szPath[MAX_RESOURCE_PATH_LENGTH]; format(szPath, charsmax(szPath), "sound/%s", g_rgrgAssetValue[iId][1]);

      if (!file_exists(szPath, true)) {
        LOG_ERROR("Sound ^"%s^" does not exist, using error sound.", g_rgrgAssetValue[iId][1]);
        copy(g_rgrgAssetValue[iId][1], charsmax(g_rgrgAssetValue[]) - 1, g_szErrorSound);
        return precache_sound(g_szErrorSound);
      }

      g_rgrgAssetValue[iId][0] = GetWavDuration(g_rgrgAssetValue[iId][1]);

      return precache_sound(g_rgrgAssetValue[iId][1]);
    }
  }

  return 0;
}

/*--------------------------------[ Resolvers ]--------------------------------*/

Asset_Type:ResolveAssetTypeByJsonValue(const &JSON:jsonValue) {
  switch (json_get_type(jsonValue)) {
    case JSONString: {
      new szValue[ASSET_MAX_DATA_SIZE]; json_get_string(jsonValue, szValue, charsmax(szValue));

      new iLen = UTIL_GetPathLength(szValue);

      if (iLen > 4) {
        if (equali(szValue[iLen - 4], ".mdl", 4)) return Asset_Type_Model;
        if (equali(szValue[iLen - 4], ".spr", 4)) return Asset_Type_Model;
        if (equali(szValue[iLen - 4], ".wav", 4)) return Asset_Type_Sound;

        return Asset_Type_Generic;
      }
    }
    case JSONArray: {
      if (ResolveVariableType(jsonValue) != Asset_Variable_Type_Invalid) return Asset_Type_Variable;

      return Asset_Type_Array;
    }
  }

  if (ResolveVariableType(jsonValue) != Asset_Variable_Type_Invalid) return Asset_Type_Variable;

  return Asset_Type_Invalid; 
}

Asset_Type:GetAssetTypeByTypeKey(const szType[]) {
  if (equal(szType, "generic")) {
    return Asset_Type_Generic;
  } else if (equal(szType, "model")) {
    return Asset_Type_Model;
  } else if (equal(szType, "sound")) {
    return Asset_Type_Sound;
  } else if (equal(szType, "variable")) {
    return Asset_Type_Variable;
  }

  return Asset_Type_Invalid;
}

ReadVariableValueFromJson(const &JSON:jsonValue, any:rgData[]) {
  new Asset_Variable_Type:iVariableType = ResolveVariableType(jsonValue);

  if (iVariableType == Asset_Variable_Type_Invalid) return false;

  rgData[0] = iVariableType;

  switch (iVariableType) {
    case Asset_Variable_Type_String: {
      json_get_string(jsonValue, rgData[1], charsmax(g_rgrgAssetValue[]) - 1);
    }
    case Asset_Variable_Type_Integer: {
      rgData[1] = json_get_number(jsonValue);
    }
    case Asset_Variable_Type_Float: {
      rgData[1] = json_get_real(jsonValue);
    }
    case Asset_Variable_Type_Bool: {
      rgData[1] = json_get_bool(jsonValue);
    }
    case Asset_Variable_Type_Vector: {
      switch (json_get_type(jsonValue)) {
        case JSONArray: {
          rgData[1] = json_array_get_real(jsonValue, 0);
          rgData[2] = json_array_get_real(jsonValue, 1);
          rgData[3] = json_array_get_real(jsonValue, 2);
        }
        case JSONObject: {
          rgData[1] = json_object_get_real(jsonValue, "x");
          rgData[2] = json_object_get_real(jsonValue, "y");
          rgData[3] = json_object_get_real(jsonValue, "z");
        }
        default: {
          return false;
        }
      }
    }
    default: {
      return false;
    }
  }

  return true;
}

Asset_Variable_Type:ResolveVariableType(const &JSON:jsonValue) {
  new JSONType:iType = json_get_type(jsonValue);

  switch (iType) {
    case JSONString: {
      return Asset_Variable_Type_String;
    }
    case JSONNumber: {
      new Float:flValue; flValue = json_get_real(jsonValue);
      new iValue; iValue = json_get_number(jsonValue);

      return float(iValue) == flValue ? Asset_Variable_Type_Integer : Asset_Variable_Type_Float;
    }
    case JSONBoolean: {
      return Asset_Variable_Type_Bool;
    }
    case JSONObject: {
      if (
        json_object_get_count(jsonValue) == 3 &&
        json_object_has_value(jsonValue, "x") &&
        json_object_has_value(jsonValue, "y") &&
        json_object_has_value(jsonValue, "z")
      ) {
        return Asset_Variable_Type_Vector;
      }
    }
    case JSONArray: {
      if (
        json_array_get_count(jsonValue) == 3 &&
        json_array_get_type(jsonValue, 0) == JSONNumber &&
        json_array_get_type(jsonValue, 1) == JSONNumber &&
        json_array_get_type(jsonValue, 2) == JSONNumber
      ) {
        return Asset_Variable_Type_Vector;
      }
    }
  }

  return Asset_Variable_Type_Invalid;
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_GetPathLength(const szPath[]) {
  new iLen = 0;

  // Check if the path is valid
  for (iLen = 0; szPath[iLen] != 0; iLen++) {
    if (isalnum(szPath[iLen])) continue;
    if (szPath[iLen] == '_') continue;
    if (szPath[iLen] == '-') continue;
    if (szPath[iLen] == '.') continue;
    if (szPath[iLen] == '/' && iLen > 0 && szPath[iLen - 1] != '/') continue;
    if (szPath[iLen] == '\' && iLen > 0 && szPath[iLen - 1] != '\') continue;

    return 0;
  }

  return iLen;
}

stock JSONType:json_array_get_type(const JSON:array, index) {
  new JSON:value = json_array_get_value(array, index);

  new JSONType:type = json_get_type(value);

  json_free(value);

  return type;
}

// By Arkshine
stock Float:GetWavDuration(const WavFile[]) {
  new Frequence[4];
  new Bitrate[2];
  new DataLength[4];

  new File = fopen(fmt("sound/%s", WavFile), "rb", true);
  if (!File) return 0.0;

  // Get the frequence from offset 24
  fseek(File, 24, SEEK_SET);
  fread_blocks(File, Frequence, 4, BLOCK_INT);
  
  // Get the bitrate from offset 34
  fseek(File, 34, SEEK_SET); 
  fread_blocks(File, Bitrate, 2, BLOCK_BYTE);
  
  // Search 'data'. If the 'd' not on the offset 40, we search it
  if (fgetc(File) != 'd') while(fgetc(File) != 'd' && !feof(File)) {}
  
  // Get the data length from offset 44
  fseek(File, 3, SEEK_CUR); 
  fread_blocks(File, DataLength, 4, BLOCK_INT);

  fclose(File);

  return float(DataLength[0]) / (float(Frequence[0] * Bitrate[0]) / 8.0);
}
