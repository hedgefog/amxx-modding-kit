#if defined _api_entity_selection_const_included
  #endinput
#endif
#define _api_entity_selection_const_included

enum Selection {
  Selection_Invalid = -1
};

enum Selection_Flags (<<=1) {
  Selection_Flag_None = 0, // No flags set
  Selection_Flag_AlwaysThink = 1,
  Selection_Flag_DontDraw
};
