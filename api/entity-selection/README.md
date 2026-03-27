# 🖱️ Entity Selection API


The **Entity Selection API** enables in-game selection of entities using a virtual cursor, providing a foundation for strategy, RTS, and advanced interaction systems. It is designed for flexibility, extensibility, and ease of integration with custom entity systems.

---

## 🚀 Features

- Virtual cursor for intuitive in-game selection
- Multi-entity selection and group operations
- Customizable selection filters and highlight logic
- API for querying, modifying, and iterating selections
- Integration with custom entities and game logic
- Visual feedback for selected entities and targets

---

## ⚡ Getting Started

### 1. Creating a Selection

Create a selection instance for a player:

```pawn
new Selection:iSelection = EntitySelection_Create(pPlayer);
```

### 2. Customizing Selection

Set a filter callback to control which entities are selectable:

```pawn
EntitySelection_SetFilterCallback(iSelection, "Callback_MyEntityFilter");
```

Set the selection highlight color:

```pawn
new const SelectionColor[3] = {255, 0, 0};
EntitySelection_SetColor(iSelection, SelectionColor);
```

### 3. Starting and Ending Selection

Begin and end selection with player input:

```pawn
EntitySelection_Start(iSelection);
// ... player selects entities ...
EntitySelection_End(iSelection);
```

### 4. Accessing Selected Entities

Iterate over selected entities:

```pawn
new iCount = EntitySelection_GetSize(iSelection);
for (new i = 0; i < iCount; ++i) {
  new pEntity = EntitySelection_GetEntity(iSelection, i);
  // Do something with pEntity
}
```

---

## 🛠️ Advanced Usage

### Custom Selection Filters

Implement a filter callback to restrict selectable entities:

```pawn
public bool:Callback_SelectionMonstersFilter(Selection:iSelection, pEntity) {
  // Only allow selection of monsters
  return CE_IsInstanceOf(pEntity, "base_monster");
}
```

### Visual Feedback

Draw highlights or markers for selected entities using your own logic or integrate with effects APIs.

---

## ✨ Tips

- Integrate with your custom entity system for advanced behaviors.
- Use selection filters to implement team, class, or type restrictions.
- Combine with other APIs (e.g., Custom Entities, States) for complex gameplay systems.
- Use the selection API for both player-controlled and AI-controlled selection logic.

---

## 🧩 Example: Simple Strategy System

![Simple Strategy Mode](../../images/example-entity-selection.gif)

This example demonstrates a basic RTS-style selection and command system.

```pawn
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>

#include <api_custom_entities>
#include <api_entity_selection>

#define ENTITY_BASE_MONSTER_CLASS "base_monster"

new const SelectionColor[3] = {255, 0, 0};

new bool:g_rgbPlayerInStrategyMode[MAX_PLAYERS + 1];
new Selection:g_rgiPlayerSelection[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("Simple Strategy System", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink");

  register_concmd("strategy_mode", "Command_StrategyMode");
}

public client_connect(pPlayer) {
  g_rgbPlayerInStrategyMode[pPlayer] = false;
}

public client_disconnected(pPlayer) {
  @Player_SetStrategyMode(pPlayer, false);
}

public Command_StrategyMode(pPlayer) {
  new bool:bValue = !!read_argv_int(1);

  @Player_SetStrategyMode(pPlayer, bValue);

  return PLUGIN_HANDLED;
}

public HamHook_Player_PreThink(pPlayer) {
  if (g_rgbPlayerInStrategyMode[pPlayer]) {
    @Player_StrategyModeThink(pPlayer);
  }
}

@Player_SetStrategyMode(this, bool:bValue) {
  if (bValue == g_rgbPlayerInStrategyMode[this]) return;
  
  if (bValue) {
    new Selection:iSelection = EntitySelection_Create(this);
    EntitySelection_SetFilterCallback(iSelection, "Callback_SelectionMonstersFilter");
    EntitySelection_SetColor(iSelection, SelectionColor);
    g_rgiPlayerSelection[this] = iSelection;

    console_print(this, "Entered strategy mode!");
  } else {
    EntitySelection_Destroy(g_rgiPlayerSelection[this]);

    console_print(this, "Left strategy mode!");
  }

  g_rgbPlayerInStrategyMode[this] = bValue;
}

@Player_StrategyModeThink(this) {
  static iButtons; iButtons = pev(this, pev_button);
  static iOldButtons; iOldButtons = pev(this, pev_oldbuttons);

  if (iButtons & IN_ATTACK && ~iOldButtons & IN_ATTACK) {
    EntitySelection_Start(g_rgiPlayerSelection[this]);
  } else if (~iButtons & IN_ATTACK && iOldButtons & IN_ATTACK) {
    EntitySelection_End(g_rgiPlayerSelection[this]);
    @Player_HighlightSelectedMonsters(this);
  }

  if (~iButtons & IN_ATTACK2 && iOldButtons & IN_ATTACK2) {
    static Float:vecTarget[3]; EntitySelection_GetCursorPos(g_rgiPlayerSelection[this], vecTarget);

    if (@Player_MoveSelectedMonsters(this, vecTarget)) {
      @Player_DrawTarget(this, vecTarget, 16.0);
    }
  }

  // Block observer input for spectators
  if (!is_user_alive(this)) {
    set_member(this, m_flNextObserverInput, get_gametime() + 1.0);
  }
}

@Player_HighlightSelectedMonsters(this) {
  new iMonstersNum = EntitySelection_GetSize(g_rgiPlayerSelection[this]);
  if (!iMonstersNum) return;

  for (new i = 0; i < iMonstersNum; ++i) {
    new pMonster = EntitySelection_GetEntity(g_rgiPlayerSelection[this], i);
    @Monster_Highlight(pMonster, this);
  }
}

@Player_MoveSelectedMonsters(this, const Float:vecGoal[3]) {
  new iMonstersNum = EntitySelection_GetSize(g_rgiPlayerSelection[this]);
  if (!iMonstersNum) return false;

  for (new i = 0; i < iMonstersNum; ++i) {
    new pMonster = EntitySelection_GetEntity(g_rgiPlayerSelection[this], i);
    @Monster_SetGoal(pMonster, vecGoal);
  }

  return true;
}

@Player_DrawTarget(this, const Float:vecTarget[3], Float:flRadius) {
  static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/zbeam2.spr");
  static const iLifeTime = 5;
  static Float:flRadiusRatio; flRadiusRatio = 1.0 / (float(iLifeTime) / 10);

  engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecTarget, this);
  write_byte(TE_BEAMCYLINDER);
  engfunc(EngFunc_WriteCoord, vecTarget[0]);
  engfunc(EngFunc_WriteCoord, vecTarget[1]);
  engfunc(EngFunc_WriteCoord, vecTarget[2]);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + (flRadius * flRadiusRatio));
  write_short(iModelIndex);
  write_byte(0);
  write_byte(0);
  write_byte(iLifeTime);
  write_byte(8);
  write_byte(0);
  write_byte(SelectionColor[0]);
  write_byte(SelectionColor[1]);
  write_byte(SelectionColor[2]);
  write_byte(255);
  write_byte(0);
  message_end();
}

@Monster_SetGoal(this, const Float:vecGoal[3]) {
  set_pev(this, pev_enemy, 0);
  CE_SetMemberVec(this, "vecGoal", vecGoal);
  CE_SetMember(this, "flNextEnemyUpdate", get_gametime() + 5.0);
}

@Monster_Highlight(this, pPlayer) {
  static Float:vecTarget[3]; pev(this, pev_origin, vecTarget);
  vecTarget[2] = UTIL_TraceGroundPosition(vecTarget, this) + 1.0;

  static Float:flRadius; flRadius = @Entity_GetSelectionRadius(this);

  @Player_DrawTarget(pPlayer, vecTarget, flRadius);
}

Float:@Entity_GetSelectionRadius(this) {
  static const Float:flRadiusBorder = 8.0;

  static Float:vecMins[3]; pev(this, pev_mins, vecMins);
  static Float:vecMaxs[3]; pev(this, pev_maxs, vecMaxs);
  static Float:flTargetRadius; flTargetRadius = floatmax(vecMaxs[0] - vecMins[0], vecMaxs[1] - vecMins[1]) / 2;
  static Float:flRadius; flRadius = flTargetRadius + flRadiusBorder;

  return flRadius;
}

public bool:Callback_SelectionMonstersFilter(Selection:iSelection, pEntity) {
  return CE_IsInstanceOf(pEntity, ENTITY_BASE_MONSTER_CLASS);
}

stock Float:UTIL_TraceGroundPosition(const Float:vecOrigin[], pIgnoreEnt) {
  static pTrace; pTrace = create_tr2();

  static Float:vecTarget[3]; xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], vecOrigin[2] - 8192.0);

  engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, pIgnoreEnt, pTrace);

  get_tr2(pTrace, TR_vecEndPos, vecTarget);

  free_tr2(pTrace);

  return vecTarget[2];
}
```

---

## 📖 API Reference

See [`api_entity_selection.inc`](include/api_entity_selection.inc) and [`api_entity_selection_const.inc`](include/api_entity_selection_const.inc) for all available natives, constants, and advanced features.
