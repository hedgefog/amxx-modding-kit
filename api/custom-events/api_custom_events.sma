#pragma semicolon 1

#include <amxmodx>
#include <fakemeta_const>

#include <stack>
#include <function_pointer>

#include <api_custom_events_const>

#define LOG_PREFIX "[Custom Events]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define MAX_EVENTS 128
#define MAX_EVENT_PARAMS 16
#define MAX_EVENT_SUBSCRIBERS 64

#define GET_PARAM_DATA(%1,%2) g_rgBuffer[STACK_READ(BufferSize) + 1 + (%1 * _:ParamHeader) + _:%2]

enum ParamHeader {
  CustomEvent_Param:ParamHeader_Type,
  ParamHeader_Size,
  ParamHeader_Pos
};

STACK_DEFINE(EventId, 32);
STACK_DEFINE(BufferSize, 32);
STACK_DEFINE(Activator, 32);

new g_pfwEmit;

new any:g_rgBuffer[MAX_STRING_LENGTH];
new g_iBufferSize = 0;

new g_rgPreparedParams[MAX_EVENT_PARAMS];
new g_iPreparedParamsNum = -1;
new g_pActivator = FM_NULLENT;

new g_iCurrentEventId = -1;
new any:g_pCurrentActivator = FM_NULLENT;

new Trie:g_itEventIds = Invalid_Trie;
new g_rgrgEventParamTypes[MAX_EVENTS][MAX_EVENT_PARAMS];
new g_rgiEventParamsNum[MAX_EVENTS];
new Function:g_rgrgEventSubscribers[MAX_EVENTS][MAX_EVENT_SUBSCRIBERS];
new g_rgEventSubscribersNum[MAX_EVENTS];
new g_iEventsNum = 0;

public plugin_precache() {
  g_itEventIds = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] Custom Events", "1.0.0", "Hedgehog Fog");

  g_pfwEmit = CreateMultiForward("CustomEvent_OnEmit", ET_STOP, FP_STRING, FP_CELL);
}

public plugin_end() {
  TrieDestroy(g_itEventIds);
}

public plugin_natives() {
  register_library("api_custom_events");
  register_native("CustomEvent_Register", "Native_RegisterEvent");
  register_native("CustomEvent_Subscribe", "Native_SubscribeEvent");
  register_native("CustomEvent_Emit", "Native_EmitEvent");
  register_native("CustomEvent_GetParamsNum", "Native_GetParamsNum");
  register_native("CustomEvent_GetParamType", "Native_GetParamType");
  register_native("CustomEvent_GetParam", "Native_GetParam");
  register_native("CustomEvent_GetParamFloat", "Native_GetParamFloat");
  register_native("CustomEvent_GetParamString", "Native_GetParamString");
  register_native("CustomEvent_GetParamArray", "Native_GetParamArray");
  register_native("CustomEvent_GetParamFloatArray", "Native_GetParamFloatArray");
  register_native("CustomEvent_GetActivator", "Native_GetActivator");
  register_native("CustomEvent_SetActivator", "Native_SetActivator");
  register_native("CustomEvent_PrepareParamTypes", "Native_PrepareParamTypes");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterEvent(const iPluginId, const iArgc) {
  new szEvent[MAX_CUSTOM_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  if (Event_IsRegistered(szEvent)) {
    LOG_FATAL_ERROR("Event ^"%s^" is already registered.", szEvent);
    return;
  }

  new rgParamsTypes[MAX_EVENT_PARAMS];
  new iParamsNum = 0;

  for (new iParam = 2; iParam <= iArgc; ++iParam) {
    new CustomEvent_Param:iType = CustomEvent_Param:get_param_byref(iParam);
    new iSize = 1;

    // Read size from next argument
    switch (iType) {
      case CEP_Array, CEP_FloatArray: {
        iSize = get_param_byref(iParam + 1);
        iParam++;
      }
    }

    rgParamsTypes[iParamsNum++] = PackedParam_Create(iType, iSize);
  }

  Event_Register(szEvent, rgParamsTypes, iParamsNum);
}

public Native_SubscribeEvent(const iPluginId, const iArgc) {
  new szEvent[MAX_CUSTOM_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));
  new szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  new iEventId = Event_GetId(szEvent);
  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  Event_AddSubscriber(iEventId, fnCallback);
}

public Native_PrepareParamTypes(const iPluginId, const iArgc) {
  g_iPreparedParamsNum = 0;

  for (new iParam = 0; iParam < iArgc; ++iParam) {
    new CustomEvent_Param:iType = CustomEvent_Param:get_param_byref(1 + iParam);

    new iSize = 1;
    switch (iType) {
      case CEP_Array, CEP_FloatArray: {
        iSize = get_param_byref(1 + iParam + 1);
        iParam++;
      }
    }

    g_rgPreparedParams[g_iPreparedParamsNum++] = PackedParam_Create(iType, iSize);
  }
}

public Native_EmitEvent(const iPluginId, const iArgc) {
  static szEvent[MAX_CUSTOM_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  STACK_PUSH(EventId, g_iCurrentEventId);
  STACK_PUSH(Activator, g_pCurrentActivator);
  STACK_PUSH(BufferSize, g_iBufferSize);

  g_iCurrentEventId = Event_GetId(szEvent);
  g_pCurrentActivator = g_pActivator;

  PrepareParamTypes(iArgc - 1);
  ReadParamsFromNativeCall(2);

  new iForwardReturn; ExecuteForward(g_pfwEmit, iForwardReturn, szEvent, g_pCurrentActivator);
  new eventReturn = CER_Continue;

  if (iForwardReturn == PLUGIN_CONTINUE) {
    for (new iSubscriber = 0; iSubscriber < g_rgEventSubscribersNum[g_iCurrentEventId]; ++iSubscriber) {
      new subscriberReturn = ExecuteCallback(g_rgrgEventSubscribers[g_iCurrentEventId][iSubscriber]);

      if (subscriberReturn > eventReturn) {
        eventReturn = subscriberReturn;
      }

      if (subscriberReturn == CER_Break) break;
    }
  } else {
    eventReturn = CER_Break;
  }

  g_iCurrentEventId = STACK_POP(EventId);
  g_pCurrentActivator = STACK_POP(Activator);
  g_iBufferSize = STACK_POP(BufferSize);

  return eventReturn;
}

public Native_SetActivator(const iPluginId, const iArgc) {
  g_pActivator = get_param(1);
}

public any:Native_GetActivator(const iPluginId, const iArgc) {
  return g_pCurrentActivator;
}

public Native_GetParamsNum(const iPluginId, const iArgc) {
  static szEvent[MAX_CUSTOM_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  new iBufferPos = STACK_READ(BufferSize);

  return g_rgBuffer[iBufferPos];
}

public CustomEvent_Param:Native_GetParamType(const iPluginId, const iArgc) {
  static szEvent[MAX_CUSTOM_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));
  static iParam; iParam = get_param(2);

  return GET_PARAM_DATA(iParam, ParamHeader_Type);
}

public Float:Native_GetParam(const iPluginId, const iArgc) {
  static iParam; iParam = get_param(1);

  static iPos; iPos = GET_PARAM_DATA(iParam, ParamHeader_Pos);

  return g_rgBuffer[iPos];
}

public Float:Native_GetParamFloat(const iPluginId, const iArgc) {
  static iParam; iParam = get_param(1);

  static iPos; iPos = GET_PARAM_DATA(iParam, ParamHeader_Pos);

  return g_rgBuffer[iPos];
}

public Float:Native_GetParamString(const iPluginId, const iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);

  static iSize; iSize = GET_PARAM_DATA(iParam, ParamHeader_Size);
  static iPos; iPos = GET_PARAM_DATA(iParam, ParamHeader_Pos);

  set_string(2, g_rgBuffer[iPos], iLen > iSize ? iSize : iLen);
}

public Native_GetParamArray(const iPluginId, const iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);

  static iSize; iSize = GET_PARAM_DATA(iParam, ParamHeader_Size);
  static iPos; iPos = GET_PARAM_DATA(iParam, ParamHeader_Pos);

  set_array(2, g_rgBuffer[iPos], iLen > iSize ? iSize : iLen);
}

public Native_GetParamFloatArray(const iPluginId, const iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);

  static iSize; iSize = GET_PARAM_DATA(iParam, ParamHeader_Size);
  static iPos; iPos = GET_PARAM_DATA(iParam, ParamHeader_Pos);

  set_array_f(2, g_rgBuffer[iPos], iLen > iSize ? iSize : iLen);
}

/*--------------------------------[ Event Methods ]--------------------------------*/

Event_GetId(const szEvent[]) {
  static iId;
  if (!TrieGetCell(g_itEventIds, szEvent, iId)) {
    // set iParamsNum to -1 means event not registered (no param types defined) 
    iId = Event_Register(szEvent, _, -1);
  }

  return iId;
}

bool:Event_IsRegistered(const szEvent[]) {
  static iId;
  if (!TrieGetCell(g_itEventIds, szEvent, iId)) return false;

  return g_rgiEventParamsNum[iId] != -1;
}

Event_Register(const szEvent[], const rgParamsTypes[] = {}, iParamsNum = 0) {
  new iId;
  if (!TrieGetCell(g_itEventIds, szEvent, iId)) {
    iId = g_iEventsNum;
    g_rgEventSubscribersNum[iId] = 0;
  } else {
    if (g_rgiEventParamsNum[iId] != -1) return iId;
  }

  for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    g_rgrgEventParamTypes[iId][iParam] = rgParamsTypes[iParam];
  }

  g_rgiEventParamsNum[iId] = iParamsNum;

  TrieSetCell(g_itEventIds, szEvent, iId);

  g_iEventsNum++;

  return iId;
}

Event_AddSubscriber(const iId, const &Function:fnCallback) {
  new iSubscriberId = g_rgEventSubscribersNum[iId];

  g_rgrgEventSubscribers[iId][iSubscriberId] = fnCallback;

  g_rgEventSubscribersNum[iId]++;
}

/*--------------------------------[ Packed Param Methods ]--------------------------------*/

PackedParam_Create(CustomEvent_Param:iType, iSize) {
  return ((_:iType + 1) << 16) | (iSize + 1);
}

CustomEvent_Param:PackedParam_GetType(const &param) {
  return CustomEvent_Param:(((_:param >> 16) & 0xFFFF) - 1);
}

PackedParam_GetSize(const &param) {
  return (_:param & 0xFFFF) - 1;
}

/*--------------------------------[ Functions ]--------------------------------*/

PrepareParamTypes(iParamsNum) {
  // If event params not defined (event not registered)
  if (g_rgiEventParamsNum[g_iCurrentEventId] == -1) {
    if (g_iPreparedParamsNum != -1) return;

    // If param types not prepared - prepare it with cell type
    for (new iParam = 0; iParam < iParamsNum; ++iParam) {
      g_rgPreparedParams[iParam] = PackedParam_Create(CEP_Cell, 1);
    }
  } else {
    // Prepare param types using defined types
    for (new iParam = 0; iParam < g_rgiEventParamsNum[g_iCurrentEventId]; ++iParam) {
      g_rgPreparedParams[iParam] = g_rgrgEventParamTypes[g_iCurrentEventId][iParam];
    }
  }

  g_iPreparedParamsNum = iParamsNum;
}

ReadParamsFromNativeCall(const iOffset) {
  g_rgBuffer[g_iBufferSize++] = g_iPreparedParamsNum;

  new iTypesPos = g_iBufferSize;

  // Write type headers
  for (new iParam = 0; iParam < g_iPreparedParamsNum; ++iParam) {
    g_rgBuffer[g_iBufferSize + _:ParamHeader_Type] = PackedParam_GetType(g_rgPreparedParams[iParam]);
    g_rgBuffer[g_iBufferSize + _:ParamHeader_Size] = PackedParam_GetSize(g_rgPreparedParams[iParam]);
    g_rgBuffer[g_iBufferSize + _:ParamHeader_Pos] = 0;

    g_iBufferSize += _:ParamHeader;
  }

  // write values
  for (new iParam = 0; iParam < g_iPreparedParamsNum; ++iParam) {
    new CustomEvent_Param:iType = PackedParam_GetType(g_rgPreparedParams[iParam]);
    new iSize = PackedParam_GetSize(g_rgPreparedParams[iParam]);

    switch (iType) {
      case CEP_Cell: {
        g_rgBuffer[g_iBufferSize] = get_param_byref(iOffset + iParam);
      }
      case CEP_Float: {
        g_rgBuffer[g_iBufferSize] = Float:get_param_byref(iOffset + iParam);
      }
      case CEP_String: {
        // Strings are dynamically sized, so need to update it
        iSize = get_string(iOffset + iParam, g_rgBuffer[g_iBufferSize], charsmax(g_rgBuffer) - g_iBufferSize);
        iSize++;
      }
      case CEP_Array: {
        get_array(iOffset + iParam, g_rgBuffer[g_iBufferSize], iSize);
      }
      case CEP_FloatArray: {
        get_array_f(iOffset + iParam, g_rgBuffer[g_iBufferSize], iSize);
      }
    }

    g_rgBuffer[iTypesPos + (iParam * 3) + _:ParamHeader_Size] = iSize;
    g_rgBuffer[iTypesPos + (iParam * 3) + _:ParamHeader_Pos] = g_iBufferSize;

    g_iBufferSize += iSize;
  }

  // Need to reset it before call to support recursive event emit
  g_iPreparedParamsNum = -1;
}

ExecuteCallback(const &Function:fnCallback) {
  callfunc_begin_p(fnCallback);

  new iBufferPos = STACK_READ(BufferSize);
  new iParamsNum = g_rgBuffer[iBufferPos++];

  for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    new CustomEvent_Param:iType = g_rgBuffer[iBufferPos + _:ParamHeader_Type];
    new iSize = g_rgBuffer[iBufferPos + _:ParamHeader_Size];
    new iPos = g_rgBuffer[iBufferPos + _:ParamHeader_Pos];

    switch (iType) {
      case CEP_Cell: callfunc_push_int(g_rgBuffer[iPos]);
      case CEP_Float: callfunc_push_float(g_rgBuffer[iPos]);
      case CEP_String: callfunc_push_array(g_rgBuffer[iPos], iSize, false);
      case CEP_Array: callfunc_push_array(g_rgBuffer[iPos], iSize, false);
      case CEP_FloatArray: callfunc_push_array(g_rgBuffer[iPos], iSize, false);
    }

    iBufferPos += _:ParamHeader;
  }

  return callfunc_end();
}

