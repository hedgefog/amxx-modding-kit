#if defined _api_custom_events_const_included
  #endinput
#endif
#define _api_custom_events_const_included

#define MAX_CUSTOM_EVENT_KEY_LENGTH 64

enum CustomEvent_Param {
  CEP_Invalid = -1,
  CEP_Cell,
  CEP_Float,
  CEP_String,
  CEP_Array,
  CEP_FloatArray
};

enum _:CustomEvent_Return {
  CER_Continue = 0,
  CER_Supercede,
  CER_Break,
};
