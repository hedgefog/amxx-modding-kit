#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <function_pointer>
#include <stack>
#include <callfunc>
#include <varargs>
#include <studiomdl>

#include <api_custom_entities_const>

#pragma semicolon 1

#define MAX_ENTITIES 2112

#define CLASS_CACHE_SIZE 128
#define CLASS_METHODS_CACHE_SIZE 64
#define CLASS_INSTANCE_CACHE_SIZE (MAX_ENTITIES + 1)

#include <cellclass>

#define ACTIVITY_NOT_AVAILABLE -1

#define method<%1::%2> any:@%1_%2
#define METHOD(%1) CE_Method_%1
#define MEMBER(%1) CE_Member_%1
#define CALL_METHOD<%1>(%2,%0) ExecuteMethod(METHOD(%1), %2, _, _, %0)
#define ARG_STRREF(%1) %1, charsmax(%1)
#define IS_NULLSTR(%1) (%1[0] == 0)

#define GET_INSTANCE(%1) (%1 <= MAX_ENTITIES ? g_rgEntityClassInstances[%1] : Invalid_ClassInstance)
#define GET_ID(%1) (%1 <= MAX_ENTITIES ? g_rgEntityIds[%1] : CE_INVALID_ID)
#define IS_CUSTOM(%1) (GET_INSTANCE(%1) != Invalid_ClassInstance && g_rgEntityIds[%1] != g_iNullId)

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define LOG_PREFIX "[CE]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define ERROR_IS_ALREADY_REGISTERED "Entity with class ^"%s^" is already registered."
#define ERROR_IS_NOT_REGISTERED "Entity ^"%s^" is not registered."
#define ERROR_IS_NOT_LINKED "Entity ^"%s^" is not linked."
#define ERROR_FUNCTION_NOT_FOUND "Function ^"%s^" not found in plugin ^"%s^"."
#define ERROR_IS_NOT_REGISTERED_BASE "Cannot extend entity class ^"%s^". The class is not exists!"
#define ERROR_CANNOT_CREATE_UNREGISTERED "Failed to create entity ^"%s^"! Entity is not registered!"
#define ERROR_CANNOT_CREATE_ABSTRACT "Failed to create entity ^"%s^"! Entity is abstract!"
#define ERROR_CANNOT_FORK_WITH_NON_RELATED_CLASS "Cannot fork entity class ^"%s^" with non-related parent class ^"%s^"!"

#define CLASS_METADATA_NAME "__NAME"
#define CLASS_METADATA_ID "__CE_ID"

#define CE_INVALID_ID -1
#define CE_INVALID_HOOK_ID -1
#define INVALID_SEQUENCE ModelSequence:(-1)

#define MAX_MODELS 128
#define MAX_SEQUENCES 2048
#define MAX_SEQUENCE_EVENTS 1024
#define MAX_ENTITY_CLASSES 512
#define MAX_HAM_HOOKS 128

enum _:GLOBALESTATE { GLOBAL_OFF = 0, GLOBAL_ON = 1, GLOBAL_DEAD = 2 };

enum ClassFlag (<<=1) {
  ClassFlag_None = 0,
  ClassFlag_Abstract = (1<<0),
  ClassFlag_Null
};

enum EntityFlag (<<=1) {
  EntityFlag_None = 0,
  EntityFlag_HasLinkedParent = 1,
  EntityFlag_IsExtension,
  EntityFlag_TouchImplemented,
  EntityFlag_ThinkImplemented
};

#define MAX_METHOD_HOOKS 64

enum EntityMethodPointer {
  EntityMethodPointer_Think,
  EntityMethodPointer_Touch,
  EntityMethodPointer_Use,
  EntityMethodPointer_Blocked
};

enum MethodParams { MethodParams_Num, ClassDataType:MethodParams_Types[6] };

enum Model {
  Float:Model_EyePosition[3],
  Model_SequencesNum,
  ModelSequence:Model_Sequences[256]
}

enum ModelSequence {
  ModelSequence_FramesNum,
  Float:ModelSequence_FPS,
  ModelSequence_Flags,
  ModelSequence_Activity,
  ModelSequence_ActivityWeight,
  ModelSequence_EventsNum,
  Float:ModelSequence_LinearMovement[3],
  ModelSequence_Events[16]
};

STACK_DEFINE(METHOD_PLUGIN, 256);
STACK_DEFINE(METHOD_RETURN, 256);
STACK_DEFINE(METHOD_HOOKS_Pre, 256);
STACK_DEFINE(METHOD_HOOKS_Post, 256);
STACK_DEFINE(KEY_MEMBER_BINDINGS, 256);

new bool:g_bIsCStrike = false;
new bool:g_bPrecache = false;
new Float:g_flGameTime = 0.0;

new Trie:g_itEntityIds = Invalid_Trie;
new Trie:g_itEntityHooks = Invalid_Trie;
new Trie:g_itAllocatedStrings = Invalid_Trie;

new const g_rgMethodParams[CE_Method][MethodParams];
new const g_rgszMethodNames[CE_Method][CE_MAX_METHOD_NAME_LENGTH];

new g_rgiClassIds[MAX_ENTITY_CLASSES];
new Class:g_rgcClasses[MAX_ENTITY_CLASSES];
new EntityFlag:g_rgiClassEntityFlags[MAX_ENTITY_CLASSES];
new ClassFlag:g_rgiClassFlags[MAX_ENTITY_CLASSES];
new Trie:g_rgitClassKeyMemberBindings[MAX_ENTITY_CLASSES];
new Function:g_rgrgrgfnClassMethodPreHooks[MAX_ENTITY_CLASSES][CE_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPreHooksNum[MAX_ENTITY_CLASSES][CE_Method];
new Function:g_rgrgrgfnClassMethodPostHooks[MAX_ENTITY_CLASSES][CE_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPostHooksNum[MAX_ENTITY_CLASSES][CE_Method];
new g_rgszClassLinkedClassnames[MAX_ENTITY_CLASSES][32];
new g_rgszClassClassnames[MAX_ENTITY_CLASSES][CE_MAX_NAME_LENGTH];
new g_iClassesNum = 0;

new ClassInstance:g_rgEntityClassInstances[MAX_ENTITIES + 1] = { Invalid_ClassInstance, ... };
new Struct:g_rgEntityMethodPointers[MAX_ENTITIES + 1][EntityMethodPointer];

new g_iBaseId = CE_INVALID_ID;
new g_iNullId = CE_INVALID_ID;

new g_rgEntityIds[MAX_ENTITIES + 1];
new g_rgiEntitySequences[MAX_ENTITIES + 1];
new g_rgiEntityModelIndexes[MAX_ENTITIES + 1];
new g_rgiEntityModels[MAX_ENTITIES + 1];
new bool:g_rgbEntityForceVisible[MAX_ENTITIES + 1];
new g_iMaxEntities = 0;
new g_iForceEntitiesVisibleNum = 0;

new Trie:g_itLoadedModels = Invalid_Trie;
new g_rgModel[MAX_MODELS][Model];
new g_iModelsNum = 0;
new g_rgModelSequences[ModelSequence:MAX_SEQUENCES][ModelSequence];
new g_iModelSequencesNum = 0;
new g_rgModelEvents[MAX_SEQUENCE_EVENTS][mstudioevent];
new g_iModelEventsNum = 0;
new g_iInstancesNum = 0;

new g_pfwfmCheckVisibility = 0;
new g_pfwfmAddToFullPackPost = 0;

new HamHook:g_rgpfwhamDynamicHooks[MAX_HAM_HOOKS];
new g_iDynamicHooksNum = 0;

new bool:g_bDynamicHooksEnabled = false;

public plugin_precache() {
  g_bPrecache = true;
  g_bIsCStrike = !!cstrike_running();
  g_iMaxEntities = min(global_get(glb_maxEntities), MAX_ENTITIES);

  register_forward(FM_CreateNamedEntity, "FMHook_CreateNamedEntity_Post", 1);
  register_forward(FM_Spawn, "FMHook_Spawn");
  register_forward(FM_KeyValue, "FMHook_KeyValue");
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");

  InitStorages();
  InitBaseClasses();
}

public plugin_init() {
  g_bPrecache = false;
  register_plugin("[API] Custom Entities", "2.0.0", "Hedgehog Fog");

  register_concmd("ce_spawn", "Command_Spawn", ADMIN_CVAR);
  register_concmd("ce_get_member", "Command_GetMember", ADMIN_CVAR);
  register_concmd("ce_get_member_float", "Command_GetMemberFloat", ADMIN_CVAR);
  register_concmd("ce_get_member_string", "Command_GetMemberString", ADMIN_CVAR);
  register_concmd("ce_set_member", "Command_SetMember", ADMIN_CVAR);
  register_concmd("ce_delete_member", "Command_DeleteMember", ADMIN_CVAR);
  register_concmd("ce_call_method", "Command_CallMethod", ADMIN_CVAR);
  register_concmd("ce_list", "Command_List", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_custom_entities");

  register_native("CE_RegisterClass", "Native_Register");
  register_native("CE_ExtendClass", "Native_Extend");
  register_native("CE_ForkClass", "Native_ForkClass");
  register_native("CE_RegisterClassAlias", "Native_RegisterAlias");
  register_native("CE_RegisterNullClass", "Native_RegisterNull"); 
  register_native("CE_IsClassRegistered", "Native_IsClassRegistered");
  register_native("CE_GetClassHandle", "Native_GetClassHandle");

  register_native("CE_RegisterClassKeyMemberBinding", "Native_RegisterKeyMemberBinding");
  register_native("CE_RemoveClassKeyMemberBinding", "Native_RemoveMemberBinding");

  register_native("CE_RegisterClassMethod", "Native_RegisterMethod");
  register_native("CE_ImplementClassMethod", "Native_ImplementMethod");
  register_native("CE_RegisterClassVirtualMethod", "Native_RegisterVirtualMethod");

  register_native("CE_RegisterClassNativeMethodHook", "Native_RegisterMethodHook");
  register_native("CE_GetMethodReturn", "Native_GetMethodReturn");
  register_native("CE_SetMethodReturn", "Native_SetMethodReturn");

  register_native("CE_Create", "Native_Create");
  register_native("CE_GetHandle", "Native_GetHandle");
  register_native("CE_IsInstanceOf", "Native_IsInstanceOf");

  register_native("CE_SetThink", "Native_SetThink");
  register_native("CE_SetTouch", "Native_SetTouch");
  register_native("CE_SetUse", "Native_SetUse");
  register_native("CE_SetBlocked", "Native_SetBlocked");

  register_native("CE_HasMember", "Native_HasMember");
  register_native("CE_GetMember", "Native_GetMember");
  register_native("CE_DeleteMember", "Native_DeleteMember");
  register_native("CE_SetMember", "Native_SetMember");
  register_native("CE_GetMemberVec", "Native_GetMemberVec");
  register_native("CE_SetMemberVec", "Native_SetMemberVec");
  register_native("CE_GetMemberString", "Native_GetMemberString");
  register_native("CE_SetMemberString", "Native_SetMemberString");

  register_native("CE_CallMethod", "Native_CallMethod");
  register_native("CE_CallBaseMethod", "Native_CallBaseMethod");
  register_native("CE_CallNativeMethod", "Native_CallNativeMethod");
  register_native("CE_GetCallerPlugin", "Native_GetCallPluginId");

  register_native("CE_Find", "Native_Find");
}

public plugin_end() {
  FreeEntities();
  DestroyRegisteredClasses();
  DestroyStorages();
}

public client_putinserver(pPlayer) {
  static iId; iId = GetIdByClassName("player");

  if (iId != CE_INVALID_ID) {
    new ClassInstance:pInstance = GET_INSTANCE(pPlayer);
    if (pInstance == Invalid_ClassInstance && g_rgiClassEntityFlags[iId] & EntityFlag_IsExtension) {
      @Entity_CreateInstance(pPlayer, iId, false);
    }
  }
}

public client_disconnected(pPlayer) {
  if (IS_CUSTOM(pPlayer)) {
    @Entity_Destroy(pPlayer);
  }
}

public server_frame() {
  g_flGameTime = get_gametime();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szBaseClassName[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szBaseClassName));
  new bool:bAbstract = bool:get_param(3);

  new ClassFlag:iFlags = bAbstract ? ClassFlag_Abstract : ClassFlag_None;

  if (IS_NULLSTR(szBaseClassName)) {
    copy(ARG_STRREF(szBaseClassName), CE_Class_Base);
  }
  
  return RegisterClass(szClassname, szBaseClassName, iFlags);
}

public Native_RegisterNull(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  if (GetIdByClassName(szClassname) != CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_ALREADY_REGISTERED, szClassname);
    return;
  }

  TrieSetCell(g_itEntityIds, szClassname, g_iNullId);
}

public Native_Extend(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  if (!UTIL_IsClassnameLinked(szClassname)) {
    LOG_ERROR(ERROR_IS_NOT_LINKED, szClassname);
    return CE_INVALID_ID;
  }

  return RegisterClass(szClassname, szClassname);
}

public Native_ForkClass(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szOriginalClassName[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szOriginalClassName));
  new szBaseClassName[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szBaseClassName));

  if (GetIdByClassName(szClassname) != CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_ALREADY_REGISTERED, szClassname);
    return CE_INVALID_ID;
  }

  if (GetIdByClassName(szOriginalClassName) == CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szOriginalClassName);
    return CE_INVALID_ID;
  }

  if (!equal(szBaseClassName, NULL_STRING) && GetIdByClassName(szBaseClassName) == CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED_BASE, szBaseClassName);
    return CE_INVALID_ID;
  }

  return ForkClass(szClassname, szOriginalClassName, szBaseClassName);
}

public Native_RegisterAlias(const iPluginId, const iArgc) {
  new szAlias[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szAlias));
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));

  if (GetIdByClassName(szAlias) != CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_ALREADY_REGISTERED, szAlias);
    return;
  }

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  TrieSetCell(g_itEntityIds, szAlias, iId);
}

public bool:Native_IsClassRegistered(const iPluginId, const iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

  return GetIdByClassName(szClassname) != CE_INVALID_ID;
}

public Native_RegisterMethodHook(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new CE_Method:iMethod = CE_Method:get_param(2);
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));
  new bool:bPost = bool:get_param(4);

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
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
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
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
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
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
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new CE_Method:iMethod = CE_Method:get_param(2);
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, ARG_STRREF(szCallback));

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
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
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);
  static bool:bTemp; bTemp = !!get_param(3);

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    LOG_ERROR(ERROR_CANNOT_CREATE_UNREGISTERED, szClassname);
    return FM_NULLENT;
  }

  new pEntity = CreateEntity(iId, vecOrigin, bTemp);
  if (pEntity == FM_NULLENT) return FM_NULLENT;

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  ClassInstanceSetMember(pInstance, MEMBER(PluginId), iPluginId);

  return pEntity;
}

public Native_RegisterKeyMemberBinding(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szMember));
  new CEMemberType:iType = CEMemberType:get_param(4);

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  RegisterClassKeyMemberBinding(iId, szKey, szMember, iType);
}

public Native_RemoveMemberBinding(const iPluginId, const iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szMember));

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    LOG_ERROR(ERROR_IS_NOT_REGISTERED, szClassname);
    return;
  }

  RemoveEntityClassKeyMemberBinding(iId, szKey, szMember);
}

public Native_GetClassHandle(const iPluginId, const iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));

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

  static szClassname[CE_MAX_NAME_LENGTH]; get_string(2, ARG_STRREF(szClassname));
  static iTargetId; iTargetId = GetIdByClassName(szClassname);
  if (iTargetId == CE_INVALID_ID) return false;

  return ClassInstanceIsInstanceOf(pInstance, g_rgcClasses[iTargetId]);
}

public bool:Native_HasMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return 0;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceGetMember(pInstance, szMember);
}

public bool:Native_DeleteMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  return ClassInstanceDeleteMember(pInstance, szMember);
}

public bool:Native_SetMember(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static iValue; iValue = get_param(3);
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public bool:Native_GetMemberVec(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public bool:Native_SetMemberVec(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public bool:Native_GetMemberString(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, ARG_STRREF(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public bool:Native_SetMemberString(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return false;

  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, ARG_STRREF(szMember));
  static szValue[128]; get_string(3, ARG_STRREF(szValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  return ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public any:Native_CallMethod(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));

  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  /*
    When executing hooks, we need to force the correct class context
    since hooks are called from base class methods but may need to call
    derived class methods. This prevents the call stack from incorrectly
    resolving method calls to the base class implementation.
  */
  static Class:class; class = Invalid_Class;
  if (!STACK_EMPTY(METHOD_HOOKS_Pre) || !STACK_EMPTY(METHOD_HOOKS_Post)) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
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
  static CE_Method:iMethod; iMethod = CE_Method:get_param(2);

  if (!IS_CUSTOM(pEntity)) return 0;
  
  return ExecuteMethod(iMethod, pEntity, 3, iArgc);
}

public Native_GetCallPluginId(const iPluginId, const iArgc) {
  return STACK_READ(METHOD_PLUGIN);
}

public Native_SetThink(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Think, szMethod, szClassname);
}

public Native_SetTouch(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Touch, szMethod, szClassname);
}

public Native_SetUse(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Use, szMethod, szClassname);
}

public Native_SetBlocked(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, ARG_STRREF(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, ARG_STRREF(szClassname));

  @Entity_SetMethodPointer(pEntity, EntityMethodPointer_Blocked, szMethod, szClassname);
}

public any:Native_GetMethodReturn(const iPluginId, const iArgc) {
  return STACK_READ(METHOD_RETURN);
}

public any:Native_SetMethodReturn(const iPluginId, const iArgc) {
  STACK_PATCH(METHOD_RETURN, any:get_param(1));
}

public Native_Find(const iPluginId, const iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, ARG_STRREF(szClassname));
  static pEntity; pEntity = max(get_param(2), 0);
  static bool:bExact; bExact = bool:get_param(3);

  if (IS_NULLSTR(szClassname)) return FM_NULLENT;

  static iId; iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) return FM_NULLENT;

  static iCounter; iCounter = 0;

  for (++pEntity; pEntity <= g_iMaxEntities; ++pEntity) {
    // static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
    // if (pInstance == Invalid_ClassInstance) continue;
    if (!IS_CUSTOM(pEntity)) continue;

    iCounter++;

    if (g_rgEntityIds[pEntity] == iId) return pEntity;

    if (!bExact) {
      if (ClassInstanceIsInstanceOf(g_rgEntityClassInstances[pEntity], g_rgcClasses[iId])) return pEntity;
    }

    if (iCounter >= g_iInstancesNum) break;
  }

  return FM_NULLENT;
}

/*--------------------------------[ Natives Util Functions ]--------------------------------*/

Array:ReadMethodRegistrationParamsFromNativeCall(iStartArg, iArgc) {
  static Array:irgParams; irgParams = ArrayCreate();

  static iParam;
  for (iParam = iStartArg; iParam <= iArgc; ++iParam) {
    static iType; iType = get_param_byref(iParam);

    switch (iType) {
      case CE_Type_Cell: {
        ArrayPushCell(irgParams, ClassDataType_Cell);
      }
      case CE_Type_String: {
        ArrayPushCell(irgParams, ClassDataType_String);
      }
      case CE_Type_Array: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, get_param_byref(iParam + 1));
        iParam++;
      }
      case CE_Type_Vector: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, 3);
      }
      case CE_Type_CellRef: {
        ArrayPushCell(irgParams, ClassDataType_CellRef);
      }
    }
  }

  return irgParams;
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Spawn(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szClassname[32]; read_argv(1, ARG_STRREF(szClassname));

  if (IS_NULLSTR(szClassname)) return PLUGIN_HANDLED;

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) return PLUGIN_HANDLED;

  new Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
  new Float:vecAngles[3]; pev(pPlayer, pev_angles, vecAngles);
  
  new pEntity = CreateEntity(iId, vecOrigin, true);
  if (pEntity == FM_NULLENT) return PLUGIN_HANDLED;
  set_pev(pEntity, pev_angles, vecAngles);

  new iArgsNum = read_argc();
  if (iArgsNum > 2) {
    new ClassInstance:pInstance = GET_INSTANCE(pEntity);

    for (new iArg = 2; iArg < iArgsNum; iArg += 2) {
      static szMember[32]; read_argv(iArg, ARG_STRREF(szMember));
      static szValue[32]; read_argv(iArg + 1, ARG_STRREF(szValue));
      static iType; iType = UTIL_GetStringType(szValue);

      switch (iType) {
        case 'i': ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
        case 'f': ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
        case 's': ClassInstanceSetMemberString(pInstance, szMember, szValue);
      }
    }
  }

  dllfunc(DLLFunc_Spawn, pEntity);

  console_print(pPlayer, "Entity ^"%s^" successfully spawned! Entity index: %d", szClassname, pEntity);

  return PLUGIN_HANDLED;
}

public Command_GetMember(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, ARG_STRREF(szMember));

  console_print(pPlayer, "Member ^"%s^" value: %d", szMember, ClassInstanceGetMember(pInstance, szMember));

  return PLUGIN_HANDLED;
}

public Command_GetMemberFloat(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, ARG_STRREF(szMember));

  console_print(pPlayer, "Member ^"%s^" value: %f", szMember, Float:ClassInstanceGetMember(pInstance, szMember));

  return PLUGIN_HANDLED;
}

public Command_GetMemberString(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, ARG_STRREF(szMember));

  static szValue[64]; ClassInstanceGetMemberString(pInstance, szMember, ARG_STRREF(szValue));
  console_print(pPlayer, "Member ^"%s^" value: ^"%s^"", szMember, szValue);

  return PLUGIN_HANDLED;
}

public Command_SetMember(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;

  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, ARG_STRREF(szMember));

  static szValue[32]; read_argv(3, ARG_STRREF(szValue));
  static iType; iType = UTIL_GetStringType(szValue);

  switch (iType) {
    case 'i': ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
    case 'f': ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
    case 's': ClassInstanceSetMemberString(pInstance, szMember, szValue);
  }

  switch (iType) {
    case 'i', 'f': console_print(pPlayer, "^"%s^" member set to %s", szMember, szValue);
    case 's': console_print(pPlayer, "^"%s^" member set to ^"%s^"", szMember, szValue);
  }

  return PLUGIN_HANDLED;
}

public Command_DeleteMember(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, ARG_STRREF(szMember));

  ClassInstanceDeleteMember(pInstance, szMember);

  console_print(pPlayer, "^"%s^" member deleted", szMember);

  return PLUGIN_HANDLED;
}

public Command_CallMethod(const pPlayer, const iLevel, const iCId) {
  static const iMethodArgOffset = 4;

  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;

  new pEntity = read_argv_int(1);
  new iArgsNum = read_argc();

  new ClassInstance:pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szClassname[32]; read_argv(2, ARG_STRREF(szClassname));

  if (IS_NULLSTR(szClassname)) return PLUGIN_HANDLED;

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) return PLUGIN_HANDLED;

  if (!ClassInstanceIsInstanceOf(pInstance, g_rgcClasses[iId])) {
    console_print(pPlayer, "Entity %d is not instance of ^"%s^"", pEntity, szClassname);
    return PLUGIN_HANDLED;
  }

  static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(3, ARG_STRREF(szMethod));

  new iParamTypesNum;
  if (!ClassInstanceMethodExists(pInstance, szMethod, iParamTypesNum)) {
    console_print(pPlayer, "Method ^"%s^" does not exist in class ^"%s^"", szMethod, szClassname);
    return PLUGIN_HANDLED;
  }

  // Remove entity parameter from the number of parameters
  iParamTypesNum -= 1;

  new iMethodArgsNum = iArgsNum - iMethodArgOffset;
  if (iMethodArgsNum < iParamTypesNum) {
    console_print(pPlayer, "Method ^"%s^" requires %d parameters, but %d were provided", szMethod, iParamTypesNum, iMethodArgsNum);
    return PLUGIN_HANDLED;
  }

  ClassInstanceCallMethodBegin(pInstance, szMethod, g_rgcClasses[iId]);

  ClassInstanceCallMethodPushParamCell(pEntity);

  for (new iArg = iMethodArgOffset; iArg < iArgsNum; ++iArg) {
    static szArg[128]; read_argv(iArg, ARG_STRREF(szArg));
    static iType; iType = UTIL_GetStringType(szArg);

    switch (iType) {
      case 'i': ClassInstanceCallMethodPushParamCell(str_to_num(szArg));
      case 'f': ClassInstanceCallMethodPushParamCell(str_to_float(szArg));
      case 's': ClassInstanceCallMethodPushParamString(szArg);
    }
  }

  new any:result = ClassInstanceCallMethodEnd();

  console_print(pPlayer, "Call ^"%s^" result: (int)%d (float)%f", szMethod, result, result);

  return PLUGIN_HANDLED;
}

public Command_List(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 1)) return PLUGIN_HANDLED;

  new iArgsNum = read_argc();

  static szFilter[32]; 
  
  if (iArgsNum >= 2) {
    read_argv(1, ARG_STRREF(szFilter));
  } else {
    copy(ARG_STRREF(szFilter), "*");
  }

  new iStart = iArgsNum >= 3 ? read_argv_int(2) : 0;
  new iLimit = iArgsNum >= 4 ? read_argv_int(3) : 10;

  new iShowedEntitiesNum = 0;
  new iEntitiesNum = 0;

  // console_print(pPlayer, "Finding entities { Start: %d; Limit: %d; Filter: ^"%s^" }", iStart, iLimit, szFilter);
  // console_print(pPlayer, "---- Found entities ----");

  for (new pEntity = iStart; pEntity <= g_iMaxEntities; ++pEntity) {
    if (!IS_CUSTOM(pEntity)) continue;

    static ClassInstance:pInstance; pInstance = g_rgEntityClassInstances[pEntity];
    static Class:class; class = ClassInstanceGetClass(pInstance);
    // static iId; iId = ClassGetMetadata(class, CLASS_METADATA_ID);
    static szClassname[CE_MAX_NAME_LENGTH]; ClassGetMetadataString(class, CLASS_METADATA_NAME, ARG_STRREF(szClassname));

    if (!equal(szFilter, "*") && strfind(szClassname, szFilter, true) == -1) continue;

    static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);

    if (iShowedEntitiesNum < iLimit) {
      console_print(pPlayer, "[%d]^t%s^t{%.3f, %.3f, %.3f}", pEntity, szClassname, vecOrigin[0], vecOrigin[1], vecOrigin[2]);
      iShowedEntitiesNum++;
    }

    iEntitiesNum++;
  }

  // console_print(pPlayer, "Found %d entities. %d of %d are entities showed.", iEntitiesNum, iShowedEntitiesNum, iEntitiesNum);

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Hooks ]--------------------------------*/

HamHook:InitHamHooks(const szClassname[]) {
  if (TrieKeyExists(g_itEntityHooks, szClassname)) return;

  RegisterHam(Ham_Spawn, szClassname, "HamHook_Base_Spawn", .Post = 0);
  RegisterHam(Ham_ObjectCaps, szClassname, "HamHook_Base_ObjectCaps", .Post = 0);
  RegisterHam(Ham_Use, szClassname, "HamHook_Base_Use", .Post = 0);
  RegisterHam(Ham_Killed, szClassname, "HamHook_Base_Killed", .Post = 0);
  RegisterHam(Ham_BloodColor, szClassname, "HamHook_Base_BloodColor", .Post = 0);
  RegisterHam(Ham_GetDelay, szClassname, "HamHook_Base_GetDelay", .Post = 0);
  RegisterHam(Ham_Classify, szClassname, "HamHook_Base_Classify", .Post = 0);
  RegisterHam(Ham_IsTriggered, szClassname, "HamHook_Base_IsTriggered", .Post = 0);
  RegisterHam(Ham_GetToggleState, szClassname, "HamHook_Base_GetToggleState", .Post = 0);
  RegisterHam(Ham_SetToggleState, szClassname, "HamHook_Base_SetToggleState", .Post = 0);
  RegisterHam(Ham_Respawn, szClassname, "HamHook_Base_Respawn", .Post = 0);
  RegisterHam(Ham_TraceAttack, szClassname, "HamHook_Base_TraceAttack", .Post = 0);
  RegisterHam(Ham_TakeDamage, szClassname, "HamHook_Base_TakeDamage", .Post = 0);
  RegisterHam(Ham_Activate, szClassname, "HamHook_Base_Activate", .Post = 0);

  if (g_bIsCStrike) {
    RegisterHam(Ham_CS_Restart, szClassname, "HamHook_Base_Restart", .Post = 0);
  }

  RegisterDynamicHam(Ham_Touch, szClassname, "HamHook_Base_Touch", false);
  RegisterDynamicHam(Ham_Blocked, szClassname, "HamHook_Base_Blocked", false);
  RegisterDynamicHam(Ham_Think, szClassname, "HamHook_Base_Think", false);
  RegisterDynamicHam(Ham_IsMoving, szClassname, "HamHook_Base_IsMoving", false);

  TrieSetCell(g_itEntityHooks, szClassname, 1);
}

HamHook:RegisterDynamicHam(Ham:iFunction, const szClassname[], const szCallback[], bool:bPost) {
  new iId = g_iDynamicHooksNum;

  g_rgpfwhamDynamicHooks[iId] = RegisterHam(iFunction, szClassname, szCallback, bPost);
  g_iDynamicHooksNum++;

  DisableHamForward(g_rgpfwhamDynamicHooks[iId]);

  return g_rgpfwhamDynamicHooks[iId];
}

EnableDynamicHooks() {
  if (g_bDynamicHooksEnabled) return;

  g_pfwfmAddToFullPackPost = register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);

  for (new iId = 0; iId < g_iDynamicHooksNum; ++iId) {
    EnableHamForward(g_rgpfwhamDynamicHooks[iId]);
  }

  g_bDynamicHooksEnabled = true;
}

DisableDynamicHooks() {
  if (!g_bDynamicHooksEnabled) return;

  unregister_forward(FM_AddToFullPack, g_pfwfmAddToFullPackPost, 1);

  for (new iId = 0; iId < g_iDynamicHooksNum; ++iId) {
    DisableHamForward(g_rgpfwhamDynamicHooks[iId]);
  }

  g_bDynamicHooksEnabled = false;
}

public FMHook_OnFreeEntPrivateData(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    // if (!pev_valid(pEntity)) return;
    @Entity_Destroy(pEntity);
  }
}

public FMHook_CheckVisibility(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    if (g_rgbEntityForceVisible[pEntity]) {
      forward_return(FMV_CELL, 1);
      return FMRES_SUPERCEDE;
    }

    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

public FMHook_AddToFullPack_Post(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const iSetFlags) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(pEntity);
  if (pInstance == Invalid_ClassInstance) return FMRES_IGNORED;
  if (!pev(pEntity, pev_modelindex)) return FMRES_IGNORED;
  if (!ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) return FMRES_IGNORED;
  if (ClassInstanceGetMember(pInstance, MEMBER(bSequenceLoops))) return FMRES_IGNORED;

  static Float:flSequenceFrameRate; flSequenceFrameRate = ClassInstanceGetMember(pInstance, MEMBER(flSequenceFrameRate));
  static Float:flFrame; pev(pEntity, pev_frame, flFrame);
  static Float:flAnimTime; pev(pEntity, pev_animtime, flAnimTime);

  // Calculate predicted frame
  flFrame = floatclamp(flFrame + ((g_flGameTime - flAnimTime) * flSequenceFrameRate), 0.0, 256.0);

  /*
    !!!HACKHACK: Used to prevent animation lag for entities that handling animation events

    By blocking client interpolation for last frames of the entity that handling by animation events,
    we prevent animation lag for entities that handling animation events.
  */
  if (flFrame >= (256.0 - (flSequenceFrameRate * 0.1))) {
    set_es(es, ES_FrameRate, 0.0);
  }

  set_es(es, ES_Frame, flFrame);
  set_es(es, ES_Sequence, g_rgiEntitySequences[pEntity]);

  return FMRES_HANDLED;
}

public FMHook_KeyValue(pEntity, hKVD) {
  @Entity_KeyValue(pEntity, hKVD);

  return FMRES_HANDLED;
}

public FMHook_CreateNamedEntity_Post(const iClassname) {
  static pEntity; pEntity = get_orig_retval();
  static szClassname[CE_MAX_NAME_LENGTH]; engfunc(EngFunc_SzFromIndex, iClassname, ARG_STRREF(szClassname));
  static iId; iId = GetIdByClassName(szClassname);

  if (iId == g_iNullId) return;

  /*
    Allocates instances for extended linked entities that are created dynamically at runtime.

    Entities are typically created during map loading through KeyValueData (KVD). 
    However, in rare cases, some entities are spawned in real-time during gameplay.
    These real-time creations still need custom instances to be allocated, 
    particularly for entities that are flagged for extension functionality.

    This ensures that all extended entities, even those created outside the normal map loading process,
    are properly initialized with their corresponding custom instances.
  */
  if (iId != CE_INVALID_ID) {
    new ClassInstance:pInstance = GET_INSTANCE(pEntity);
    if (pInstance == Invalid_ClassInstance) {
      @Entity_CreateInstance(pEntity, iId, false);
    }
  }
}

public FMHook_Spawn(const pEntity) {
  new ClassInstance:pInstance = GET_INSTANCE(pEntity);

  // Update entity classname (in case entity spawned by the engine)
  if (pInstance != Invalid_ClassInstance) {
    static Class:class; class = ClassInstanceGetClass(pInstance);

    static szClassname[CE_MAX_NAME_LENGTH];
    ClassGetMetadataString(class, CLASS_METADATA_NAME, ARG_STRREF(szClassname));
    set_pev(pEntity, pev_classname, szClassname);
  }
}

public HamHook_Base_Spawn(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    if (pev_valid(pEntity) && ~pev(pEntity, pev_flags) & FL_KILLME) {
      CALL_METHOD<ResetVariables>(pEntity, 0);
      CALL_METHOD<Spawn>(pEntity, 0);
    }

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_ObjectCaps(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    new iObjectCaps = CALL_METHOD<ObjectCaps>(pEntity, 0);
    SetHamReturnInteger(iObjectCaps);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Restart(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Restart>(pEntity, 0);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Touch(const pEntity, const pToucher) {
  if (IS_CUSTOM(pEntity)) {
    static iId; iId = GET_ID(pEntity);

    if (
      Struct:g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Touch] == Invalid_Struct &&
      !(g_rgiClassEntityFlags[iId] & EntityFlag_TouchImplemented)
    ) {
      return HAM_HANDLED;
    }

    CALL_METHOD<Touch>(pEntity, pToucher);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Use(const pEntity, const pCaller, const pActivator, iUseType, Float:flValue) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Use>(pEntity, pActivator, pCaller, iUseType, flValue);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Blocked(const pEntity, const pOther) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Blocked>(pEntity, pOther);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Killed(const pEntity, const pKiller, iShouldGib) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Killed>(pEntity, pKiller, iShouldGib);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Think(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    if (~pev(pEntity, pev_flags) & FL_KILLME) {
      // static iId; iId = GET_ID(pEntity);

      // if (
      //   Struct:g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Think] == Invalid_Struct &&
      //   !(g_rgiClassEntityFlags[iId] & EntityFlag_ThinkImplemented)
      // ) {
      //   return HAM_HANDLED;
      // }

      static szClassname[32]; pev(pEntity, pev_classname, szClassname, charsmax(szClassname));

      CALL_METHOD<Think>(pEntity, 0);
    }

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_BloodColor(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    static iBloodColor; iBloodColor = CALL_METHOD<BloodColor>(pEntity, 0);
    SetHamReturnInteger(iBloodColor);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_GetDelay(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    static Float:flDelay; flDelay = CALL_METHOD<GetDelay>(pEntity, 0);
    SetHamReturnFloat(flDelay);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Classify(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    static iClass; iClass = CALL_METHOD<Classify>(pEntity, 0);
    SetHamReturnInteger(iClass);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_IsTriggered(const pEntity, const pActivator) {
  if (IS_CUSTOM(pEntity)) {
    static iTriggered; iTriggered = CALL_METHOD<IsTriggered>(pEntity, pActivator);
    SetHamReturnInteger(iTriggered);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_GetToggleState(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    static iState; iState = CALL_METHOD<GetToggleState>(pEntity, 0);
    SetHamReturnInteger(iState);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_SetToggleState(const pEntity, iState) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<SetToggleState>(pEntity, iState);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Respawn(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Respawn>(pEntity, 0);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_TraceAttack(const pEntity, const pAttacker, Float:flDamage, const Float:vecDirection[3], pTrace, iDamageBits) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<TraceAttack>(pEntity, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_TakeDamage(const pEntity, const pInflictor, const pAttacker, Float:flDamage, iDamageBits) {
  if (IS_CUSTOM(pEntity)) {
    new iResult = CALL_METHOD<TakeDamage>(pEntity, pInflictor, pAttacker, flDamage, iDamageBits);
    SetHamReturnInteger(iResult);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Activate(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    CALL_METHOD<Activate>(pEntity, 0);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_IsMoving(const pEntity) {
  if (IS_CUSTOM(pEntity)) {
    static iResult; iResult = CALL_METHOD<IsMoving>(pEntity, 0);
    SetHamReturnInteger(iResult);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

/*--------------------------------[ Entity Hookable Methods ]--------------------------------*/

ClassInstance:@Entity_CreateInstance(const &this, iId, bool:bTemp) {
  if (this > g_iMaxEntities) return Invalid_ClassInstance;

  static ClassInstance:pInstance; pInstance = ClassInstanceCreate(g_rgcClasses[iId]);

  // log_amx("Entity_CreateInstance: %d %d", iId, pInstance);

  pInstance = ClassInstanceCache(pInstance);

  // log_amx("Entity_CreateInstance (cached): %d %d", iId, pInstance);

  ClassInstanceSetMember(pInstance, MEMBER(Id), iId);
  ClassInstanceSetMember(pInstance, MEMBER(Pointer), this);
  ClassInstanceSetMember(pInstance, MEMBER(bWorld), !bTemp);
  ClassInstanceSetMember(pInstance, MEMBER(bForceVisible), false);

  g_rgEntityClassInstances[this] = pInstance;
  g_rgEntityIds[this] = iId;
  g_rgiEntitySequences[this] = -1;
  g_rgiEntityModels[this] = -1;
  g_rgiEntityModelIndexes[this] = 0;

  for (new EntityMethodPointer:iMethodPointer = EntityMethodPointer:0; iMethodPointer < EntityMethodPointer; ++iMethodPointer) {
    g_rgEntityMethodPointers[this][iMethodPointer] = Invalid_Struct;
  }

  g_iInstancesNum++;

  CALL_METHOD<Create>(this, 0);

  g_rgbEntityForceVisible[this] = ClassInstanceGetMember(pInstance, MEMBER(bForceVisible));

  if (g_rgbEntityForceVisible[this]) {
    g_iForceEntitiesVisibleNum++;
  }

  UpdateForwards();

  return pInstance;
}

@Entity_KeyValue(const &this, const &hKVD) {
  static szKey[32]; get_kvd(hKVD, KV_KeyName, ARG_STRREF(szKey));
  static szValue[64]; get_kvd(hKVD, KV_Value, ARG_STRREF(szValue));
  
  if (equal(szKey, "classname")) {
    new iId = GetIdByClassName(szValue);
    if (iId != CE_INVALID_ID) {
      // using set_kvd leads to duplicate kvd emit, this check will fix the issue
      if (GET_INSTANCE(this) == Invalid_ClassInstance) {
        if (~g_rgiClassFlags[iId] & ClassFlag_Abstract) {

          static szParent[CE_MAX_NAME_LENGTH]; copy(ARG_STRREF(szParent), g_rgszClassLinkedClassnames[iId]);

          // if (IS_NULLSTR(szParent)) {
          //   copy(ARG_STRREF(szParent), CE_BASE_CLASSNAME);
          // }

          set_kvd(hKVD, KV_Value, szParent);

          if (iId != g_iNullId) {
            @Entity_CreateInstance(this, iId, false);
          }
        }
      }
    } else {
      // if for some reason data was not assigned
      if (GET_INSTANCE(this) != Invalid_ClassInstance) {
        @Entity_Destroy(this);
      }
    }
  }

  if (GET_ID(this) == g_iNullId) return;

  new ClassInstance:pInstance = GET_INSTANCE(this);
  if (pInstance == Invalid_ClassInstance) return;

  CALL_METHOD<KeyValue>(this, szKey, szValue);
  @Entity_HandleKeyMemberBinding(this, szKey, szValue);
}

@Entity_Destroy(const &this) {
  if (g_rgEntityIds[this] == g_iNullId) return;

  CALL_METHOD<Destroy>(this, 0);
  ClassInstanceDestroy(g_rgEntityClassInstances[this]);
  g_rgEntityClassInstances[this] = Invalid_ClassInstance;
  g_rgEntityIds[this] = CE_INVALID_ID;
  g_iInstancesNum--;

  if (g_rgbEntityForceVisible[this]) {
    g_iForceEntitiesVisibleNum--;
    g_rgbEntityForceVisible[this] = false;
  }

  UpdateForwards();
}

@Entity_HandleKeyMemberBinding(const &this, const szKey[], const szValue[]) {
  new iId = GET_ID(this);
  new ClassInstance:pInstance = GET_INSTANCE(this);

  for (new Class:cCurrent = g_rgcClasses[iId]; cCurrent != Invalid_Class; cCurrent = ClassGetBaseClass(cCurrent)) {
    static iId; iId = ClassGetMetadata(cCurrent, CLASS_METADATA_ID);
    STACK_PUSH(KEY_MEMBER_BINDINGS, iId);
  }

  while (!STACK_EMPTY(KEY_MEMBER_BINDINGS)) {
    static iId; iId = STACK_POP(KEY_MEMBER_BINDINGS);

    if (g_rgitClassKeyMemberBindings[iId] == Invalid_Trie) continue;

    static Trie:itMemberTypes; itMemberTypes = Invalid_Trie;
    if (!TrieGetCell(g_rgitClassKeyMemberBindings[iId], szKey, itMemberTypes)) continue;

    static TrieIter:itMemberTypesIter;

    for (itMemberTypesIter = TrieIterCreate(itMemberTypes); !TrieIterEnded(itMemberTypesIter); TrieIterNext(itMemberTypesIter)) {
      static szMember[32]; TrieIterGetKey(itMemberTypesIter, ARG_STRREF(szMember));
      static CEMemberType:iType; TrieIterGetCell(itMemberTypesIter, iType);

      switch (iType) {
        case CEMemberType_Cell: {
          ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
        }
        case CEMemberType_Float: {
          ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
        }
        case CEMemberType_String: {
          ClassInstanceSetMemberString(pInstance, szMember, szValue);
        }
        case CEMemberType_Vector: {
          new Float:vecValue[3]; UTIL_ParseVector(szValue, vecValue);
          ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3);
        }
      }
    }

    TrieIterDestroy(itMemberTypesIter);
  }
}

bool:@Entity_ShouldCallBaseImplementation(const &this) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(this);

  if (pInstance == Invalid_ClassInstance) return false;

  static iId; iId = GET_ID(this);

  if (~g_rgiClassEntityFlags[iId] & EntityFlag_HasLinkedParent) return false;

  return true;
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
    if (iType == EntityMethodPointer_Think || iType == EntityMethodPointer_Touch || iType == EntityMethodPointer_Blocked) {
      ClassCacheMethod(class, szMethod);
    }

    g_rgEntityMethodPointers[this][iType] = ClassGetMethodPointer(class, szMethod);
  } else {
    g_rgEntityMethodPointers[this][iType] = Invalid_Struct;
  }
}

ModelSequence:@Entity_GetModelSequence(const &this) {
  static iSequence; iSequence = g_rgiEntitySequences[this];
  if (iSequence == -1) return INVALID_SEQUENCE;

  static iModel; iModel = g_rgiEntityModels[this];
  if (iModel == -1) return INVALID_SEQUENCE;

  return g_rgModel[iModel][Model_Sequences][iSequence];
}

/*--------------------------------[ Entity Functions ]--------------------------------*/

CreateEntity(const iId, const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, bool:bTemp = false) {
  if (iId == g_iNullId) return FM_NULLENT;

  static ClassFlag:iFlags; iFlags = g_rgiClassFlags[iId];
  if (iFlags & ClassFlag_Abstract) {
    LOG_ERROR(ERROR_CANNOT_CREATE_ABSTRACT, g_rgszClassClassnames[iId]);
    return FM_NULLENT;
  }

  if (engfunc(EngFunc_NumberOfEntities) >= g_iMaxEntities) return FM_NULLENT;

  new iszClassname = g_rgiClassEntityFlags[iId] & EntityFlag_HasLinkedParent
    ? GetAllocatedString(g_rgszClassLinkedClassnames[iId])
    : GetAllocatedString(CE_BASE_CLASSNAME);

  new this = engfunc(EngFunc_CreateNamedEntity, iszClassname);
  if (this == FM_NULLENT) return FM_NULLENT;

  set_pev(this, pev_classname, g_rgszClassClassnames[iId]);

  engfunc(EngFunc_SetOrigin, this, vecOrigin);
  // set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new ClassInstance:pInstance = @Entity_CreateInstance(this, iId, bTemp);

  if (pInstance == Invalid_ClassInstance) {
    engfunc(EngFunc_RemoveEntity, this);
    return FM_NULLENT;
  }

  ClassInstanceSetMemberArray(pInstance, MEMBER(vecOrigin), vecOrigin, 3);

  return this;
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

/*--------------------------------[ Functions ]--------------------------------*/

GetAllocatedString(const szValue[]) {
  new isz;
  if (!TrieGetCell(g_itAllocatedStrings, szValue, isz)) {
    TrieSetCell(g_itAllocatedStrings, szValue, isz = engfunc(EngFunc_AllocString, szValue));
  }

  return isz;
}

/*--------------------------------[ Storage Functions ]--------------------------------*/

InitStorages() {
  g_itEntityIds = TrieCreate();
  g_itEntityHooks = TrieCreate();
  g_itAllocatedStrings = TrieCreate();
  g_itLoadedModels = TrieCreate();

  for (new pEntity = 0; pEntity <= g_iMaxEntities; ++pEntity) {
    g_rgEntityClassInstances[pEntity] = Invalid_ClassInstance;
    
    for (new EntityMethodPointer:iFunctionPointer = EntityMethodPointer:0; iFunctionPointer < EntityMethodPointer; ++iFunctionPointer) {
      g_rgEntityMethodPointers[pEntity][iFunctionPointer] = Invalid_Struct;
    }
  }
}

DestroyStorages() {
  TrieDestroy(g_itEntityIds);
  TrieDestroy(g_itEntityHooks);
  TrieDestroy(g_itAllocatedStrings);
  TrieDestroy(g_itLoadedModels);
}

/*--------------------------------[ Class Functions ]--------------------------------*/

GetIdByClassName(const szClassname[]) {
  static iId;
  if (!TrieGetCell(g_itEntityIds, szClassname, iId)) return CE_INVALID_ID;

  return iId;
}

RegisterClass(const szClassname[], const szParent[] = "", const ClassFlag:iClassFlags = ClassFlag_None) {
  new iId = g_iClassesNum;

  new Class:cParent = Invalid_Class;
  new bool:bLinked = false;

  if (!IS_NULLSTR(szParent)) {
    new iParentId = CE_INVALID_ID;

    if (!TrieGetCell(g_itEntityIds, szParent, iParentId)) {
      bLinked = UTIL_IsClassnameLinked(szParent);

      if (!bLinked) {
        LOG_ERROR(ERROR_IS_NOT_REGISTERED_BASE, szParent);
        return CE_INVALID_ID;
      }

      // Use the base class as a parent for linked entities
      TrieGetCell(g_itEntityIds, CE_Class_Base, iParentId);
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
  g_rgitClassKeyMemberBindings[iId] = Invalid_Trie;
  g_rgiClassEntityFlags[iId] = EntityFlag_None;
  copy(g_rgszClassClassnames[iId], charsmax(g_rgszClassClassnames[]), szClassname);

  for (new CE_Method:iMethod = CE_Method:0; iMethod < CE_Method; ++iMethod) {
    g_rgrgiClassMethodPreHooksNum[iId][iMethod] = 0;
    g_rgrgiClassMethodPostHooksNum[iId][iMethod] = 0;
  }

  // Inherit implementation flags for Touch and Think methods to optimize calls
  if (cParent != Invalid_Class) {
    static iParentId; iParentId = ClassGetMetadata(cParent, CLASS_METADATA_ID);
    g_rgiClassEntityFlags[iId] |= g_rgiClassEntityFlags[iParentId] & (EntityFlag_ThinkImplemented | EntityFlag_TouchImplemented);
  }

  // Store base entity classname
  copy(
    g_rgszClassLinkedClassnames[iId],
    charsmax(g_rgszClassLinkedClassnames[]),
    bLinked ? szParent : CE_BASE_CLASSNAME
  );

  // Mark that the entity class is inherits a native entity class
  if (bLinked) {
    g_rgiClassEntityFlags[iId] |= EntityFlag_HasLinkedParent;

    if (equal(szClassname, szParent)) {
      g_rgiClassEntityFlags[iId] |= EntityFlag_IsExtension;
    }
  }

  TrieSetCell(g_itEntityIds, szClassname, iId);

  InitHamHooks(g_rgszClassLinkedClassnames[iId]);

  g_iClassesNum++;

  LOG_INFO("Entity ^"%s^" successfully registred.", szClassname);

  if (!(iClassFlags & (ClassFlag_Abstract | ClassFlag_Null))) {
    if (g_bPrecache) {
      PrecacheEntityClass(iId);
    } else {
      LOG_WARNING("Entity ^"%s^" is registered after the precache phase!", szClassname);
    }
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
    return CE_INVALID_ID;
  }

  new Class:cEntity = ClassFork(g_rgcClasses[iOriginalId], g_rgcClasses[iParentId]);
  cEntity = ClassCache(cEntity);

  ClassSetMetadataString(cEntity, CLASS_METADATA_NAME, szClassname);
  ClassSetMetadata(cEntity, CLASS_METADATA_ID, iId);

  g_rgiClassIds[iId] = iId;
  g_rgcClasses[iId] = cEntity;
  g_rgiClassFlags[iId] = g_rgiClassFlags[iOriginalId];
  g_rgitClassKeyMemberBindings[iId] = g_rgitClassKeyMemberBindings[iOriginalId];
  g_rgiClassEntityFlags[iId] = g_rgiClassEntityFlags[iOriginalId];
  copy(g_rgszClassClassnames[iId], charsmax(g_rgszClassClassnames[]), szClassname);
  copy(g_rgszClassLinkedClassnames[iId], charsmax(g_rgszClassLinkedClassnames[]), g_rgszClassLinkedClassnames[iOriginalId]);

  for (new CE_Method:iMethod = CE_Method:0; iMethod < CE_Method; ++iMethod) {
    g_rgrgiClassMethodPreHooksNum[iId][iMethod] = 0;
    g_rgrgiClassMethodPostHooksNum[iId][iMethod] = 0;
  }

  TrieSetCell(g_itEntityIds, szClassname, iId);

  LOG_INFO("Entity ^"%s^" successfully forked from ^"%s^".", szClassname, g_rgszClassClassnames[iOriginalId]);

  g_iClassesNum++;

  return iId;
}

FreeClass(const iId) {
  // for (new CE_Method:iMethod = CE_Method:0; iMethod < CE_Method; ++iMethod) {
  //   if (g_rgClassMethodPreHooks[iId][iMethod] != Invalid_Array) {
  //     ArrayDestroy(g_rgClassMethodPreHooks[iId][iMethod]);
  //   }

  //   if (g_rgClassMethodPostHooks[iId][iMethod] != Invalid_Array) {
  //     ArrayDestroy(g_rgClassMethodPostHooks[iId][iMethod]);
  //   }
  // }

  if (g_rgitClassKeyMemberBindings[iId] != Invalid_Trie) {
    new TrieIter:itKeyMemberBindingsIter = TrieIterCreate(g_rgitClassKeyMemberBindings[iId]);

    while (!TrieIterEnded(itKeyMemberBindingsIter)) {
      new Trie:itMemberTypes; TrieIterGetCell(itKeyMemberBindingsIter, itMemberTypes);
      TrieDestroy(itMemberTypes);
      TrieIterNext(itKeyMemberBindingsIter);
    }

    TrieIterDestroy(itKeyMemberBindingsIter);

    TrieDestroy(g_rgitClassKeyMemberBindings[iId]);
  }

  ClassDestroy(g_rgcClasses[iId]);
}

AddClassMethod(const iId, const szMethod[], const Function:fnCallback, Array:irgParamTypes, bool:bVirtual) {
  ClassDefineMethod(g_rgcClasses[iId], szMethod, fnCallback, bVirtual, ClassDataType_Cell, ClassDataType_ParamsCellArray, irgParamTypes);
}

ImplementClassMethod(const iId, const CE_Method:iMethod, const Function:fnCallback) {
  new Class:class = g_rgcClasses[iId];

  new Array:irgParams = ArrayCreate(_, 8);

  for (new iParam = 0; iParam < g_rgMethodParams[iMethod][MethodParams_Num]; ++iParam) {
    ArrayPushCell(irgParams, g_rgMethodParams[iMethod][MethodParams_Types][iParam]);
  }

  // TODO: Probably can use native array here
  ClassDefineMethod(class, g_rgszMethodNames[iMethod], fnCallback, true, ClassDataType_Cell, ClassDataType_ParamsCellArray, irgParams);

  // Cache methods
  // if (iMethod == METHOD(Think) || iMethod == METHOD(Touch) || iMethod == METHOD(Blocked)) {
  //   ClassCacheMethod(class, g_rgszMethodNames[iMethod]);
  // }

  // Update implementation flags (used for optimization)
  if (g_iBaseId != -1 && iId != g_iBaseId) {
    switch (iMethod) {
      case METHOD(Touch): {
        g_rgiClassEntityFlags[iId] |= EntityFlag_TouchImplemented;
      }
      case METHOD(Think): {
        g_rgiClassEntityFlags[iId] |= EntityFlag_ThinkImplemented;
      }
    }
  }

  ArrayDestroy(irgParams);
}

RegisterClassMethodHook(const iId, CE_Method:iMethod, const Function:fnCallback, bool:bPost) {
  // new Array:irgHooks = Invalid_Array;
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

RegisterClassKeyMemberBinding(const iId, const szKey[], const szMember[], CEMemberType:iType) {
  if (g_rgitClassKeyMemberBindings[iId] == Invalid_Trie) {
    g_rgitClassKeyMemberBindings[iId] = TrieCreate();
  }

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(g_rgitClassKeyMemberBindings[iId], szKey, itMemberTypes)) {
    itMemberTypes = TrieCreate();
    TrieSetCell(g_rgitClassKeyMemberBindings[iId], szKey, itMemberTypes);
  }

  TrieSetCell(itMemberTypes, szMember, iType);
}

RemoveEntityClassKeyMemberBinding(const iId, const szKey[], const szMember[]) {
  if (g_rgitClassKeyMemberBindings[iId] == Invalid_Trie) return;

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(g_rgitClassKeyMemberBindings[iId], szKey, itMemberTypes)) return;

  TrieDeleteKey(itMemberTypes, szMember);
}

PrecacheEntityClass(const iId) {
  new pEntity = CreateEntity(iId);
  if (pEntity == FM_NULLENT) return;

  CALL_METHOD<Precache>(pEntity, 0);

  engfunc(EngFunc_RemoveEntity, pEntity);
}

UpdateForwards() {
  if (g_iForceEntitiesVisibleNum) {
    if (!g_pfwfmCheckVisibility) {
      g_pfwfmCheckVisibility = register_forward(FM_CheckVisibility, "FMHook_CheckVisibility", 0);
    }
  } else {
    if (g_pfwfmCheckVisibility) {
      unregister_forward(FM_CheckVisibility, g_pfwfmCheckVisibility, 0);
      g_pfwfmCheckVisibility = 0;
    }
  }

  if (g_iInstancesNum) {
    EnableDynamicHooks();
  } else {
    DisableDynamicHooks();
  }
}

/*--------------------------------[ Init Base Classes Functions ]--------------------------------*/

InitBaseClasses() {
  #define _TO_STR(%1) #%1
  #define __METHOD_FN_NAME<%1::%2> _TO_STR(@%1_%2)
  #define __METHOD_PARAMS(%1,%2) GetIdByClassName(CE_Class_%1), CE_Method_%2, #%2, __METHOD_FN_NAME<%1::%2>

  #define DEFINE_CLASS<%1> RegisterClass(CE_Class_%1, NULL_STRING, ClassFlag_Abstract)
  #define EXTEND_CLASS<%2,%1> RegisterClass(CE_Class_%1, CE_Class_%2, ClassFlag_Abstract)
  #define DEFINE_METHOD_NOARGS<%1::%2>() InitNativeMethod(__METHOD_PARAMS(%1,%2))
  #define DEFINE_METHOD_ARGS<%1::%2>(%0) InitNativeMethod(__METHOD_PARAMS(%1,%2), %0)
  #define CELL(%1) ClassDataType_Cell 
  #define STR(%1) ClassDataType_String
  #define ARR(%1,%2) ClassDataType_Array, %2
  #define VEC(%1) ARR(%1,3)
  #define ARRREF(%1,%2) ClassDataType_ArrayRef, %2
  #define VECREF(%1) ARRREF(%1,3)

  RegisterClass(CE_Class_Null, NULL_STRING, ClassFlag_Null);
  TrieGetCell(g_itEntityIds, CE_Class_Null, g_iNullId);

  DEFINE_CLASS<Base>;

  DEFINE_METHOD_NOARGS<Base::Create>();
  DEFINE_METHOD_NOARGS<Base::Destroy>();
  DEFINE_METHOD_ARGS<Base::KeyValue>(STR(szKey), STR(szValue));
  DEFINE_METHOD_NOARGS<Base::Spawn>();
  DEFINE_METHOD_NOARGS<Base::ResetVariables>();
  DEFINE_METHOD_NOARGS<Base::InitPhysics>();
  DEFINE_METHOD_NOARGS<Base::InitModel>();
  DEFINE_METHOD_NOARGS<Base::InitSize>();
  DEFINE_METHOD_ARGS<Base::Touch>(CELL(pToucher));
  DEFINE_METHOD_NOARGS<Base::Think>();
  DEFINE_METHOD_NOARGS<Base::Restart>();
  DEFINE_METHOD_NOARGS<Base::Precache>();
  DEFINE_METHOD_ARGS<Base::Killed>(CELL(pKiller), CELL(iShouldGib));
  DEFINE_METHOD_ARGS<Base::IsMasterTriggered>(CELL(pActivator));
  DEFINE_METHOD_NOARGS<Base::ObjectCaps>();
  DEFINE_METHOD_NOARGS<Base::BloodColor>();
  DEFINE_METHOD_ARGS<Base::Use>(CELL(pActivator), CELL(pCaller), CELL(iUseType), CELL(flValue));
  DEFINE_METHOD_ARGS<Base::Blocked>(CELL(pBlocker));
  DEFINE_METHOD_NOARGS<Base::GetDelay>();
  DEFINE_METHOD_NOARGS<Base::Classify>();
  DEFINE_METHOD_ARGS<Base::IsTriggered>(CELL(pActivator));
  DEFINE_METHOD_NOARGS<Base::GetToggleState>();
  DEFINE_METHOD_ARGS<Base::SetToggleState>(CELL(iState));
  DEFINE_METHOD_NOARGS<Base::Respawn>();
  DEFINE_METHOD_ARGS<Base::TraceAttack>(CELL(pAttacker), CELL(flDamage), VEC(vecDirection), CELL(pTrace), CELL(iDamageBits));
  DEFINE_METHOD_ARGS<Base::TakeDamage>(CELL(pInflictor), CELL(pAttacker), CELL(flDamage), CELL(iDamageBits));
  DEFINE_METHOD_NOARGS<Base::Activate>();

  DEFINE_METHOD_NOARGS<Base::LoadModel>();
  DEFINE_METHOD_NOARGS<Base::ResetSequenceInfo>();
  DEFINE_METHOD_NOARGS<Base::UpdateSequenceInfo>();
  DEFINE_METHOD_ARGS<Base::SetSequence>(CELL(iSequence), CELL(bForce));
  DEFINE_METHOD_ARGS<Base::FrameAdvance>(CELL(flInterval));
  DEFINE_METHOD_ARGS<Base::DispatchAnimEvents>(CELL(flInterval));
  DEFINE_METHOD_NOARGS<Base::FinishSequence>();
  DEFINE_METHOD_ARGS<Base::HandleAnimEvent>(CELL(iEventId), ARR(rgOptions, 32));
  DEFINE_METHOD_ARGS<Base::LookupActivity>(CELL(iActivity));
  DEFINE_METHOD_ARGS<Base::LookupActivityHeaviest>(CELL(iActivity));
  DEFINE_METHOD_ARGS<Base::GetModelViewOfs>(VECREF(vecOut));
  DEFINE_METHOD_NOARGS<Base::IsMoving>();

  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "origin", MEMBER(vecOrigin), CEMemberType_Vector);
  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "angles", MEMBER(vecAngles), CEMemberType_Vector);
  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "master", MEMBER(szMaster), CEMemberType_String);
  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "targetname", MEMBER(szTargetname), CEMemberType_String);
  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "target", MEMBER(szTarget), CEMemberType_String);
  RegisterClassKeyMemberBinding(GetIdByClassName(CE_Class_Base), "model", MEMBER(szModel), CEMemberType_String);

  TrieGetCell(g_itEntityIds, CE_Class_Base, g_iBaseId);

  EXTEND_CLASS<Base,BaseItem>;
  DEFINE_METHOD_NOARGS<BaseItem::Spawn>();
  DEFINE_METHOD_ARGS<BaseItem::Touch>(CELL(pToucher));
  DEFINE_METHOD_ARGS<BaseItem::CanPickup>(CELL(pPlayer));
  DEFINE_METHOD_ARGS<BaseItem::Pickup>(CELL(pPlayer));
  DEFINE_METHOD_NOARGS<BaseItem::InitPhysics>();

  EXTEND_CLASS<Base,BaseMonster>;
  DEFINE_METHOD_NOARGS<BaseMonster::Spawn>();
  DEFINE_METHOD_NOARGS<BaseMonster::InitPhysics>();

  EXTEND_CLASS<Base,BaseProp>;
  DEFINE_METHOD_NOARGS<BaseProp::InitPhysics>();

  EXTEND_CLASS<Base,BaseTrigger>;
  DEFINE_METHOD_NOARGS<BaseTrigger::Spawn>();
  DEFINE_METHOD_ARGS<BaseTrigger::Touch>(CELL(pToucher));
  DEFINE_METHOD_ARGS<BaseTrigger::CanTrigger>(CELL(pActivator));
  DEFINE_METHOD_ARGS<BaseTrigger::Trigger>(CELL(pActivator));
  DEFINE_METHOD_NOARGS<BaseTrigger::InitPhysics>();
  DEFINE_METHOD_ARGS<BaseTrigger::IsTriggered>(CELL(pActivator));

  EXTEND_CLASS<Base,BaseBsp>;
  DEFINE_METHOD_NOARGS<BaseBsp::InitPhysics>();
}

InitNativeMethod(const iId, CE_Method:iMethod, const szMethod[], const szFunction[], any:...) {  
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

any:ExecuteMethod(CE_Method:iMethod, const &pEntity, const iNativeArg = 0, const iNativeArgsNum = 0, any:...) {
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
    if (iHookResult != CE_SUPERCEDE) iCallResult = ClassInstanceCallMethod(pInstance, g_rgszMethodNames[iMethod], class, pEntity, %0);\
    if (iHookResult <= CE_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);\
    CALL_METHOD_HOOKS<Post>(%0)\
    if (iHookResult <= CE_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);

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

  #define READ_EXECUTION_PARAM_VECREF<%1>(%2)\
    callfunc_set_arg_types(%1 + 1, CFP_ArrayRef, 3)

  #define SET_EXECUTION_PARAM_VECREF<%1>(%2)\
    if (%1 < iExecutionParamsNum)\
    if (iNativeArg) set_array_f(iNativeArg + %1, %2, 3);\
    else vararg_set_array(iArgOffset + %1, %2, 3);

  for (new Class:cCurrent = g_rgcClasses[iId]; cCurrent != Invalid_Class; cCurrent = ClassGetBaseClass(cCurrent)) {
    static iId; iId = ClassGetMetadata(cCurrent, CLASS_METADATA_ID);
    PUSH_HOOKS_TO_STACK<Pre>(iId)
    PUSH_HOOKS_TO_STACK<Post>(iId)
  }

  switch (iMethod) {
    case METHOD(KeyValue): {
      new szKey[32]; READ_EXECUTION_PARAM_STR<0>(szKey, NULL_STRING);
      new szValue[64]; READ_EXECUTION_PARAM_STR<1>(szValue, NULL_STRING);

      HOOKABLE_METHOD_IMPLEMENTATION(szKey, szValue)
    }
    case METHOD(Touch): {
      new pToucher = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(CanPickup): {
      new pToucher = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(Pickup): {
      new pToucher = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(CanTrigger): {
      new pToucher = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(Trigger): {
      new pToucher = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pToucher)
    }
    case METHOD(Killed): {
      new pKiller = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new iShouldGib = READ_EXECUTION_PARAM<1>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pKiller, iShouldGib)
    }
    case METHOD(IsMasterTriggered): {
      new pActivator = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pActivator)
    }
    case METHOD(Use): {
      new pCaller = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new pActivator = READ_EXECUTION_PARAM<1>(FM_NULLENT);
      new iUseType = READ_EXECUTION_PARAM<2>(0);
      new Float:flValue = READ_EXECUTION_PARAM_F<3>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(pCaller, pActivator, iUseType, flValue)
    }
    case METHOD(Blocked): {
      new pOther = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pOther)
    }
    case METHOD(IsTriggered): {
      new pActivator = READ_EXECUTION_PARAM<0>(FM_NULLENT);

      HOOKABLE_METHOD_IMPLEMENTATION(pActivator)
    }
    case METHOD(SetToggleState): {
      new iState = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(iState)
    }
    case METHOD(TraceAttack): {
      new pAttacker = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new Float:flDamage = READ_EXECUTION_PARAM_F<1>(0.0);
      new Float:vecDirection[3]; READ_EXECUTION_PARAM_VEC<2>(vecDirection, NULL_VECTOR);
      new pTrace = READ_EXECUTION_PARAM<3>(0);
      new iDamageBits = READ_EXECUTION_PARAM<4>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pAttacker, flDamage, vecDirection, pTrace, iDamageBits)
    }
    case METHOD(TakeDamage): {
      new pInflictor = READ_EXECUTION_PARAM<0>(FM_NULLENT);
      new pAttacker = READ_EXECUTION_PARAM<1>(FM_NULLENT);
      new Float:flDamage = READ_EXECUTION_PARAM_F<2>(0.0);
      new iDamageBits = READ_EXECUTION_PARAM<3>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(pInflictor, pAttacker, flDamage, iDamageBits)
    }
    case METHOD(FrameAdvance): {
      new Float:flInterval = READ_EXECUTION_PARAM_F<0>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(flInterval)
    }
    case METHOD(DispatchAnimEvents): {
      new Float:flInterval = READ_EXECUTION_PARAM_F<0>(0.0);

      HOOKABLE_METHOD_IMPLEMENTATION(flInterval)
    }
    case METHOD(HandleAnimEvent): {
      new iEventId = READ_EXECUTION_PARAM<0>(0);
      static rgOptions[32]; READ_EXECUTION_PARAM_STR<1>(rgOptions, NULL_STRING);

      HOOKABLE_METHOD_IMPLEMENTATION(iEventId, rgOptions)
    }
    case METHOD(LookupActivity), METHOD(LookupActivityHeaviest): {
      new iActivity = READ_EXECUTION_PARAM<0>(0);

      HOOKABLE_METHOD_IMPLEMENTATION(iActivity)
    }
    case METHOD(SetSequence): {
      new iSequence = READ_EXECUTION_PARAM<0>(0);
      new bool:bForce = READ_EXECUTION_PARAM<1>(false);

      HOOKABLE_METHOD_IMPLEMENTATION(iSequence, bForce)
    }
    case METHOD(GetModelViewOfs): {
      new Float:vecOut[3]; READ_EXECUTION_PARAM_VECREF<0>(vecOut);

      HOOKABLE_METHOD_IMPLEMENTATION(vecOut)

      SET_EXECUTION_PARAM_VECREF<0>(vecOut)
    }
    default: {
      HOOKABLE_METHOD_IMPLEMENTATION(0)
    }
  }

  return STACK_POP(METHOD_RETURN);
}

/*--------------------------------[ Model Loader Functions ]--------------------------------*/

GetAnimationEvent(const &ModelSequence:iModelSequence, Float:flStart, Float:flEnd, iStartEvent) {
  // log_amx("[%d] GetAnimationEvent flStart: %.3f, flEnd: %.3f, iStartEvent: %d", iModelSequence, flStart, flEnd, iStartEvent);
  if (flStart == flEnd) return -1;

  static iEventsNum; iEventsNum = g_rgModelSequences[iModelSequence][ModelSequence_EventsNum];
  if (iStartEvent > iEventsNum) return -1;

  static iFlags; iFlags = g_rgModelSequences[iModelSequence][ModelSequence_Flags];
  static iFramesNum; iFramesNum = g_rgModelSequences[iModelSequence][ModelSequence_FramesNum];
  static Float:flFramesNum; flFramesNum = float(iFramesNum);
  static Float:flLastFrame; flLastFrame = flFramesNum - 1.0;

  flStart = (flStart * (flFramesNum / 256.0)) - 1.0;
  flEnd = (flEnd * (flFramesNum / 256.0)) - 1.0;

  if (iFlags & STUDIO_LOOPING) {
    static Float:flFixedStart; flFixedStart = flStart;

    if (flStart < 0) {
      flFixedStart = flLastFrame - UTIL_FloatMod(-flStart, flLastFrame);
    } else if (flStart > flLastFrame) {
      flFixedStart = 0.0 + UTIL_FloatMod(flStart, flLastFrame);
    }

    flEnd += (flFixedStart - flStart);
    flStart = flFixedStart;
  } else {
    // TODO: Investigate
    flStart = floatclamp(flStart, 0.0, flLastFrame);
    flEnd = floatclamp(flEnd, 0.0, flLastFrame);
  }

  static Float:flCurrentFrame; flCurrentFrame = flStart;
  // log_amx("[%d] frames num: %d", iModelSequence, iFramesNum);
  // log_amx("[%d] frame ratio %.3f -> %.3f", iModelSequence, flStart, flEnd);
  // log_amx("[%d] flCurrentFrame: %f", iModelSequence, flCurrentFrame);
  
  do {
    static Float:flNormalizedStart; flNormalizedStart = UTIL_FloatMod(flCurrentFrame, flLastFrame);
    static Float:flNormalizedEnd; flNormalizedEnd = floatmin(flNormalizedStart + (flEnd - flCurrentFrame), flLastFrame);

    for (new iEvent = iStartEvent < 0 ? 0 : iStartEvent + 1; iEvent < iEventsNum; ++iEvent) {
      static iEventId; iEventId = g_rgModelSequences[iModelSequence][ModelSequence_Events][iEvent];
      // if (iEventId >= EVENT_CLIENT) continue;

      static Float:flFrame; flFrame = float(g_rgModelEvents[iEventId][mstudioevent_frame]);
      if (flFrame < flNormalizedStart) continue;
      if (flFrame >= flNormalizedEnd) continue;

      return iEvent;
    }

    flCurrentFrame += flNormalizedEnd - flNormalizedStart;
  } while (flCurrentFrame < flEnd);

  return -1;
}

GetSequenceInfo(const &ModelSequence:iSequence, &Float:flFrameRate, &Float:flGroundSpeed) {
  static Float:flFPS; flFPS = g_rgModelSequences[iSequence][ModelSequence_FPS];
  static iFramesNum; iFramesNum = g_rgModelSequences[iSequence][ModelSequence_FramesNum];

  if (iFramesNum > 1) {
    flFrameRate = (flFPS / iFramesNum) * 256.0;
    flGroundSpeed = xs_vec_len(g_rgModelSequences[iSequence][ModelSequence_LinearMovement]) * (flFPS / iFramesNum);
  } else {
    flFrameRate = 256.0;
    flGroundSpeed = 0.0;
  }
}

LoadModel(const szModel[]) {
  new iModelId = -1;
  if (TrieGetCell(g_itLoadedModels, szModel, iModelId)) return iModelId;

  new iFile = studiomdl_open(szModel);
  if (!iFile) return -1;

  new rgHeader[studiohdr]; studiomdl_read_header(iFile, rgHeader);

  iModelId = g_iModelsNum;

  xs_vec_copy(rgHeader[studiohdr_eyeposition], g_rgModel[iModelId][Model_EyePosition]);

  g_rgModel[iModelId][Model_SequencesNum] = 0;

  fseek(iFile, rgHeader[studiohdr_seqindex], SEEK_SET);

  for (new iSequence = 0; iSequence < rgHeader[studiohdr_numseq]; iSequence++) {
    new rgSequence[mstudioseqdesc]; studiomdl_read_sequence(iFile, rgSequence);

    new ModelSequence:iModelSequence; iModelSequence = ModelSequence:g_iModelSequencesNum;

    g_rgModelSequences[iModelSequence][ModelSequence_FramesNum] = rgSequence[mstudioseqdesc_numframes];
    g_rgModelSequences[iModelSequence][ModelSequence_FPS] = rgSequence[mstudioseqdesc_fps];
    g_rgModelSequences[iModelSequence][ModelSequence_Flags] = rgSequence[mstudioseqdesc_flags];
    g_rgModelSequences[iModelSequence][ModelSequence_Activity] = rgSequence[mstudioseqdesc_activity];
    g_rgModelSequences[iModelSequence][ModelSequence_ActivityWeight] = rgSequence[mstudioseqdesc_actweight];
    xs_vec_copy(rgSequence[mstudioseqdesc_linearmovement], g_rgModelSequences[iModelSequence][ModelSequence_LinearMovement]);
    g_rgModelSequences[iModelSequence][ModelSequence_EventsNum] = 0;

    // Only save sequences with events
    if (rgSequence[mstudioseqdesc_numevents]) {
      new iNextSeqPos = ftell(iFile);

      fseek(iFile, rgSequence[mstudioseqdesc_eventindex], SEEK_SET);

      for (new iEvent = 0; iEvent < rgSequence[mstudioseqdesc_numevents]; iEvent++) {
        if (iEvent >= sizeof(g_rgModelSequences[][ModelSequence_Events])) {
          LOG_ERROR("Failed to load event %d for iModelSequence %d. ModelSequence limit reached.", iEvent, iSequence);
          break;
        }

        studiomdl_read_event(iFile, g_rgModelEvents[g_iModelEventsNum]);

        if (g_rgModelEvents[g_iModelEventsNum][mstudioevent_frame] < 0) continue;
        if (g_rgModelEvents[g_iModelEventsNum][mstudioevent_frame] >= g_rgModelSequences[iModelSequence][ModelSequence_FramesNum]) continue;

        g_rgModelSequences[iModelSequence][ModelSequence_Events][iEvent] = g_iModelEventsNum;
        g_rgModelSequences[iModelSequence][ModelSequence_EventsNum]++;

        // log_amx("Loading event %d for iModelSequence %d. {event = %d, frame = %d}", g_iModelEventsNum, iSequence, g_rgModelEvents[g_iModelEventsNum][mstudioevent_event], g_rgModelEvents[g_iModelEventsNum][mstudioevent_frame]);

        g_iModelEventsNum++;
      }

      fseek(iFile, iNextSeqPos, SEEK_SET);
    }

    g_rgModel[iModelId][Model_Sequences][iSequence] = iModelSequence;
    g_rgModel[iModelId][Model_SequencesNum]++;
    g_iModelSequencesNum++;
  }

  log_amx("Loaded model %s with %d sequences", szModel, g_rgModel[iModelId][Model_SequencesNum]);

  fclose(iFile);

  TrieSetCell(g_itLoadedModels, szModel, iModelId);
  g_iModelsNum++;

  return iModelId;
}

/*--------------------------------[ Base Methods Implementation ]--------------------------------*/

method <Base::Create> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(bIgnoreRounds), false);
}

method <Base::Destroy> (const this) {}

method <Base::KeyValue> (const this, const szKey[], const szValue[]) {}

method <Base::Spawn> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, MEMBER(flLastSpawn), g_flGameTime);

  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_Spawn, this);
    return;
  }

  set_pev(this, pev_deadflag, DEAD_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  static bool:bIsWorld; bIsWorld = ClassInstanceGetMember(pInstance, MEMBER(bWorld));

  static Float:flLifeTime; flLifeTime = 0.0;
  if (!bIsWorld && ClassInstanceHasMember(pInstance, MEMBER(flLifeTime))) {
    flLifeTime = ClassInstanceGetMember(pInstance, MEMBER(flLifeTime));
  }

  if (flLifeTime > 0.0) {
    ClassInstanceSetMember(pInstance, MEMBER(flNextKill), g_flGameTime + flLifeTime);
    set_pev(this, pev_nextthink, g_flGameTime + flLifeTime);
  } else {
    ClassInstanceSetMember(pInstance, MEMBER(flNextKill), 0.0);
  }
}

method <Base::Respawn> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_Respawn, this);
  } else {
    dllfunc(DLLFunc_Spawn, this);
  }

  return this;
}

method <Base::TraceAttack> (const this, const pAttacker, Float:flDamage, const Float:vecDirection[3], pTrace, iDamageBits) {
  ExecuteHam(Ham_TraceAttack, this, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);
}

method <Base::TakeDamage> (const this, const pInflictor, const pAttacker, Float:flDamage, iDamageBits) {
  return ExecuteHam(Ham_TakeDamage, this, pInflictor, pAttacker, flDamage, iDamageBits);
}

method <Base::Restart> (const this) {
  if (g_bIsCStrike && @Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_CS_Restart, this);
  }

  new iObjectCaps = ExecuteHamB(Ham_ObjectCaps, this);

  if (!g_bIsCStrike) {
    if (iObjectCaps & FCAP_MUST_RELEASE) {
      set_pev(this, pev_globalname, GLOBAL_DEAD);
      set_pev(this, pev_solid, SOLID_NOT);
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
      set_pev(this, pev_targetname, "");
      
      return;
    }
  }

  if (~iObjectCaps & FCAP_ACROSS_TRANSITION) {
    ExecuteHamB(Ham_Respawn, this);
  }
}

method <Base::ResetVariables> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, MEMBER(vecOrigin))) {
    static Float:vecOrigin[3];
    ClassInstanceGetMemberArray(pInstance, MEMBER(vecOrigin), vecOrigin, 3);
    engfunc(EngFunc_SetOrigin, this, vecOrigin);
  }

  if (ClassInstanceHasMember(pInstance, MEMBER(vecAngles))) {
    static Float:vecAngles[3];
    ClassInstanceGetMemberArray(pInstance, MEMBER(vecAngles), vecAngles, 3);
    set_pev(this, pev_angles, vecAngles);
  }

  if (ClassInstanceHasMember(pInstance, MEMBER(szTargetname))) {
    static szTargetname[32];
    ClassInstanceGetMemberString(pInstance, MEMBER(szTargetname), ARG_STRREF(szTargetname));
    set_pev(this, pev_targetname, szTargetname);
  }

  if (ClassInstanceHasMember(pInstance, MEMBER(szTarget))) {
    static szTarget[32];
    ClassInstanceGetMemberString(pInstance, MEMBER(szTarget), ARG_STRREF(szTarget));
    set_pev(this, pev_target, szTarget);
  }

  CALL_METHOD<InitPhysics>(this, 0);
  CALL_METHOD<InitModel>(this, 0);
  CALL_METHOD<InitSize>(this, 0);
  CALL_METHOD<ResetSequenceInfo>(this, 0);
}

method <Base::InitPhysics> (const this) {}

method <Base::InitModel> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, MEMBER(szModel))) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    ClassInstanceGetMemberString(pInstance, MEMBER(szModel), ARG_STRREF(szModel));
    engfunc(EngFunc_SetModel, this, szModel);
  }
}

method <Base::InitSize> (const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, MEMBER(vecMins)) && ClassInstanceHasMember(pInstance, MEMBER(vecMaxs))) {
    static Float:vecMins[3]; ClassInstanceGetMemberArray(pInstance, MEMBER(vecMins), vecMins, 3);
    static Float:vecMaxs[3]; ClassInstanceGetMemberArray(pInstance, MEMBER(vecMaxs), vecMaxs, 3);
    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
  }
}

method <Base::Killed> (const this, const pKiller, iShouldGib) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(flNextKill), 0.0);

  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_Killed, this, pKiller, iShouldGib);
    return;
  }

  set_pev(this, pev_takedamage, DAMAGE_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);
  set_pev(this, pev_solid, SOLID_NOT);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new bool:bIsWorld = ClassInstanceGetMember(pInstance, MEMBER(bWorld));

  if (bIsWorld) {
    new Float:flRespawnTime = ClassInstanceGetMember(pInstance, MEMBER(flRespawnTime));
    if (flRespawnTime > 0.0) {
      ClassInstanceSetMember(pInstance, MEMBER(flNextRespawn), g_flGameTime + flRespawnTime);
      set_pev(this, pev_deadflag, DEAD_RESPAWNABLE);
      set_pev(this, pev_nextthink, g_flGameTime + flRespawnTime);
    } else {
      set_pev(this, pev_deadflag, DEAD_DEAD);
    }
  } else {
    set_pev(this, pev_deadflag, DEAD_DISCARDBODY);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  }
}

method <Base::Think> (const this) {
  // if (@Entity_ShouldCallBaseImplementation(this)) {
  ExecuteHam(Ham_Think, this);
  // }

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static iModelIndex; iModelIndex = pev(this, pev_modelindex);

  if (iModelIndex && ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) {
    if (g_rgiEntitySequences[this] != pev(this, pev_sequence) || g_rgiEntityModelIndexes[this] != iModelIndex) {
      CALL_METHOD<UpdateSequenceInfo>(this, 0);
    }
  }
  
  static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

  switch (iDeadFlag) {
    case DEAD_NO: {
      static Float:flNextKill; flNextKill = ClassInstanceGetMember(pInstance, MEMBER(flNextKill));
      if (flNextKill > 0.0 && flNextKill <= g_flGameTime) {
        ExecuteHamB(Ham_Killed, this, 0, 0);
      }
    }
    case DEAD_RESPAWNABLE: {
      static Float:flNextRespawn; flNextRespawn = ClassInstanceGetMember(pInstance, MEMBER(flNextRespawn));
      if (flNextRespawn <= g_flGameTime) {
        ExecuteHamB(Ham_Respawn, this);
      }
    }
  }

  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think] != Invalid_Struct) {
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think], this);
  }
}

method <Base::Touch> (const this, const pToucher) {
  // if (@Entity_ShouldCallBaseImplementation(this)) {
  ExecuteHam(Ham_Touch, this, pToucher);
  // }

  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch], this, pToucher);
  }
}

method <Base::Use> (const this, const pActivator, const pCaller, iUseType, Float:flValue) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    // TODO: Investigate if validation bypass for pCaller works properly
    ExecuteHam(Ham_Use, this, pCaller != FM_NULLENT ? pCaller : 0, pActivator != FM_NULLENT ? pActivator : 0, iUseType, flValue);
  }

  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Use] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Use], this, pCaller, pActivator, iUseType, flValue);
  }
}

method <Base::Blocked> (const this, const pBlocker) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_Blocked, this, pBlocker);
  }

  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Blocked] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Blocked], this, pBlocker);
  }
}

method <Base::IsMasterTriggered> (const this, const pActivator) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static szMaster[32]; ClassInstanceGetMemberString(pInstance, MEMBER(szMaster), ARG_STRREF(szMaster));

  return UTIL_IsMasterTriggered(szMaster, pActivator);
}

method <Base::ObjectCaps> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  new iId = GET_ID(this);
  new iObjectCaps = ExecuteHam(Ham_ObjectCaps, this);

  if (~g_rgiClassEntityFlags[iId] & EntityFlag_IsExtension) {
    new bool:bIgnoreRound = ClassInstanceGetMember(pInstance, MEMBER(bIgnoreRounds));

    if (!bIgnoreRound) {
      new bool:bIsWorld = ClassInstanceGetMember(pInstance, MEMBER(bWorld));
      iObjectCaps |= bIsWorld ? FCAP_MUST_RESET : FCAP_MUST_RELEASE;
    } else {
      iObjectCaps |= FCAP_ACROSS_TRANSITION;
    }
  }

  return iObjectCaps;
}

method <Base::BloodColor> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) return ExecuteHam(Ham_BloodColor, this);

  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  if (!ClassInstanceHasMember(pInstance, MEMBER(iBloodColor))) return -1;

  return ClassInstanceGetMember(pInstance, MEMBER(iBloodColor));
}

method <Base::GetDelay> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    static Float:flDelay; ExecuteHam(Ham_GetDelay, this, flDelay);
    return flDelay;
  }

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return Float:ClassInstanceGetMember(pInstance, MEMBER(flDelay));
}

method <Base::Classify> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) return ExecuteHam(Ham_Classify, this);

  return 0;
}

method <Base::IsTriggered> (const this, const pActivator) {
  if (@Entity_ShouldCallBaseImplementation(this)) return ExecuteHam(Ham_IsTriggered, this, pActivator != FM_NULLENT ? pActivator : 0);

  return true;
}

method <Base::GetToggleState> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) return ExecuteHam(Ham_GetToggleState, this);
  
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceGetMember(pInstance, MEMBER(iToggleState));
}

method <Base::SetToggleState> (const this, iState) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_SetToggleState, this, iState);
  }

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, MEMBER(iToggleState), iState);
}

method <Base::Activate> (const this) {
  if (@Entity_ShouldCallBaseImplementation(this)) {
    ExecuteHam(Ham_Activate, this, 0);
  }
}

method <Base::Precache> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  new szModel[MAX_RESOURCE_PATH_LENGTH]; ClassInstanceGetMemberString(pInstance, MEMBER(szModel), ARG_STRREF(szModel));

  if (!IS_NULLSTR(szModel)) {
    precache_model(szModel);
  }
}

method <Base::SetSequence> (const this, const iSequence, bool:bForce) {
  if (!bForce && pev(this, pev_modelindex) && iSequence == g_rgiEntitySequences[this]) {
    static ClassInstance:pInstance; pInstance = GET_INSTANCE(this);

    if (
      !ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations)) ||
      ClassInstanceGetMember(pInstance, MEMBER(bSequenceLoops)) ||
      !ClassInstanceGetMember(pInstance, MEMBER(bSequenceFinished))
     ) {
      return;
    }
  }

  set_pev(this, pev_sequence, iSequence);
  CALL_METHOD<ResetSequenceInfo>(this, 0);
}

method <Base::ResetSequenceInfo> (const this) {
  new ClassInstance:pInstance = GET_INSTANCE(this);

  CALL_METHOD<UpdateSequenceInfo>(this, 0);
  ClassInstanceSetMember(pInstance, MEMBER(flLastEventCheck), g_flGameTime);

  set_pev(this, pev_frame, 0.0);
  set_pev(this, pev_framerate, 1.0);
  set_pev(this, pev_animtime, g_flGameTime);
}

method <Base::UpdateSequenceInfo> (const this) {
  new ClassInstance:pInstance = GET_INSTANCE(this);

  if (pev(this, pev_modelindex) && ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) {
    CALL_METHOD<LoadModel>(this, 0);
    g_rgiEntitySequences[this] = pev(this, pev_sequence);

    static ModelSequence:iModelSequence; iModelSequence = @Entity_GetModelSequence(this);
    if (iModelSequence != INVALID_SEQUENCE) {
      static Float:flSequenceFrameRate;
      static Float:flGroundSpeed;
      // log_amx("Getting sequence info for model: %d", g_rgiEntityModels[this]);
      GetSequenceInfo(iModelSequence, flSequenceFrameRate, flGroundSpeed);
      // log_amx("ResetSequenceInfo: flSequenceFrameRate: %.3f, flGroundSpeed: %.3f", flSequenceFrameRate, flGroundSpeed);

      ClassInstanceSetMember(pInstance, MEMBER(flSequenceFrameRate), flSequenceFrameRate);
      ClassInstanceSetMember(pInstance, MEMBER(flGroundSpeed), flGroundSpeed);
      ClassInstanceSetMember(pInstance, MEMBER(bSequenceLoops), !!(g_rgModelSequences[iModelSequence][ModelSequence_Flags] & STUDIO_LOOPING));
      ClassInstanceSetMember(pInstance, MEMBER(bSequenceFinished), false);
    }
  } else {
    g_rgiEntitySequences[this] = -1;
  }
}

method <Base::FrameAdvance> (const this, Float:flInterval) {
  static ClassInstance:pInstance; pInstance = GET_INSTANCE(this);
  if (!pev(this, pev_modelindex)) return 0.0;
  if (!ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) return 0.0;

  static Float:flAnimTime; pev(this, pev_animtime, flAnimTime);

  if (!flAnimTime) return 0.0;
  if (flAnimTime == g_flGameTime) return 0.0;

  if (!flInterval) {
    flInterval = (g_flGameTime - flAnimTime);

    if (flInterval <= 0.001) {
      set_pev(this, pev_animtime, g_flGameTime);
      return 0.0;
    }
  }

  static bool:bSequenceLoops; bSequenceLoops = ClassInstanceGetMember(pInstance, MEMBER(bSequenceLoops));
  static bool:bSequenceFinished; bSequenceFinished = ClassInstanceGetMember(pInstance, MEMBER(bSequenceFinished));
  if (bSequenceFinished && !bSequenceLoops) return 0.0;

  static Float:flFrame; pev(this, pev_frame, flFrame);
  static Float:flFrameRate; pev(this, pev_framerate, flFrameRate);
  static Float:flSequenceFrameRate; flSequenceFrameRate = ClassInstanceGetMember(pInstance, MEMBER(flSequenceFrameRate));

  flFrame += (flSequenceFrameRate * flFrameRate) * flInterval;

  set_pev(this, pev_animtime, g_flGameTime);

  if (flFrame < 0.0 || flFrame >= 256.0) {
    if (bSequenceLoops) {
      flFrame = UTIL_FloatMod(flFrame, 256.0);
    } else {
      flFrame = floatclamp(flFrame, 0.0, 255.0);
    }

    if (!bSequenceFinished) {
      CALL_METHOD<FinishSequence>(this, 0);
    }
  }

  set_pev(this, pev_frame, flFrame);

  ClassInstanceSetMember(pInstance, MEMBER(flLastFrameAdvance), g_flGameTime);

  return flInterval;
}

method <Base::LoadModel> (const this) {
  if (pev(this, pev_modelindex) == g_rgiEntityModelIndexes[this]) return true;

  g_rgiEntityModelIndexes[this] = 0;

  new szModel[MAX_RESOURCE_PATH_LENGTH]; pev(this, pev_model, szModel, charsmax(szModel));
  if (IS_NULLSTR(szModel)) return false;

  g_rgiEntityModels[this] = LoadModel(szModel);
  g_rgiEntityModelIndexes[this] = pev(this, pev_modelindex);

  return true;
}

method <Base::DispatchAnimEvents> (const this, Float:flInterval) {
  if (!pev(this, pev_modelindex)) return;

  new ClassInstance:pInstance = GET_INSTANCE(this);
  if (!ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) return;

  static ModelSequence:iModelSequence; iModelSequence = @Entity_GetModelSequence(this);
  if (iModelSequence == INVALID_SEQUENCE) return;

  static Float:flLastEventCheck; flLastEventCheck = ClassInstanceGetMember(pInstance, MEMBER(flLastEventCheck));
  static Float:flAnimTime; pev(this, pev_animtime, flAnimTime);
  if (flAnimTime <= flLastEventCheck) {
    ClassInstanceSetMember(pInstance, MEMBER(flLastEventCheck), g_flGameTime);
    return;
  }

  // Seconds per frame (for 100 fps it's 0.01)
  if (!flInterval) flInterval = 0.01;

  static Float:flFrame; pev(this, pev_frame, flFrame);
  static Float:flFrameRate; pev(this, pev_framerate, flFrameRate);
  static Float:flSequenceFrameRate; flSequenceFrameRate = ClassInstanceGetMember(pInstance, MEMBER(flSequenceFrameRate));
  static bool:bSequenceLoops; bSequenceLoops = ClassInstanceGetMember(pInstance, MEMBER(bSequenceLoops));
  
  static Float:flEndTime; flEndTime = UTIL_FloatToFixed(g_flGameTime + flInterval, 3);
  static Float:flCalculatedFrameRate; flCalculatedFrameRate = flFrameRate * flSequenceFrameRate;

  /*
    Process events since last event check to the current time (+ tick interval for compensation).
    flStartFrame and flEndFrame is a frame ratio (from 0.0 to 256.0).
  */
  static Float:flStartFrame; flStartFrame = flFrame - ((g_flGameTime - flLastEventCheck) * flCalculatedFrameRate);
  static Float:flEndFrame; flEndFrame = flFrame + ((flEndTime - g_flGameTime) * flCalculatedFrameRate);

  // log_amx("[dispatch] %.3f -> %.3f", flStartFrame, flEndFrame);

  /*
    In case we missed some cycles of sequence, because of high frame rate or low update interval,
    we need to handle missed cycles.
  */
  while ((flStartFrame + XS_FLEQ_TOLERANCE) < flEndFrame) {
    static Float:flSegmentStart; flSegmentStart = flStartFrame;
    static Float:flSegmentEnd; flSegmentEnd = flEndFrame;

    flStartFrame += UTIL_NormalizeFrameRangeSegment(flSegmentStart, flSegmentEnd, bSequenceLoops);

    // log_amx("^t[opeartion] %f -> %f (%f)", flSegmentStart, flSegmentEnd, flStartFrame);

    static iEvent; iEvent = -1;
    while ((iEvent = GetAnimationEvent(iModelSequence, flSegmentStart, flSegmentEnd, iEvent)) != -1) {
      static event; event = g_rgModelSequences[iModelSequence][ModelSequence_Events][iEvent];
      // log_amx("Handling event %d (#%d, idx: %d) for iModelSequence %d", g_rgModelEvents[event][mstudioevent_event], event, iEvent, g_rgiEntitySequences[this]);
      CALL_METHOD<HandleAnimEvent>(this, g_rgModelEvents[event][mstudioevent_event], g_rgModelEvents[event][mstudioevent_options]);
    }

    // Non-looping sequences should only handle events once
    if (!bSequenceLoops) break;
  }

  ClassInstanceSetMember(pInstance, MEMBER(flLastEventCheck), flEndTime);
}

method <Base::HandleAnimEvent> (const this, const iEventId, const rgOptions[32]) {}

method <Base::FinishSequence> (const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, MEMBER(bSequenceFinished), true);
}

method <Base::LookupActivity> (const this, iActivity) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  if (!ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) return ACTIVITY_NOT_AVAILABLE;

  static iModel; iModel = g_rgiEntityModels[this];
  if (iModel == -1) return ACTIVITY_NOT_AVAILABLE;

  static iSequencesNum; iSequencesNum = g_rgModel[iModel][Model_SequencesNum];

  static iActivitySeq; iActivitySeq = ACTIVITY_NOT_AVAILABLE;
  static iTotalWeight; iTotalWeight = 0;

  for (new iSequence = 0; iSequence < iSequencesNum; ++iSequence) {
    static ModelSequence:iModelSequence; iModelSequence = g_rgModel[iModel][Model_Sequences][iSequence];
    static iSeqActivity; iSeqActivity = g_rgModelSequences[iModelSequence][ModelSequence_Activity];

    if (iActivity != iSeqActivity) continue;

    static iActivityWeight; iActivityWeight = g_rgModelSequences[iModelSequence][ModelSequence_ActivityWeight];

    if (!iTotalWeight || random(iTotalWeight - 1) < iActivityWeight) {
      iActivitySeq = iSequence;
    }

    iTotalWeight += iActivityWeight;
  }
  
  return iActivitySeq;
}

method <Base::LookupActivityHeaviest> (const this, iActivity) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  if (!ClassInstanceGetMember(pInstance, MEMBER(bHandleAnimations))) return ACTIVITY_NOT_AVAILABLE;

  static iModel; iModel = g_rgiEntityModels[this];
  if (iModel == -1) return ACTIVITY_NOT_AVAILABLE;

  static iSequencesNum; iSequencesNum = g_rgModel[iModel][Model_SequencesNum];

  new iActivitySeq = ACTIVITY_NOT_AVAILABLE;
  static iWeight; iWeight = 0;

  for (new iSequence = 0; iSequence < iSequencesNum; ++iSequence) {
    static ModelSequence:iModelSequence; iModelSequence = g_rgModel[iModel][Model_Sequences][iSequence];
    static iSeqActivity; iSeqActivity = g_rgModelSequences[iModelSequence][ModelSequence_Activity];

    if (iActivity != iSeqActivity) continue;

    static iActivityWeight; iActivityWeight = g_rgModelSequences[iModelSequence][ModelSequence_ActivityWeight];

    if (iActivityWeight > iWeight) {
      iWeight = iActivityWeight;
      iActivitySeq = iSequence;
    }
  }

  return iActivitySeq;
}

method <Base::GetModelViewOfs> (const this, Float:vecOut[3]) {
  static iModel; iModel = g_rgiEntityModels[this];
  if (iModel == -1) {
    xs_vec_set(vecOut, 0.0, 0.0, 0.0);
    return;
  }

  xs_vec_copy(g_rgModel[iModel][Model_EyePosition], vecOut);
}

method <Base::IsMoving> (const this) {
  return ExecuteHam(Ham_IsMoving, this);
}

/*--------------------------------[ BaseItem Methods Implementation ]--------------------------------*/

method <BaseItem::Spawn> (const this) {
  ClassInstanceCallBaseMethod(this);

  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, MEMBER(bPicked), false);
}

method <BaseItem::InitPhysics> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_TOSS);
  set_pev(this, pev_takedamage, DAMAGE_NO);
}

method <BaseItem::Touch> (const this, const pToucher) {
  if (!IS_PLAYER(pToucher)) return;

  if (!CALL_METHOD<CanPickup>(this, pToucher)) return;

  CALL_METHOD<Pickup>(this, pToucher);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, MEMBER(bPicked), true);
  ExecuteHamB(Ham_Killed, this, pToucher, 0);
}

method <BaseItem::CanPickup> (const this, const pToucher) {
  if (pev(this, pev_deadflag) != DEAD_NO) return false;
  if (~pev(this, pev_flags) & FL_ONGROUND) return false;

  return true;
}

method <BaseItem::Pickup> (const this, const pToucher) {}

/*--------------------------------[ BaseProp Methods Implementation ]--------------------------------*/

method <BaseProp::InitPhysics> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_BBOX);
  set_pev(this, pev_movetype, MOVETYPE_FLY);
  set_pev(this, pev_takedamage, DAMAGE_NO);
}

/*--------------------------------[ BaseMonster Methods Implementation ]--------------------------------*/

method <BaseMonster::Spawn> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);
}

method <BaseMonster::InitPhysics> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_BBOX);
  set_pev(this, pev_movetype, MOVETYPE_PUSHSTEP);
  set_pev(this, pev_takedamage, DAMAGE_AIM);

  set_pev(this, pev_controller_0, 125);
  set_pev(this, pev_controller_1, 125);
  set_pev(this, pev_controller_2, 125);
  set_pev(this, pev_controller_3, 125);

  set_pev(this, pev_gamestate, 1);
  set_pev(this, pev_gravity, 1.0);
  set_pev(this, pev_fixangle, 1);
  set_pev(this, pev_friction, 0.25);
}

/*--------------------------------[ BaseTrigger Methods Implementation ]--------------------------------*/

method <BaseTrigger::Spawn> (const this) {
  ClassInstanceCallBaseMethod(this);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();  
  ClassInstanceSetMember(pInstance, MEMBER(flDelay), 0.1);

  if (get_cvar_num("showtriggers") == 0) {
    set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);
  }
}

method <BaseTrigger::InitPhysics> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
}

method <BaseTrigger::IsTriggered> (const this, const pActivator) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceGetMember(pInstance, MEMBER(bTriggered));
}

method <BaseTrigger::Touch> (const this, const pToucher) {
  if (CALL_METHOD<CanTrigger>(this, pToucher)) {
    CALL_METHOD<Trigger>(this, pToucher);
  }
}

method <BaseTrigger::CanTrigger> (const this, const pActivator) {
  static Float:flNextThink; pev(this, pev_nextthink, flNextThink);

  if (flNextThink > g_flGameTime) return false;

  if (!CALL_METHOD<IsMasterTriggered>(this, pActivator)) return false;

  return true;
}

method <BaseTrigger::Trigger> (const this, const pActivator) {
  static Float:flDelay; ExecuteHamB(Ham_GetDelay, this, flDelay);

  set_pev(this, pev_nextthink, g_flGameTime + flDelay);

  return true;
}

/*--------------------------------[ BaseBSP Methods Implementation ]--------------------------------*/

method <BaseBsp::InitPhysics> (const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_movetype, MOVETYPE_PUSH);
  set_pev(this, pev_solid, SOLID_BSP);
  set_pev(this, pev_flags, pev(this, pev_flags) | FL_WORLDBRUSH);
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock bool:UTIL_IsClassnameLinked(const szClassname[]) {
  new pEntity = engfunc(EngFunc_CreateNamedEntity, GetAllocatedString(szClassname));

  static bool:bLinked; bLinked = !!pEntity;

  if (pEntity) {
    engfunc(EngFunc_RemoveEntity, pEntity);
  }

  return bLinked;
}

stock UTIL_ParseVector(const szBuffer[], Float:vecOut[3]) {
  static rgszOrigin[3][8];
  parse(szBuffer, rgszOrigin[0], charsmax(rgszOrigin[]), rgszOrigin[1], charsmax(rgszOrigin[]), rgszOrigin[2], charsmax(rgszOrigin[]));

  for (new i = 0; i < 3; ++i) {
    vecOut[i] = str_to_float(rgszOrigin[i]);
  }
}

stock bool:UTIL_IsMasterTriggered(const szMaster[], const &pActivator) {
  if (IS_NULLSTR(szMaster)) return true;

  new pMaster = engfunc(EngFunc_FindEntityByString, 0, "targetname", szMaster);
  if (pMaster > 0 && (ExecuteHamB(Ham_ObjectCaps, pMaster) & FCAP_MASTER)) {
    return !!ExecuteHamB(Ham_IsTriggered, pMaster, pActivator);
  }

  return true;
}

stock UTIL_GetStringType(const szString[]) {
  enum {
    string_type = 's',
    integer_type = 'i',
    float_type = 'f'
  };

  static bool:bIsFloat; bIsFloat = false;

  // Check for numeric type
  for (new i = 0; szString[i] != '^0'; ++i) {
    if (szString[i] == '.') {
      if (bIsFloat) return string_type;

      bIsFloat = true;
    } else if (!isdigit(szString[i])) {
      if (!i && szString[i] == '-') continue;
      return string_type;
    }
  }

  return bIsFloat ? float_type : integer_type;
}

stock Float:UTIL_FloatMod(Float:flValue, Float:flDelimiter) {
  return flValue - (float(floatround(flValue / flDelimiter, floatround_floor)) * flDelimiter);
}

stock Float:UTIL_FloatToFixed(Float:flValue, iDigits = 0) {
  static Float:rgrgMultipliers[8][2];

  if (iDigits >= sizeof(rgrgMultipliers)) {
    iDigits = sizeof(rgrgMultipliers) - 1;
  }

  if (!rgrgMultipliers[iDigits][0]) {
    rgrgMultipliers[iDigits][0] = 1.0;

    for (new i = 0; i < iDigits; ++i) {
      rgrgMultipliers[iDigits][0] *= 10.0;
    }
   
    rgrgMultipliers[iDigits][1] = 1.0 / rgrgMultipliers[iDigits][0];
  }

  return floatround(flValue * rgrgMultipliers[iDigits][0], flValue < 0.0 ? floatround_ceil : floatround_floor) * rgrgMultipliers[iDigits][1];
}

stock Float:UTIL_NormalizeFrameRangeSegment(&Float:flStart, &Float:flEnd, bool:bLoops) {
  if (bLoops) {
    // Infinite loop protection
    if (flStart < -0.00001) {
      flStart = flStart < -256.0 ? 0.0 : flStart + 256.0;
      flEnd = 256.0;
    } else if (flStart >= 256.0) {
      /*
        We expect that flStart should be normalized value at the start of the loop.
        The case when flStart is greater than 255 is only possible during processing overflowed flEndFrame.
      */
      flEnd = floatmin(flEnd - flStart, 256.0);
      flStart = 0.0;
    } else {
      if (flEnd > 256.0) flEnd = 256.0;
    }
  } else {
    if (flStart < 0.0) flStart = 0.0;
    if (flEnd > 256.0) flEnd = 256.0;
  }

  return flEnd - flStart;
}
