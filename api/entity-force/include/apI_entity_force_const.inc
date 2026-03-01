#if defined _api_entity_force_const_included
  #endinput
#endif
#define _api_entity_force_const_included

enum EntityForce_Mode {
  EntityForce_Mode_Add = 0,
  EntityForce_Mode_Set,
  EntityForce_Mode_Overlap
};

enum EntityForce_Flags (<<=1) {
  EntityForce_Flag_None = 0,
  EntityForce_Flag_Set = 1,
  EntityForce_Flag_Overlap,
  EntityForce_Flag_ForceSetOutOfSoft,
  EntityForce_Flag_Launch,
  EntityForce_Flag_Attack
};
