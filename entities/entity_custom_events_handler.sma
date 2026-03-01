#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>

#include <api_custom_entities>
#include <api_custom_events>

#include <entity_custom_events_handler_const>

#define MAX_ENTITIES 2048

new g_rgpEntities[MAX_ENTITIES] = { FM_NULLENT, ... };
new g_iEntitiesNum = 0;

public plugin_precache() {
  CE_RegisterClass(ENTITY_CUSTOM_EVENTS_HANDLER);
  CE_ImplementClassMethod(ENTITY_CUSTOM_EVENTS_HANDLER, CE_Method_Create, "@CustomEventsHandler_Create");
  CE_ImplementClassMethod(ENTITY_CUSTOM_EVENTS_HANDLER, CE_Method_Destroy, "@CustomEventsHandler_Destroy");
  CE_ImplementClassMethod(ENTITY_CUSTOM_EVENTS_HANDLER, CE_Method_Think, "@CustomEventsHandler_Think");

  CE_RegisterClassKeyMemberBinding(ENTITY_CUSTOM_EVENTS_HANDLER, "event", Entity_CustomEventsHandler_Member_szEvent, CEMemberType_String);
}

public plugin_init() {
  register_plugin("[Entity] Custom Events Handler", "1.0.0", "Hedgehog Fog");
}

public CustomEvent_OnEmit(const szEvent[], const pActivator) {
  for (new i = 0; i < g_iEntitiesNum; ++i) {
    static szEntityEvent[64]; CE_GetMemberString(g_rgpEntities[i], Entity_CustomEventsHandler_Member_szEvent, szEntityEvent, charsmax(szEntityEvent));
    if (!equal(szEntityEvent, szEvent)) continue;

    CE_SetMember(g_rgpEntities[i], Entity_CustomEventsHandler_Member_pActivator, pActivator);
    dllfunc(DLLFunc_Think, g_rgpEntities[i]);
  }
}

@CustomEventsHandler_Create(const this) {
  g_rgpEntities[g_iEntitiesNum++] = this;
}

@CustomEventsHandler_Destroy(const this) {
  for (new i = 0; i < g_iEntitiesNum; ++i) {
    if (g_rgpEntities[i] == this) {
      g_rgpEntities[i] = g_rgpEntities[g_iEntitiesNum - 1];
      g_rgpEntities[g_iEntitiesNum - 1] = FM_NULLENT;
      g_iEntitiesNum--;
      break;
    }
  }
}

@CustomEventsHandler_Think(const this) {
  static pActivator; pActivator = CE_GetMember(this, Entity_CustomEventsHandler_Member_pActivator);
  static szTarget[64]; CE_GetMemberString(this, CE_Member_szTarget, szTarget, charsmax(szTarget));

  new pTarget = 0;
  while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTarget)) != 0) {
    ExecuteHamB(Ham_Use, pTarget, pActivator, this, 2, 1.0);
  }
}
