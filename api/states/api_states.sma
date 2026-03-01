#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <function_pointer>

#include <api_states_const>

#define LOG_PREFIX "[States]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define ERR_CONTEXT_NOT_REGISTERED "Context ^"%s^" is not registered"

enum StateContext {
  StateContext_Id,
  StateContext_HooksNum,
  StateContext_GuardsNum,
  StateContext_InitialState,
  StateContext_Name[STATE_CONTEXT_MAX_NAME_LEN],
  Function:StateContext_Guards[STATE_MAX_CONTEXT_GUARDS],
  StateContext_Hooks[STATE_MAX_CONTEXT_HOOKS],
};

enum StateManager {
  StateManager_ContextId,
  bool:StateManager_Free,
  any:StateManager_State,
  any:StateManager_NextState,
  any:StateManager_PrevState,
  Float:StateManager_StartChangeTime,
  Float:StateManager_ChangeTime,
  any:StateManager_UserToken
};

enum StateHookType {
  StateHookType_Change = 0,
  StateHookType_Enter,
  StateHookType_Exit,
  StateHookType_Transition,
  StateHookType_Reset
};

enum StateHook {
  StateHookType:StateHook_Type,
  any:StateHook_From,
  any:StateHook_To,
  Function:StateHook_Function
};

enum StateChange {
  bool:StateChange_Scheduled,
  any:StateChange_Value,
  Float:StateChange_TransitionTime,
  bool:StateChange_Force
};

new g_rgStateHooks[STATE_MAX_HOOKS][StateHook];
new g_iStateHooksNum = 0;

new Trie:g_itStateContexts = Invalid_Trie;
new g_rgStateContexts[STATE_MAX_CONTEXTS][StateContext];
new g_iStateContextsNum = 0;

new g_rgStateManagers[STATE_MAX_MANAGERS][StateManager];
new g_iStateManagersNum = 0;

new g_iFreeStateManagersNum = 0;

// Used to correctly handle state changes during hook calls
new bool:g_bProcessingStateChange = false;
new g_rgScheduledChange[StateChange] = { false, 0, 0.0, false };

new bool:g_bDebug = false;

/*--------------------------------[ Initialization ]--------------------------------*/

public plugin_precache() {
  g_itStateContexts = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] States", "1.0.0", "Hedgehog Fog");

  #if AMXX_VERSION_NUM < 183
    g_bDebug = !!get_cvar_num("developer");
  #else
    bind_pcvar_num(get_cvar_pointer("developer"), g_bDebug);
  #endif
}

public plugin_natives() {
  register_library("api_states");

  register_native("State_Context_Register", "Native_RegisterContext");
  register_native("State_Context_IsRegistered", "Native_IsContextRegistered");
  register_native("State_Context_RegisterChangeGuard", "Native_RegisterContextChangeGuard");
  register_native("State_Context_RegisterChangeHook", "Native_RegisterContextChangeHook");
  register_native("State_Context_RegisterEnterHook", "Native_RegisterContextEnterHook");
  register_native("State_Context_RegisterExitHook", "Native_RegisterContextExitHook");
  register_native("State_Context_RegisterTransitionHook", "Native_RegisterContextTransitionHook");
  register_native("State_Context_RegisterResetHook", "Native_RegisterContextResetHook");

  register_native("State_Manager_Create", "Native_CreateManager");
  register_native("State_Manager_Destroy", "Native_DestroyManager");
  register_native("State_Manager_ResetState", "Native_ResetManagerState");
  register_native("State_Manager_SetState", "Native_SetManagerState");
  register_native("State_Manager_GetState", "Native_GetManagerState");
  register_native("State_Manager_GetPrevState", "Native_GetManagerPrevState");
  register_native("State_Manager_GetNextState", "Native_GetManagerNextState");
  register_native("State_Manager_GetUserToken", "Native_GetManagerUserToken");

  register_native("State_Manager_IsInTransition", "Native_IsManagerInTransition");
  register_native("State_Manager_EndTransition", "Native_EndManagerTransition");
  register_native("State_Manager_CancelTransition", "Native_CancelManagerTransition");
  register_native("State_Manager_GetTransitionProgress", "Native_GetManagerTransitionProgress");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterContext(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:initialState = any:get_param(2);

  return StateContext_Register(szContext, initialState);
}

public Native_IsContextRegistered(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) return false;

  return true;
}

public Native_RegisterContextChangeGuard(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(2, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterGuard(iContextId, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextChangeHook(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(2, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterHook(iContextId, StateHookType_Change, _, _, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextEnterHook(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:toState = any:get_param(2);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(3, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterHook(iContextId, StateHookType_Enter, _, toState, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextExitHook(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:fromState = any:get_param(2);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(3, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterHook(iContextId, StateHookType_Exit, fromState, _, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextTransitionHook(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:fromState = any:get_param(2);
  new any:toState = any:get_param(3);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(4, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterHook(iContextId, StateHookType_Transition, fromState, toState, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextResetHook(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(2, szFunction, charsmax(szFunction));

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateContext_RegisterHook(iContextId, StateHookType_Reset, _, _, get_func_pointer(szFunction, iPluginId));
}

public Native_CreateManager(const iPluginId, const iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:userToken = any:get_param(2);

  new iContextId = StateContext_GetId(szContext);
  if (iContextId == -1) {
    LOG_ERROR(ERR_CONTEXT_NOT_REGISTERED, szContext);
    return -1;
  }

  return StateManager_Create(iContextId, userToken);
}

public Native_DestroyManager(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  
  StateManager_Destroy(iManagerId);
}

public Native_ResetManagerState(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  
  StateManager_ResetState(iManagerId);
}

public Native_SetManagerState(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  static any:newState; newState = any:get_param(2);
  static Float:flTransitionTime; flTransitionTime = get_param_f(3);
  static bool:bForce; bForce = bool:get_param(4);

  StateManager_SetState(iManagerId, newState, flTransitionTime, bForce);
}

public any:Native_GetManagerState(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_State];
}

public any:Native_GetManagerPrevState(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_PrevState];
}

public any:Native_GetManagerNextState(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_NextState];
}

public any:Native_GetManagerUserToken(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_UserToken];
}

public bool:Native_IsManagerInTransition(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return StateManager_IsInTransition(iManagerId);
}

public Native_CancelManagerTransition(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  StateManager_CancelTransition(iManagerId);
}

public Native_EndManagerTransition(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  StateManager_EndTransition(iManagerId);
}

public Float:Native_GetManagerTransitionProgress(const iPluginId, const iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return StateManager_GetTransitionProgress(iManagerId);
}

/*--------------------------------[ State Context Methods ]--------------------------------*/

StateContext_Register(const szId[], any:initialState) {
  new iId = g_iStateContextsNum;

  g_rgStateContexts[iId][StateContext_Id] = iId;
  g_rgStateContexts[iId][StateContext_InitialState] = initialState;
  copy(g_rgStateContexts[iId][StateContext_Name], charsmax(g_rgStateContexts[][StateContext_Name]), szId);

  TrieSetCell(g_itStateContexts, szId, iId);

  g_iStateContextsNum++;

  return iId;
}

StateContext_GetId(const szContext[]) {
  new iId;
  if (!TrieGetCell(g_itStateContexts, szContext, iId)) return -1;

  return iId;
}

StateContext_RegisterGuard(const iId, Function:fnCallback) {
  new iContextGuardId = g_rgStateContexts[iId][StateContext_GuardsNum];

  g_rgStateContexts[iId][StateContext_Guards][iContextGuardId] = fnCallback;
  g_rgStateContexts[iId][StateContext_GuardsNum]++;

  return iContextGuardId;
}

StateContext_RegisterHook(const iid, StateHookType:iType, any:fromState = 0, any:toState = 0, Function:fnCallback) {
  new iId = g_iStateHooksNum;

  g_rgStateHooks[iId][StateHook_From] = fromState;
  g_rgStateHooks[iId][StateHook_To] = toState;
  g_rgStateHooks[iId][StateHook_Function] = fnCallback;
  g_rgStateHooks[iId][StateHook_Type] = iType;

  new iContextHookId = g_rgStateContexts[iid][StateContext_HooksNum];

  g_rgStateContexts[iid][StateContext_Hooks][iContextHookId] = iId;
  g_rgStateContexts[iid][StateContext_HooksNum]++;

  g_iStateHooksNum++;

  return iId;
}

/*--------------------------------[ State Manager Methods ]--------------------------------*/

StateManager_Create(const iContextId, any:userToken) {
  new iId = StateManager_AllocateId();

  g_rgStateManagers[iId][StateManager_ContextId] = iContextId;
  g_rgStateManagers[iId][StateManager_Free] = false;
  g_rgStateManagers[iId][StateManager_UserToken] = userToken;

  StateManager_ResetState(iId);

  g_iStateManagersNum++;

  return iId;
}

StateManager_AllocateId() {
  if (g_iFreeStateManagersNum) {
    for (new iId = 0; iId < g_iStateManagersNum; ++iId) {
      if (g_rgStateManagers[iId][StateManager_Free]) {
        g_rgStateManagers[iId][StateManager_Free] = false;
        g_iFreeStateManagersNum--;
        return iId;
      }
    }
  }

  return g_iStateManagersNum < STATE_MAX_MANAGERS ? g_iStateManagersNum : -1;
}

StateManager_Destroy(const iId) {
  if (iId == g_iStateManagersNum - 1) {
    g_iStateManagersNum--;
    return;
  }

  g_rgStateManagers[iId][StateManager_Free] = true;
  g_iFreeStateManagersNum++;
}

StateManager_ResetState(const iId) {
  static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];

  g_rgStateManagers[iId][StateManager_State] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iId][StateManager_PrevState] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iId][StateManager_NextState] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iId][StateManager_StartChangeTime] = 0.0;
  g_rgStateManagers[iId][StateManager_ChangeTime] = 0.0;
  
  remove_task(iId);

  if (g_bDebug) {
    engfunc(EngFunc_AlertMessage, at_aiconsole, "Reset state of context ^"%s^". User Token: ^"%d^".^n", g_rgStateContexts[iContextId][StateContext_Name], g_rgStateManagers[iId][StateManager_UserToken]);
  }

  static iHooksNum; iHooksNum = g_rgStateContexts[iContextId][StateContext_HooksNum];

  for (new iHook = 0; iHook < iHooksNum; ++iHook) {
    static iHookId; iHookId = g_rgStateContexts[iContextId][StateContext_Hooks][iHook];

    if (g_rgStateHooks[iHookId][StateHook_Type] != StateHookType_Reset) continue;

    callfunc_begin_p(g_rgStateHooks[iHookId][StateHook_Function]);
    callfunc_push_int(iId);
    callfunc_end();
  }
}

bool:StateManager_CanChangeState(const iId, any:fromState, any:toState) {
  static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];
  static iGuardsNum; iGuardsNum = g_rgStateContexts[iContextId][StateContext_GuardsNum];

  for (new iContextGuardId = 0; iContextGuardId < iGuardsNum; ++iContextGuardId) {
    callfunc_begin_p(g_rgStateContexts[iContextId][StateContext_Guards][iContextGuardId]);
    callfunc_push_int(iId);
    callfunc_push_int(fromState);
    callfunc_push_int(toState);
    if (callfunc_end() == STATE_GUARD_BLOCK) return false;
  }

  return true;
}

bool:StateManager_SetState(const iId, any:newState, Float:flTransitionTime, bool:bForce = false) {
  if (g_bProcessingStateChange) {
    if (g_bDebug && g_rgScheduledChange[StateChange_Scheduled]) {
      static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];
      engfunc(EngFunc_AlertMessage, at_aiconsole, "An override of a scheduled change was detected for the state of context ^"%s^"!^n", g_rgStateContexts[iContextId][StateContext_Name]);
    }

    g_rgScheduledChange[StateChange_Value] = newState;
    g_rgScheduledChange[StateChange_TransitionTime] = flTransitionTime;
    g_rgScheduledChange[StateChange_Force] = bForce;
    g_rgScheduledChange[StateChange_Scheduled] = true;

    if (g_bDebug) {
      static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];
      engfunc(EngFunc_AlertMessage, at_aiconsole, "State of context ^"%s^" change scheduled. Change to ^"%d^". User Token: ^"%d^".^n", g_rgStateContexts[iContextId][StateContext_Name], newState, g_rgStateManagers[iId][StateManager_UserToken]);
    }

    return true;
  }

  static any:currentState; currentState = g_rgStateManagers[iId][StateManager_State];
  if (currentState == newState) return false;

  if (!StateManager_CanChangeState(iId, currentState, newState)) {
    if (g_bDebug) {
      static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];
      engfunc(EngFunc_AlertMessage, at_aiconsole, "State of context ^"%s^" change blocked by guard. Change from ^"%d^" to ^"%d^". User Token: ^"%d^".^n", g_rgStateContexts[iContextId][StateContext_Name], currentState, newState, g_rgStateManagers[iId][StateManager_UserToken]);
    }

    return false;
  }

  static Float:flGameTime; flGameTime = get_gametime();

  if (g_rgStateManagers[iId][StateManager_ChangeTime] > flGameTime) {
    if (!bForce) return false;
    StateManager_CancelTransition(iId);
  }

  g_rgStateManagers[iId][StateManager_NextState] = newState;
  g_rgStateManagers[iId][StateManager_StartChangeTime] = flGameTime;
  g_rgStateManagers[iId][StateManager_ChangeTime] = flGameTime + flTransitionTime;

  if (flTransitionTime > 0.0) {
    set_task(flTransitionTime, "Task_UpdateManagerState", iId);
  } else {
    g_bProcessingStateChange = true;
    StateManager_Update(iId);
    g_bProcessingStateChange = false;
    StateManager_ProcessScheduledChange(iId);
  }

  return true;
}

bool:StateManager_IsInTransition(const iId) {
  return g_rgStateManagers[iId][StateManager_ChangeTime] > get_gametime();
}

Float:StateManager_GetTransitionProgress(const iId) {
  static Float:flStartTime; flStartTime = g_rgStateManagers[iId][StateManager_StartChangeTime];
  static Float:flChangeTime; flChangeTime = g_rgStateManagers[iId][StateManager_ChangeTime];
  static Float:flDuration; flDuration = floatmax(flChangeTime - flStartTime, 0.0);

  if (!flDuration) return 1.0;

  static Float:flTimeLeft; flTimeLeft = floatmax(flChangeTime - get_gametime(), 0.0);

  return (1.0 - (flTimeLeft / flDuration));
}

StateManager_EndTransition(const iId) {
  remove_task(iId);
  g_rgStateManagers[iId][StateManager_ChangeTime] = get_gametime();
  StateManager_Update(iId);
}

StateManager_CancelTransition(const iId) {
  remove_task(iId);
  g_rgStateManagers[iId][StateManager_NextState] = g_rgStateManagers[iId][StateManager_State];
  g_rgStateManagers[iId][StateManager_ChangeTime] = get_gametime();
}

StateManager_Update(const iId) {
  static any:currentState; currentState = g_rgStateManagers[iId][StateManager_State];
  static any:nextState; nextState = g_rgStateManagers[iId][StateManager_NextState];

  if (currentState == nextState) return;
  if (StateManager_IsInTransition(iId)) return;

  g_rgStateManagers[iId][StateManager_State] = nextState;
  g_rgStateManagers[iId][StateManager_PrevState] = currentState;

  static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];
  static iHooksNum; iHooksNum = g_rgStateContexts[iContextId][StateContext_HooksNum];

  if (g_bDebug) {
    engfunc(EngFunc_AlertMessage, at_aiconsole, "State of context ^"%s^" changed from ^"%d^" to ^"%d^". User Token: ^"%d^".^n", g_rgStateContexts[iContextId][StateContext_Name], currentState, nextState, g_rgStateManagers[iId][StateManager_UserToken]);
  }

  for (new iHook = 0; iHook < iHooksNum; ++iHook) {
    static iHookId; iHookId = g_rgStateContexts[iContextId][StateContext_Hooks][iHook];

    switch (g_rgStateHooks[iHookId][StateHook_Type]) {
      case StateHookType_Transition: {
        if (g_rgStateHooks[iHookId][StateHook_From] != currentState) continue;
        if (g_rgStateHooks[iHookId][StateHook_To] != nextState) continue;
      }
      case StateHookType_Enter: {
        if (g_rgStateHooks[iHookId][StateHook_To] != nextState) continue;
      }
      case StateHookType_Exit: {
        if (g_rgStateHooks[iHookId][StateHook_From] != currentState) continue;
      }
      case StateHookType_Reset: {
        continue;
      }
    }

    callfunc_begin_p(g_rgStateHooks[iHookId][StateHook_Function]);
    callfunc_push_int(iId);
    callfunc_push_int(currentState);
    callfunc_push_int(nextState);
    callfunc_end();
  }
}

StateManager_ProcessScheduledChange(const iId) {
  if (!g_rgScheduledChange[StateChange_Scheduled]) return;

  static any:currentState; currentState = g_rgStateManagers[iId][StateManager_State];
  static iContextId; iContextId = g_rgStateManagers[iId][StateManager_ContextId];

  if (g_bDebug) {
    engfunc(EngFunc_AlertMessage, at_aiconsole, "Processing scheduled change of context ^"%s^". Change from ^"%d^" to ^"%d^". Transition Time: %0.3f User Token: ^"%d^".^n", g_rgStateContexts[iContextId][StateContext_Name], currentState, g_rgScheduledChange[StateChange_Value], g_rgScheduledChange[StateChange_TransitionTime], g_rgStateManagers[iId][StateManager_UserToken]);
  }
  
  g_rgScheduledChange[StateChange_Scheduled] = false;

  StateManager_SetState(iId, g_rgScheduledChange[StateChange_Value], g_rgScheduledChange[StateChange_TransitionTime], g_rgScheduledChange[StateChange_Force]);
}

public Task_UpdateManagerState(const iTaskId) {
  static iManagerId; iManagerId = iTaskId;

  StateManager_Update(iManagerId);
}
