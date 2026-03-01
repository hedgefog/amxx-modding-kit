#pragma semicolon 1;

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#tryinclude <cstrike>

#include <cellclass>
#include <function_pointer>
#include <stack>
#include <command_util>
#include <callfunc>
#include <varargs>

#include <api_player_roles_const>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define LOG_PREFIX "[Player Role]"
#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define METHOD(%1) PlayerRole_Method_%1

#define BASE_ROLE "__base_role"

#define CLASS_METADATA_NAME "__NAME"
#define CLASS_METADATA_ID "__ROLE_ID"

#define CLASS_INSTANCE_MEMBER_POINTER "__pPlayer"

#define ERR_INVALID_ROLE_ID "Role ^"%s^" is not registered."
#define ERR_INVALID_PLAYER_ID "Invalid player ID: %d"
#define ERR_INVALID_FUNCTION "Cannot find function ^"%s^" in plugin ^"%s^"."
#define ERR_ROLE_ALREADY_REGISTERED "Role ^"%s^" is already registered."
#define ERR_PLAYER_ROLE_NOT_ASSIGNED "Player ^"%n^" does not have role ^"%s^" assigned."
#define ERR_FUNCTION_NOT_FOUND "Function ^"%s^" not found in plugin ^"%s^"."

#define MAX_METHOD_HOOKS 64

STACK_DEFINE(METHOD_PLUGIN, 256);
STACK_DEFINE(METHOD_RETURN, 256);
STACK_DEFINE(METHOD_HOOKS_Pre, 256);
STACK_DEFINE(METHOD_HOOKS_Post, 256);

new Trie:g_itRoleIds = Invalid_Trie;
new Trie:g_itAssignmentGroupIds = Invalid_Trie;

new const g_rgszMethodNames[PlayerRole_Method][PLAYER_ROLE_MAX_METHOD_NAME_LENGTH];

new g_rgszRoleId[PLAYER_ROLE_MAX_ROLES][PLAYER_ROLE_MAX_LENGTH];
new Class:g_rgcRoleClass[PLAYER_ROLE_MAX_ROLES];
new g_rgiRoleRootRoleId[PLAYER_ROLE_MAX_ROLES];
new Function:g_rgrgrgfnClassMethodPreHooks[PLAYER_ROLE_MAX_ROLES][PlayerRole_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPreHooksNum[PLAYER_ROLE_MAX_ROLES][PlayerRole_Method];
new Function:g_rgrgrgfnClassMethodPostHooks[PLAYER_ROLE_MAX_ROLES][PlayerRole_Method][MAX_METHOD_HOOKS];
new g_rgrgiClassMethodPostHooksNum[PLAYER_ROLE_MAX_ROLES][PlayerRole_Method];
new g_iRolesNum = 0;

new g_rgszAssignmentGroupId[PLAYER_ROLE_MAX_ASSIGNMENT_GROUPS][PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH];
new g_iAssignmentGroupsNum = 0;

new g_rgrgiPlayerRoles[MAX_PLAYERS + 1][PLAYER_ROLE_MAX_ROLES];
new ClassInstance:g_rgrgiPlayerRoleInstance[MAX_PLAYERS + 1][PLAYER_ROLE_MAX_ROLES];
new g_rgrgiPlayerRoleGroups[MAX_PLAYERS + 1][PLAYER_ROLE_MAX_ROLES];
new g_rgiPlayerRolesNum[MAX_PLAYERS + 1];
new g_rgrgiPlayerRoleIndexMap[MAX_PLAYERS + 1][PLAYER_ROLE_MAX_ROLES];

#define INIT_METHOD_NAME(%1) copy(g_rgszMethodNames[PlayerRole_Method_%1], charsmax(g_rgszMethodNames[]), #%1)

public plugin_precache() {
  g_itRoleIds = TrieCreate();
  g_itAssignmentGroupIds = TrieCreate();

  INIT_METHOD_NAME(Assign);
  INIT_METHOD_NAME(Unassign);

  Role_Register(BASE_ROLE);
  Role_ImplementClassMethod(BASE_ROLE, PlayerRole_Method_Assign, get_func_pointer("@BaseRole_Assign"));
  Role_ImplementClassMethod(BASE_ROLE, PlayerRole_Method_Unassign, get_func_pointer("@BaseRole_Unassign"));
}

public plugin_init() {
  register_plugin("[API] Player Roles", "1.0.0", "Hedgehog Fog");

  register_concmd("player_role_assign", "Command_AssignRole", ADMIN_CVAR);
  register_concmd("player_role_unassign", "Command_UnassignRole", ADMIN_CVAR);
  register_concmd("player_role_group_unassign", "Command_UnassignRoleGroup", ADMIN_CVAR);
  register_concmd("player_role_get_by_group", "Command_GetRoleByGroup", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_player_roles");

  register_native("PlayerRole_Register", "Native_RegisterRole");
  register_native("PlayerRole_IsRegistered", "Native_IsRoleRegistered");
  register_native("PlayerRole_RegisterMethod", "Native_RegisterRoleMethod");
  register_native("PlayerRole_RegisterVirtualMethod", "Native_RegisterRoleVirtualMethod");
  register_native("PlayerRole_ImplementMethod", "Native_ImplementMethod");
  register_native("PlayerRole_RegisterNativeMethodHook", "Native_RegisterMethodHook");
  register_native("PlayerRole_Is", "Native_IsRole");

  register_native("PlayerRole_Player_AssignRole", "Native_PlayerAssignRole");
  register_native("PlayerRole_Player_UnassignRole", "Native_PlayerUnassignRole");
  register_native("PlayerRole_Player_UnassignRoles", "Native_PlayerUnassignRoles");
  register_native("PlayerRole_Player_UnassignRoleGroup", "Native_PlayerUnassignRoleGroup");
  register_native("PlayerRole_Player_HasRole", "Native_PlayerHasRole");
  register_native("PlayerRole_Player_HasExactRole", "Native_PlayerHasExactRole");
  register_native("PlayerRole_Player_HasRoleGroup", "Native_PlayerHasRoleGroup");
  register_native("PlayerRole_Player_GetRoleByGroup", "Native_PlayerGetRoleByGroup");

  register_native("PlayerRole_Player_HasMember", "Native_HasRoleMember");
  register_native("PlayerRole_Player_GetMember", "Native_GetRoleMember");
  register_native("PlayerRole_Player_SetMember", "Native_SetRoleMember");
  register_native("PlayerRole_Player_DeleteMember", "Native_DeleteRoleMember");
  register_native("PlayerRole_Player_GetMemberVec", "Native_GetRoleMemberVec");
  register_native("PlayerRole_Player_SetMemberVec", "Native_SetRoleMemberVec");
  register_native("PlayerRole_Player_GetMemberString", "Native_GetRoleMemberString");
  register_native("PlayerRole_Player_SetMemberString", "Native_SetRoleMemberString");

  register_native("PlayerRole_Player_CallMethod", "Native_CallRoleMethod");

  register_native("PlayerRole_This_HasMember", "Native_HasThisRoleMember");
  register_native("PlayerRole_This_GetMember", "Native_GetThisRoleMember");
  register_native("PlayerRole_This_SetMember", "Native_SetThisRoleMember");
  register_native("PlayerRole_This_DeleteMember", "Native_DeleteThisRoleMember");
  register_native("PlayerRole_This_GetMemberVec", "Native_GetThisRoleMemberVec");
  register_native("PlayerRole_This_SetMemberVec", "Native_SetThisRoleMemberVec");
  register_native("PlayerRole_This_GetMemberString", "Native_GetThisRoleMemberString");
  register_native("PlayerRole_This_SetMemberString", "Native_SetThisRoleMemberString");

  register_native("PlayerRole_This_CallMethod", "Native_CallThisRoleMethod");
  register_native("PlayerRole_This_CallBaseMethod", "Native_CallRoleBaseMethod");

  register_native("PlayerRole_This_CallerPlugin", "Native_CallerPlugin");
}

public plugin_end() {
  TrieDestroy(g_itRoleIds);
  TrieDestroy(g_itAssignmentGroupIds);

  for (new iRole = 0; iRole < g_iRolesNum; ++iRole) {
    ClassDestroy(g_rgcRoleClass[iRole]);
  }
}

/*--------------------------------[ Natives ]--------------------------------*/

public bool:Native_IsRoleRegistered(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  return Role_GetId(szRoleId) != -1;
}

public Native_RegisterRole(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  new szParentRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szParentRoleId, charsmax(szParentRoleId));

  if (Role_GetId(szRoleId) != -1) {
    LOG_FATAL_ERROR(ERR_ROLE_ALREADY_REGISTERED, szRoleId);
    return;
  }

  if (!equal(szParentRoleId, NULL_STRING)) {
    if (Role_GetId(szParentRoleId) == -1) {
      LOG_FATAL_ERROR(ERR_INVALID_ROLE_ID, szParentRoleId);
      return;
    }
  } else {
    copy(szParentRoleId, charsmax(szParentRoleId), BASE_ROLE);
  }

  Role_Register(szRoleId, szParentRoleId);
}

public Native_PlayerAssignRole(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szGroupId[PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH]; get_string(3, szGroupId, charsmax(szGroupId));

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return;
  }

  Player_AssignRole(pPlayer, szRoleId, szGroupId);
}

public Native_PlayerUnassignRole(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static bool:bExact; bExact = bool:get_param(3);

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return;
  }

  Player_UnassignRole(pPlayer, szRoleId, bExact);
}

public Native_PlayerUnassignRoles(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return;
  }

  Player_UnassignRoles(pPlayer);
}

public Native_PlayerUnassignRoleGroup(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szGroupId[PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH]; get_string(2, szGroupId, charsmax(szGroupId));

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return;
  }

  Player_UnassignRoleGroup(pPlayer, szGroupId);
}

public bool:Native_PlayerHasRole(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return false;
  }

  return Player_HasRole(pPlayer, szRoleId, false);
}

public bool:Native_PlayerHasExactRole(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return false;
  }

  return Player_HasRole(pPlayer, szRoleId, true);
}

public bool:Native_PlayerHasRoleGroup(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szGroupId[PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH]; get_string(2, szGroupId, charsmax(szGroupId));

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return false;
  }

  static iRoleId; iRoleId = Player_FindRoleByGroup(pPlayer, szGroupId);
  if (iRoleId == -1) return false;

  return true;
}

public bool:Native_PlayerGetRoleByGroup(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szGroupId[PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH]; get_string(2, szGroupId, charsmax(szGroupId));

  static iRoleId; iRoleId = Player_FindRoleByGroup(pPlayer, szGroupId);
  if (iRoleId == -1) return false;

  if (!IS_PLAYER(pPlayer)) {
    LOG_FATAL_ERROR(ERR_INVALID_PLAYER_ID, pPlayer);
    return false;
  }

  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; copy(szRoleId, charsmax(szRoleId), g_rgszRoleId[iRoleId]);

  set_string(3, szRoleId, get_param(4));

  return true;
}

public bool:Native_RegisterRoleMethod(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  new szMethod[PLAYER_ROLE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[PLAYER_ROLE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));
  
  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    LOG_FATAL_ERROR(ERR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodRegistrationParamsFromNativeCall(4, iArgc);
  Role_AddClassMethod(szRoleId, szMethod, fnCallback, irgParamsTypes, false);
  ArrayDestroy(irgParamsTypes);
}

public bool:Native_RegisterRoleVirtualMethod(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  new szMethod[PLAYER_ROLE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[PLAYER_ROLE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));
  
  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    LOG_FATAL_ERROR(ERR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodRegistrationParamsFromNativeCall(4, iArgc);
  Role_AddClassMethod(szRoleId, szMethod, fnCallback, irgParamsTypes, true);
  ArrayDestroy(irgParamsTypes);
}

public Native_ImplementMethod(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  new PlayerRole_Method:iMethod = PlayerRole_Method:get_param(2);
  new szCallback[PLAYER_ROLE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    LOG_FATAL_ERROR(ERR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  Role_ImplementClassMethod(szRoleId, iMethod, fnCallback);
}

public Native_RegisterMethodHook(const iPluginId, const iArgc) {
  new szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  new PlayerRole_Method:iMethod = PlayerRole_Method:get_param(2);
  new szCallback[PLAYER_ROLE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));
  new bool:bPost = bool:get_param(4);

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    LOG_FATAL_ERROR(ERR_FUNCTION_NOT_FOUND, szCallback, szFilename);
    return;
  }

  Role_RegisterClassMethodHook(szRoleId, iMethod, fnCallback, bPost);
}

public bool:Native_IsRole(const iPluginId, const iArgc) {
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(1, szRoleId, charsmax(szRoleId));
  static szOtherRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szOtherRoleId, charsmax(szOtherRoleId));
  static bool:bExact; bExact = bool:get_param(3);

  static iRoleId; iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) {
    LOG_ERROR(ERR_INVALID_ROLE_ID, szRoleId);
    return false;
  }

  static iOtherRoleId; iOtherRoleId = Role_GetId(szOtherRoleId);
  if (iOtherRoleId == -1) {
    LOG_ERROR(ERR_INVALID_ROLE_ID, szOtherRoleId);
    return false;
  }

  if (bExact) return iRoleId == iOtherRoleId;

  return ClassIs(g_rgcRoleClass[iRoleId], g_rgcRoleClass[iOtherRoleId]);
}

public bool:Native_HasRoleMember(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return false;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetRoleMember(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return false;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  return ClassInstanceGetMember(pInstance, szMember);
}

public Native_SetRoleMember(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));
  static iValue; iValue = get_param(4);
  static bool:bReplace; bReplace = bool:get_param(5);

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public Native_DeleteRoleMember(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  ClassInstanceDeleteMember(pInstance, szMember);
}

public bool:Native_GetRoleMemberVec(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return false;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(4, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetRoleMemberVec(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(4, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(5);

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public bool:Native_GetRoleMemberString(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return false;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, szValue, charsmax(szValue))) return false;

  set_string(4, szValue, get_param(4));

  return true;
}

public Native_SetRoleMemberString(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));
  static szValue[128]; get_string(4, szValue, charsmax(szValue));
  static bool:bReplace; bReplace = bool:get_param(5);

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];
  ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public Native_CallRoleMethod(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szRoleId[PLAYER_ROLE_MAX_LENGTH]; get_string(2, szRoleId, charsmax(szRoleId));
  static szMethod[PLAYER_ROLE_MAX_METHOD_NAME_LENGTH]; get_string(3, szMethod, charsmax(szMethod));

  static iRole; iRole = Player_GetRoleIndex(pPlayer, szRoleId);
  if (iRole == -1) {
    LOG_ERROR(ERR_PLAYER_ROLE_NOT_ASSIGNED, pPlayer, szRoleId);
    return 0;
  }

  static ClassInstance:pInstance; pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRole];

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallMethodBegin(pInstance, szMethod);
  ClassInstanceCallMethodPushParamCell(pPlayer);
  ClassInstanceCallMethodPushNativeArgParams(4, iArgc - 3);
  static any:result; result = ClassInstanceCallMethodEnd();

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public Native_HasThisRoleMember(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetThisRoleMember(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceGetMember(pInstance, szMember);
}

public Native_SetThisRoleMember(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));
  static iValue; iValue = get_param(2);
  static bool:bReplace; bReplace = bool:get_param(3);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public Native_DeleteThisRoleMember(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceDeleteMember(pInstance, szMember);
}

public Native_GetThisRoleMemberVec(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(2, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetThisRoleMemberVec(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(2, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(5);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public Native_GetThisRoleMemberString(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, szValue, charsmax(szValue))) return false;

  set_string(2, szValue, get_param(3));

  return true;
}

public Native_SetThisRoleMemberString(const iPluginId, const iArgc) {
  static szMember[PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH]; get_string(1, szMember, charsmax(szMember));
  static szValue[128]; get_string(2, szValue, charsmax(szValue));
  static bool:bReplace; bReplace = bool:get_param(3);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public Native_CallThisRoleMethod(const iPluginId, const iArgc) {
  static szMethod[PLAYER_ROLE_MAX_METHOD_NAME_LENGTH]; get_string(1, szMethod, charsmax(szMethod));

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallMethodBegin(pInstance, szMethod);
  ClassInstanceCallMethodPushParamCell(ClassInstanceGetMember(pInstance, CLASS_INSTANCE_MEMBER_POINTER));
  ClassInstanceCallMethodPushNativeArgParams(2, iArgc - 1);
  static any:result; result = ClassInstanceCallMethodEnd();

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public Native_CallRoleBaseMethod(const iPluginId, const iArgc) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static pPlayer; pPlayer = ClassInstanceGetMember(pInstance, CLASS_INSTANCE_MEMBER_POINTER);

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallBaseMethodBegin();
  ClassInstanceCallMethodPushParamCell(pPlayer);
  ClassInstanceCallMethodPushNativeArgParams(1, iArgc);
  static any:result; result = ClassInstanceCallMethodEnd();

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public Native_CallerPlugin(const iPluginId, const iArgc) {
  return STACK_READ(METHOD_PLUGIN);
}

Array:ReadMethodRegistrationParamsFromNativeCall(iStartArg, iArgc) {
  static Array:irgParams; irgParams = ArrayCreate();

  static iParam;
  for (iParam = iStartArg; iParam <= iArgc; ++iParam) {
    static iType; iType = get_param_byref(iParam);

    switch (iType) {
      case PlayerRole_Type_Cell: {
        ArrayPushCell(irgParams, ClassDataType_Cell);
      }
      case PlayerRole_Type_String: {
        ArrayPushCell(irgParams, ClassDataType_String);
      }
      case PlayerRole_Type_Array: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, get_param_byref(iParam + 1));
        iParam++;
      }
      case PlayerRole_Type_Vector: {
        ArrayPushCell(irgParams, ClassDataType_Array);
        ArrayPushCell(irgParams, 3);
      }
    }
  }

  return irgParams;
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_AssignRole(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szRoleId[32]; read_argv(2, szRoleId, charsmax(szRoleId));
  static szGroupId[32]; read_argv(3, szGroupId, charsmax(szGroupId));

  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    Player_AssignRole(pTarget, szRoleId, szGroupId);
  }

  return PLUGIN_HANDLED;
}

public Command_UnassignRole(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;
  
  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szRoleId[32]; read_argv(2, szRoleId, charsmax(szRoleId));

  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    Player_UnassignRole(pTarget, szRoleId);
  }

  return PLUGIN_HANDLED;
}

public Command_UnassignRoleGroup(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szGroupId[32]; read_argv(2, szGroupId, charsmax(szGroupId));

  new iGroupId = RoleGroup_GetId(szGroupId);
  if (iGroupId == -1) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    Player_UnassignRoleGroup(pTarget, szGroupId);
  }

  return PLUGIN_HANDLED;
}

public Command_GetRoleByGroup(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szGroupId[32]; read_argv(2, szGroupId, charsmax(szGroupId));

  new iGroupId = RoleGroup_GetId(szGroupId);
  if (iGroupId == -1) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;

    static iRoleId; iRoleId = Player_FindRoleByGroup(pPlayer, szGroupId);
    if (iRoleId == -1) continue;

    console_print(pPlayer, "^"%n^" have role ^"%s^" in group ^"%s^".", pTarget, g_rgszRoleId[iRoleId], szGroupId);
  }

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(pPlayer) {
  g_rgiPlayerRolesNum[pPlayer] = 0;

  for (new iRoleId = 0; iRoleId < sizeof(g_rgrgiPlayerRoleIndexMap[]); ++iRoleId) {
    g_rgrgiPlayerRoleIndexMap[pPlayer][iRoleId] = -1;
  }
}

public client_disconnected(pPlayer) {
  Player_UnassignRoles(pPlayer);
}

/*--------------------------------[ Role Group Methods ]--------------------------------*/

RoleGroup_Register(const szGroupId[]) {
  new iGroupId = g_iAssignmentGroupsNum;

  copy(g_rgszAssignmentGroupId[iGroupId], charsmax(g_rgszAssignmentGroupId[]), szGroupId);
  TrieSetCell(g_itAssignmentGroupIds, szGroupId, iGroupId);

  g_iAssignmentGroupsNum++;

  return iGroupId;  
}

RoleGroup_GetId(const szGroupId[]) {
  static iGroupId;
  if (!TrieGetCell(g_itAssignmentGroupIds, szGroupId, iGroupId)) return -1;

  return iGroupId;
}

/*--------------------------------[ Role Methods ]--------------------------------*/

Role_Register(const szRoleId[], const szParentRole[] = "") {
  new iRoleId = g_iRolesNum;

  copy(g_rgszRoleId[iRoleId], charsmax(g_rgszRoleId[]), szRoleId);
  TrieSetCell(g_itRoleIds, szRoleId, iRoleId);

  new iParentRoleId = !equal(szParentRole, NULL_STRING) ? Role_GetId(szParentRole) : -1;
  new Class:cParent = iParentRoleId != -1 ? g_rgcRoleClass[iParentRoleId] : Invalid_Class;

  g_rgcRoleClass[iRoleId] = ClassCreate(cParent);
  ClassSetMetadata(g_rgcRoleClass[iRoleId], CLASS_METADATA_ID, iRoleId);
  ClassSetMetadataString(g_rgcRoleClass[iRoleId], CLASS_METADATA_NAME, szRoleId);

  /*
    Custom logic for role inheritance. Used for relation check during role assignment.
    Each role is inherits from `BASE_ROLE` so we can't use original `ClassIsRelated()` check because it will always return `true`.
  */
  if (iParentRoleId != -1 && iParentRoleId != Role_GetId(BASE_ROLE)) {
    g_rgiRoleRootRoleId[iRoleId] = g_rgiRoleRootRoleId[iParentRoleId];
  } else {
    g_rgiRoleRootRoleId[iRoleId] = iRoleId;
  }

  g_iRolesNum++;

  LOG_INFO("Role ^"%s^" successfully registred.", szRoleId);
}

Role_GetId(const szRoleId[]) {
  static iRoleId;
  if (!TrieGetCell(g_itRoleIds, szRoleId, iRoleId)) return -1;

  return iRoleId;
}

Role_AddClassMethod(const szRoleId[], const szMethod[], const Function:fnCallback, Array:irgParamTypes, bool:bVirtual) {
  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) {
    LOG_FATAL_ERROR(ERR_INVALID_ROLE_ID, szRoleId);
    return;
  }

  ClassDefineMethod(g_rgcRoleClass[iRoleId], szMethod, fnCallback, bVirtual, ClassDataType_Cell, ClassDataType_ParamsCellArray, irgParamTypes);
}

Role_ImplementClassMethod(const szRoleId[], const PlayerRole_Method:iMethod, const Function:fnCallback) {
  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) {
    LOG_FATAL_ERROR(ERR_INVALID_ROLE_ID, szRoleId);
    return;
  }

  ClassDefineMethod(g_rgcRoleClass[iRoleId], g_rgszMethodNames[iMethod], fnCallback, true, ClassDataType_Cell);
}


Role_RegisterClassMethodHook(const szRoleId[], const PlayerRole_Method:iMethod, const Function:fnCallback, bool:bPost) {
  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) {
    LOG_FATAL_ERROR(ERR_INVALID_ROLE_ID, szRoleId);
    return -1;
  }

  if (bPost) {
    new iHookId = g_rgrgiClassMethodPostHooksNum[iRoleId][iMethod];
    g_rgrgrgfnClassMethodPostHooks[iRoleId][iMethod][iHookId] = fnCallback;
    g_rgrgiClassMethodPostHooksNum[iRoleId][iMethod]++;
    return iHookId;
  } else {
    new iHookId = g_rgrgiClassMethodPreHooksNum[iRoleId][iMethod];
    g_rgrgrgfnClassMethodPreHooks[iRoleId][iMethod][iHookId] = fnCallback;
    g_rgrgiClassMethodPreHooksNum[iRoleId][iMethod]++;
    return iHookId;
  }
}

/*--------------------------------[ Player Methods ]--------------------------------*/

Player_AssignRole(const &this, const szRoleId[], const szGroupId[]) {
  new iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) return;

  new iGroupId = -1;
  if (!equal(szGroupId, NULL_STRING)) {
    iGroupId = RoleGroup_GetId(szGroupId);

    if (iGroupId == -1) {
      iGroupId = RoleGroup_Register(szGroupId);
    }
  }

  for (new iRoleIndex = g_rgiPlayerRolesNum[this] - 1; iRoleIndex >= 0; --iRoleIndex) {
    new iCurrentRoleId = g_rgrgiPlayerRoles[this][iRoleIndex];

    // Role is already assigned
    if (iCurrentRoleId == iRoleId) return;

    // Unassign role if it is in the same group with the new role
    if (g_rgrgiPlayerRoleGroups[this][iRoleIndex] != -1 && g_rgrgiPlayerRoleGroups[this][iRoleIndex] == iGroupId) {
      Player_UnassignRoleByIndex(this, iRoleIndex);
      continue;
    }

    // Unassign role if it is related to the new role (have same parent)
    if (g_rgiRoleRootRoleId[iCurrentRoleId] == g_rgiRoleRootRoleId[iRoleId]) {
      Player_UnassignRoleByIndex(this, iRoleIndex);
      continue;
    }
  }

  new iIndex = g_rgiPlayerRolesNum[this];

  g_rgrgiPlayerRoles[this][iIndex] = iRoleId;
  g_rgrgiPlayerRoleInstance[this][iIndex] = ClassInstanceCreate(g_rgcRoleClass[iRoleId]);
  g_rgrgiPlayerRoleGroups[this][iIndex] = iGroupId;
  ClassInstanceSetMember(g_rgrgiPlayerRoleInstance[this][iIndex], CLASS_INSTANCE_MEMBER_POINTER, this);

  g_rgrgiPlayerRoleIndexMap[this][iRoleId] = iIndex;

  g_rgiPlayerRolesNum[this]++;

  ExecuteRoleMethod(iRoleId, PlayerRole_Method_Assign, this);

  LOG_INFO("Role ^"%s^" is assigned to player ^"%n^".", g_rgszRoleId[iRoleId], this);
}

Player_UnassignRole(const &this, const szRoleId[], bool:bExact = false) {
  new iRoleIndex = Player_GetRoleIndex(this, szRoleId, bExact);
  if (iRoleIndex == -1) return;

  Player_UnassignRoleByIndex(this, iRoleIndex);
}

Player_UnassignRoleByIndex(const &this, const iRoleIndex) {
  new iRoleId = g_rgrgiPlayerRoles[this][iRoleIndex];
  ExecuteRoleMethod(iRoleId, PlayerRole_Method_Unassign, this);

  new iRolesNum = g_rgiPlayerRolesNum[this];

  ClassInstanceDestroy(g_rgrgiPlayerRoleInstance[this][iRoleIndex]);
  g_rgrgiPlayerRoles[this][iRoleIndex] = g_rgrgiPlayerRoles[this][iRolesNum - 1];
  g_rgrgiPlayerRoleInstance[this][iRoleIndex] = g_rgrgiPlayerRoleInstance[this][iRolesNum - 1];
  g_rgrgiPlayerRoleGroups[this][iRoleIndex] = g_rgrgiPlayerRoleGroups[this][iRolesNum - 1];
  g_rgrgiPlayerRoles[this][iRolesNum - 1] = -1;
  g_rgrgiPlayerRoleInstance[this][iRolesNum - 1] = Invalid_ClassInstance;
  g_rgrgiPlayerRoleGroups[this][iRolesNum - 1] = -1;
  g_rgiPlayerRolesNum[this]--;

  g_rgrgiPlayerRoleIndexMap[this][iRoleId] = -1;

  // Update index of the role that was moved to the unassigned role's position
  new iNewRoleId = g_rgrgiPlayerRoles[this][iRoleIndex];
  if (iNewRoleId != -1) {
    g_rgrgiPlayerRoleIndexMap[this][iNewRoleId] = iRoleIndex;
  }

  LOG_INFO("Role ^"%s^" is unassigned from player ^"%n^".", g_rgszRoleId[iRoleId], this);
}

Player_UnassignRoles(const &this) {
  new iRolesNum = g_rgiPlayerRolesNum[this];

  for (new iRoleIndex = iRolesNum - 1; iRoleIndex >= 0; --iRoleIndex) {
    Player_UnassignRoleByIndex(this, iRoleIndex);
  }

  g_rgiPlayerRolesNum[this] = 0;
}

Player_UnassignRoleGroup(const &this, const szGroupId[]) {
  new iGroupId = RoleGroup_GetId(szGroupId);
  if (iGroupId == -1) return;

  for (new iRoleIndex = g_rgiPlayerRolesNum[this] - 1; iRoleIndex >= 0; --iRoleIndex) {
    if (g_rgrgiPlayerRoleGroups[this][iRoleIndex] == iGroupId) {
      Player_UnassignRoleByIndex(this, iRoleIndex);

      // Force break. Only signle role with same group can be assigned.
      break;
    }
  }
}

bool:Player_HasRole(const &this, const szRoleId[], bool:bExact = false) {
  return Player_GetRoleIndex(this, szRoleId, bExact) != -1;
}

Player_GetRoleIndex(const &this, const szRoleId[], bool:bExact = false) {
  static iRoleId; iRoleId = Role_GetId(szRoleId);
  if (iRoleId == -1) return -1;

  static iRolesNum; iRolesNum = g_rgiPlayerRolesNum[this];

  if (g_rgrgiPlayerRoleIndexMap[this][iRoleId] != -1) return g_rgrgiPlayerRoleIndexMap[this][iRoleId];

  if (!bExact) {
    for (new iRole = 0; iRole < iRolesNum; ++iRole) {
      if (ClassInstanceIsInstanceOf(g_rgrgiPlayerRoleInstance[this][iRole], g_rgcRoleClass[iRoleId])) return iRole;
    }
  }

  return -1;
}

Player_FindRoleByGroup(const &this, const szGroupId[]) {
  static iGroupId; iGroupId = RoleGroup_GetId(szGroupId);
  if (iGroupId == -1) return -1;

  static iRolesNum; iRolesNum = g_rgiPlayerRolesNum[this];

  for (new iRoleIndex = 0; iRoleIndex < iRolesNum; ++iRoleIndex) {
    if (g_rgrgiPlayerRoleGroups[this][iRoleIndex] == iGroupId) {
      return g_rgrgiPlayerRoles[this][iRoleIndex];
    }
  }

  return -1;
}

/*--------------------------------[ Class Method Functions ]--------------------------------*/

any:ExecuteRoleMethod(const iRoleId, const PlayerRole_Method:iMethod, const &pPlayer) {
  new iPreHookStackPosition = STACK_SIZE(METHOD_HOOKS_Pre);
  new iPostHookStackPosition = STACK_SIZE(METHOD_HOOKS_Post);

  new iRoleIndex = g_rgrgiPlayerRoleIndexMap[pPlayer][iRoleId];
  new ClassInstance:pInstance = g_rgrgiPlayerRoleInstance[pPlayer][iRoleIndex];
  
  new Class:class = Invalid_Class;
  if (!STACK_EMPTY(METHOD_HOOKS_Pre) || !STACK_EMPTY(METHOD_HOOKS_Post)) {
    class = ClassInstanceGetClass(pInstance);
  }

  STACK_PUSH(METHOD_RETURN, 0);
  callfunc_prepare_arg_types(CFP_Cell, CFP_String);

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
        callfunc_call(get_pfunc_function(fnCurrentHookCb), get_pfunc_plugin(fnCurrentHookCb), pPlayer, g_rgszRoleId[iRoleId]),\
        iHookResult\
      ),\
      fnCurrentHookCb = STACK_POP(METHOD_HOOKS_%1);

  for (new Class:cCurrent = g_rgcRoleClass[iRoleId]; cCurrent != Invalid_Class; cCurrent = ClassGetBaseClass(cCurrent)) {
    static iRoleId; iRoleId = ClassGetMetadata(cCurrent, CLASS_METADATA_ID);
    PUSH_HOOKS_TO_STACK<Pre>(iRoleId)
    PUSH_HOOKS_TO_STACK<Post>(iRoleId)
  }

  CALL_METHOD_HOOKS<Pre>()
  if (iHookResult != PLAYER_ROLE_SUPERCEDE) iCallResult = ClassInstanceCallMethod(pInstance, g_rgszMethodNames[iMethod], class, pPlayer);
  if (iHookResult <= PLAYER_ROLE_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);
  CALL_METHOD_HOOKS<Post>()
  if (iHookResult <= PLAYER_ROLE_HANDLED) STACK_PATCH(METHOD_RETURN, iCallResult);

  return STACK_POP(METHOD_RETURN);
}

/*--------------------------------[ Methods ]--------------------------------*/

@BaseRole_Assign() {}
@BaseRole_Unassign() {}
