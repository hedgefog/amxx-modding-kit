#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#tryinclude <reapi>

#if !defined _reapi_included
  #tryinclude <orpheu>
  #if defined _orpheu_included
    ;
  #endif
#endif

#include <function_pointer>
#include <stack>
#include <combat_util>
#include <shared_random>
#include <callfunc>
#include <varargs>

#pragma semicolon 1

#define MAX_ENTITIES 2112

#define CLASS_CACHE_SIZE 128
#define CLASS_METHODS_CACHE_SIZE 64
#define CLASS_INSTANCE_CACHE_SIZE MAX_ENTITIES

#include <cellclass>

#include <api_custom_weapons_const>

#if !defined BIT
  #define BIT(%0) (1<<(%0))
#endif

#define method<%1::%2> any:@%1_%2
#define METHOD(%1) CW_Method_%1
#define MEMBER(%1) CW_Member_%1
#define INTERNAL_MEMBER(%1) InternalMember_%1
#define CALL_METHOD<%1>(%2,%0) ExecuteMethod(METHOD(%1), %2, _, _, %0)
#define AMMO_HOOK(%1) CW_AmmoHook_%1
#define EXECUTE_AMMO_HOOK<%1>(%2,%3,%0) ExecuteAmmoHook(AMMO_HOOK(%1), %2, %3, %0)
#define EXECUTE_AMMO_PREHOOK<%1>(%2,%0) EXECUTE_AMMO_HOOK<%1>(%2, false, %0)
#define EXECUTE_AMMO_POSTHOOK<%1>(%2,%0) EXECUTE_AMMO_HOOK<%1>(%2, true, %0)
#define ARG_STRREF(%1) %1, charsmax(%1)
#define IS_NULLSTR(%1) (%1[0] == 0)

#define GET_INSTANCE(%1) (%1 <= MAX_ENTITIES ? g_rgEntityClassInstances[%1] : Invalid_ClassInstance)
#define GET_ID(%1) (%1 <= MAX_ENTITIES ? g_rgEntityIds[%1] : CW_INVALID_ID)
#define IS_CUSTOM(%1) (GET_INSTANCE(%1) != Invalid_ClassInstance)

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define LOG_PREFIX "[CW]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define ERROR_IS_ALREADY_REGISTERED "Weapon with class ^"%s^" is already registered."
#define ERROR_IS_NOT_REGISTERED "Weapon ^"%s^" is not registered."
#define ERROR_FUNCTION_NOT_FOUND "Function ^"%s^" not found in plugin ^"%s^"."
#define ERROR_IS_NOT_REGISTERED_BASE "Cannot extend weapon class ^"%s^". The class is not exists!"
#define ERROR_CANNOT_CREATE_UNREGISTERED "Failed to create weapon ^"%s^"! weapon is not registered!"
#define ERROR_CANNOT_CREATE_ABSTRACT "Failed to create weapon ^"%s^"! weapon is abstract!"
#define ERROR_AMMO_IS_ALREADY_REGISTERED "Failed to register ammo ^"%s^"! Ammo is already registered."
#define ERROR_AMMO_IS_NOT_REGISTERED "Ammo ^"%s^" is not registered."
#define ERROR_CANNOT_FORK_WITH_NON_RELATED_CLASS "Cannot fork weapon class ^"%s^" with non-related parent class ^"%s^"!"

#define CLASS_METADATA_NAME "__NAME"
#define CLASS_METADATA_ID "__CW_ID"

#define CW_INVALID_ID -1
#define CW_INVALID_HOOK_ID -1
#define InternalMember_iPrimaryAmmoId "__iPrimaryAmmoId"
#define InternalMember_iSecondaryAmmoId "__iSecondaryAmmoId"

#define MAX_ENTITY_CLASSES 128
#define MAX_AMMO_TYPES 32
#define MAX_AMMO_GROUPS 16
#define MAX_PLAYER_ITEMS 100
#define MAX_AMMO_HOOKS 32

#define BASE_WEAPON_ID 1
#define WEAPON_NOCLIP -1
#define DEFAULT_FOV 90
#define WPNSTATE_SHIELD_DRAWN (1<<5)
#define VEC_DUCK_HULL_MIN Float:{-16.0, -16.0, -18.0}
#define VEC_DUCK_HULL_MAX Float:{16.0, 16.0, 18.0}
#define LOUD_GUN_VOLUME 1000
#define NORMAL_GUN_FLASH 256
#define MAX_CUSTOM_AMMO_ID_LENGTH 32
#define MAX_WEAPON_SLOTS 6
#define MAX_AMMO_SLOTS 32

enum ClassFlag (<<=1) {
  ClassFlag_None = 0,
  ClassFlag_Abstract = (1<<0)
};

enum (<<=1) {
  ITEM_FLAG_NOFIREUNDERWATER = (1<<5),
  ITEM_FLAG_EXHAUST_SECONDARYAMMO
};

enum Ammo {
  Ammo_Id,
  Ammo_Type,
  Ammo_MaxAmount,
  Trie:Ammo_Metadata,
  Array:Ammo_PreHooks[CW_AmmoHook],
  Array:Ammo_PostHooks[CW_AmmoHook],
  Ammo_Name[CW_MAX_AMMO_NAME_LENGTH]
};

#define MAX_METHOD_HOOKS 64

enum EntityMethodPointer {
  EntityMethodPointer_Think,
  EntityMethodPointer_Touch
};

enum MethodParams { MethodParams_Num, ClassDataType:MethodParams_Types[10] };

STACK_DEFINE(METHOD_PLUGIN, 256);
STACK_DEFINE(METHOD_RETURN, 256);
STACK_DEFINE(METHOD_HOOKS_Pre, 256);
STACK_DEFINE(METHOD_HOOKS_Post, 256);
STACK_DEFINE(AMMO_HOOKS, 256);

/*
  Used as a prefix for custom ammo ID.
  Because we can't get real ammo ID by ammo type index,
  we use custom ammo ID to support ammo packing and extraction from WeaponBox.
*/
new const CUSTOM_AMMO_PREFIX[] = "cw#";

new gmsgWeaponList;
new gmsgDeathMsg;

new g_rgDecals[256];
new g_rgiBreakDecals[3];

new g_iMaxEntities = 0;
new g_iszBaseClassName = 0;
new g_pTrace = -1;
new bool:g_bIsCStrike = false;
new bool:g_bPrecache = false;
new bool:g_bIsMultiplayer = true;
new Float:g_flGameTime = 0.0;

new g_szBaseWeaponName[32];

new Trie:g_itEntityIds = Invalid_Trie;

new g_rgMethodParams[CW_Method][MethodParams];
new g_rgszMethodNames[CW_Method][CW_MAX_METHOD_NAME_LENGTH];

new g_rgiClassIds[MAX_ENTITY_CLASSES];
new Class:g_rgcClasses[MAX_ENTITY_CLASSES];
new ClassFlag:g_rgiClassFlags[MAX_ENTITY_CLASSES];
new Function:g_rgrgrgfnClassMethodPreHooks[MAX_ENTITY_CLASSES][CW_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPreHooksNum[MAX_ENTITY_CLASSES][CW_Method];
new Function:g_rgrgrgfnClassMethodPostHooks[MAX_ENTITY_CLASSES][CW_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPostHooksNum[MAX_ENTITY_CLASSES][CW_Method];
new g_rgszClassClassnames[MAX_ENTITY_CLASSES][CW_MAX_NAME_LENGTH];
new g_iClassesNum = 0;

new Trie:g_itAmmoIds = Invalid_Trie;
new g_rgAmmos[MAX_AMMO_TYPES][Ammo];
new g_iAmmosNum = 0;

// new bool:g_rgbHookRegistered[MAX_PLAYER_ITEMS] = { false, ... };
new ClassInstance:g_rgEntityClassInstances[MAX_ENTITIES + 1] = { Invalid_ClassInstance, ... };
new Struct:g_rgEntityMethodPointers[MAX_ENTITIES + 1][EntityMethodPointer];

new bool:g_rgbPlayerShouldFixDeploy[MAX_PLAYERS + 1];
new bool:g_rgbPlayerRightHand[MAX_PLAYERS + 1];

new g_rgEntityIds[MAX_ENTITIES + 1];

new g_rgAmmoGroupTypes[MAX_AMMO_GROUPS][MAX_AMMO_SLOTS];
new g_rgAmmoGroupAmmos[MAX_AMMO_GROUPS][MAX_AMMO_TYPES];
new g_rgAmmoGroupAmmosNum[MAX_AMMO_GROUPS];
new g_rgAmmoGroupsNum = 0;

new Trie:g_itCustomMaterials = Invalid_Trie;
new Trie:g_itAmmoGroups = Invalid_Trie;

new g_iGiveAmmoResult;

new g_iPlayerHasCustomWeaponBits = 0;

new g_pfwfmUpdateClientDataPost = 0;
new HamHook:g_pfwhamPlayerPostThinkPost = HamHook:0;
// new HamHook:g_pfwhamItemPreFrame = HamHook:0;
new HamHook:g_pfwhamItemPostFrame = HamHook:0;
new HamHook:g_pfwhamItemUpdateClientData = HamHook:0;

new bool:g_bDynamicHooksEnabled = false;

/*--------------------------------[ Plugin Forwards ]--------------------------------*/

public plugin_precache() {
  g_bPrecache = true;
  g_bIsCStrike = !!cstrike_running();
  g_iMaxEntities = min(global_get(glb_maxEntities), MAX_ENTITIES);

  register_forward(FM_SetModel, "FMHook_SetModel", 0);
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData", 0);
  register_forward(FM_DecalIndex, "FMHook_DecalIndex_Post", 1);

  InitStorages();
  InitBaseClasses();

  precache_model("sprites/bubble.spr");
  precache_sound("weapons/scock1.wav");
}

public plugin_init() {
  g_bPrecache = false;

  register_plugin("[API] Custom Player Weapons", "Hedgehog Fog", "2.0.0");

  get_weaponname(BASE_WEAPON_ID, ARG_STRREF(g_szBaseWeaponName));
  g_iszBaseClassName = engfunc(EngFunc_AllocString, g_szBaseWeaponName);

  gmsgWeaponList = get_user_msgid("WeaponList");
  gmsgDeathMsg = get_user_msgid("DeathMsg");

  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
  RegisterHamPlayer(Ham_GiveAmmo, "HamHook_Player_GiveAmmo", .Post = 0);
  RegisterHamPlayer(Ham_GiveAmmo, "HamHook_Player_GiveAmmo_Post", .Post = 1);

  if (g_bIsCStrike) {
    RegisterHam(Ham_Item_Holster, "weapon_knife", "HamHook_Knife_Holster", .Post = 0);
  }

  register_message(gmsgDeathMsg, "Message_DeathMsg");

  register_concmd("cw_give", "Command_Give", ADMIN_CVAR);

  InitBreakDecals();
}

public plugin_cfg() {
  RegisterWeaponHooks();
}

public plugin_natives() {
  register_library("api_custom_weapons");

  register_native("CW_RegisterClass", "Native_Register");
  register_native("CW_ForkClass", "Native_ForkClass");
  register_native("CW_RegisterClassAlias", "Native_RegisterAlias");
  register_native("CW_IsClassRegistered", "Native_IsClassRegistered");
  register_native("CW_GetClassHandle", "Native_GetClassHandle");

  register_native("CW_RegisterClassMethod", "Native_RegisterMethod");
  register_native("CW_ImplementClassMethod", "Native_ImplementMethod");
  register_native("CW_RegisterClassVirtualMethod", "Native_RegisterVirtualMethod");

  register_native("CW_RegisterClassMethodHook", "Native_RegisterMethodHook");
  register_native("CW_GetMethodReturn", "Native_GetMethodReturn");
  register_native("CW_SetMethodReturn", "Native_SetMethodReturn");

  register_native("CW_Create", "Native_Create");
  register_native("CW_GetHandle", "Native_GetHandle");
  register_native("CW_IsInstanceOf", "Native_IsInstanceOf");

  register_native("CW_SetThink", "Native_SetThink");
  register_native("CW_SetTouch", "Native_SetTouch");

  register_native("CW_HasMember", "Native_HasMember");
  register_native("CW_GetMember", "Native_GetMember");
  register_native("CW_DeleteMember", "Native_DeleteMember");
  register_native("CW_SetMember", "Native_SetMember");
  register_native("CW_GetMemberVec", "Native_GetMemberVec");
  register_native("CW_SetMemberVec", "Native_SetMemberVec");
  register_native("CW_GetMemberString", "Native_GetMemberString");
  register_native("CW_SetMemberString", "Native_SetMemberString");

  register_native("CW_CallMethod", "Native_CallMethod");
  register_native("CW_CallBaseMethod", "Native_CallBaseMethod");
  register_native("CW_CallNativeMethod", "Native_CallNativeMethod");
  register_native("CW_GetCallerPlugin", "Native_GetCallPluginId");

  register_native("CW_Give", "Native_GiveWeapon");
  register_native("CW_GiveAmmo", "Native_GiveAmmo");

  register_native("CW_PlayerHasWeapon", "Native_PlayerHasWeapon");
  register_native("CW_PlayerFindWeapon", "Native_PlayerFindWeapon");
  register_native("CW_Ammo_Register", "Native_RegisterAmmo");
  register_native("CW_Ammo_IsRegistered", "Native_IsAmmoRegistered");
  register_native("CW_Ammo_GetType", "Native_GetAmmoType");
  register_native("CW_Ammo_GetMaxAmount", "Native_GetMaxAmmount");
  register_native("CW_Ammo_RegisterHook", "Native_AddAmmoHook");
  register_native("CW_Ammo_HasMetadata", "Native_HasAmmoMetadata");
  register_native("CW_Ammo_DeleteMetadata", "Native_DeleteAmmoMetadata");
  register_native("CW_Ammo_SetMetadata", "Native_SetAmmoMetadata");
  register_native("CW_Ammo_GetMetadata", "Native_GetAmmoMetadata");
  register_native("CW_Ammo_GetMetadataString", "Native_GetAmmoMetadataString");
  register_native("CW_Ammo_SetMetadataString", "Native_SetAmmoMetadataString");
  register_native("CW_Ammo_GetMetadataVector", "Native_GetAmmoMetadataVector");
  register_native("CW_Ammo_SetMetadataVector", "Native_SetAmmoMetadataVector");

  register_native("CW_AmmoGroup_GetSize", "Native_GetAmmoGroupSize");
  register_native("CW_AmmoGroup_GetAmmoId", "Native_GetAmmoGroupAmmo");
  register_native("CW_AmmoGroup_GetAmmoType", "Native_GetAmmoGroupAmmoType");
  register_native("CW_AmmoGroup_GetAmmoByType", "Native_GetAmmoGroupAmmoByType");

  register_native("CW_SetPlayerAnimation", "Native_SetPlayerAnimation");
  register_native("CW_LoadCustomMaterials", "Native_LoadCustomMaterials");
}

public plugin_end() {
  FreeEntities();
  DestroyRegisteredClasses();
  DestroyRegisteredAmmos();
  DestroyStorages();
}

public server_frame() {
  g_flGameTime = get_gametime();
}

/*--------------------------------[ Weapon Natives ]--------------------------------*/

public Native_Register(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szBaseClassName[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szBaseClassName));
  new bool:bAbstract = bool:get_param(3);

  new ClassFlag:iFlags = bAbstract ? ClassFlag_Abstract : ClassFlag_None;

  if (IS_NULLSTR(szBaseClassName)) {
    copy(ARG_STRREF(szBaseClassName), CW_Class_Base);
  }

  return RegisterClass(szClassname, szBaseClassName, iFlags);
}

public Native_ForkClass(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szOriginalClassName[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szOriginalClassName));
  new szBaseClassName[CW_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szBaseClassName));

  if (GetIdByClassName(szClassname) != CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_ALREADY_REGISTERED, szClassname);
    return CW_INVALID_ID;
  }

  if (GetIdByClassName(szOriginalClassName) == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szOriginalClassName);
    return CW_INVALID_ID;
  }

  if (!equal(szBaseClassName, NULL_STRING) && GetIdByClassName(szBaseClassName) == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED_BASE, szBaseClassName);
    return CW_INVALID_ID;
  }

  return ForkClass(szClassname, szOriginalClassName, szBaseClassName);
}

public Native_RegisterAlias(const iPluginId, const iArgc) {
  new szAlias[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szAlias));
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));

  if (GetIdByClassName(szAlias) != CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_ALREADY_REGISTERED, szAlias);
    return;
  }

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  TrieSetCell(g_itEntityIds, szAlias, iId);
}

public bool:Native_IsClassRegistered(const iPluginId, const iArgc) {
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  return GetIdByClassName(szClassname) != CW_INVALID_ID;
}

public Native_RegisterMethodHook(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new CW_Method:iMethod = CW_Method:get_param(2);
  new szCallback[CW_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));
  new bool:bPost = bool:get_param(4);

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, ARG_STRREF(szFilename));
    LOG_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  RegisterClassMethodHook(iId, iMethod, fnCallback, bool:bPost);
}

public Native_RegisterMethod(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szMethod[CW_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  new szCallback[CW_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, ARG_STRREF(szFilename));
    LOG_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodRegistrationParamsFromNativeCall(4, iArgc);
  AddClassMethod(iId, szMethod, fnCallback, irgParamsTypes, false);
  ArrayDestroy(irgParamsTypes);
}

public Native_RegisterVirtualMethod(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szMethod[CW_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  new szCallback[CW_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, ARG_STRREF(szFilename));
    LOG_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodRegistrationParamsFromNativeCall(4, iArgc);
  AddClassMethod(iId, szMethod, fnCallback, irgParamsTypes, true);
  ArrayDestroy(irgParamsTypes);
}

public Native_ImplementMethod(const iPluginId, const iArgc) {
  new szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new CW_Method:iMethod = CW_Method:get_param(2);
  new szCallback[CW_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, ARG_STRREF(szFilename));
    LOG_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  ImplementClassMethod(iId, iMethod, fnCallback);
}

public Native_Create(const iPluginId, const iArgc) {
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_CANNOT_CREATE_UNREGISTERED, szClassname);
    return FM_NULLENT;
  }

  new pEntity = CreateEntity(iId);
  if (pEntity == FM_NULLENT) return FM_NULLENT;

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  ClassInstanceSetMember(pInstance, MEMBER(PluginId), iPluginId);

  return pEntity;
}

public bool:Native_GiveWeapon(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));
  static bool:bDropOther; bDropOther = bool:get_param(3);

  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return false;
  }

  return GiveWeapon(pPlayer, iId, bDropOther);
}

public Native_GiveAmmo(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(2, ARG_STRREF(szName));
  static iAmount; iAmount = get_param(3); 

  new iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  return GiveAmmo(pPlayer, iId, iAmount);
}

public Native_PlayerFindWeapon(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));

  static iId; iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return FM_NULLENT;
  }

  return FindPlayerCustomWeapon(pPlayer, iId);
}

public bool:Native_PlayerHasWeapon(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));

  static iId; iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return false;
  }

  return FindPlayerCustomWeapon(pPlayer, iId) != FM_NULLENT;
}

public Native_GetClassHandle(const iPluginId, const iArgc) {
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  return GetIdByClassName(szClassname);
}

public Native_GetHandle(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  return GET_ID(pEntity);
}

public bool:Native_IsInstanceOf(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szClassname[CW_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));
  static iTargetId; iTargetId = GetIdByClassName(szClassname);
  if (iTargetId == CW_INVALID_ID) return false;

  return ClassInstanceIsInstanceOf(pInstance, g_rgcClasses[iTargetId]);
}

public bool:Native_HasMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return 0;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceGetMember(pInstance, szMember);
}

public bool:Native_DeleteMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceDeleteMember(pInstance, szMember);
}

public bool:Native_SetMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static iValue; iValue = get_param(3);
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public bool:Native_GetMemberVec(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public bool:Native_SetMemberVec(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public bool:Native_GetMemberString(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, ARG_STRREF(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public bool:Native_SetMemberString(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CW_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static szValue[128]; get_string(3, ARG_STRREF(szValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public any:Native_CallMethod(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return 0;

  static szMethod[CW_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  /*
    When executing hooks, we need to force the correct class context
    since hooks are called from base class methods but may need to call
    derived class methods. This prevents the call stack from incorrectly
    resolving method calls to the base class implementation.
  */
  static Class:class; class = Invalid_Class;
  if (!STACK_EMPTY(METHOD_HOOKS_Pre) || !STACK_EMPTY(METHOD_HOOKS_Post) || !STACK_EMPTY(AMMO_HOOKS)) {
    class = ClassInstanceGetClass(pInstance);
  }

  ClassInstanceCallMethodBegin(pInstance, szMethod, class);
  ClassInstanceCallMethodPushParamCell(pEntity);
  static any:result; result = ClassInstanceCallMethodWithNativeParams(3, iArgc - 2);

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public any:Native_CallBaseMethod(const iPluginId, const iArgc) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static pEntity; pEntity = ClassInstanceGetMember(pInstance, MEMBER(Pointer));

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallBaseMethodBegin();
  ClassInstanceCallMethodPushParamCell(pEntity);
  static any:result; result = ClassInstanceCallMethodWithNativeParams(1, iArgc);

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public any:Native_CallNativeMethod(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static CW_Method:iMethod; iMethod = CW_Method:get_param(2);

  if (!IS_CUSTOM(pEntity)) return 0;

  return ExecuteMethod(iMethod, pEntity, 3, iArgc);
}

public Native_GetCallPluginId(const iPluginId, const iArgc) {
  return STACK_READ(METHOD_PLUGIN);
}

public Native_SetThink(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CW_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Think, szMethod, szClassname);
}

public Native_SetTouch(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CW_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CW_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Touch, szMethod, szClassname);
}

public any:Native_GetMethodReturn(const iPluginId, const iArgc) {
  return STACK_READ(METHOD_RETURN);
}

public any:Native_SetMethodReturn(const iPluginId, const iArgc) {
  STACK_PATCH(METHOD_RETURN, any:get_param(1));
}

public Native_SetPlayerAnimation(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new PLAYER_ANIM:iPlayerAnim = PLAYER_ANIM:get_param(2);

  SetAnimation(pPlayer, iPlayerAnim);
}

public Native_LoadCustomMaterials(const iPluginId, const iArgc) {
  new szPath[MAX_RESOURCE_PATH_LENGTH]; get_string(1, ARG_STRREF(szPath));

  LoadCustomMaterials(szPath);
}

/*--------------------------------[ Ammo Natives ]--------------------------------*/

public Native_RegisterAmmo(const iPluginId, const iArgc) {
  new szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  new iAmmoType = get_param(2);
  new iMaxAmount = get_param(3);
  new szGroup[CW_MAX_AMMO_GROUP_NAME_LENGTH]; get_string(4, ARG_STRREF(szGroup));

  if (IsCustomAmmoRegistered(szName)) {
    LOG_ERROR(ERROR_AMMO_IS_ALREADY_REGISTERED, szName);
    return;
  }

  RegisterCustomAmmo(szName, iAmmoType, iMaxAmount, szGroup);
}

public Native_AddAmmoHook(const iPluginId, const iArgc) {
  new szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  new CW_AmmoHook:iHook = CW_AmmoHook:get_param(2);
  new szCallback[CW_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));
  new bool:bPost = bool:get_param(4);

  new iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);  
  if (fnCallback == Invalid_FunctionPointer) {
    LOG_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, szName);
    return;
  }

  AddAmmoHook(iId, iHook, fnCallback, bPost);
}

public Native_IsAmmoRegistered(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  
  return IsCustomAmmoRegistered(szName);
}

public Native_GetAmmoType(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  
  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) return -1;
  
  return g_rgAmmos[iId][Ammo_Type];
}

public Native_GetMaxAmmount(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  
  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) return -1;
  
  return g_rgAmmos[iId][Ammo_MaxAmount];
}

public bool:Native_HasAmmoMetadata(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  return TrieKeyExists(g_rgAmmos[iId][Ammo_Metadata], szKey);
}

public bool:Native_DeleteAmmoMetadata(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  return TrieDeleteKey(g_rgAmmos[iId][Ammo_Metadata], szKey);
}

public any:Native_GetAmmoMetadata(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return 0;
  }

  static any:value;
  if (!TrieGetCell(g_rgAmmos[iId][Ammo_Metadata], szKey, value)) return 0;

  return value;
}

public Native_SetAmmoMetadata(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));
  static bool:bReplace; bReplace = bool:get_param(3);

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  return TrieSetCell(g_rgAmmos[iId][Ammo_Metadata], szKey, any:get_param(3), bReplace);
}

public bool:Native_GetAmmoMetadataString(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  static szValue[128];
  if (!TrieGetString(g_rgAmmos[iId][Ammo_Metadata], szKey, ARG_STRREF(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public bool:Native_SetAmmoMetadataString(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));
  static szValue[128]; get_string(3, ARG_STRREF(szValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }
  
  return !!TrieSetString(g_rgAmmos[iId][Ammo_Metadata], szKey, szValue, bReplace);
}

public bool:Native_GetAmmoMetadataVector(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }
  
  static Float:vecValue[3];
  if (!TrieGetArray(g_rgAmmos[iId][Ammo_Metadata], szKey, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public bool:Native_SetAmmoMetadataVector(const iPluginId, const iArgc) {
  static szName[CW_MAX_AMMO_NAME_LENGTH]; get_string(1, ARG_STRREF(szName));
  static szKey[CW_MAX_AMMO_METADATA_KEY_LENGTH]; get_string(2, ARG_STRREF(szKey));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  static iId; iId = GetCustomAmmoId(szName);
  if (iId == -1) {
    LOG_ERROR(ERROR_AMMO_IS_NOT_REGISTERED, szName);
    return false;
  }

  return !!TrieSetArray(g_rgAmmos[iId][Ammo_Metadata], szKey, vecValue, 3, bReplace);
}

/*--------------------------------[ Ammo Group Natives ]--------------------------------*/

public Native_GetAmmoGroupSize(const iPluginId, const iArgc) {
  static szGroup[CW_MAX_AMMO_GROUP_NAME_LENGTH]; get_string(1, ARG_STRREF(szGroup));

  static iId; iId = AmmoGroup_GetId(szGroup);
  if (iId == -1) return 0;

  return g_rgAmmoGroupAmmosNum[iId];
}

public bool:Native_GetAmmoGroupAmmo(const iPluginId, const iArgc) {
  static szGroup[CW_MAX_AMMO_GROUP_NAME_LENGTH]; get_string(1, ARG_STRREF(szGroup));
  static iIndex; iIndex = get_param(2);

  static iId; iId = AmmoGroup_GetId(szGroup);
  if (iId == -1) return false;

  if (iIndex < 0 || iIndex >= g_rgAmmoGroupAmmosNum[iId]) return false;

  static iAmmoId; iAmmoId = g_rgAmmoGroupAmmos[iId][iIndex];
  
  set_string(3, g_rgAmmos[iAmmoId][Ammo_Name], get_param(4));

  return true;
}

public Native_GetAmmoGroupAmmoType(const iPluginId, const iArgc) {
  static szGroup[CW_MAX_AMMO_GROUP_NAME_LENGTH]; get_string(1, ARG_STRREF(szGroup));
  static iIndex; iIndex = get_param(2);

  static iId; iId = AmmoGroup_GetId(szGroup);
  if (iId == -1) return -1;

  if (iIndex < 0 || iIndex >= g_rgAmmoGroupAmmosNum[iId]) return -1;

  static iAmmoId; iAmmoId = g_rgAmmoGroupAmmos[iId][iIndex];

  return g_rgAmmos[iAmmoId][Ammo_Type];
}

public Native_GetAmmoGroupAmmoByType(const iPluginId, const iArgc) {
  static szGroup[CW_MAX_AMMO_GROUP_NAME_LENGTH]; get_string(1, ARG_STRREF(szGroup));
  static iAmmoType; iAmmoType = get_param(2);

  static iAmmoId; iAmmoId = AmmoGroup_GetAmmoByType(szGroup, iAmmoType);
  if (iAmmoId == -1) return -1;

  set_string(3, g_rgAmmos[iAmmoId][Ammo_Name], get_param(4));

  return iAmmoId;
}

/*--------------------------------[ Natives Util Functions ]--------------------------------*/

Array:ReadMethodRegistrationParamsFromNativeCall(iStartArg, iArgc) {
  static Array:irgParams; irgParams = ArrayCreate();

  static iParam;
  for (iParam = iStartArg; iParam <= iArgc; ++iParam) {
    static iType; iType = get_param_byref(iParam);

    switch (iType) {
      case CW_Type_Cell: {
        ArrayPushCell(irgParams, ClassDataType_Cell);
      }
      case CW_Type_String: {
        ArrayPushCell(irgParams, ClassDataType_String);
      }
      case CW_Type_Array: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, get_param_byref(iParam + 1));
        iParam++;
      }
      case CW_Type_Vector: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, 3);
      }
      case CW_Type_CellRef: {
        ArrayPushCell(irgParams, ClassDataType_CellRef);
      }
    }
  }

  return irgParams;
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Give(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szClassname[CW_MAX_NAME_LENGTH]; read_argv(1, ARG_STRREF(szClassname));
  if (IS_NULLSTR(szClassname)) return PLUGIN_HANDLED;
  
  new iId = GetIdByClassName(szClassname);
  if (iId == CW_INVALID_ID) return PLUGIN_HANDLED;

  GiveWeapon(pPlayer, iId);

  return PLUGIN_HANDLED;
}

public Command_WeaponAlias(const pPlayer) {
  static szClassname[64]; read_argv(0, ARG_STRREF(szClassname));

  UTIL_SelectItem(pPlayer, szClassname);

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Client Forwards ]--------------------------------*/

public client_connect(pPlayer) {
  g_rgbPlayerShouldFixDeploy[pPlayer] = true;

  QueryPlayerRightHandCvar(pPlayer);
}

/*--------------------------------[ Client Cvars ]--------------------------------*/

public ClientCvar_RightHand(const pPlayer, const szCvar[], const szValue[]) {
  g_rgbPlayerRightHand[pPlayer] = !!str_to_num(szValue);
}

QueryPlayerRightHandCvar(const &pPlayer) {
  if (is_user_bot(pPlayer)) return;
  if (is_user_hltv(pPlayer)) return;

  query_client_cvar(pPlayer, "cl_righthand", "ClientCvar_RightHand");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_SetModel(const pEntity, const szModel[]) {
  static szClassname[32]; pev(pEntity, pev_classname, ARG_STRREF(szClassname));

  if (equal(szClassname, "weaponbox")) {
    static pItem; pItem = UTIL_GetWeaponBoxItem(pEntity);

    if (pItem != FM_NULLENT) {
      static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

      if (pInstance != Invalid_ClassInstance) {
        CALL_METHOD<UpdateWeaponBoxModel>(pItem, pEntity);
        return FMRES_SUPERCEDE;
      }
    }
  }

  return FMRES_IGNORED;
}

public FMHook_DecalIndex_Post() {
  static iDecalsNum = 0;

  if (!g_bPrecache) return;

  g_rgDecals[iDecalsNum++] = get_orig_retval();
}

public FMHook_OnFreeEntPrivateData(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    // if (!pev_valid(pEntity)) return;
    @Entity_Destroy(pEntity);
  }
}

public FMHook_UpdateClientData_Post(const pPlayer, iSendWeapons, pCdHandle) {
  // TODO?: Cache this
  if (!is_user_alive(pPlayer)) return FMRES_IGNORED;

  static pItem; pItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem");
  if (pItem != FM_NULLENT && IS_CUSTOM(pItem)) {
    set_cd(pCdHandle, CD_flNextAttack, g_flGameTime + 0.001); // block default animation
    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

/*--------------------------------[ Weapon Hooks ]--------------------------------*/

RegisterWeaponHooks() {
  // if (!iWeaponId) return;
  // if (g_rgbHookRegistered[iWeaponId]) return;

  // new szClassname[32]; get_weaponname(iWeaponId, ARG_STRREF(szClassname));
  if (IS_NULLSTR(g_szBaseWeaponName)) return;

  if (g_bIsCStrike) {
    RegisterHam(Ham_CS_Item_CanDrop, g_szBaseWeaponName, "HamHook_Base_CanDrop", .Post = 0);
    RegisterHam(Ham_CS_Item_IsWeapon, g_szBaseWeaponName, "HamHook_Base_IsWeapon", .Post = 0);
    RegisterHam(Ham_CS_Item_GetMaxSpeed, g_szBaseWeaponName, "HamHook_Base_GetMaxSpeed", .Post = 0);
  }

  RegisterHam(Ham_Spawn, g_szBaseWeaponName, "HamHook_Base_Spawn", .Post = 0);
  RegisterHam(Ham_Item_Deploy, g_szBaseWeaponName, "HamHook_Base_Deploy", .Post = 0);
  RegisterHam(Ham_Item_CanDeploy, g_szBaseWeaponName, "HamHook_Base_CanDeploy", .Post = 0);
  RegisterHam(Ham_Item_Holster, g_szBaseWeaponName, "HamHook_Base_Holster", .Post = 0);
  RegisterHam(Ham_Item_CanHolster, g_szBaseWeaponName, "HamHook_Base_CanHolster", .Post = 0);
  RegisterHam(Ham_Item_ItemSlot, g_szBaseWeaponName, "HamHook_Base_ItemSlot", .Post = 0);
  RegisterHam(Ham_Item_PrimaryAmmoIndex, g_szBaseWeaponName, "HamHook_Base_PrimaryAmmoIndex", .Post = 0);
  RegisterHam(Ham_Item_SecondaryAmmoIndex, g_szBaseWeaponName, "HamHook_Base_SecondaryAmmoIndex", .Post = 0);
  RegisterHam(Ham_Item_AddDuplicate, g_szBaseWeaponName, "HamHook_Base_AddDuplicate", .Post = 0);
  RegisterHam(Ham_Weapon_ExtractAmmo, g_szBaseWeaponName, "HamHook_Base_ExtractAmmo", .Post = 0);
  RegisterHam(Ham_Weapon_ExtractClipAmmo, g_szBaseWeaponName, "HamHook_Base_ExtractClipAmmo", .Post = 0);
  RegisterHam(Ham_Item_Drop, g_szBaseWeaponName, "HamHook_Base_Drop", .Post = 0);
  RegisterHam(Ham_Weapon_AddWeapon, g_szBaseWeaponName, "HamHook_Base_AddWeapon", .Post = 0);
  RegisterHam(Ham_Item_AddToPlayer, g_szBaseWeaponName, "HamHook_Base_AddToPlayer", .Post = 0);
  RegisterHam(Ham_Item_AddToPlayer, g_szBaseWeaponName, "HamHook_Base_AddToPlayer_Post", .Post = 1);
  RegisterHam(Ham_Item_UpdateItemInfo, g_szBaseWeaponName, "HamHook_Base_UpdateItemInfo", .Post = 0);

  #if defined _orpheu_included
    OrpheuRegisterHook(OrpheuGetFunctionFromClass(g_szBaseWeaponName, "GetItemInfo", "CBasePlayerItem"), "OrpheuHook_Base_GetItemInfo_Post", OrpheuHookPost);
  #else
    RegisterHam(Ham_Item_GetItemInfo, g_szBaseWeaponName, "HamHook_Base_GetItemInfo_Post", .Post = 1);
  #endif

  RegisterHam(Ham_Think, g_szBaseWeaponName, "HamHook_Base_Think", .Post = 0);
  RegisterHam(Ham_Touch, g_szBaseWeaponName, "HamHook_Base_Touch_Post", .Post = 1);

  // g_rgbHookRegistered[iWeaponId] = true;
}

public HamHook_Base_Spawn(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<Spawn>(pItem, 0);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_CanDeploy(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<CanDeploy>(pItem, 0);
    SetHamReturnInteger(bValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_CanHolster(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<CanHolster>(pItem, 0);
    SetHamReturnInteger(bValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_IsWeapon(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<IsWeapon>(pItem, 0);
    SetHamReturnInteger(bValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_GetMaxSpeed(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static Float:flValue; flValue = CALL_METHOD<GetMaxSpeed>(pItem, 0);
    SetHamReturnFloat(flValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Drop(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<Drop>(pItem, 0);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_CanDrop(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<CanDrop>(pItem, 0);
    SetHamReturnInteger(bValue);
    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_ItemSlot(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static iValue; iValue = ClassInstanceGetMember(pInstance, MEMBER(iSlot));
    SetHamReturnInteger(iValue + 1);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_PrimaryAmmoIndex(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static iValue; iValue = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
    SetHamReturnInteger(iValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_SecondaryAmmoIndex(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static iValue; iValue = ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType));
    SetHamReturnInteger(iValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_AddDuplicate(const pItem, const pOriginal) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<AddDuplicate>(pItem, pOriginal);
    SetHamReturnInteger(bValue);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_ExtractAmmo(const pItem, const pOriginal) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<ExtractAmmo>(pItem, pOriginal);
    SetHamReturnInteger(bValue);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_ExtractClipAmmo(const pItem, const pOriginal) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static bool:bValue; bValue = CALL_METHOD<ExtractClipAmmo>(pItem, pOriginal);
    SetHamReturnInteger(bValue);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Deploy(const pItem) {
  static pPlayer; pPlayer = get_ent_data_entity(pItem, "CBasePlayerItem", "m_pPlayer");

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    SetPlayerCustomWeapon(pPlayer, true);

    QueryPlayerRightHandCvar(pPlayer);

    static bool:bValue; bValue = CALL_METHOD<Deploy>(pItem, 0);

    if (g_rgbPlayerShouldFixDeploy[pPlayer]) {
      g_rgbPlayerShouldFixDeploy[pPlayer] = false;
      UTIL_FixWeaponDeploymentHand(pPlayer, pItem);
    }

    SetHamReturnInteger(bValue);

    return HAM_SUPERCEDE;
  }

  SetPlayerCustomWeapon(pPlayer, false);
  
  return HAM_IGNORED;
}

public HamHook_Base_Holster(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static pPlayer; pPlayer = get_ent_data_entity(pItem, "CBasePlayerItem", "m_pPlayer");
    CALL_METHOD<Holster>(pItem, 0);
    SetPlayerCustomWeapon(pPlayer, false);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

SetPlayerCustomWeapon(const &pPlayer, bool:bValue) {
  if (bValue) {
    g_iPlayerHasCustomWeaponBits |= BIT(pPlayer & 31);
  } else {
    g_iPlayerHasCustomWeaponBits &= ~BIT(pPlayer & 31);
  }

  if (g_iPlayerHasCustomWeaponBits) {
    EnableDynamicHooks();
  } else {
    DisableDynamicHooks();
  }
}

EnableDynamicHooks() {
  if (g_bDynamicHooksEnabled == !!g_iPlayerHasCustomWeaponBits) return;

  if (!g_pfwfmUpdateClientDataPost) {
    g_pfwfmUpdateClientDataPost = register_forward(FM_UpdateClientData, "FMHook_UpdateClientData_Post", 1);
  }

  if (!g_pfwhamPlayerPostThinkPost) {
    g_pfwhamPlayerPostThinkPost = RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
  } else {
    EnableHamForward(g_pfwhamPlayerPostThinkPost);
  }

  // if (!g_pfwhamItemPreFrame) {
  //   g_pfwhamItemPreFrame = RegisterHam(Ham_Item_PreFrame, g_szBaseWeaponName, "HamHook_Base_PreFrame", .Post = 0);
  // } else {
  //   EnableHamForward(g_pfwhamItemPreFrame);
  // }

  if (!g_pfwhamItemPostFrame) {
    g_pfwhamItemPostFrame = RegisterHam(Ham_Item_PostFrame, g_szBaseWeaponName, "HamHook_Base_PostFrame", .Post = 0);
  } else {
    EnableHamForward(g_pfwhamItemPostFrame);
  }

  if (!g_pfwhamItemUpdateClientData) {
    g_pfwhamItemUpdateClientData = RegisterHam(Ham_Item_UpdateClientData, g_szBaseWeaponName, "HamHook_Base_UpdateClientData", .Post = 0);
  } else {
    EnableHamForward(g_pfwhamItemUpdateClientData);
  }

  g_bDynamicHooksEnabled = true;
}

DisableDynamicHooks() {
  if (g_bDynamicHooksEnabled == !!g_iPlayerHasCustomWeaponBits) return;

  unregister_forward(FM_UpdateClientData, g_pfwfmUpdateClientDataPost, 1);
  g_pfwfmUpdateClientDataPost = 0;

  DisableHamForward(g_pfwhamPlayerPostThinkPost);
  // DisableHamForward(g_pfwhamItemPreFrame);
  DisableHamForward(g_pfwhamItemPostFrame);
  DisableHamForward(g_pfwhamItemUpdateClientData);

  g_bDynamicHooksEnabled = false;
}

public HamHook_Base_UpdateItemInfo(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<UpdateItemInfo>(pItem, 0);

    /*
      Not sure if it's a good idea to SUPERCECE this function.
      I didn't see any related issues, however, it may be something on a lower level.
    */
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_PreFrame(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<PreFrame>(pItem, 0);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_PostFrame(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<PostFrame>(pItem, 0);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_UpdateClientData(const pItem, const pPlayer) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<UpdateClientData>(pItem, pPlayer);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_AddWeapon(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);
    set_ent_data(pItem, "CBasePlayerItem", "m_iId", ClassInstanceGetMember(pInstance, MEMBER(iId)));
    set_ent_data(pItem, "CBasePlayerWeapon", "m_iClip", ClassInstanceGetMember(pInstance, MEMBER(iClip)));
    set_ent_data(pItem, "CBasePlayerWeapon", "m_iPrimaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType)));
    set_ent_data(pItem, "CBasePlayerWeapon", "m_iSecondaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType)));

    static bool:bValue; bValue = CALL_METHOD<AddWeapon>(pItem, 0);
    SetHamReturnInteger(bValue);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_AddToPlayer(const pItem, const pPlayer) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    /*
      ! AddToPlayer logic cannot be overridden !

      Blocking the original function call with manual execution of AddToPlayer is not working properly.
      The only solution is to block the original call if the custom AddToPlayer returns a false value.
    */
    static bool:bValue; bValue = CALL_METHOD<AddToPlayer>(pItem, pPlayer);
    SetHamReturnInteger(bValue);
    return bValue ? HAM_OVERRIDE : HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_AddToPlayer_Post(const pItem, const pPlayer) {
  static bool:bResult; GetHamReturnInteger(any:bResult);
  if (bResult) {
    UpdateWeaponList(pPlayer, pItem);
  }

  return HAM_HANDLED;
}

public HamHook_Player_PostThink_Post(const pPlayer) {
  UTIL_FixWeaponDeploymentHand(pPlayer);
}

public HamHook_Player_Killed(const pPlayer) {
  static pActiveItem; pActiveItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem");
  if (pActiveItem == FM_NULLENT) return;
  if (!pActiveItem) return;
  if (!IS_CUSTOM(pActiveItem)) return;

  /*
    Because some mods may have some "fixes" for handling player death during the attack,
    we need to ensure that the attack button is not pressed when the player is killed with custom weapon.
    
    Example of the "fix": https://github.com/s1lentq/ReGameDLL_CS/blob/c48be874743b2a440728889acb4797f4ec04137a/regamedll/dlls/player.cpp#L2284
  */
  set_pev(pPlayer, pev_button, pev(pPlayer, pev_button) & ~IN_ATTACK);
}

public HamHook_Player_GiveAmmo(const pPlayer, iAmount, const szAmmo[], iMaxCarry) {
  static iAmmoId; iAmmoId = GetCustomAmmoId(szAmmo);

  if (iAmmoId != -1 && EXECUTE_AMMO_PREHOOK<GiveToPlayer>(iAmmoId, pPlayer, iAmount) > CW_OVERRIDE) {
    SetHamReturnInteger(-1);
    return HAM_SUPERCEDE;
  }

  static iAmmoType; iAmmoType = -1;

  if (iAmmoId != -1) {
    iAmmoType = g_rgAmmos[iAmmoId][Ammo_Type];
    iMaxCarry = g_rgAmmos[iAmmoId][Ammo_MaxAmount];
  } else {
    iAmmoType = AmmoTypeFromString(szAmmo);

    if (iAmmoType != -1) {
      iMaxCarry = max(GetMaxCustomAmmoCarry(pPlayer, iAmmoType), iMaxCarry);
    }
  }

  static bool:bResult; bResult = false;

  if (iAmmoType != -1) {
    if (UTIL_GivePlayerAmmo(pPlayer, iAmmoType, iAmount, iMaxCarry)) {
      bResult = true;
    }
  }

  if (iAmmoId != -1) {
    EXECUTE_AMMO_POSTHOOK<GiveToPlayer>(iAmmoId, pPlayer, iAmount);
  }

  if (iAmmoType != -1) {
    SetHamReturnInteger(bResult ? iAmmoType : -1);
    return HAM_SUPERCEDE;
  }

  return HAM_HANDLED;
}

public HamHook_Player_GiveAmmo_Post() {
  GetHamReturnInteger(g_iGiveAmmoResult);
}

public HamHook_Knife_Holster(const pKnife) {
  if (!IS_CUSTOM(pKnife)) {
    static pPlayer; pPlayer = get_ent_data_entity(pKnife, "CBasePlayerItem", "m_pPlayer");
    if (is_user_alive(pPlayer)) {
      g_rgbPlayerShouldFixDeploy[pPlayer] = true;
    }
  }
}

#if defined _orpheu_included
  public OrpheuHook_Base_GetItemInfo_Post(const pItem, const pItemInfo) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

    if (pInstance != Invalid_ClassInstance) {
      static iId; iId = GET_ID(pItem);
      static szClassname[CW_MAX_NAME_LENGTH]; ClassGetMetadataString(g_rgcClasses[iId], CLASS_METADATA_NAME, ARG_STRREF(szClassname));
      static szPrimaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetPrimaryAmmoName>(pItem, ARG_STRREF(szPrimaryAmmo));
      static szSecondaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetSecondaryAmmoName>(pItem, ARG_STRREF(szSecondaryAmmo));

      OrpheuSetParamStructMember(pItemInfo, "iId", ClassInstanceGetMember(pInstance, MEMBER(iId)));
      OrpheuSetParamStructMember(pItemInfo, "iSlot", ClassInstanceGetMember(pInstance, MEMBER(iSlot)));
      OrpheuSetParamStructMember(pItemInfo, "iPosition", ClassInstanceGetMember(pInstance, MEMBER(iPosition)));
      OrpheuSetParamStructMember(pItemInfo, "iMaxAmmo1", ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo)));
      OrpheuSetParamStructMember(pItemInfo, "iMaxAmmo2", ClassInstanceGetMember(pInstance, MEMBER(iMaxSecondaryAmmo)));
      OrpheuSetParamStructMember(pItemInfo, "iMaxClip", ClassInstanceGetMember(pInstance, MEMBER(iMaxClip)));
      OrpheuSetParamStructMember(pItemInfo, "iFlags", ClassInstanceGetMember(pInstance, MEMBER(iFlags)));
      OrpheuSetParamStructMember(pItemInfo, "iWeight", ClassInstanceGetMember(pInstance, MEMBER(iWeight)));
      OrpheuSetParamStructMember(pItemInfo, "pszName", szClassname);
      OrpheuSetParamStructMember(pItemInfo, "pszAmmo1", szPrimaryAmmo);
      OrpheuSetParamStructMember(pItemInfo, "pszAmmo2", szSecondaryAmmo);
    }
  }
#else
  public HamHook_Base_GetItemInfo_Post(const pItem, const pItemInfo) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

    if (pInstance != Invalid_ClassInstance) {
      // static iId; iId = GET_ID(pItem);

      // static szClassname[CW_MAX_NAME_LENGTH]; ClassGetMetadataString(g_rgcClasses[iId], CLASS_METADATA_NAME, ARG_STRREF(szClassname));
      // static szPrimaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetPrimaryAmmoName>(pItem, ARG_STRREF(szPrimaryAmmo));
      // static szSecondaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetSecondaryAmmoName>(pItem, ARG_STRREF(szSecondaryAmmo));

      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iId, ClassInstanceGetMember(pInstance, MEMBER(iId)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iSlot, ClassInstanceGetMember(pInstance, MEMBER(iSlot)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iPosition, ClassInstanceGetMember(pInstance, MEMBER(iPosition)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iMaxAmmo1, ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iMaxAmmo2, ClassInstanceGetMember(pInstance, MEMBER(iMaxSecondaryAmmo)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iMaxClip, ClassInstanceGetMember(pInstance, MEMBER(iMaxClip)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iFlags, ClassInstanceGetMember(pInstance, MEMBER(iFlags)));
      SetHamItemInfo(pItemInfo, Ham_ItemInfo_iWeight, ClassInstanceGetMember(pInstance, MEMBER(iWeight)));

      /*
        !ATTENTION! SetHamItemInfo is broken for string types.

        Because of the native implementation it's have a weird behavior:
          Setting string value to HamItemInfo will set the pointer to the AMX string using `MF_GetAmxString` function.
          The function is return pointer, which always points to the same memory address,
            so any native call which read string from the arguments will change the value of the ItemInfo field.

        Even you set multiple string values to the ItemInfo, the last one will be used.

        Link: https://github.com/alliedmodders/amxmodx/blob/735928e6bf663e76aaf19a670dc994232f3e6bee/modules/hamsandwich/DataHandler.cpp#L423
      */
      // SetHamItemInfo(pItemInfo, Ham_ItemInfo_pszName, szClassname);
      // SetHamItemInfo(pItemInfo, Ham_ItemInfo_pszAmmo1, szPrimaryAmmo);
      // SetHamItemInfo(pItemInfo, Ham_ItemInfo_pszAmmo2, szSecondaryAmmo);

      return HAM_HANDLED;
    }

    return HAM_IGNORED;
  }
#endif

public HamHook_Base_Think(const pItem) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    if (~pev(pItem, pev_flags) & FL_KILLME) {
      CALL_METHOD<Think>(pItem, 0);
    }

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Touch_Post(pItem, pToucher) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    CALL_METHOD<Touch>(pItem, pToucher);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

/*--------------------------------[ Message Hooks ]--------------------------------*/

public Message_DeathMsg(const iMsgId, const iDest, const pPlayer) {
  static pKiller; pKiller = get_msg_arg_int(1);

  static szWeapon[64]; get_msg_arg_string(4, ARG_STRREF(szWeapon));

  if (pKiller && is_user_alive(pKiller)) {
    new pItem = UTIL_FindPlayerItemByClassname(pKiller, szWeapon);

    if (pItem != FM_NULLENT) {
      static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

      if (pInstance != Invalid_ClassInstance) {
        ClassInstanceGetMemberString(pInstance, MEMBER(szIcon), ARG_STRREF(szWeapon));

        if (!IS_NULLSTR(szWeapon)) {
          set_msg_arg_string(4, szWeapon);
        }
      }
    }
  }

  return PLUGIN_CONTINUE;
}

/*--------------------------------[ Entity Hookable Methods ]--------------------------------*/

ClassInstance:@Entity_CreateInstance(const &this, iId) {
  if (this > g_iMaxEntities) return Invalid_ClassInstance;

  new ClassInstance:pInstance = ClassInstanceCreate(g_rgcClasses[iId]);

  pInstance = ClassInstanceCache(pInstance);

  ClassInstanceSetMember(pInstance, MEMBER(Id), iId);
  ClassInstanceSetMember(pInstance, MEMBER(Pointer), this);

  g_rgEntityClassInstances[this] = pInstance;
  g_rgEntityIds[this] = iId;

  ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iPrimaryAmmoId), -1);
  ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iSecondaryAmmoId), -1);

  CALL_METHOD<Create>(this, 0);

  return pInstance;
}

@Entity_Destroy(const &this) {
  CALL_METHOD<Destroy>(this, 0);

  ClassInstanceDestroy(g_rgEntityClassInstances[this]);
  g_rgEntityClassInstances[this] = Invalid_ClassInstance;
  g_rgEntityIds[this] = CW_INVALID_ID;
}

@Entity_SetMethodPointer(const &this, EntityMethodPointer:iType, const szMethod[], const szClassname[]) {
  static Class:class;
  if (IS_NULLSTR(szClassname)) {
    class = ClassInstanceGetCurrentClass();

    if (class == Invalid_Class) {
      static ClassInstance:pInstance; pInstance = GET_INSTANCE(this);
      class = ClassInstanceGetClass(pInstance);
    }
  } else {
    class = g_rgcClasses[GetIdByClassName(szClassname)];
  }

  if (!IS_NULLSTR(szMethod)) {
    g_rgEntityMethodPointers[this][iType] = ClassGetMethodPointer(class, szMethod);
  } else {
    g_rgEntityMethodPointers[this][iType] = Invalid_Struct;
  }
}


/*--------------------------------[ Entity Functions ]--------------------------------*/

CreateEntity(const iId) {
  static ClassFlag:iFlags; iFlags = g_rgiClassFlags[iId];
  if (iFlags & ClassFlag_Abstract) {
    LOG_ERROR(ERROR_CANNOT_CREATE_ABSTRACT, g_rgszClassClassnames[iId]);
    return FM_NULLENT;
  }

  if (engfunc(EngFunc_NumberOfEntities) >= g_iMaxEntities) return FM_NULLENT;

  new this = engfunc(EngFunc_CreateNamedEntity, g_iszBaseClassName);
  if (this == FM_NULLENT) return FM_NULLENT;

  set_pev(this, pev_classname, g_rgszClassClassnames[iId]);

  new ClassInstance:pInstance = @Entity_CreateInstance(this, iId);

  if (pInstance == Invalid_ClassInstance) {
    engfunc(EngFunc_RemoveEntity, this);
    return FM_NULLENT;
  }

  CALL_METHOD<UpdateAmmoType>(this, 0);

  set_ent_data(this, "CBasePlayerItem", "m_iId", ClassInstanceGetMember(pInstance, MEMBER(iId)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iClip", ClassInstanceGetMember(pInstance, MEMBER(iClip)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iPrimaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iSecondaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iDefaultAmmo", ClassInstanceGetMember(pInstance, MEMBER(iDefaultAmmo)));

  #if defined _reapi_included
    static szPrimaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetPrimaryAmmoName>(this, ARG_STRREF(szPrimaryAmmo));
    static szSecondaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetSecondaryAmmoName>(this, ARG_STRREF(szSecondaryAmmo));

    // Setting pszName is required for ReAPI because some methods, such as the DefaultSwing method, can cause the game to crash
    rg_set_iteminfo(this, ItemInfo_pszName, g_rgszClassClassnames[iId]);
    rg_set_iteminfo(this, ItemInfo_iId, ClassInstanceGetMember(pInstance, MEMBER(iId)));
    rg_set_iteminfo(this, ItemInfo_iSlot, ClassInstanceGetMember(pInstance, MEMBER(iSlot)));
    rg_set_iteminfo(this, ItemInfo_iPosition, ClassInstanceGetMember(pInstance, MEMBER(iPosition)));
    rg_set_iteminfo(this, ItemInfo_iMaxAmmo1, ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo)));
    rg_set_iteminfo(this, ItemInfo_iMaxAmmo2, ClassInstanceGetMember(pInstance, MEMBER(iMaxSecondaryAmmo)));
    rg_set_iteminfo(this, ItemInfo_iMaxClip, ClassInstanceGetMember(pInstance, MEMBER(iMaxClip)));
    rg_set_iteminfo(this, ItemInfo_iFlags, ClassInstanceGetMember(pInstance, MEMBER(iFlags)));
    rg_set_iteminfo(this, ItemInfo_iWeight, ClassInstanceGetMember(pInstance, MEMBER(iWeight)));
    rg_set_iteminfo(this, ItemInfo_pszAmmo1, szPrimaryAmmo);
    rg_set_iteminfo(this, ItemInfo_pszAmmo2, szSecondaryAmmo);
  #endif

  return this;
}

bool:GiveWeapon(const &pPlayer, const iId, bool:bDropOther = false) {
  static pItem; pItem = CreateEntity(iId);
  if (pItem == FM_NULLENT) return false;

  dllfunc(DLLFunc_Spawn, pItem);

  if (bDropOther) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);
    static iSlot; iSlot = ClassInstanceGetMember(pInstance, MEMBER(iSlot));

    rg_drop_items_by_slot(pPlayer, InventorySlotType:(iSlot + 1));
  }
  
  if (!ExecuteHamB(Ham_AddPlayerItem, pPlayer, pItem)) return false;

  ExecuteHamB(Ham_Item_AttachToPlayer, pItem, pPlayer);

  CALL_METHOD<PickupSound>(pItem, 0);

  return true;
}

GiveAmmo(const &pPlayer, const iId, iAmount) {
  // Ham_GiveAmmo execution is broken and does't return value, so we use this variable to store the result.
  ExecuteHamB(Ham_GiveAmmo, pPlayer, iAmount, g_rgAmmos[iId][Ammo_Name], g_rgAmmos[iId][Ammo_MaxAmount]);

  return g_iGiveAmmoResult;
}

UpdateWeaponList(pPlayer, pItem) {
  if (!is_user_alive(pPlayer)) return;
  if (is_user_bot(pPlayer)) return;

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

  if (pInstance != Invalid_ClassInstance) {
    static Class:cClass; cClass = ClassInstanceGetClass(pInstance);
    static iId; iId = ClassGetMetadata(cClass, CLASS_METADATA_ID);
    static szName[64]; ClassGetMetadataString(g_rgcClasses[iId], CLASS_METADATA_NAME, ARG_STRREF(szName));

    emessage_begin(MSG_ONE, gmsgWeaponList, _, pPlayer);
    ewrite_string(szName);
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iMaxSecondaryAmmo)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iSlot)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iPosition)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iId)));
    ewrite_byte(ClassInstanceGetMember(pInstance, MEMBER(iFlags)));
    emessage_end();
  } else {
    static pItemInfo; pItemInfo = CreateHamItemInfo();
    ExecuteHam(Ham_Item_GetItemInfo, pItem, pItemInfo);

    static szName[32]; GetHamItemInfo(pItemInfo, Ham_ItemInfo_pszName, ARG_STRREF(szName));

    emessage_begin(MSG_ONE, gmsgWeaponList, _, pPlayer);
    ewrite_string(szName);
    ewrite_byte(get_ent_data(pItem, "CBasePlayerWeapon", "m_iPrimaryAmmoType"));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iMaxAmmo1));
    ewrite_byte(get_ent_data(pItem, "CBasePlayerWeapon", "m_iSecondaryAmmoType"));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iMaxAmmo2));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iSlot));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iPosition));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iId));
    ewrite_byte(GetHamItemInfo(pItemInfo, Ham_ItemInfo_iFlags));
    emessage_end();

    FreeHamItemInfo(pItemInfo);
  }
}

FreeEntities() {
  for (new pEntity = 0; pEntity <= g_iMaxEntities; ++pEntity) {
    if (!IS_CUSTOM(pEntity)) continue;

    @Entity_Destroy(pEntity);
  }
}

DestroyRegisteredClasses() {
  for (new iId = 0; iId < g_iClassesNum; ++iId) {
    FreeClass(iId);
  }
}

DestroyRegisteredAmmos() {
  for (new iId = 0; iId < g_iAmmosNum; ++iId) {
    FreeCustomAmmo(iId);
  }
}

PrecacheWeaponHudSprites(const szPath[]) {
  new iFile = fopen(szPath, "r", true);

  new szBuffer[512];
  new iSpritesNum = -1;
  new iLoadedSprites = 0;

  while (!feof(iFile)) {
    if (iSpritesNum != -1 && iLoadedSprites >= iSpritesNum) break;

    new iLen = fgets(iFile, ARG_STRREF(szBuffer));

    iLen -= trim(szBuffer);

    if (!iLen) continue;

    // Read number of sprites
    if (iSpritesNum == -1) {
      iSpritesNum = str_to_num(szBuffer);
      continue;
    }

    // Skip comments
    if (equal(szBuffer, "//", 2)) continue;

    new szSprite[MAX_RESOURCE_PATH_LENGTH];

    new iParamsNum = parse(szBuffer, 0, 0, 0, 0, ARG_STRREF(szSprite), 0, 0, 0, 0, 0, 0, 0, 0);
    if (iParamsNum != 7) {
      LOG_WARNING("Failed to parse weapon sprite parameters. Skipping line.", 0);
      continue;
    }

    if (IS_NULLSTR(szSprite)) {
      LOG_WARNING("Failed to parse weapon sprite path. Skipping line.", 0);
      continue;
    }

    iLoadedSprites++;

    static szSpritePath[MAX_RESOURCE_PATH_LENGTH]; format(ARG_STRREF(szSpritePath), "sprites/%s.spr", szSprite);

    if (!file_exists(szSpritePath, true)) {
      LOG_WARNING("Failed to locate weapon sprite ^"%s^". Skip.", szSpritePath);
      continue;
    }

    precache_generic(szSpritePath);
  }

  if (iLoadedSprites < iSpritesNum) {
    LOG_WARNING("HUD file is corupted. Loaded %i sprites, expected %i.", iLoadedSprites, iSpritesNum);
    return;
  }

  fclose(iFile);
}

/*--------------------------------[ Storage Functions ]--------------------------------*/

InitStorages() {
  g_pTrace = create_tr2();
  g_itEntityIds = TrieCreate();
  g_itAmmoIds = TrieCreate();
  g_itCustomMaterials = TrieCreate();
  g_itAmmoGroups = TrieCreate();

  for (new pEntity = 0; pEntity <= g_iMaxEntities; ++pEntity) {
    g_rgEntityClassInstances[pEntity] = Invalid_ClassInstance;
  }
}

DestroyStorages() {
  free_tr2(g_pTrace);
  TrieDestroy(g_itEntityIds);
  TrieDestroy(g_itAmmoIds);
  TrieDestroy(g_itCustomMaterials);
  TrieDestroy(g_itAmmoGroups);
}

/*--------------------------------[ Class Functions ]--------------------------------*/

GetIdByClassName(const szClassname[]) {
  static iId;
  if (!TrieGetCell(g_itEntityIds, szClassname, iId)) return CW_INVALID_ID;

  return iId;
}

RegisterClass(const szClassname[], const szParent[] = "", const ClassFlag:iClassFlags = ClassFlag_None) {
  new iId = g_iClassesNum;

  new Class:cParent = Invalid_Class;

  if (!IS_NULLSTR(szParent)) {
    new iParentId = CW_INVALID_ID;
    if (!TrieGetCell(g_itEntityIds, szParent, iParentId)) {
      LOG_ERROR(ERROR_IS_NOT_REGISTERED_BASE, szParent);
      return CW_INVALID_ID;
    }

    cParent = g_rgcClasses[iParentId];
  }

  new Class:cEntity = ClassCreate(cParent);
  cEntity = ClassCache(cEntity);
  ClassSetMetadataString(cEntity, CLASS_METADATA_NAME, szClassname);

  ClassSetMetadata(cEntity, CLASS_METADATA_ID, iId);
  g_rgiClassIds[iId] = iId;
  g_rgcClasses[iId] = cEntity;
  g_rgiClassFlags[iId] = iClassFlags;
  copy(g_rgszClassClassnames[iId], charsmax(g_rgszClassClassnames[]), szClassname);

  for (new CW_Method:iMethod = CW_Method:0; iMethod < CW_Method; ++iMethod) {
    g_rgrgiClassMethodPreHooksNum[iId][iMethod] = 0;
    g_rgrgiClassMethodPostHooksNum[iId][iMethod] = 0;
  }

  TrieSetCell(g_itEntityIds, szClassname, iId);

  g_iClassesNum++;

  if (~iClassFlags & ClassFlag_Abstract) {
    if (!equal(szClassname, "weapon_", 7)) {
      register_clcmd(szClassname, "Command_WeaponAlias");
    }

    if (g_bPrecache) {
      PrecacheWeaponHud(iId);
    }
  }

  LOG_INFO("Weapon ^"%s^" successfully registred.", szClassname);

  if (!g_bPrecache) {
    LOG_WARNING("Weapon ^"%s^" is registered after the precache phase!", szClassname);
  }

  return iId;
}

ForkClass(const szClassname[], const szOriginalClassName[], const szParent[] = "") {
  new iId = g_iClassesNum;

  new iOriginalId = GetIdByClassName(szOriginalClassName);
  
  new Class:cOriginalParent = ClassGetBaseClass(g_rgcClasses[iOriginalId]);
  new iOriginalParentId = ClassGetMetadata(cOriginalParent, CLASS_METADATA_ID);

  new iParentId = equal(szParent, NULL_STRING) ? iOriginalParentId : GetIdByClassName(szParent);

  if (!ClassIs(g_rgcClasses[iParentId], g_rgcClasses[iOriginalParentId])) {
    LOG_ERROR(ERROR_CANNOT_FORK_WITH_NON_RELATED_CLASS, szOriginalClassName, szParent);
    return CW_INVALID_ID;
  }

  new Class:cEntity = ClassFork(g_rgcClasses[iOriginalId], g_rgcClasses[iParentId]);
  cEntity = ClassCache(cEntity);

  ClassSetMetadataString(cEntity, CLASS_METADATA_NAME, szClassname);
  ClassSetMetadata(cEntity, CLASS_METADATA_ID, iId);

  g_rgiClassIds[iId] = iId;
  g_rgcClasses[iId] = cEntity;
  g_rgiClassFlags[iId] = g_rgiClassFlags[iOriginalId];
  copy(g_rgszClassClassnames[iId], charsmax(g_rgszClassClassnames[]), szClassname);

  for (new CW_Method:iMethod = CW_Method:0; iMethod < CW_Method; ++iMethod) {
    g_rgrgiClassMethodPreHooksNum[iId][iMethod] = 0;
    g_rgrgiClassMethodPostHooksNum[iId][iMethod] = 0;
  }

  TrieSetCell(g_itEntityIds, szClassname, iId);

  if (~g_rgiClassFlags[iId] & ClassFlag_Abstract) {
    if (!equal(szClassname, "weapon_", 7)) {
      register_clcmd(szClassname, "Command_WeaponAlias");
    }

    if (g_bPrecache) {
      PrecacheWeaponHud(iId);
    }
  }

  LOG_INFO("Weapon ^"%s^" successfully forked from ^"%s^".", szClassname, g_rgszClassClassnames[iOriginalId]);

  g_iClassesNum++;

  return iId;
}

FreeClass(const iId) {
  // for (new CW_Method:iMethod = CW_Method:0; iMethod < CW_Method; ++iMethod) {
  //   if (g_rgEntities[iId][Entity_MethodPreHooks][iMethod] != Invalid_Array) {
  //     ArrayDestroy(g_rgEntities[iId][Entity_MethodPreHooks][iMethod]);
  //   }

  //   if (g_rgEntities[iId][Entity_MethodPostHooks][iMethod] != Invalid_Array) {
  //     ArrayDestroy(g_rgEntities[iId][Entity_MethodPostHooks][iMethod]);
  //   }
  // }

  ClassDestroy(g_rgcClasses[iId]);
}

AddClassMethod(const iId, const szMethod[], const Function:fnCallback, Array:irgParamTypes, bool:bVirtual) {
  ClassDefineMethod(g_rgcClasses[iId], szMethod, fnCallback, bVirtual, ClassDataType_Cell, ClassDataType_ParamsCellArray, irgParamTypes);
}

ImplementClassMethod(const iId, const CW_Method:iMethod, const Function:fnCallback) {
  new Class:class = g_rgcClasses[iId];

  new Array:irgParams = ArrayCreate(_, 8);

  for (new iParam = 0; iParam < g_rgMethodParams[iMethod][MethodParams_Num]; ++iParam) {
    ArrayPushCell(irgParams, g_rgMethodParams[iMethod][MethodParams_Types][iParam]);
  }

  ClassDefineMethod(class, g_rgszMethodNames[iMethod], fnCallback, true, ClassDataType_Cell, ClassDataType_ParamsCellArray, irgParams);

  ArrayDestroy(irgParams);
}

RegisterClassMethodHook(const iId, CW_Method:iMethod, const Function:fnCallback, bool:bPost) {
  if (bPost) {
    new iHookId = g_rgrgiClassMethodPostHooksNum[iId][iMethod];
    g_rgrgrgfnClassMethodPostHooks[iId][iMethod][iHookId] = fnCallback;
    g_rgrgiClassMethodPostHooksNum[iId][iMethod]++;
    return iHookId;
  } else {
    new iHookId = g_rgrgiClassMethodPreHooksNum[iId][iMethod];
    g_rgrgrgfnClassMethodPreHooks[iId][iMethod][iHookId] = fnCallback;
    g_rgrgiClassMethodPreHooksNum[iId][iMethod]++;
    return iHookId;
  }
}

PrecacheWeaponHud(const iId) {
  new szPath[MAX_RESOURCE_PATH_LENGTH]; format(ARG_STRREF(szPath), "sprites/%s.txt", g_rgszClassClassnames[iId]);

  if (!file_exists(szPath, true)) {
    LOG_WARNING("Failed to precache hud for weapon ^"%s^"", g_rgszClassClassnames[iId]);
    return;
  }

  precache_generic(szPath);
  PrecacheWeaponHudSprites(szPath);
}

/*--------------------------------[ Init Base Classes Functions ]--------------------------------*/

InitBaseClasses() {
  #define _TO_STR(%1) #%1
  #define __METHOD_FN_NAME<%1::%2> _TO_STR(@%1_%2)
  #define __METHOD_PARAMS(%1,%2) GetIdByClassName(CW_Class_%1), CW_Method_%2, #%2, __METHOD_FN_NAME<%1::%2>

  #define DEFINE_CLASS<%1> RegisterClass(CW_Class_%1, NULL_STRING, ClassFlag_Abstract)
  #define DEFINE_METHOD_NOARGS<%1::%2>() InitNativeMethod(__METHOD_PARAMS(%1,%2))
  #define DEFINE_METHOD_ARGS<%1::%2>(%0) InitNativeMethod(__METHOD_PARAMS(%1,%2), %0)
  #define CELL(%1) ClassDataType_Cell
  #define STR(%1) ClassDataType_String
  #define ARR(%1,%2) ClassDataType_Array, %2
  #define STRREF(%1,%2) ClassDataType_StringRef, %2
  #define VEC(%1) ARR(%1,3)

  DEFINE_CLASS<Base>;

  DEFINE_METHOD_NOARGS<Base::Create>();
  DEFINE_METHOD_NOARGS<Base::Destroy>();
  DEFINE_METHOD_NOARGS<Base::IsWeapon>();
  DEFINE_METHOD_NOARGS<Base::Spawn>();
  DEFINE_METHOD_NOARGS<Base::Think>();
  DEFINE_METHOD_NOARGS<Base::PreFrame>();
  DEFINE_METHOD_NOARGS<Base::PostFrame>();
  DEFINE_METHOD_NOARGS<Base::UpdateItemInfo>();
  DEFINE_METHOD_ARGS<Base::Touch>(CELL(pToucher));
  DEFINE_METHOD_NOARGS<Base::ShouldIdle>();
  DEFINE_METHOD_NOARGS<Base::Idle>();
  DEFINE_METHOD_NOARGS<Base::CanDeploy>();
  DEFINE_METHOD_NOARGS<Base::Deploy>();
  DEFINE_METHOD_NOARGS<Base::CanHolster>();
  DEFINE_METHOD_NOARGS<Base::Holster>();
  DEFINE_METHOD_NOARGS<Base::CanDrop>();
  DEFINE_METHOD_NOARGS<Base::Drop>();
  DEFINE_METHOD_NOARGS<Base::GetMaxSpeed>();
  DEFINE_METHOD_NOARGS<Base::FallInit>();
  DEFINE_METHOD_ARGS<Base::PlayAnimation>(CELL(iAnim), CELL(flDuration));
  DEFINE_METHOD_ARGS<Base::UpdateWeaponBoxModel>(CELL(pWeaponBox));
  DEFINE_METHOD_NOARGS<Base::UpdateAmmoType>();

  DEFINE_METHOD_NOARGS<Base::IsUseable>();
  DEFINE_METHOD_NOARGS<Base::CanPrimaryAttack>();
  DEFINE_METHOD_NOARGS<Base::PrimaryAttack>();
  DEFINE_METHOD_NOARGS<Base::CanSecondaryAttack>();
  DEFINE_METHOD_NOARGS<Base::SecondaryAttack>();
  DEFINE_METHOD_NOARGS<Base::CanReload>();
  DEFINE_METHOD_NOARGS<Base::Reload>();
  DEFINE_METHOD_NOARGS<Base::CompleteReload>();
  DEFINE_METHOD_NOARGS<Base::CompleteSpecialReload>();
  DEFINE_METHOD_NOARGS<Base::GetBaseAccuracy>();
  DEFINE_METHOD_NOARGS<Base::IsExhausted>();
  DEFINE_METHOD_ARGS<Base::HitTexture>(CELL(chTextureType), CELL(pTrace));

  DEFINE_METHOD_ARGS<Base::AddToPlayer>(CELL(pPlayer));
  DEFINE_METHOD_ARGS<Base::AddDuplicate>(CELL(pOriginal));
  DEFINE_METHOD_ARGS<Base::UpdateClientData>(CELL(pPlayer));
  DEFINE_METHOD_NOARGS<Base::AddWeapon>();

  DEFINE_METHOD_ARGS<Base::ExtractAmmo>(CELL(pWeapon));
  DEFINE_METHOD_ARGS<Base::ExtractClipAmmo>(CELL(pWeapon));
  DEFINE_METHOD_ARGS<Base::AddPrimaryAmmo>(CELL(iCount));
  DEFINE_METHOD_ARGS<Base::AddSecondaryAmmo>(CELL(iCount));

  DEFINE_METHOD_NOARGS<Base::PickupSound>();
  DEFINE_METHOD_NOARGS<Base::PickupAmmoSound>();
  DEFINE_METHOD_NOARGS<Base::PumpSound>();
  DEFINE_METHOD_NOARGS<Base::PlayEmptySound>();
  DEFINE_METHOD_NOARGS<Base::ResetEmptySound>();
  DEFINE_METHOD_NOARGS<Base::ReloadSound>();

  DEFINE_METHOD_ARGS<Base::EjectBrass>(CELL(iModelIndex), CELL(iSoundType));
  DEFINE_METHOD_ARGS<Base::MakeDecal>(CELL(pHit), CELL(pTrace), CELL(bGunShot));
  DEFINE_METHOD_ARGS<Base::BulletSmoke>(CELL(pHit), CELL(pTrace), CELL(bGunShot));
  DEFINE_METHOD_ARGS<Base::BubbleTrail>(CELL(pHit), CELL(pTrace), CELL(bGunShot));

  DEFINE_METHOD_ARGS<Base::FireBullets>(CELL(iShots), VEC(vecSpread), CELL(flDistance), CELL(flDamage), CELL(flRangeModifier));
  DEFINE_METHOD_ARGS<Base::DefaultDeploy>(STR(szViewModel), STR(szWeaponModel), CELL(iAnim), STR(szAnimExt));
  DEFINE_METHOD_ARGS<Base::DefaultShot>(CELL(flDamage), CELL(flRangeModifier), CELL(flRate), VEC(vecSpread), CELL(iShots));
  DEFINE_METHOD_ARGS<Base::DefaultReload>(CELL(iAnim), CELL(flDelay));
  DEFINE_METHOD_ARGS<Base::DefaultShotgunIdle>(CELL(iAnim), CELL(iReloadEndAnim), CELL(flDuration), CELL(flReloadEndDuration));
  DEFINE_METHOD_ARGS<Base::DefaultShotgunShot>(CELL(flDamage), CELL(flRangeModifier), CELL(flRate), CELL(flPumpDelay), VEC(vecSpread), CELL(iShots));
  DEFINE_METHOD_ARGS<Base::DefaultShotgunReload>(CELL(iStartAnim), CELL(iEndAnim), CELL(flDelay), CELL(flDuration));
  DEFINE_METHOD_ARGS<Base::DefaultSwing>(CELL(flDamage), CELL(flRate), CELL(flDistance), CELL(flDistance));

  DEFINE_METHOD_ARGS<Base::TraceSwing>(CELL(flDistance));
  DEFINE_METHOD_ARGS<Base::PlayTextureSound>(CELL(pTrace));
  DEFINE_METHOD_NOARGS<Base::Smack>();
  DEFINE_METHOD_NOARGS<Base::SmackTraceAttack>();
  DEFINE_METHOD_NOARGS<Base::IsOutOfAmmo>();
  DEFINE_METHOD_ARGS<Base::GetPrimaryAmmoName>(STRREF(szOut, MAX_CUSTOM_AMMO_ID_LENGTH), CELL(iMaxLength));
  DEFINE_METHOD_ARGS<Base::GetSecondaryAmmoName>(STRREF(szOut, MAX_CUSTOM_AMMO_ID_LENGTH), CELL(iMaxLength));

  // Hidden methods
  // ClassDefineMethod(g_rgEntities[GetIdByClassName(CW_Class_Base)][Entity_Class], SMACK_METHOD, get_func_pointer(__METHOD_FN_NAME<Base::Smack>), true, ClassDataType_Cell);
}

InitNativeMethod(const iId, CW_Method:iMethod, const szMethod[], const szFunction[], any:...) {
  const iArgParamoffset = 4;

  new iParamsNum = vararg_get_length() - iArgParamoffset;
  for (new i = 0; i < iParamsNum; ++i) {
    g_rgMethodParams[iMethod][MethodParams_Types][i] = any:vararg_get(iArgParamoffset + i);
  }

  g_rgMethodParams[iMethod][MethodParams_Num] = iParamsNum;

  copy(g_rgszMethodNames[iMethod], charsmax(g_rgszMethodNames[]), szMethod);

  ImplementClassMethod(iId, iMethod, get_func_pointer(szFunction));
}

/*--------------------------------[ Class Method Functions ]--------------------------------*/

any:ExecuteMethod(CW_Method:iMethod, const &pEntity, const iNativeArg = 0, const iNativeArgsNum = 0, any:...) {
  static const iArgOffset = 4;

  new iExecutionParamsNum = iNativeArg ? (iNativeArgsNum - iNativeArg + 1) : (vararg_get_length() - iArgOffset);
  new iPreHookStackPosition = STACK_SIZE(METHOD_HOOKS_Pre);
  new iPostHookStackPosition = STACK_SIZE(METHOD_HOOKS_Post);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  
  new Class:class = Invalid_Class;
  if (!STACK_EMPTY(METHOD_HOOKS_Pre) || !STACK_EMPTY(METHOD_HOOKS_Post)) {
    class = ClassInstanceGetClass(pInstance);
  }

  STACK_PUSH(METHOD_RETURN, 0);
  callfunc_prepare_arg_types(CFP_Cell);

  new iId = GET_ID(pEntity);

  static Function:fnCurrentHookCb;

  new iCallResult;
  new iHookResult;

  #define PUSH_HOOKS_TO_STACK<%1>(%2)\
    for (new iHookId = g_rgrgiClassMethod%1HooksNum[%2][iMethod] - 1; iHookId >= 0; --iHookId)\
      STACK_PUSH(METHOD_HOOKS_%1, g_rgrgrgfnClassMethod%1Hooks[%2][iMethod][iHookId]);

  #define CALL_METHOD_HOOKS<%1>(%0)\
    while (STACK_SIZE(METHOD_HOOKS_%1) > i%1HookStackPosition)\
      fnCurrentHookCb = STACK_READ(METHOD_HOOKS_%1),\
      iHookResult = max(\
        callfunc_call(get_pfunc_function(fnCurrentHookCb), get_pfunc_plugin(fnCurrentHookCb), pEntity, %0),\
        iHookResult\
      ),\
      fnCurrentHookCb = STACK_POP(METHOD_HOOKS_%1);


  #define HOOKABLE_METHOD_IMPLEMENTATION(%0)\
    CALL_METHOD_HOOKS<Pre>(%0)\
    if (iHookResult != CW_SUPERCEDE) iCallResult = ClassInstanceCallMethod(pInstance, g_rgszMethodNames[iMethod], class, pEntity, %0);\
    if (iHookResult <= CW_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);\
    CALL_METHOD_HOOKS<Post>(%0)\
    if (iHookResult <= CW_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);

  #define READ_EXECUTION_PARAM<%1>(%2) any:(%1 < iExecutionParamsNum\
    ? (iNativeArg ? get_param_byref(iNativeArg + %1) : vararg_get(iArgOffset + %1))\
    : any:%2);\
    callfunc_set_arg_types(%1 + 1, CFP_Cell)

  #define READ_EXECUTION_PARAM_F<%1>(%2) %1 < iExecutionParamsNum\
    ? (iNativeArg ? (Float:get_param_byref(iNativeArg + %1)) : Float:vararg_get(iArgOffset + %1))\
    : %2;\
    callfunc_set_arg_types(%1 + 1, CFP_Cell)
  
  #define READ_EXECUTION_PARAM_VEC<%1>(%2,%3)\
    if (%1 >= iExecutionParamsNum) xs_vec_copy(%3, %2);\
    else if (iNativeArg) get_array_f(iNativeArg + %1, %2, 3);\
    else vararg_get_array(iArgOffset + %1, %2, 3);\
    callfunc_set_arg_types(%1 + 1, CFP_Array, 3)
  
  #define READ_EXECUTION_PARAM_STR<%1>(%2,%3)\
    if (%1 >= iExecutionParamsNum) copy(ARG_STRREF(%2), %3);\
    else if (iNativeArg) get_string(iNativeArg + %1, ARG_STRREF(%2));\
    else vararg_get_string(iArgOffset + %1, ARG_STRREF(%2));\
    callfunc_set_arg_types(%1 + 1, CFP_String)

  #define READ_EXECUTION_PARAM_STRREF<%1>(%2)\
    callfunc_set_arg_types(%1 + 1, CFP_StringRef)

  #define SET_EXECUTION_PARAM_STRREF<%1>(%2,%3)\
    if (%1 < iExecutionParamsNum)\
    if (iNativeArg) set_string(iNativeArg + %1, %2, %3);\
    else vararg_set_string(iArgOffset + %1, %2, %3);

  for (new Class:cCurrent = g_rgcClasses[iId]; cCurrent != Invalid_Class; cCurrent = ClassGetBaseClass(cCurrent)) {
    static iId; iId = ClassGetMetadata(cCurrent, CLASS_METADATA_ID);
    PUSH_HOOKS_TO_STACK<Pre>(iId)
    PUSH_HOOKS_TO_STACK<Post>(iId)
  }

  switch (iMethod) {
    case METHOD(FireBullets): {
      new iShots = READ_EXECUTION_PARAM<0>(0);
      new Float:vecSpread[3]; READ_EXECUTION_PARAM_VEC<1>(vecSpread, NULL_VECTOR);
      new Float:flDistance = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:flDamage = READ_EXECUTION_PARAM_F<3>(0.0);
      new Float:flRangeModifier = READ_EXECUTION_PARAM_F<4>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(iShots, vecSpread, flDistance, flDamage, flRangeModifier)
    }
    case METHOD(DefaultDeploy): {
      new szViewModel[64]; READ_EXECUTION_PARAM_STR<0>(szViewModel, NULL_STRING);
      new szWeaponModel[64]; READ_EXECUTION_PARAM_STR<1>(szWeaponModel, NULL_STRING);
      new iAnimation; iAnimation = READ_EXECUTION_PARAM<2>(0);
      new szAnimExt[32]; READ_EXECUTION_PARAM_STR<3>(szAnimExt, NULL_STRING);

      HOOKABLE_METHOD_IMPLEMENTATION(szViewModel, szWeaponModel, iAnimation, szAnimExt)
    }
    case METHOD(DefaultShot): {
      new Float:flDamage = READ_EXECUTION_PARAM_F<0>(0.0);
      new Float:flRangeModifier = READ_EXECUTION_PARAM_F<1>(0.0);
      new Float:flRate = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:vecSpread[3]; READ_EXECUTION_PARAM_VEC<3>(vecSpread, NULL_VECTOR);
      new iShots = READ_EXECUTION_PARAM<4>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(flDamage, flRangeModifier, flRate, vecSpread, iShots)
    }
    case METHOD(DefaultShotgunShot): {
      new Float:flDamage = READ_EXECUTION_PARAM_F<0>(0.0);
      new Float:flRangeModifier = READ_EXECUTION_PARAM_F<1>(0.0);
      new Float:flRate = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:flPumpDelay = READ_EXECUTION_PARAM_F<3>(0.0);
      new Float:vecSpread[3]; READ_EXECUTION_PARAM_VEC<4>(vecSpread, NULL_VECTOR);
      new iShots = READ_EXECUTION_PARAM<5>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(flDamage, flRangeModifier, flRate, flPumpDelay, vecSpread, iShots)
    }
    case METHOD(DefaultSwing): {
      new Float:flDamage = READ_EXECUTION_PARAM_F<0>(0.0);
      new Float:flRate = READ_EXECUTION_PARAM_F<1>(0.0);
      new Float:flDistance = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:flSmackDelay = -1.0;
      
      if (iExecutionParamsNum > 3) {
        flSmackDelay = READ_EXECUTION_PARAM_F<3>(0.0);
      }

      HOOKABLE_METHOD_IMPLEMENTATION(flDamage, flRate, flDistance, flSmackDelay)
    }
    case METHOD(DefaultReload): {
      new iAnim = READ_EXECUTION_PARAM<0>(0);
      new Float:flDelay = READ_EXECUTION_PARAM_F<1>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(iAnim, flDelay)
    }
    case METHOD(DefaultShotgunReload): {
      new iStartAnim = READ_EXECUTION_PARAM<0>(0);
      new iEndAnim = READ_EXECUTION_PARAM<1>(0);
      new Float:flDelay = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:flDuration = READ_EXECUTION_PARAM_F<3>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(iStartAnim, iEndAnim, flDelay, flDuration)
    }
    case METHOD(DefaultShotgunIdle): {
      new iStartAnim = READ_EXECUTION_PARAM<0>(0);
      new iReloadEndAnim = READ_EXECUTION_PARAM<1>(0);
      new Float:flDuration = READ_EXECUTION_PARAM_F<2>(0.0);
      new Float:flReloadEndDuration = READ_EXECUTION_PARAM_F<3>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(iStartAnim, iReloadEndAnim, flDuration, flReloadEndDuration)
    }
    case METHOD(PlayAnimation): {
      new iAnim = READ_EXECUTION_PARAM<0>(0);
      new Float:flDuration = -1.0;

      if (iExecutionParamsNum > 1) {
        flDuration = READ_EXECUTION_PARAM_F<1>(0.0);
      }

      HOOKABLE_METHOD_IMPLEMENTATION(iAnim, flDuration)
    }
    case METHOD(EjectBrass): {
      new iModelIndex = READ_EXECUTION_PARAM<0>(0);
      new iSoundType = READ_EXECUTION_PARAM<1>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(iModelIndex, iSoundType)
    }
    case METHOD(Touch): {
      new pToucher = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(AddDuplicate): {
      new pOriginal = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pOriginal)
    }
    case METHOD(UpdateClientData): {
      new pPlayer = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pPlayer)
    }
    case METHOD(AddToPlayer): {
      new pPlayer = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pPlayer)
    }
    case METHOD(PickupSound): {
      new pPlayer = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pPlayer)
    }
    case METHOD(UpdateWeaponBoxModel): {
      new pWeaponBox = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pWeaponBox)
    }
    case METHOD(MakeDecal), METHOD(BulletSmoke), METHOD(BubbleTrail): {
      new pHit = READ_EXECUTION_PARAM<0>(0);
      new pTrace = READ_EXECUTION_PARAM<1>(0);
      new bGunShot = READ_EXECUTION_PARAM<2>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pHit, pTrace, bGunShot)
    }
    case METHOD(ExtractAmmo), METHOD(ExtractClipAmmo): {
      new pOriginal = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pOriginal)
    }
    case METHOD(AddPrimaryAmmo), METHOD(AddSecondaryAmmo): {
      new iCount = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(iCount)
    }
    case METHOD(TraceSwing): {
      new Float:flDistance = READ_EXECUTION_PARAM_F<0>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(flDistance)
    }
    case METHOD(PlayTextureSound): {
      new pTrace = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pTrace)
    }
    case METHOD(GetPrimaryAmmoName), METHOD(GetSecondaryAmmoName): {
      new szOut[MAX_CUSTOM_AMMO_ID_LENGTH]; READ_EXECUTION_PARAM_STRREF<0>(szOut);
      new iMaxLength = READ_EXECUTION_PARAM<1>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(szOut, iMaxLength)

      SET_EXECUTION_PARAM_STRREF<0>(szOut, iMaxLength)
    }
    case METHOD(HitTexture): {
      new chTextureType = READ_EXECUTION_PARAM<0>(0);
      new pTrace = READ_EXECUTION_PARAM<1>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(chTextureType, pTrace)
    }
    default: {
      HOOKABLE_METHOD_IMPLEMENTATION(0)
    }
  }

  #undef PUSH_HOOKS_TO_STACK
  #undef CALL_METHOD_HOOKS
  #undef HOOKABLE_METHOD_IMPLEMENTATION
  #undef READ_EXECUTION_PARAM
  #undef READ_EXECUTION_PARAM_F
  #undef READ_EXECUTION_PARAM_VEC
  #undef READ_EXECUTION_PARAM_STR
  #undef READ_EXECUTION_PARAM_STRREF
  #undef SET_EXECUTION_PARAM_STRREF

  return STACK_POP(METHOD_RETURN);
}

/*--------------------------------[ Util Functions ]--------------------------------*/

ClearMultiDamage() {
#if defined _reapi_included
  rg_multidmg_clear();
#elseif defined _orpheu_included
  OrpheuCall(OrpheuGetFunction("ClearMultiDamage"));
#else
  static bool:bNotified = false;
  if (!bNotified) {
    LOG_WARNING("ClearMultiDamage is not implemented in current build!");
    bNotified = true;
  }
#endif
}

ApplyMultiDamage(const pInflictor, const pAttacker) {
#if defined _reapi_included
  rg_multidmg_apply(pInflictor, pAttacker);
#elseif defined _orpheu_included
  OrpheuCall(OrpheuGetFunction("ClearMultiDamage"), pInflictor, pAttacker);
#else
  #pragma unused pInflictor, pAttacker

  static bool:bNotified = false;
  if (!bNotified) {
    LOG_WARNING("ApplyMultiDamage is not implemented in current build!");
    bNotified = true;
  }
#endif
}

SetAnimation(pPlayer, PLAYER_ANIM:iPlayerAnim) {
#if defined _reapi_included
  rg_set_animation(pPlayer, iPlayerAnim);
#elseif defined _orpheu_included
  OrpheuCall(OrpheuGetFunction("SetAnimation"), pPlayer, iPlayerAnim);
#else
  #pragma unused pPlayer, iPlayerAnim

  static bool:bNotified = false;
  if (!bNotified) {
    LOG_WARNING("SetAnimation is not implemented in current build!");
    bNotified = true;
  }
#endif
}

InitBreakDecals() {
  g_rgiBreakDecals[0] = engfunc(EngFunc_DecalIndex, "{break1");
  g_rgiBreakDecals[1] = engfunc(EngFunc_DecalIndex, "{break2");
  g_rgiBreakDecals[2] = engfunc(EngFunc_DecalIndex, "{break3");
}

GetDecalIndex(const &pEntity) {
  static iDecalIndex; iDecalIndex = ExecuteHamB(Ham_DamageDecal, pEntity, 0);
  if (iDecalIndex < 0) return -1;

  iDecalIndex = g_rgDecals[iDecalIndex];

  for (new i = 0; i < sizeof(g_rgiBreakDecals); ++i) {
    if (iDecalIndex == g_rgiBreakDecals[i]) {
      return engfunc(EngFunc_DecalIndex, "{bproof1");
    }
  }

  return iDecalIndex;
}

GetMaxCustomAmmoCarry(const pPlayer, iAmmoType) {
  for (new iSlot = 0; iSlot < MAX_WEAPON_SLOTS; ++iSlot) {
    static pItem; pItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_rgpPlayerItems", iSlot);

    while (pItem != FM_NULLENT) {
      static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

      if (pInstance != Invalid_ClassInstance) {
        if (ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType)) == iAmmoType) {
          return ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo));
        }
      }

      pItem = get_ent_data_entity(pItem, "CBasePlayerItem", "m_pNext");
    }
  }

  return 0;
}

AmmoTypeToString(const iAmmoType, szOut[], iMaxLength) {
  if (iAmmoType == -1) {
    copy(szOut, iMaxLength, NULL_STRING);
    return;
  }

  format(szOut, iMaxLength, "%s%d", CUSTOM_AMMO_PREFIX, iAmmoType);
}

AmmoTypeFromString(const szValue[]) {
  if (!equal(szValue, CUSTOM_AMMO_PREFIX, sizeof(CUSTOM_AMMO_PREFIX) - 1)) return -1;

  return str_to_num(szValue[sizeof(CUSTOM_AMMO_PREFIX) - 1]);
}

FindPlayerCustomWeapon(const pPlayer, iId) {
  for (new iSlot = 0; iSlot < MAX_WEAPON_SLOTS; ++iSlot) {
    static pItem; pItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_rgpPlayerItems", iSlot);

    while (pItem != FM_NULLENT) {
      static ClassInstance:pInstance; pInstance = GET_INSTANCE(pItem);

      if (pInstance != Invalid_ClassInstance) {
        if (ClassInstanceIsInstanceOf(pInstance, g_rgcClasses[iId])) return pItem;
      }

      pItem = get_ent_data_entity(pItem, "CBasePlayerItem", "m_pNext");
    }
  }

  return FM_NULLENT;
}

/*--------------------------------[ Ammo ]--------------------------------*/

bool:IsCustomAmmoRegistered(const szId[]) {
  if (IS_NULLSTR(szId)) return false;

  return TrieKeyExists(g_itAmmoIds, szId);
}

RegisterCustomAmmo(const szId[], iAmmoType, iMaxAmount, const szGroup[]) {
  if (!IS_NULLSTR(szGroup) && AmmoGroup_IsRegistered(szGroup)) {
    if (AmmoGroup_IsAmmoTypeRegistered(szGroup, iAmmoType)) {
      LOG_FATAL_ERROR("Ammo type %d is already registered in group ^"%s^"", iAmmoType, szGroup);
      return -1;
    }
  }

  new iId = g_iAmmosNum;

  g_rgAmmos[iId][Ammo_Id] = iId;
  g_rgAmmos[iId][Ammo_Type] = iAmmoType;
  g_rgAmmos[iId][Ammo_MaxAmount] = iMaxAmount;
  g_rgAmmos[iId][Ammo_Metadata] = TrieCreate();
  copy(g_rgAmmos[iId][Ammo_Name], charsmax(g_rgAmmos[][Ammo_Name]), szId);

  for (new CW_AmmoHook:iHook = CW_AmmoHook:0; iHook < CW_AmmoHook; ++iHook) {
    g_rgAmmos[iId][Ammo_PreHooks][iHook] = Invalid_Array;
    g_rgAmmos[iId][Ammo_PostHooks][iHook] = Invalid_Array;
  }

  TrieSetCell(g_itAmmoIds, szId, iId);

  if (!IS_NULLSTR(szGroup)) {
    if (!AmmoGroup_IsRegistered(szGroup)) {
      AmmoGroup_Register(szGroup);
    }

    AmmoGroup_AddAmmo(szGroup, iAmmoType, iId);
  }

  g_iAmmosNum++;

  return iId;
}

FreeCustomAmmo(const iId) {  
  for (new CW_AmmoHook:iHook = CW_AmmoHook:0; iHook < CW_AmmoHook; ++iHook) {
    if (g_rgAmmos[iId][Ammo_PreHooks][iHook] != Invalid_Array) {
      ArrayDestroy(g_rgAmmos[iId][Ammo_PreHooks][iHook]);
    }

    if (g_rgAmmos[iId][Ammo_PostHooks][iHook] != Invalid_Array) {
      ArrayDestroy(g_rgAmmos[iId][Ammo_PostHooks][iHook]);
    }
  }

  TrieDestroy(g_rgAmmos[iId][Ammo_Metadata]);
}

AddAmmoHook(const iId, const CW_AmmoHook:iHook, const Function:fnCallback, bool:bPost = false) {
  new Array:irgHooks = Invalid_Array;

  if (bPost) {
    if (g_rgAmmos[iId][Ammo_PostHooks][iHook] == Invalid_Array) {
      g_rgAmmos[iId][Ammo_PostHooks][iHook] = ArrayCreate();
    }

    irgHooks = g_rgAmmos[iId][Ammo_PostHooks][iHook];
  } else {
    if (g_rgAmmos[iId][Ammo_PreHooks][iHook] == Invalid_Array) {
      g_rgAmmos[iId][Ammo_PreHooks][iHook] = ArrayCreate();
    }

    irgHooks = g_rgAmmos[iId][Ammo_PreHooks][iHook];
  }

  ArrayPushCell(irgHooks, fnCallback);
}

GetCustomAmmoId(const szId[]) {
  static iId;
  if (!TrieGetCell(g_itAmmoIds, szId, iId)) return -1;

  return iId;
}

ExecuteAmmoHook(const CW_AmmoHook:iHookId, const iId, bool:bPost, any:...) {
  static const iArgOffset = 3;

  new iExecutionParamsNum = vararg_get_length() - iArgOffset;

  new Array:irgHooks = bPost ? g_rgAmmos[iId][Ammo_PostHooks][iHookId] : g_rgAmmos[iId][Ammo_PreHooks][iHookId];
  if (irgHooks == Invalid_Array) return CW_IGNORED;

  new iHooksNum = ArraySize(irgHooks);
  if (!iHooksNum) return CW_IGNORED;

  STACK_PUSH(AMMO_HOOKS, iId);

  new iHookResult;
  static Function:fnCurrentHookCb;
  
  #define READ_EXECUTION_PARAM<%1>(%2) %1 < iExecutionParamsNum\
    ? vararg_get(iArgOffset + %1)\
    : %2;\
    callfunc_set_arg_types(%1 + 1, CFP_Cell)

  #define __EXECUTE_AMMO_HOOK_FN(%0)\
    for (new iHook = 0; iHook < iHooksNum; ++iHook)\
      fnCurrentHookCb = ArrayGetCell(irgHooks, iHook),\
      iHookResult = max(\
        callfunc_call(get_pfunc_function(fnCurrentHookCb), get_pfunc_plugin(fnCurrentHookCb), %0),\
        iHookResult\
      )

  switch (iHookId) {
    case AMMO_HOOK(GiveToPlayer): {
      new pPlayer = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new iAmount = READ_EXECUTION_PARAM<1>(0);

      __EXECUTE_AMMO_HOOK_FN(pPlayer, iAmount);
    }
    case AMMO_HOOK(Extract), AMMO_HOOK(ExtractClip): {
      new pWeapon = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new iAmount = READ_EXECUTION_PARAM<1>(0);
      new pTargetWeapon = READ_EXECUTION_PARAM<2>(FM_NULLENT);

      __EXECUTE_AMMO_HOOK_FN(pWeapon, iAmount, pTargetWeapon);
    }
  }

  #undef READ_EXECUTION_PARAM

  STACK_POP(AMMO_HOOKS);

  return iHookResult;
}

/*--------------------------------[ Ammo Groups ]--------------------------------*/

AmmoGroup_Register(const szGroup[]) {
  if (AmmoGroup_IsRegistered(szGroup)) {
    LOG_FATAL_ERROR("Ammo group ^"%s^" is already registered", szGroup);
    return -1;
  }

  new iId;
  TrieSetCell(g_itAmmoGroups, szGroup, iId);

  for (new iAmmoType = 0; iAmmoType < sizeof(g_rgAmmoGroupTypes[]); ++iAmmoType) {
    g_rgAmmoGroupTypes[iId][iAmmoType] = -1;
  }

  g_rgAmmoGroupAmmosNum[iId] = 0;

  g_rgAmmoGroupsNum++;

  return iId;
}

AmmoGroup_GetId(const szGroup[]) {
  static iId;
  if (!TrieGetCell(g_itAmmoGroups, szGroup, iId)) return -1;

  return iId;
}

AmmoGroup_IsRegistered(const szGroup[]) {
  return TrieKeyExists(g_itAmmoGroups, szGroup);
}

AmmoGroup_AddAmmo(const szGroup[], iAmmoType, iAmmoId) {
  static iGroupId;
  if (!TrieGetCell(g_itAmmoGroups, szGroup, iGroupId)) return;

  g_rgAmmoGroupTypes[iGroupId][iAmmoType] = iAmmoId;

  new iIndex = g_rgAmmoGroupAmmosNum[iGroupId];
  g_rgAmmoGroupAmmos[iGroupId][iIndex] = iAmmoId;
  g_rgAmmoGroupAmmosNum[iGroupId]++;
}

AmmoGroup_GetAmmoByType(const szGroup[], iAmmoType) {
  static iGroupId;
  if (!TrieGetCell(g_itAmmoGroups, szGroup, iGroupId)) return -1;

  return g_rgAmmoGroupTypes[iGroupId][iAmmoType];
}

AmmoGroup_IsAmmoTypeRegistered(const szGroup[], iAmmoType) {
  static iGroupId;
  if (!TrieGetCell(g_itAmmoGroups, szGroup, iGroupId)) return false;

  return g_rgAmmoGroupTypes[iGroupId][iAmmoType] != -1;
}

/*--------------------------------[ Functions ]--------------------------------*/

LoadCustomMaterials(const szPath[]) {
  new CBTEXTURENAMEMAX = 32;

  new iFile = fopen(szPath, "r", true);
  if (!iFile) return;
  LOG_INFO("Loading custom materials from ^"%s^"", szPath);

  new szBuffer[512];

  while (!feof(iFile)) {
    fgets(iFile, ARG_STRREF(szBuffer));

    new iPos = 0;
    while (isspace(szBuffer[iPos])) iPos++;
    
    if (!szBuffer[iPos]) continue;
    if (szBuffer[iPos] == '/' || !isalpha(szBuffer[iPos])) continue;

    new type = toupper(szBuffer[iPos++]);

    while(szBuffer[iPos] && isspace(szBuffer[iPos])) iPos++;

    if (!szBuffer[iPos]) continue;

    new i = iPos;
    while (szBuffer[i] && !isspace(szBuffer[i])) i++;
    if (!szBuffer[i]) continue;

    i = min(CBTEXTURENAMEMAX - 1 + iPos, i);
    szBuffer[i] = 0;

    TrieSetCell(g_itCustomMaterials, szBuffer[iPos], type);
  }

  fclose(iFile);
}


/*--------------------------------[ Base Methods Implementation ]--------------------------------*/

method <Base::Create> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(iClip), 0);
  ClassInstanceSetMember(pInstance, MEMBER(iWeight), 0);
  ClassInstanceSetMember(pInstance, MEMBER(iFlags), 0);
  ClassInstanceSetMember(pInstance, MEMBER(iSlot), 0);
  ClassInstanceSetMember(pInstance, MEMBER(iPosition), 0);
  ClassInstanceSetMember(pInstance, MEMBER(iMaxClip), -1);
  ClassInstanceSetMember(pInstance, MEMBER(iPrimaryAmmoType), -1);
  ClassInstanceSetMember(pInstance, MEMBER(iSecondaryAmmoType), -1);
  ClassInstanceSetMember(pInstance, MEMBER(iMaxPrimaryAmmo), -1);
  ClassInstanceSetMember(pInstance, MEMBER(iMaxSecondaryAmmo), -1);
  ClassInstanceSetMember(pInstance, MEMBER(iId), BASE_WEAPON_ID);
  ClassInstanceSetMember(pInstance, MEMBER(bInReload), false);
  ClassInstanceSetMember(pInstance, MEMBER(flNextSecondaryAttack), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(flNextPrimaryAttack), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(flLastFireTime), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(bFireOnEmpty), false);
  ClassInstanceSetMember(pInstance, MEMBER(iShotsFired), 0);
  ClassInstanceSetMember(pInstance, MEMBER(flDecreaseShotsFired), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(flAccuracy), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(flTimeIdle), 0.0);
  ClassInstanceSetMemberString(pInstance, MEMBER(szIcon), NULL_STRING);
  ClassInstanceSetMember(pInstance, MEMBER(flShotDistance), 8192.0);
  ClassInstanceSetMember(pInstance, MEMBER(bExhaustible), false);
  ClassInstanceSetMemberString(pInstance, MEMBER(szPrimaryAmmo), NULL_STRING);
  ClassInstanceSetMemberString(pInstance, MEMBER(szSecondaryAmmo), NULL_STRING);
  ClassInstanceSetMember(pInstance, MEMBER(bReloadOnFire), true);
  ClassInstanceSetMember(pInstance, MEMBER(bDirty), false);
}

method <Base::Destroy> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, MEMBER(pSwingTrace))) {
    new pSwingTrace = ClassInstanceGetMember(pInstance, MEMBER(pSwingTrace));
    free_tr2(pSwingTrace);
  }

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  if (IS_PLAYER(pPlayer)) {
    ExecuteHamB(Ham_RemovePlayerItem, pPlayer, this);
  }

  ExecuteHamB(Ham_Killed, this, 0, 0);
}

method <Base::IsWeapon> (const this) { return true; }

method <Base::Spawn> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static Class:class; class = ClassInstanceGetClass(pInstance);

  static iMaxClip; iMaxClip = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  ClassInstanceSetMember(pInstance, MEMBER(iClip), iMaxClip);

  // set_ent_data(this, "CBasePlayerWeapon", "m_iClip", iMaxClip);
  set_ent_data(this, "CBasePlayerItem", "m_iId", ClassInstanceGetMember(g_rgEntityClassInstances[this] , MEMBER(iId)));

  static szClassname[CW_MAX_NAME_LENGTH]; ClassGetMetadataString(class, CLASS_METADATA_NAME, ARG_STRREF(szClassname));
  set_pev(this, pev_classname, szClassname);

  static szModel[MAX_RESOURCE_PATH_LENGTH]; ClassInstanceGetMemberString(pInstance, MEMBER(szModel), ARG_STRREF(szModel));
  engfunc(EngFunc_SetModel, this, szModel);

  CALL_METHOD<FallInit>(this, 0);
}

method <Base::Think> (const this) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think], this);
  }
}

method <Base::PreFrame> (const this) {}

method <Base::PostFrame> (const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  if (pPlayer == FM_NULLENT) return;

  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static iButtons; iButtons = pev(pPlayer, pev_button);
  static iUsableButtons; iUsableButtons = iButtons;
  static Float:flNextAttack; flNextAttack = get_ent_data_float(pPlayer, "CBaseMonster", "m_flNextAttack");
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iSecondaryAmmoType; iSecondaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType));
  static iMaxClip; iMaxClip = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  static Float:flTimeIdle; flTimeIdle = ClassInstanceGetMember(pInstance, MEMBER(flTimeIdle));
  static iWeaponState; iWeaponState = 0; //? TODO: Implement
  static iWeaponId; iWeaponId = get_ent_data(this, "CBasePlayerItem", "m_iId");
  static Float:flPumpTime; flPumpTime = ClassInstanceGetMember(pInstance, MEMBER(flPumpTime));
  static Float:flSmackTime; flSmackTime = ClassInstanceGetMember(pInstance, MEMBER(flSmackTime));

  set_ent_data(this, "CBasePlayerItem", "m_iId", iWeaponId);
  set_ent_data(this, "CBasePlayerWeapon", "m_iClip", iClip);
  set_ent_data(this, "CBasePlayerWeapon", "m_iPrimaryAmmoType", iPrimaryAmmoType);
  set_ent_data(this, "CBasePlayerWeapon", "m_iSecondaryAmmoType", iSecondaryAmmoType);

  if (flSmackTime && flSmackTime <= g_flGameTime) {
    CALL_METHOD<Smack>(this, 0);
    ClassInstanceSetMember(pInstance, MEMBER(flSmackTime), 0.0);
  }

  // if (!HasSecondaryAttack()) {
  //   iUsableButtons &= ~IN_ATTACK2;
  // }

  // if (m_flGlock18Shoot != 0) {
  //   FireRemaining(m_iGlock18ShotsFired, m_flGlock18Shoot, TRUE);
  // } else if (g_flGameTime > m_flFamasShoot && m_flFamasShoot != 0) {
  //   FireRemaining(m_iFamasShotsFired, m_flFamasShoot, FALSE);
  // }

  // Return zoom level back to previous zoom level before we fired a shot.
  // This is used only for the AWP and Scout
  // if (m_flNextPrimaryAttack <= g_flGameTime) {
  //   if (m_pPlayer->m_bResumeZoom) {
  //     m_pPlayer->m_iFOV = m_pPlayer->m_iLastZoom;
  //     pev(pPlayer, pev_fov) = m_pPlayer->m_iFOV;

  //     if (m_pPlayer->m_iFOV == m_pPlayer->m_iLastZoom)
  //     {
  //       // return the fade level in zoom.
  //       m_pPlayer->m_bResumeZoom = false;
  //     }
  //   }
  // }

  // if (m_pPlayer->m_flEjectBrass != 0 && m_pPlayer->m_flEjectBrass <= g_flGameTime) {
  //   m_pPlayer->m_flEjectBrass = 0;
  //   EjectBrassLate();
  // }

  if (flPumpTime && flPumpTime < g_flGameTime) {
    CALL_METHOD<PumpSound>(this, 0);
    ClassInstanceSetMember(pInstance, MEMBER(flPumpTime), 0.0);
  }

  if (!(iButtons & IN_ATTACK)) {
    ClassInstanceSetMember(pInstance, MEMBER(flLastFireTime), 0.0);
  }

  if (ClassInstanceGetMember(pInstance, MEMBER(bInReload)) && flNextAttack <= g_flGameTime) {
    CALL_METHOD<CompleteReload>(this, 0);
  }

  static bool:bIsDefusing; bIsDefusing = g_bIsCStrike ? get_ent_data(pPlayer, "CBasePlayer", "m_bIsDefusing") : false;
  static Float:flNextPrimaryAttack; flNextPrimaryAttack = ClassInstanceGetMember(pInstance, MEMBER(flNextPrimaryAttack));
  static iFlags; iFlags = ClassInstanceGetMember(pInstance, MEMBER(iFlags));

  if ((iUsableButtons & IN_ATTACK2) && CALL_METHOD<CanSecondaryAttack>(this, 0) && !bIsDefusing) {
    if (iSecondaryAmmoType > 0) {
      if (!get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iSecondaryAmmoType)) {
        ClassInstanceSetMember(pInstance, MEMBER(bFireOnEmpty), true);
      }
    }

    CALL_METHOD<SecondaryAttack>(this, 0);

    iButtons &= ~IN_ATTACK2;
  } else if ((iButtons & IN_ATTACK) && CALL_METHOD<CanPrimaryAttack>(this, 0)) {
    if (iPrimaryAmmoType > 0) {
      if (!iClip || (iMaxClip == WEAPON_NOCLIP && !get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType))) {
        ClassInstanceSetMember(pInstance, MEMBER(bFireOnEmpty), true);
      }
    }

    // Can't shoot during the freeze period
    // Always allow firing in single player

    static bool:bCanShoot; bCanShoot = g_bIsCStrike ? get_ent_data(pPlayer, "CBasePlayer", "m_bCanShoot") : false;
    static bool:bIsFreezePeriod; bIsFreezePeriod = g_bIsCStrike ? get_gamerules_int("CGameRules", "m_bFreezePeriod") : false;

    if ((bCanShoot && g_bIsMultiplayer && !bIsFreezePeriod && !bIsDefusing) || !g_bIsMultiplayer) {
      // don't fire underwater
      if (pev(pPlayer, pev_waterlevel) == 3 && (iFlags & ITEM_FLAG_NOFIREUNDERWATER)) {
        CALL_METHOD<PlayEmptySound>(this, 0);
        ClassInstanceSetMember(pInstance, MEMBER(flNextPrimaryAttack), (flNextPrimaryAttack = g_flGameTime + 0.15));
      } else {
        CALL_METHOD<PrimaryAttack>(this, 0);
      }
    }
  } else if ((iButtons & IN_RELOAD) && iMaxClip != WEAPON_NOCLIP && !ClassInstanceGetMember(pInstance, MEMBER(bInReload)) && flNextPrimaryAttack < g_flGameTime) {
    // reload when reload is pressed, or if no buttons are down and weapon is empty.
    if (CALL_METHOD<CanReload>(this, 0)) {
      if (!(iWeaponState & WPNSTATE_SHIELD_DRAWN)) {
        CALL_METHOD<Reload>(this, 0);
      }
    }
  } else if (!(iUsableButtons & (IN_ATTACK | IN_ATTACK2))) {
    static iShotsFired; iShotsFired = ClassInstanceGetMember(pInstance, MEMBER(iShotsFired));
    static Float:flDecreaseShotsFired; flDecreaseShotsFired = ClassInstanceGetMember(pInstance, MEMBER(flDecreaseShotsFired));

    if (ClassInstanceGetMember(pInstance, MEMBER(bDelayFire))) {
      ClassInstanceSetMember(pInstance, MEMBER(bDelayFire), false);

      // if (iShotsFired > 15) {
      //   ClassInstanceSetMember(pInstance, MEMBER(iShotsFired), (iShotsFired = 15));
      // }

      ClassInstanceSetMember(pInstance, MEMBER(flDecreaseShotsFired), (flDecreaseShotsFired = g_flGameTime + 0.4));
    }

    ClassInstanceSetMember(pInstance, MEMBER(bFireOnEmpty), false);

    // if it's a pistol then set the shots fired to 0 after the player releases a button

    if (iShotsFired > 0 && flDecreaseShotsFired <= g_flGameTime) {
      ClassInstanceSetMember(pInstance, MEMBER(flDecreaseShotsFired), (flDecreaseShotsFired = g_flGameTime + 0.0225));
      ClassInstanceSetMember(pInstance, MEMBER(iShotsFired), --iShotsFired);

      // Reset accuracy
      if (!iShotsFired) {
        static Float:flAccuracy; flAccuracy = CALL_METHOD<GetBaseAccuracy>(this, 0);
        ClassInstanceSetMember(pInstance, MEMBER(flAccuracy), flAccuracy);
      }
    }

    if (!CALL_METHOD<IsUseable>(this, 0) && flNextPrimaryAttack < g_flGameTime) {
      // weapon isn't useable, switch.
      // if (!(iFlags & ITEM_FLAG_NOAUTOSWITCHEMPTY) && g_pGameRules->GetNextBestWeapon(m_pPlayer, this)) {
      //   flNextPrimaryAttack = g_flGameTime + 0.3f;
      //   return;
      // }
    } else {
      if (!(iWeaponState & WPNSTATE_SHIELD_DRAWN))
      {
        // weapon is useable. Reload if empty and weapon has waited as long as it has to after firing
        if (!iClip && !(iFlags & ITEM_FLAG_NOAUTORELOAD) && flNextPrimaryAttack < g_flGameTime) {
          if (CALL_METHOD<CanReload>(this, 0)) {
            CALL_METHOD<Reload>(this, 0);
            return;
          }
        }
      }
    }

    if (flTimeIdle <= g_flGameTime) {
      CALL_METHOD<Idle>(this, 0);
    }

    return;
  }

  // catch all
  if (flTimeIdle <= g_flGameTime) {
    if (CALL_METHOD<ShouldIdle>(this, 0)) {
      CALL_METHOD<Idle>(this, 0);
    }
  }
}

method <Base::UpdateItemInfo> (const this) {}

method <Base::Touch> (const this, const pToucher) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch], this, pToucher);
  }
}

method <Base::ShouldIdle> (const this) { return false; }

method <Base::Idle> (const this) {
  CALL_METHOD<ResetEmptySound>(this, 0);
  return true;
}

method <Base::CanDeploy> (const this) { return true; }

method <Base::Deploy> (const this) { return true; }

method <Base::CanHolster> (const this) { return true; }

method <Base::Holster> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(bInReload), false);
  ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 0);

  if (CALL_METHOD<IsExhausted>(this, 0)) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    static iWeaponId; iWeaponId = ClassInstanceGetMember(pInstance, MEMBER(iId));

    set_pev(pPlayer, pev_weapons, pev(pPlayer, pev_weapons) & ~(1<<iWeaponId));

    @Entity_SetMethodPointer(this, EntityMethodPointer_Think, g_rgszMethodNames[METHOD(Destroy)], NULL_STRING);

    set_pev(this, pev_nextthink, g_flGameTime + 0.1);
  }

  ExecuteHam(Ham_Item_Holster, this, 0);

  return true;
}

method <Base::CanDrop> (const this) { return true; }

method <Base::Drop> (const this) {
  ExecuteHam(Ham_Item_Drop, this);
  return true;
}

method <Base::GetMaxSpeed> (const this) { return 0.0; }

method <Base::IsExhausted> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (!ClassInstanceGetMember(pInstance, MEMBER(bExhaustible))) return false;
  if (!CALL_METHOD<IsOutOfAmmo>(this, 0)) return false;

  return true;
}

method <Base::HitTexture> (const this, const chTextureType, const pTrace) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(chHitTextureType), chTextureType);

  CALL_METHOD<PlayTextureSound>(this, pTrace);
}

method <Base::FallInit> (const this) {
  // TODO?: Implement
}

method <Base::PlayAnimation> (const this, iAnim, Float:flDuration) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  UTIL_SendWeaponAnim(this, iAnim);
  if (flDuration >= 0.0) {
    ClassInstanceSetMember(pInstance, MEMBER(flTimeIdle), g_flGameTime + flDuration);
  }
}

method <Base::UpdateWeaponBoxModel> (const this, pWeaponBox) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static szModel[MAX_RESOURCE_PATH_LENGTH]; ClassInstanceGetMemberString(pInstance, MEMBER(szModel), ARG_STRREF(szModel));
  engfunc(EngFunc_SetModel, pWeaponBox, szModel);
}

/*--------------------------------[ Combat Methods Implementation ]--------------------------------*/

method <Base::IsUseable> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceGetMember(pInstance, MEMBER(iClip)) <= 0) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));

    if (iPrimaryAmmoType != -1) {
      static iMaxPrimaryAmmo; iMaxPrimaryAmmo = ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo));

      if (get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType) <= 0 && iMaxPrimaryAmmo != -1) {
        return false;
      }
    }
  }

  return true;
}

method <Base::CanPrimaryAttack> (const this) {
  return Float:ClassInstanceGetMember(g_rgEntityClassInstances[this], MEMBER(flNextPrimaryAttack)) <= g_flGameTime;
}

method <Base::PrimaryAttack> (const this) { return true; }

method <Base::CanSecondaryAttack> (const this) {
  return Float:ClassInstanceGetMember(g_rgEntityClassInstances[this], MEMBER(flNextSecondaryAttack)) <= g_flGameTime;
}

method <Base::SecondaryAttack> (const this) { return true; }

method <Base::CanReload> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static iClipSize; iClipSize = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  if (iClipSize == -1) return false;

  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  if (iPrimaryAmmoType == -1) return false;
  if (!iPrimaryAmmoType) return false;

  return true;
}

method <Base::Reload> (const this) { return true; }

method <Base::CompleteReload> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iPrimaryAmmoAmount; iPrimaryAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iClipSize; iClipSize = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  static iSize; iSize = min(iClipSize - iClip, iPrimaryAmmoAmount);

  ClassInstanceSetMember(pInstance, MEMBER(bInReload), false);
  ClassInstanceSetMember(pInstance, MEMBER(iClip), iClip += iSize);
  set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", (iPrimaryAmmoAmount -= iSize), iPrimaryAmmoType);
}

method <Base::GetBaseAccuracy> (const this) { return 0.0; }

/*--------------------------------[ Player Interaction Methods Implementation ]--------------------------------*/

method <Base::AddToPlayer> (const this, const pPlayer) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  // return ExecuteHam(Ham_Item_AddToPlayer, this, pPlayer);
  
  CALL_METHOD<UpdateAmmoType>(this, 0);
  ClassInstanceSetMember(pInstance, MEMBER(bDirty), true);

  return true;
}

method <Base::AddDuplicate> (const this, const pOriginal) {
  return ExecuteHam(Ham_Item_AddDuplicate, this, pOriginal);
}

method <Base::UpdateClientData> (const this, const pPlayer) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  // Synchronize variables for correct update
  set_ent_data(this, "CBasePlayerItem", "m_iId", ClassInstanceGetMember(pInstance, MEMBER(iId)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iClip", ClassInstanceGetMember(pInstance, MEMBER(iClip)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iPrimaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType)));
  set_ent_data(this, "CBasePlayerWeapon", "m_iSecondaryAmmoType", ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType)));

  ExecuteHam(Ham_Item_UpdateClientData, this, pPlayer);
}

method <Base::AddWeapon> (const this) {
  // Original AddWeapon implementation does not check if ammo is extracted or not and always returns true
  new bool:bResult = bool:ExecuteHamB(Ham_Weapon_ExtractAmmo, this, this);

  return bResult;
  // return ExecuteHam(Ham_Weapon_AddWeapon, this);
}

/*--------------------------------[ Ammo Methods Implementation ]--------------------------------*/

method <Base::ExtractAmmo> (const this, const pOther) {
  new bool:bResult = false;

  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  new iPrimaryAmmoType = get_ent_data(this, "CBasePlayerWeapon", "m_iPrimaryAmmoType");
  new iDefaultAmmo = get_ent_data(this, "CBasePlayerWeapon", "m_iDefaultAmmo");

  if (iDefaultAmmo > 0 && iPrimaryAmmoType != -1) {
    new iAmmoId = ClassInstanceGetMember(pInstance, INTERNAL_MEMBER(iPrimaryAmmoId));

    if (iAmmoId == -1 || EXECUTE_AMMO_PREHOOK<Extract>(iAmmoId, pOther, iDefaultAmmo, this) < CW_SUPERCEDE) {
      if (CALL_METHOD<AddPrimaryAmmo>(pOther, iDefaultAmmo)) {
        set_ent_data(this, "CBasePlayerWeapon", "m_iDefaultAmmo", 0);
        bResult = true;
        ClassInstanceSetMember(pInstance, MEMBER(bDirty), true);
      }
    }

    if (iAmmoId != -1) {
      EXECUTE_AMMO_POSTHOOK<Extract>(iAmmoId, pOther, iDefaultAmmo, this);
    }
  } else {
    bResult = true;
    ClassInstanceSetMember(pInstance, MEMBER(bDirty), true);
  }

  return bResult;
}

method <Base::ExtractClipAmmo> (const this, const pOther) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  if (iPrimaryAmmoType <= 0) return false;

  static pPlayer; pPlayer = get_ent_data_entity(pOther, "CBasePlayerItem", "m_pPlayer");
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iMaxClip; iMaxClip = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  // static iMaxPrimaryAmmo; iMaxPrimaryAmmo = ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo));

  static iAmount; iAmount = iClip == -1 ? 0 : iClip;
  if (!iAmount) return false;

  static bool:bResult; bResult = false;

  static iPrimaryAmmoId; iPrimaryAmmoId = ClassInstanceGetMember(pInstance, INTERNAL_MEMBER(iPrimaryAmmoId));
  if (iPrimaryAmmoId == -1 || EXECUTE_AMMO_PREHOOK<ExtractClip>(iPrimaryAmmoId, pOther, iAmount, this) < CW_SUPERCEDE) {
    static szPrimaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetPrimaryAmmoName>(pOther, ARG_STRREF(szPrimaryAmmo));
    static iPrimaryAmmoId; iPrimaryAmmoId = GetCustomAmmoId(szPrimaryAmmo);

    if (iPrimaryAmmoId != -1) {
      bResult = GiveAmmo(pPlayer, iPrimaryAmmoId, iAmount) != -1;

      if (bResult) {
        ClassInstanceSetMember(pInstance, MEMBER(bDirty), true);
      }
    }
  }

  if (bResult && iMaxClip == -1) {
    CALL_METHOD<PickupAmmoSound>(pOther, 0);
  }

  if (iPrimaryAmmoId != -1) {
    EXECUTE_AMMO_POSTHOOK<ExtractClip>(iPrimaryAmmoId, pOther, iAmount, this);
  } 

  return bResult;
}

method <Base::AddPrimaryAmmo> (const this, iCount) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  // static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iMaxClip; iMaxClip = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  // static iMaxPrimaryAmmo; iMaxPrimaryAmmo = ClassInstanceGetMember(pInstance, MEMBER(iMaxPrimaryAmmo));
  static szPrimaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetPrimaryAmmoName>(this, ARG_STRREF(szPrimaryAmmo));
  static iPrimaryAmmoId; iPrimaryAmmoId = GetCustomAmmoId(szPrimaryAmmo);

  if (iPrimaryAmmoId != -1) {
    if (iMaxClip < 1) {
      ClassInstanceSetMember(pInstance, MEMBER(iClip), (iClip = WEAPON_NOCLIP));
      if (GiveAmmo(pPlayer, iPrimaryAmmoId, iCount) == -1) return false;
    } else if (iClip == 0) {
      new i; i = min(iClip + iCount, iMaxClip) - iClip;
      ClassInstanceSetMember(pInstance, MEMBER(iClip), (iClip += i));
      if (GiveAmmo(pPlayer, iPrimaryAmmoId, iCount - i) == -1) return false;
    } else {
      if (GiveAmmo(pPlayer, iPrimaryAmmoId, iCount) == -1) return false;
    }
  } else {
    // Deprecated implementation, use custom ammo instead
    static iPrimaryAmmoType; iPrimaryAmmoType = AmmoTypeFromString(szPrimaryAmmo);
    if (iPrimaryAmmoType == -1) return false;
    UTIL_GivePlayerAmmo(pPlayer, iPrimaryAmmoType, iCount);
  }

  CALL_METHOD<PickupAmmoSound>(this, 0);

  return true;
}

method <Base::AddSecondaryAmmo> (const this, iCount) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static szSecondaryAmmo[MAX_CUSTOM_AMMO_ID_LENGTH]; CALL_METHOD<GetSecondaryAmmoName>(this, ARG_STRREF(szSecondaryAmmo));
  static iSecondaryAmmoId; iSecondaryAmmoId = GetCustomAmmoId(szSecondaryAmmo);

  if (iSecondaryAmmoId == -1) return false;

  if (GiveAmmo(pPlayer, iSecondaryAmmoId, iCount) == -1) return false;

  CALL_METHOD<PickupAmmoSound>(this, 0);

  return true;
}

/*--------------------------------[ Sound Methods Implementation ]--------------------------------*/

method <Base::PickupSound> (const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  if (pPlayer == FM_NULLENT) return;

  emit_sound(pPlayer, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

method <Base::PickupAmmoSound> (const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  if (pPlayer == FM_NULLENT) return;

  emit_sound(pPlayer, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

method <Base::PumpSound> (const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  if (pPlayer == FM_NULLENT) return;

  static iPitch; iPitch = 85 + random_num(0, 0x1f);

  emit_sound(pPlayer, CHAN_ITEM, "weapons/scock1.wav", VOL_NORM, ATTN_NORM, 0, iPitch);
}

method <Base::PlayEmptySound> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceGetMember(pInstance, MEMBER(bPlayEmptySound))) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    if (pPlayer == FM_NULLENT) return;

    emit_sound(pPlayer, CHAN_ITEM, "weapons/357_cock1.wav", VOL_NORM * 0.8, ATTN_NORM, 0, PITCH_NORM);
    ClassInstanceSetMember(pInstance, MEMBER(bPlayEmptySound), false);
  }
}

method <Base::ResetEmptySound> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(bPlayEmptySound), true);
}

method <Base::ReloadSound> (const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  if (pPlayer == FM_NULLENT) return;

  static iPitch; iPitch = 85 + random_num(0, 0x1f);

  emit_sound(pPlayer, CHAN_ITEM, random(2) ? "weapons/reload1.wav" : "weapons/reload3.wav", VOL_NORM, ATTN_NORM, 0, iPitch);
}

/*--------------------------------[ Effect Methods Implementation ]--------------------------------*/

method <Base::EjectBrass> (const this, iModelIndex, iSoundType) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static Float:vecOffset[3]; xs_vec_set(vecOffset, 0.0, -9.0, 16.0);
  static Float:vecSpeed[3]; xs_vec_set(vecSpeed, random_float(50.0, 70.0), random_float(100.0, 150.0), 25.0);

  return UTIL_EjectWeaponBrass(this, iModelIndex, iSoundType, _, vecOffset, vecSpeed, !g_rgbPlayerRightHand[pPlayer]);
}

method <Base::MakeDecal> (const this, const pHit, const pTrace, bool:bGunShot) {
  if (pHit == FM_NULLENT) return;

  static iDecalIndex; iDecalIndex = GetDecalIndex(pHit);
  if (iDecalIndex < 0) return;

  UTIL_MakeDecal(pTrace, pHit, iDecalIndex, bGunShot);
}

method <Base::BulletSmoke> (const this, const pHit, const pTrace, bool:bGunShot) {
  UTIL_BulletSmoke(pTrace);
}

method <Base::BubbleTrail> (const this, const pHit, const pTrace, bool:bGunShot) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
  static Float:vecEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecEnd);

  UTIL_BubbleTrail(vecSrc, vecEnd, floatround(xs_vec_distance(vecSrc, vecEnd) / 64.0));
}

/*--------------------------------[ Default Methods Implementation ]--------------------------------*/

method <Base::FireBullets> (const this, iShots, const Float:vecSpread[3], Float:flDistance, Float:flDamage, Float:flRangeModifier) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
  static Float:vecViewAngles[3]; pev(pPlayer, pev_v_angle, vecViewAngles);
  static Float:vecForward[3]; angle_vector(vecViewAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecRight[3]; angle_vector(vecViewAngles, ANGLEVECTOR_RIGHT, vecRight);
  static Float:vecUp[3]; angle_vector(vecViewAngles, ANGLEVECTOR_UP, vecUp);

  static iRandomSeed; iRandomSeed = pPlayer > 0 ? get_ent_data(pPlayer, "CBasePlayer", "random_seed") : 0;

  ClearMultiDamage();
  
  ClassInstanceSetMember(pInstance, MEMBER(chHitTextureType), 0);

  for (new iShot = 1; iShot <= iShots; iShot++) {
    // Use player's random seed.
    // get circular gaussian spread
    static Float:vecMultiplier[3];
    vecMultiplier[0] = SharedRandomFloat(iRandomSeed + iShot, -0.5, 0.5) + SharedRandomFloat(iRandomSeed + (1 + iShot) , -0.5, 0.5);
    vecMultiplier[1] = SharedRandomFloat(iRandomSeed + (2 + iShot), -0.5, 0.5) + SharedRandomFloat(iRandomSeed + (3 + iShot), -0.5, 0.5);
    vecMultiplier[2] = (vecMultiplier[0] * vecMultiplier[0]) + (vecMultiplier[1] * vecMultiplier[1]);

    static Float:vecDirection[3];
    for (new i = 0; i < 3; ++i) {
      vecDirection[i] = vecForward[i] + (vecMultiplier[0] * vecSpread[0] * vecRight[i]) + (vecMultiplier[1] * vecSpread[1] * vecUp[i]);
    }

    static Float:vecEnd[3]; xs_vec_add_scaled(vecSrc, vecDirection, flDistance, vecEnd);

    engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

    // do damage, paint decals
    static pHit; pHit = FM_NULLENT;
    if (flFraction != 1.0) {
      pHit = get_tr2(g_pTrace, TR_pHit);

      // Fraction value 1.0 means we hit world, not sure why the engine returns NULL
      if (pHit == FM_NULLENT) {
        pHit = 0;
      }

      static Float:flCurrentDistance; flCurrentDistance = flDistance * flFraction;
      static Float:flCurrentDamage; flCurrentDamage = flDamage * floatpower(flRangeModifier, flCurrentDistance / 500.0);

      ClassInstanceSetMember(pInstance, MEMBER(flHitDamage), flCurrentDamage);

      ExecuteHamB(Ham_TraceAttack, pHit, pPlayer, flCurrentDamage, vecDirection, g_pTrace, DMG_BULLET | DMG_NEVERGIB);

      if (!IS_PLAYER(pHit) && (!pHit || ExecuteHam(Ham_IsBSPModel, pHit))) {
        CALL_METHOD<HitTexture>(this, GetTextureType(g_pTrace, vecSrc, vecEnd), g_pTrace);
        CALL_METHOD<BulletSmoke>(this, pHit, g_pTrace, true);
        CALL_METHOD<MakeDecal>(this, pHit, g_pTrace, true);
      }
    }

    CALL_METHOD<BubbleTrail>(this, pHit, g_pTrace, true);
  }

  ApplyMultiDamage(this, pPlayer);
}

GetTextureType(const &pTrace, const Float:vecSrc[3], const Float:vecEnd[3]) {
  new chTextureType = UTIL_GetTextureType(pTrace, vecSrc, vecEnd);

  if (chTextureType == CHAR_TEX_CONCRETE) {
    static pHit; pHit = get_tr2(pTrace, TR_pHit);
    if (pHit == FM_NULLENT) {
      pHit = 0;
    }

    static szTexture[32]; engfunc(EngFunc_TraceTexture, pHit, vecSrc, vecEnd, szTexture, charsmax(szTexture));
    TrieGetCell(g_itCustomMaterials, szTexture, chTextureType);
  }

  return chTextureType;
}

method <Base::DefaultDeploy> (const this, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[]) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  if (!CALL_METHOD<CanDeploy>(this, 0)) return false;

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  set_pev(pPlayer, pev_viewmodel2, szViewModel);
  set_pev(pPlayer, pev_weaponmodel2, szWeaponModel);

  // model_name = m_pPlayer->pev->viewmodel; ???

  if (!IS_NULLSTR(szAnimExt)) {
    set_ent_data_string(pPlayer, "CBasePlayer", "m_szAnimExtention", szAnimExt);
  }

  CALL_METHOD<PlayAnimation>(this, iAnim, 1.5);

  set_ent_data_float(pPlayer, "CBaseMonster", "m_flNextAttack", 0.75);

  ClassInstanceSetMember(pInstance, MEMBER(flLastFireTime), 0.0);
  ClassInstanceSetMember(pInstance, MEMBER(flDecreaseShotsFired), g_flGameTime);

  set_ent_data(pPlayer, "CBasePlayer", "m_iFOV", DEFAULT_FOV);
  set_pev(pPlayer, pev_fov, float(DEFAULT_FOV));
  set_ent_data(pPlayer, "CBasePlayer", "m_iLastZoom", DEFAULT_FOV);
  set_ent_data(pPlayer, "CBasePlayer", "m_bResumeZoom", false);

  return true;
}

method <Base::DefaultShot> (const this, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:vecSpread[3], iShots) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(flNextPrimaryAttack), g_flGameTime + flRate);
  ClassInstanceSetMember(pInstance, MEMBER(flNextSecondaryAttack), g_flGameTime + flRate);

  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  if (iClip <= 0) {
    CALL_METHOD<PlayEmptySound>(this, 0);

    if (ClassInstanceGetMember(pInstance, MEMBER(bReloadOnFire))) {
      CALL_METHOD<Reload>(this, 0);
    }

    return false;
  }

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iShotsFired; iShotsFired = ClassInstanceGetMember(pInstance, MEMBER(iShotsFired));
  static Float:flDistance; flDistance = ClassInstanceGetMember(pInstance, MEMBER(flShotDistance));

  CALL_METHOD<FireBullets>(this, iShots, vecSpread, flDistance, flDamage, flRangeModifier);

  ClassInstanceSetMember(pInstance, MEMBER(iClip), --iClip);
  ClassInstanceSetMember(pInstance, MEMBER(iShotsFired), ++iShotsFired);
  SetAnimation(pPlayer, ClassInstanceGetMember(pInstance, MEMBER(bAltAttack)) ? PLAYER_ATTACK2 : PLAYER_ATTACK1);

  return true;
}

method <Base::DefaultReload> (const this, iAnim, Float:flDelay) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceGetMember(pInstance, MEMBER(bInReload))) return false;

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  if (iPrimaryAmmoType == -1) return false;
  if (!iPrimaryAmmoType) return false;

  static iPrimaryAmmoAmount; iPrimaryAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);
  if (iPrimaryAmmoAmount <= 0) return false;

  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iClipSize; iClipSize = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));

  static iSize; iSize = min(iClipSize - iClip, iPrimaryAmmoAmount);
  if (!iSize) return false;

  set_ent_data_float(pPlayer, "CBaseMonster", "m_flNextAttack", flDelay);
  ClassInstanceSetMember(pInstance, MEMBER(bInReload), true);

  CALL_METHOD<PlayAnimation>(this, iAnim, flDelay);
  SetAnimation(pPlayer, PLAYER_RELOAD);

  return true;
}

method <Base::DefaultShotgunIdle> (const this, iAnim, iReloadEndAnim, Float:flDuration, Float:flReloadEndDuration) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static Float:flTimeIdle; flTimeIdle = ClassInstanceGetMember(pInstance, MEMBER(flTimeIdle));
  if (flTimeIdle <= g_flGameTime) {
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
    static iPrimaryAmmoAmount; iPrimaryAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);
    static iSpecialReload; iSpecialReload = ClassInstanceGetMember(pInstance, MEMBER(iSpecialReload));
    static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
    static iFlags; iFlags = ClassInstanceGetMember(pInstance, MEMBER(iFlags));

    if (!iClip && !(iFlags & ITEM_FLAG_NOAUTORELOAD) && iSpecialReload == 0 && iPrimaryAmmoAmount) {
      CALL_METHOD<Reload>(this, 0);
    } else if (iSpecialReload != 0) {
      static iClipSize; iClipSize = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
      if (iClip < iClipSize && iPrimaryAmmoAmount) {
        CALL_METHOD<Reload>(this, 0);
      } else {
        ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 0);
        CALL_METHOD<PumpSound>(this, 0);
        CALL_METHOD<PlayAnimation>(this, iReloadEndAnim, flReloadEndDuration);
      }
    } else {
      CALL_METHOD<PlayAnimation>(this, iAnim, flDuration);
    }
  }

  return true;
}

method <Base::DefaultShotgunShot> (const this, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:flPumpDelay, Float:vecSpread[3], iShots) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));

  if (iClip <= 0) {
    CALL_METHOD<PlayEmptySound>(this, 0);

    if (ClassInstanceGetMember(pInstance, MEMBER(bReloadOnFire))) {
      CALL_METHOD<Reload>(this, 0);
    }

    return false;
  }

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static Float:flDistance; flDistance = ClassInstanceGetMember(pInstance, MEMBER(flShotDistance));

  set_ent_data(pPlayer, "CBasePlayer", "m_iWeaponVolume", LOUD_GUN_VOLUME);
  set_ent_data(pPlayer, "CBasePlayer", "m_iWeaponFlash", NORMAL_GUN_FLASH);

  set_pev(pPlayer, pev_effects, pev(pPlayer, pev_effects) | EF_MUZZLEFLASH);

  if (!CALL_METHOD<DefaultShot>(this, flDamage, flRangeModifier, flRate, vecSpread, iShots, flDistance)) {
    return false;
  }

  ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 0);

  if (iClip) {
    ClassInstanceSetMember(pInstance, MEMBER(flNextReload), g_flGameTime + flPumpDelay);
    ClassInstanceSetMember(pInstance, MEMBER(flPumpTime), g_flGameTime + flPumpDelay);
  }

  return true;
}

method <Base::DefaultShotgunReload> (const this, iStartAnim, iEndAnim, Float:flDelay, Float:flDuration) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iClipSize; iClipSize = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));
  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iPrimaryAmmoAmount; iPrimaryAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);

  if (iPrimaryAmmoAmount <= 0 || iClip >= iClipSize) return false;

  // don't reload until recoil is done
  static Float:flNextPrimaryAttack; flNextPrimaryAttack = ClassInstanceGetMember(pInstance, MEMBER(flNextPrimaryAttack));
  if (flNextPrimaryAttack > g_flGameTime) return false;

  static iSpecialReload; iSpecialReload = ClassInstanceGetMember(pInstance, MEMBER(iSpecialReload));

  static Float:flTimeIdle; flTimeIdle = ClassInstanceGetMember(pInstance, MEMBER(flTimeIdle));

  switch (iSpecialReload) {
    case 0: {
      SetAnimation(pPlayer, PLAYER_RELOAD);
      CALL_METHOD<PlayAnimation>(this, iStartAnim, flDelay);

      ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 1);
      set_ent_data_float(pPlayer, "CBaseMonster", "m_flNextAttack", flDelay);
      ClassInstanceSetMember(pInstance, MEMBER(flNextPrimaryAttack), g_flGameTime + 1.0);
      ClassInstanceSetMember(pInstance, MEMBER(flNextSecondaryAttack), g_flGameTime + 1.0);
    }
    case 1: {
      if (flTimeIdle > g_flGameTime) return false;

      ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 2);

      CALL_METHOD<ReloadSound>(this, 0);
      CALL_METHOD<PlayAnimation>(this, iEndAnim, flDuration);
    }
    case 2: {
      ClassInstanceSetMember(pInstance, MEMBER(iSpecialReload), 1);
      CALL_METHOD<CompleteSpecialReload>(this, 0);
    }
  }

  return true;
}

method <Base::CompleteSpecialReload> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iPrimaryAmmoAmount; iPrimaryAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);

  ClassInstanceSetMember(pInstance, MEMBER(iClip), ++iClip);

  set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", --iPrimaryAmmoAmount, iPrimaryAmmoType);
}

method <Base::DefaultSwing> (const this, Float:flDamage, Float:flRate, Float:flDistance, Float:flSmackDelay) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  // static Float:vecAngles[3]; pev(pPlayer, pev_v_angle, vecAngles);
  // engfunc(EngFunc_MakeVectors, vecAngles);

  static iShotsFired; iShotsFired = ClassInstanceGetMember(pInstance, MEMBER(iShotsFired));

  ClassInstanceSetMember(pInstance, MEMBER(iShotsFired), ++iShotsFired);
  ClassInstanceSetMember(pInstance, MEMBER(flNextPrimaryAttack), g_flGameTime + flRate);
  ClassInstanceSetMember(pInstance, MEMBER(flSwingDamage), flDamage);

  // static Float:flSmackDelay;
  
  // if (ClassInstanceHasMember(pInstance, MEMBER(flSmackDelay))) {
  //   flSmackDelay = floatmin(flRate, ClassInstanceGetMember(pInstance, MEMBER(flSmackDelay)));
  // } else {
  //   flSmackDelay = flRate * 0.5;
  // }

  if (flSmackDelay == -1.0) {
    flSmackDelay = flRate * 0.5;
  } else {
    flSmackDelay = floatmin(flRate, flSmackDelay);
  }

  ClassInstanceSetMember(pInstance, MEMBER(flSmackTime), g_flGameTime + flSmackDelay);

  SetAnimation(pPlayer, ClassInstanceGetMember(pInstance, MEMBER(bAltAttack)) ? PLAYER_ATTACK2 : PLAYER_ATTACK1);

  return CALL_METHOD<TraceSwing>(this, flDistance);
}

method <Base::TraceSwing> (const this, Float:flDistance) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  // Initializing special trace structure for swing
  if (!ClassInstanceHasMember(pInstance, MEMBER(pSwingTrace))) {
    ClassInstanceSetMember(pInstance, MEMBER(pSwingTrace), create_tr2());
  }

  static pTrace; pTrace = ClassInstanceGetMember(pInstance, MEMBER(pSwingTrace));

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static Float:vecAngles[3]; pev(pPlayer, pev_v_angle, vecAngles);
  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
  static Float:vecEnd[3]; xs_vec_add_scaled(vecSrc, vecForward, flDistance, vecEnd);

  ClassInstanceSetMemberArray(pInstance, MEMBER(vecSwing), vecForward, 3);

  engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, pTrace);

  static pHit; pHit = FM_NULLENT;
  static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);

  if (flFraction >= 1.0) {
    engfunc(EngFunc_TraceHull, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, this, pTrace);
    get_tr2(pTrace, TR_flFraction, flFraction);

    if (flFraction < 1.0) {
      // Calculate the point of interANCHOR of the line (or hull) and the object we hit
      // This is and approximation of the "best" interANCHOR
      pHit = get_tr2(pTrace, TR_pHit);

      if (pHit == FM_NULLENT || ExecuteHam(Ham_IsBSPModel, pHit)) {
        static Float:flHalfSize; flHalfSize = flDistance / 2;
        static Float:vecHullMin[3]; xs_vec_set(vecHullMin, -flHalfSize, -flHalfSize, -flHalfSize);
        static Float:vecHullMax[3]; xs_vec_set(vecHullMax, flHalfSize, flHalfSize, flHalfSize);
        UTIL_FindHullIntersection(vecSrc, pTrace, vecHullMin, vecHullMax, this);
        // UTIL_FindHullIntersection(vecSrc, pTrace, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, this);
        ClassInstanceSetMember(pInstance, MEMBER(pSwingTrace), pTrace);
      }

      get_tr2(pTrace, TR_flFraction, flFraction);
      get_tr2(pTrace, TR_vecEndPos, vecEnd); // This is the point on the actual surface (the hull could have hit space)
    }
  }

  if (flFraction < 1.0) {
    pHit = get_tr2(pTrace, TR_pHit);

    if (pHit == FM_NULLENT) {
      set_tr2(pTrace, TR_pHit, pHit = 0);
    }
  }

  ClassInstanceSetMember(pInstance, MEMBER(pSwingHit), pHit);

  return pHit;
}

method <Base::Smack> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  new pHit = ClassInstanceGetMember(pInstance, MEMBER(pSwingHit));

  new bool:bHitWorld = true;

  ClassInstanceSetMember(pInstance, MEMBER(chHitTextureType), 0);
  
  if (pHit > 0 && !pev_valid(pHit)) {
    pHit = FM_NULLENT;
  }

  if (pHit != FM_NULLENT) {
    CALL_METHOD<SmackTraceAttack>(this, 0);

    if (pHit) {
      static iClass; iClass = ExecuteHamB(Ham_Classify, pHit);

      if (iClass > CLASS_MACHINE && iClass != CLASS_VEHICLE) {
        bHitWorld = false;
      }
    }
  } else {
    bHitWorld = false;
  }

  if (bHitWorld) {
    static pTrace; pTrace = ClassInstanceGetMember(pInstance, MEMBER(pSwingTrace));
    static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
    static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
    static Float:vecEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecEnd);
    static Float:vecDirection[3]; ClassInstanceGetMemberArray(pInstance, MEMBER(vecSwing), vecDirection, 3);
    xs_vec_add_scaled(vecEnd, vecDirection, 1.0, vecEnd);

    CALL_METHOD<HitTexture>(this, GetTextureType(pTrace, vecSrc, vecEnd), pTrace);
    CALL_METHOD<MakeDecal>(this, pHit, pTrace, false);
    CALL_METHOD<BulletSmoke>(this, pHit, pTrace, false);
  }

  return pHit;
}

method <Base::SmackTraceAttack> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  new pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static pTrace; pTrace = ClassInstanceGetMember(pInstance, MEMBER(pSwingTrace));
  static Float:flDamage; flDamage = ClassInstanceGetMember(pInstance, MEMBER(flSwingDamage));
  static pHit; pHit = ClassInstanceGetMember(pInstance, MEMBER(pSwingHit));
  static Float:vecDirection[3]; ClassInstanceGetMemberArray(pInstance, MEMBER(vecSwing), vecDirection, 3);

  // static Float:flHealth; pev(pHit, pev_health, flHealth);

  // server_print("hit: %d", pHit);
  // server_print("damage: %f", flDamage);
  // server_print("health before attack %f", flHealth);

  ClearMultiDamage();
  ExecuteHamB(Ham_TraceAttack, pHit, pPlayer, flDamage, vecDirection, pTrace, DMG_CLUB);
  ApplyMultiDamage(pPlayer, pPlayer);

  // pev(pHit, pev_health, flHealth);

  // server_print("health after attack %f", flHealth);
}

method <Base::PlayTextureSound> (const this, pTrace) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (!pTrace) {
    pTrace = g_pTrace;
  }

  static chTextureType; chTextureType = ClassInstanceGetMember(pInstance, MEMBER(chHitTextureType));

  UTIL_PlayTextureSound(chTextureType, pTrace);
}

method <Base::IsOutOfAmmo> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  static iPrimaryAmmoType; iPrimaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
  static iSecondaryAmmoType; iSecondaryAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType));
  static iMaxClip; iMaxClip = ClassInstanceGetMember(pInstance, MEMBER(iMaxClip));

  if (iMaxClip < 0 && iPrimaryAmmoType <= 0 && iSecondaryAmmoType <= 0) return false;

  if (iMaxClip >= 0) {
    static iClip; iClip = ClassInstanceGetMember(pInstance, MEMBER(iClip));
    if (iClip > 0) return false;
  }

  if (iPrimaryAmmoType > 0) {
    static iPrimaryAmmo; iPrimaryAmmo = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);
    if (iPrimaryAmmo > 0) return false;
  }

  if (iSecondaryAmmoType > 0) {
    static iSecondaryAmmo; iSecondaryAmmo = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iSecondaryAmmoType);
    if (iSecondaryAmmo > 0) return false;
  }

  return true;
}

method <Base::UpdateAmmoType> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static szPrimaryAmmo[CW_MAX_AMMO_NAME_LENGTH]; ClassInstanceGetMemberString(pInstance, MEMBER(szPrimaryAmmo), ARG_STRREF(szPrimaryAmmo));
  if (!IS_NULLSTR(szPrimaryAmmo)) {
    static iAmmoId; iAmmoId = GetCustomAmmoId(szPrimaryAmmo);
    if (iAmmoId != -1) {
      ClassInstanceSetMember(pInstance, MEMBER(iPrimaryAmmoType), g_rgAmmos[iAmmoId][Ammo_Type]);
      ClassInstanceSetMember(pInstance, MEMBER(iMaxPrimaryAmmo), g_rgAmmos[iAmmoId][Ammo_MaxAmount]);
      set_ent_data(this, "CBasePlayerWeapon", "m_iPrimaryAmmoType", g_rgAmmos[iAmmoId][Ammo_Type]);
      ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iPrimaryAmmoId), iAmmoId);
    } else {
      ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iPrimaryAmmoId), -1);
    }
  }

  static szSecondaryAmmo[CW_MAX_AMMO_NAME_LENGTH]; ClassInstanceGetMemberString(pInstance, MEMBER(szSecondaryAmmo), ARG_STRREF(szSecondaryAmmo));
  if (!IS_NULLSTR(szSecondaryAmmo)) {
    static iAmmoId; iAmmoId = GetCustomAmmoId(szSecondaryAmmo);
    if (iAmmoId != -1) {
      ClassInstanceSetMember(pInstance, MEMBER(iSecondaryAmmoType), g_rgAmmos[iAmmoId][Ammo_Type]);
      ClassInstanceSetMember(pInstance, MEMBER(iMaxSecondaryAmmo), g_rgAmmos[iAmmoId][Ammo_MaxAmount]);
      set_ent_data(this, "CBasePlayerWeapon", "m_iSecondaryAmmoType", g_rgAmmos[iAmmoId][Ammo_Type]);
      ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iSecondaryAmmoId), iAmmoId);
    } else {
      ClassInstanceSetMember(pInstance, INTERNAL_MEMBER(iSecondaryAmmoId), -1);
    }
  }
}

method <Base::GetPrimaryAmmoName> (const this, szOut[], iMaxLength) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceGetMemberString(pInstance, MEMBER(szPrimaryAmmo), szOut, iMaxLength);

  if (IS_NULLSTR(szOut)) {
    static iAmmoType; iAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iPrimaryAmmoType));
    AmmoTypeToString(iAmmoType, szOut, iMaxLength);
  }
}

method <Base::GetSecondaryAmmoName> (const this, szOut[], iMaxLength) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceGetMemberString(pInstance, MEMBER(szSecondaryAmmo), szOut, iMaxLength);

  if (IS_NULLSTR(szOut)) {
    static iAmmoType; iAmmoType = ClassInstanceGetMember(pInstance, MEMBER(iSecondaryAmmoType));
    AmmoTypeToString(iAmmoType, szOut, iMaxLength);
  }
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_FixWeaponDeploymentHand(const &pPlayer, const &pRealItem = FM_NULLENT) {
  /*
    !!!HACKHACK: This function fixes the mirroring issue (incorrect hand positioning) when deploying Counter-Strike weapons.

    Usage:
      - Call this function during the initial weapon deployment (first deployment after joining the game)
        or after holstering the knife.
      - Continuously call this function in the player's Think function without passing the "pRealItem" parameter
        to correctly manage the transition.

    How it works:
      - The function temporarily deploys a fake item and delays the deployment of the actual weapon to ensure
        the game engine correctly applies the hand position for the weapon model.
      - It uses a single entity for fake items, implementing a simple scheduling and queueing mechanism to handle
        multiple player requests.

    Performance Considerations:
      - Calling this function every frame should have minimal impact on performance, as it maintains internal
        state and only processes when necessary.

    Function State Management:
      - Manages a fake item entity used for temporary deployment.
      - Tracks when the real weapon deployment should be resumed.
      - Stores the actual item (weapon) to be deployed after the fix is applied.

    Additional Notes:
      - The smoke grenade entity is used as the fake item because it cannot be dropped, which prevents it from
        being accidentally removed or destroyed during the process.
      - The function uses an unused ammo index to ensure the fake item is not destroyed by the game engine.
      - The delay duration is calculated based on the player's ping to ensure proper synchronization of the
        weapon model transformation.

    Implementation Details:
      - The function schedules weapon transitions and ensures that during the transition, the player's last item
        and active item are managed correctly to avoid crashes.
      - Once the transition is completed or suspended, the function cleans up the state and ensures the fake item
        is detached from the player.
  */

  // We can use any unused ammo index and set the player some ammo each deployment to avoid destroying the item.
  static const __UNUSED_AMMO_INDEX = 0;

  // Only apply the fix for Counter-Strike
  static s_iCstrike = -1;
  if (s_iCstrike == -1) {
      s_iCstrike = cstrike_running();
  }

  if (!s_iCstrike) return false;
  if (!is_user_connected(pPlayer)) return false;
  if (is_user_bot(pPlayer)) return false;

  static Float:s_flNextAvailableTransitionTime = 0.0;
  static Float:s_rgflPlayerFixStart[MAX_PLAYERS + 1] = { 0.0, ... };
  static Float:s_rgflPlayerFixRelease[MAX_PLAYERS + 1] = { 0.0, ... };
  static s_rgpPlayerItemToDeploy[MAX_PLAYERS + 1] = { FM_NULLENT, ... };

  static s_pFakeItem = FM_NULLENT;
  if (s_pFakeItem == FM_NULLENT) {
    // Initialize the fake item as a smoke grenade (cannot be dropped)
    s_pFakeItem = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "weapon_smokegrenade"));

    dllfunc(DLLFunc_Spawn, s_pFakeItem);

    // Make sure we are not using any existing Weapon HUD
    set_pev(s_pFakeItem, pev_classname, "__empty__");

    // Fake ID to avoid collision
    set_ent_data(s_pFakeItem, "CBasePlayerItem", "m_iId", 99);

    // We don't want player to use the weapon
    set_ent_data(s_pFakeItem, "CBasePlayerWeapon", "m_iClip", -1);
    set_ent_data(s_pFakeItem, "CBasePlayerWeapon", "m_iDefaultAmmo", 0);
    set_ent_data(s_pFakeItem, "CBasePlayerWeapon", "m_iPrimaryAmmoType", __UNUSED_AMMO_INDEX);
    set_ent_data(s_pFakeItem, "CBasePlayerWeapon", "m_iSecondaryAmmoType", 0);

    // Not owned by player
    set_ent_data_entity(s_pFakeItem, "CBasePlayerItem", "m_pPlayer", FM_NULLENT);

    // Block touch
    set_pev(s_pFakeItem, pev_solid, SOLID_NOT);

    // Hide from worlds
    set_pev(s_pFakeItem, pev_effects, pev(s_pFakeItem, pev_effects) | EF_NODRAW);
    set_pev(s_pFakeItem, pev_modelindex, 0);

    // Don't think (it will remove the entity)
    set_pev(s_pFakeItem, pev_nextthink, 0.0);
  }

  static bool:bShouldReleaseTransition; bShouldReleaseTransition = false;

  if (s_rgflPlayerFixStart[pPlayer] || s_rgflPlayerFixRelease[pPlayer]) {
    if (!bShouldReleaseTransition) {
      bShouldReleaseTransition = !is_user_alive(pPlayer);
    }

    if (!bShouldReleaseTransition) {
      // If the transition is scheduled and not started
      if (s_rgflPlayerFixStart[pPlayer]) {
        if (s_rgflPlayerFixStart[pPlayer] <= g_flGameTime) {
          /*
            Make sure fake item is free to use.

            Sometimes a collision can occur because the entities have Think priority,
              allowing a new transition to start before the previous one is fully released.
          */
          if (get_ent_data_entity(s_pFakeItem, "CBasePlayerItem", "m_pPlayer") == FM_NULLENT) {
            // The orignal deploy function is using m_pPlayer member, so need to set it
            set_ent_data_entity(s_pFakeItem, "CBasePlayerItem", "m_pPlayer", pPlayer);

            // Deploy the fake item
            set_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem", s_pFakeItem);
            ExecuteHam(Ham_Item_Deploy, s_pFakeItem);

            // We don't want player to use the weapon
            set_ent_data_float(s_pFakeItem, "CBasePlayerWeapon", "m_flTimeWeaponIdle", 999.0);
            set_ent_data_float(s_pFakeItem, "CBasePlayerWeapon", "m_flNextPrimaryAttack", 999.0);
            set_ent_data_float(s_pFakeItem, "CBasePlayerWeapon", "m_flNextSecondaryAttack", 999.0);

            // Set some ammo to avoid destroying the item
            set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", 1, __UNUSED_AMMO_INDEX);

            // Hide the weapon model from player screen
            set_pev(pPlayer, pev_viewmodel2, NULL_STRING);
            set_pev(pPlayer, pev_weaponmodel2, NULL_STRING);

            // Start the transition
            s_rgflPlayerFixStart[pPlayer] = 0.0;
          }
        }
      } else {
        // The transition is in progress, need to check for suspended
        static pActiveItem; pActiveItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem");
        static pExpectedItem; pExpectedItem = s_rgflPlayerFixStart[pPlayer] ? s_rgpPlayerItemToDeploy[pPlayer] : s_pFakeItem;

        // If the player changed weapons during the transition. We need to fix the last item to avoid crashes.
        if (pActiveItem != pExpectedItem) {
          set_ent_data_entity(pPlayer, "CBasePlayer", "m_pLastItem", s_rgpPlayerItemToDeploy[pPlayer]);
          bShouldReleaseTransition = true;
        }
      }
    }
  } else {
    // If the new transition is requested and current transition is already started, need to suspend current transition before start
    if (pRealItem != FM_NULLENT && !s_rgflPlayerFixStart[pPlayer]) {
      bShouldReleaseTransition = true;
    }
  }

  if (!bShouldReleaseTransition) {
    // If the transition is finished
    if (s_rgflPlayerFixRelease[pPlayer] && s_rgflPlayerFixRelease[pPlayer] <= g_flGameTime) {
      // Restore a real item from the storage and redeploy
      if (s_rgpPlayerItemToDeploy[pPlayer] != FM_NULLENT) {
        if (pev_valid(s_rgpPlayerItemToDeploy[pPlayer])) {
          set_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem", s_rgpPlayerItemToDeploy[pPlayer]);
          ExecuteHamB(Ham_Item_Deploy, s_rgpPlayerItemToDeploy[pPlayer]);
        }
      }

      bShouldReleaseTransition = true;
      // client_print(0, print_console, "[%.2f] %n status: Finished", g_flGameTime, pPlayer);
    }
  }

  // If the transition need to be released (finished or suspended)
  if (bShouldReleaseTransition) {
    // Make sure that the fake item is no longer attached to the player
    if (get_ent_data_entity(s_pFakeItem, "CBasePlayerItem", "m_pPlayer") == pPlayer) {
      set_ent_data_entity(s_pFakeItem, "CBasePlayerItem", "m_pPlayer", FM_NULLENT);
      set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", 0, __UNUSED_AMMO_INDEX);
    }

    // Rollback schedule time
    if (s_rgflPlayerFixRelease[pPlayer] == s_flNextAvailableTransitionTime) {
      s_flNextAvailableTransitionTime = g_flGameTime;
    }

    // End the transition
    s_rgflPlayerFixStart[pPlayer] = 0.0;
    s_rgflPlayerFixRelease[pPlayer] = 0.0;
    s_rgpPlayerItemToDeploy[pPlayer] = FM_NULLENT;

    // client_print(0, print_console, "[%.2f] %n status: Released", g_flGameTime, pPlayer);
  }

  // New item passed. Schedule the time to process.
  if (pRealItem != FM_NULLENT) {
    // client_print(0, print_console, "[%.2f] %n requested schedule. Next available time: %.2f", g_flGameTime, pPlayer, s_flNextAvailableTransitionTime);

    // If not in transition - schedule a new transition
    if (!s_rgflPlayerFixStart[pPlayer]) {
      s_rgflPlayerFixStart[pPlayer] = (s_flNextAvailableTransitionTime > g_flGameTime) ? s_flNextAvailableTransitionTime : g_flGameTime;

      /*
        The time required to apply transform to the view model depends on the player's latency.
        A latency of about 0.1 ms takes about 1.0 seconds for the client to handle the transformation.
      */
      static iPing, iLoss; get_user_ping(pPlayer, iPing, iLoss);
      static Float:flDuration; flDuration = floatmax(float(iPing) / 1000.0, 0.01) * 10.0;

      s_rgflPlayerFixRelease[pPlayer] = s_rgflPlayerFixStart[pPlayer] + flDuration;

      s_flNextAvailableTransitionTime = s_rgflPlayerFixRelease[pPlayer];
    }

    // Store real item to redeploy after the transition
    s_rgpPlayerItemToDeploy[pPlayer] = pRealItem;

    // client_print(0, print_console, "[%.2f] %n status: Scheduled to %.2f", g_flGameTime, pPlayer, s_rgflPlayerFixStart[pPlayer]);

    return true;
  }

  // false - means no job left, can continue
  return !bShouldReleaseTransition;
}
