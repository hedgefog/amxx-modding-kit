#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#tryinclude <reapi>

#if !defined _reapi_included
  #tryinclude <orpheu>
  #if defined _orpheu_included
    ;
  #endif
#endif

#include <api_rounds_const>

#pragma semicolon 1

#define MAX_TEAMS 8

enum GameState {
  GameState_Uninitialized = -1,
  GameState_NewRound,
  GameState_RoundStarted,
  GameState_RoundEnd
};

new gmsgTeamScore;

new GameState:g_iGameState = GameState_Uninitialized;
new bool:g_bIsCStrike;

new g_pfwNewRound;
new g_pfwRoundStart;
new g_pfwRoundEnd;
new g_pfwRoundExpired;
new g_pfwRoundRestart;
new g_pfwRoundTimerTick;
new g_pfwUpdateTimer;
new g_pfwCheckWinConditions;
new g_pfwCheckRoundStart;

new g_pCvarRoundEndDelay;

new g_pCvarRoundTime;
new g_pCvarFreezeTime;
new g_pCvarMaxRounds;
new g_pCvarWinLimits;
new g_pCvarRestartRound;
new g_pCvarRestart;

new bool:g_bUseCustomRounds = false;
new g_iIntroRoundTime = 2;
new g_iRoundWinTeam = 0;
new g_iRoundTime = 0;
new g_iRoundTimeSecs = 2;
new g_iTotalRoundsPlayed = 0;
new g_iMaxRounds = 0;
new g_iMaxRoundsWon = 0;
new Float:g_flRoundStartTime = 0.0;
new Float:g_flRoundStartTimeReal = 0.0;
new Float:g_flRestartRoundTime = 0.0;
new Float:g_flNextPeriodicThink = 0.0;
new Float:g_flNextThink = 0.0;
new bool:g_bRoundTerminating = false;
new bool:g_bFreezePeriod = true;
new bool:g_bGameStarted = false;
new bool:g_bCompleteReset = false;
new bool:g_bNeededPlayers = false;
new bool:g_bExpired = false;
new g_iSpawnablePlayersNum = 0;
new g_rgiWinsNum[MAX_TEAMS];

#if defined _orpheu_included
  new g_pGameRules;
#endif

new Float:g_flGameTime = 0.0;

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();

  #if defined _orpheu_included
    if (g_bIsCStrike) {
      OrpheuRegisterHook(OrpheuGetFunction("InstallGameRules"), "OrpheuHook_InstallGameRules_Post", OrpheuHookPost);
    }
  #endif
}

public plugin_init() {
  register_plugin("[API] Rounds", "2.1.0", "Hedgehog Fog");

  if (g_bIsCStrike) {
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
  }

  #if defined _reapi_included
    RegisterHookChain(RG_CSGameRules_RestartRound, "HC_RestartRound", .post = 0);
    RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "HC_OnRoundFreezeEnd", .post = 0);
    RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "HC_OnRoundFreezeEnd_Post", .post = 1);
    RegisterHookChain(RG_RoundEnd, "HC_RoundEnd", .post = 1);
    RegisterHookChain(RG_CSGameRules_CheckWinConditions, "HC_CheckWinConditions", .post = 0);

    g_pCvarRoundEndDelay = get_cvar_pointer("mp_round_restart_delay");
  #elseif defined _orpheu_included
    if (g_bIsCStrike) {
      OrpheuRegisterHook(OrpheuGetFunctionFromObject(g_pGameRules, "CheckWinConditions", "CGameRules"), "OrpheuHook_CheckWinConditions" , OrpheuHookPre);
    }
  #endif

  g_pfwNewRound = CreateMultiForward("Round_OnInit", ET_IGNORE);
  g_pfwRoundStart = CreateMultiForward("Round_OnStart", ET_IGNORE);
  g_pfwRoundEnd = CreateMultiForward("Round_OnEnd", ET_IGNORE, FP_CELL);
  g_pfwRoundExpired = CreateMultiForward("Round_OnExpired", ET_IGNORE);
  g_pfwRoundRestart = CreateMultiForward("Round_OnRestart", ET_IGNORE);
  g_pfwRoundTimerTick = CreateMultiForward("Round_OnTimerTick", ET_IGNORE);
  g_pfwUpdateTimer = CreateMultiForward("Round_OnUpdateTimer", ET_IGNORE, FP_CELL);
  g_pfwCheckWinConditions = CreateMultiForward("Round_OnCheckWinConditions", ET_CONTINUE);
  g_pfwCheckRoundStart = CreateMultiForward("Round_OnCanStartCheck", ET_CONTINUE);

  if (g_bIsCStrike) {
    gmsgTeamScore = get_user_msgid("TeamScore");
  }
}

public plugin_natives() {
  register_library("api_rounds");
  register_native("Round_UseCustomManager", "Native_UseCustomRounds");
  register_native("Round_DispatchWin", "Native_DispatchWin");
  register_native("Round_Terminate", "Native_TerminateRound");
  register_native("Round_GetTime", "Native_GetTime");
  register_native("Round_SetTime", "Native_SetTime");
  register_native("Round_GetIntroTime", "Native_GetIntroTime");
  register_native("Round_GetStartTime", "Native_GetStartTime");
  register_native("Round_GetRestartTime", "Native_GetRestartRoundTime");
  register_native("Round_GetRemainingTime", "Native_GetRemainingTime");
  register_native("Round_IsFreezePeriod", "Native_IsFreezePeriod");
  register_native("Round_IsStarted", "Native_IsRoundStarted");
  register_native("Round_IsEnd", "Native_IsRoundEnd");
  register_native("Round_IsTerminating", "Native_IsRoundTerminating");
  register_native("Round_IsPlayersNeeded", "Native_IsPlayersNeeded");
  register_native("Round_IsCompleteReset", "Native_IsCompleteReset");
  register_native("Round_CheckWinConditions", "Native_CheckWinConditions");
  register_native("Round_IsExpired", "Native_IsExpired");
}

public client_putinserver(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public client_disconnected(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public HamHook_Player_Spawn_Post(pPlayer) {
  if (!g_bUseCustomRounds) return;
  if (!is_user_alive(pPlayer)) return;

  if (g_bFreezePeriod) {
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);
  } else {
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
  }
}

public HamHook_Player_Killed(pPlayer) {
  if (!g_bUseCustomRounds) return;

  set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
}

public HamHook_Player_Killed_Post(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public server_frame() {
  g_flGameTime = get_gametime();
  static Float:flNextPeriodicThink; 
  
  if (g_iGameState == GameState_Uninitialized) {
    g_iGameState = GameState_NewRound;
    ExecuteForward(g_pfwNewRound);
  }

  if (g_bUseCustomRounds) {
    flNextPeriodicThink = g_flNextPeriodicThink;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      flNextPeriodicThink = get_member_game(m_tmNextPeriodicThink);
    #else
      flNextPeriodicThink = get_gamerules_float("CHalfLifeMultiplay", "m_tmNextPeriodicThink");
    #endif
  } else {
    return;
  }

  if (g_bUseCustomRounds) {
    if (g_flNextThink <= g_flGameTime) {
      RoundThink();
      g_flNextThink = g_flGameTime + 0.1;
    }
  }

  if (flNextPeriodicThink <= g_flGameTime) {
    ExecuteForward(g_pfwRoundTimerTick);

    static iRoundTimeSecs;
    static Float:flStartTime;
    static bool:bFreezePeriod;

    if (g_bUseCustomRounds) {
      iRoundTimeSecs = g_iRoundTimeSecs;
      flStartTime = g_flRoundStartTimeReal;
      bFreezePeriod = g_bFreezePeriod;
    } else if (g_bIsCStrike) {
      #if defined _reapi_included
        iRoundTimeSecs = get_member_game(m_iRoundTimeSecs);
        flStartTime = get_member_game(m_fRoundStartTimeReal);
        bFreezePeriod = get_member_game(m_bFreezePeriod);
      #else
        iRoundTimeSecs = get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
        flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
        bFreezePeriod = get_gamerules_int("CGameRules", "m_bFreezePeriod");
      #endif
    }

    if (!bFreezePeriod && g_flGameTime >= flStartTime + float(iRoundTimeSecs)) {
      g_bExpired = true;
      ExecuteForward(g_pfwRoundExpired);
    }
  }
}

public Event_NewRound() {
  if (g_bUseCustomRounds) return;

  g_bExpired = false;
  g_iGameState = GameState_NewRound;
  ExecuteForward(g_pfwNewRound);
}

#if defined _reapi_included
  public HC_RestartRound() {
    if (g_bUseCustomRounds) return;

    g_bExpired = false;
    ExecuteForward(g_pfwRoundRestart);
  }

  public HC_OnRoundFreezeEnd() {
    if (g_bUseCustomRounds) return HC_CONTINUE;

    if (!CheckRoundStart()) {
      DelayRoundStart(1.0);
      return HC_BREAK;
    }

    return HC_CONTINUE;
  }

  public HC_OnRoundFreezeEnd_Post() {
    if (g_bUseCustomRounds) return;
    if (g_iGameState == GameState_RoundEnd) return;

    g_iGameState = GameState_RoundStarted;
    ExecuteForward(g_pfwRoundStart);
  }

  public HC_RoundEnd(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:flDelay) {
    if (g_bUseCustomRounds) return;
    if (g_iGameState == GameState_RoundEnd) return;

    new iTeam;

    switch (iStatus) {
      case WINSTATUS_TERRORISTS: iTeam = 1;
      case WINSTATUS_CTS: iTeam = 2;
      case WINSTATUS_DRAW: iTeam = 3;
    }

    g_iGameState = GameState_RoundEnd;
    ExecuteForward(g_pfwRoundEnd, _, iTeam);
  }

  public HC_CheckWinConditions() {
    if (g_bUseCustomRounds) return HC_CONTINUE;

    static Round_CheckResult:iCheckResult; ExecuteForward(g_pfwCheckWinConditions, _:iCheckResult);

    return iCheckResult == Round_CheckResult_Continue ? HC_CONTINUE : HC_SUPERCEDE;
  }
#endif

#if defined _orpheu_included
  public OrpheuHook_InstallGameRules_Post() {
    g_pGameRules = OrpheuGetReturn();
  }

  public OrpheuHook_CheckWinConditions() {
    if (g_bUseCustomRounds) return OrpheuIgnored;

    static Round_CheckResult:iCheckResult; ExecuteForward(g_pfwCheckWinConditions, _:iCheckResult);

    return iCheckResult == Round_CheckResult_Continue ? OrpheuIgnored : OrpheuSupercede;
  }
#endif

StartCustomRounds() {
  if (g_bUseCustomRounds) return;

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

  if (!cvar_exists("mp_roundtime")) register_cvar("mp_roundtime", "5.0");
  if (!cvar_exists("mp_freezetime")) register_cvar("mp_freezetime", "6.0");
  if (!cvar_exists("mp_maxrounds")) register_cvar("mp_maxrounds", "0");
  if (!cvar_exists("mp_winlimit")) register_cvar("mp_winlimit", "0");
  if (!cvar_exists("sv_restart")) register_cvar("sv_restart", "0");
  if (!cvar_exists("sv_restartround")) register_cvar("sv_restartround", "0");
  if (!cvar_exists("mp_round_restart_delay")) register_cvar("mp_round_restart_delay", "5.0");

  g_pCvarRoundTime = get_cvar_pointer("mp_roundtime");
  g_pCvarFreezeTime = get_cvar_pointer("mp_freezetime");
  g_pCvarMaxRounds = get_cvar_pointer("mp_maxrounds");
  g_pCvarWinLimits = get_cvar_pointer("mp_winlimit");
  g_pCvarRestart = get_cvar_pointer("sv_restart");
  g_pCvarRestartRound = get_cvar_pointer("sv_restartround");
  g_pCvarRoundEndDelay = get_cvar_pointer("mp_round_restart_delay");

  g_iMaxRounds = max(get_pcvar_num(g_pCvarMaxRounds), 0);
  g_iMaxRoundsWon = max(get_pcvar_num(g_pCvarWinLimits), 0);

  ReadMultiplayCvars();

  g_bUseCustomRounds = true;
}

public Native_UseCustomRounds(const iPluginId, const iArgc) {
  StartCustomRounds();
}

public Native_DispatchWin(const iPluginId, const iArgc) {
  new iTeam = get_param(1);
  new Float:flDelay = get_param_f(2);

  DispatchWin(iTeam, flDelay);
}

public Native_TerminateRound(const iPluginId, const iArgc) {
  new Float:flDelay = get_param_f(1);
  new iTeam = get_param(2);

  if (g_bUseCustomRounds) {
    TerminateRound(flDelay, iTeam);
  } else {
    DispatchWin(iTeam, flDelay);
  }
}

public Native_GetTime(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_iRoundTimeSecs;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_iRoundTimeSecs);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
    #endif
  }

  return 0;
}

public Native_SetTime(const iPluginId, const iArgc) {
  new iTime = get_param(1);

  SetTime(iTime);
}

public Native_GetIntroTime(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_iIntroRoundTime;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_iIntroRoundTime);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_iIntroRoundTime");
    #endif
  }

  return 0;
}

public Float:Native_GetStartTime(const iPluginId, const iArgc) {
  return GetStartTime();
}

public Float:Native_GetRestartRoundTime(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_flRestartRoundTime;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_flRestartRoundTime);
    #else
      return get_gamerules_float("CHalfLifeMultiplay", "m_flRestartRoundTime");
    #endif
  }

  return 0.0;
}

public Float:Native_GetRemainingTime(const iPluginId, const iArgc) {
  return GetRoundRemainingTime();
}

public bool:Native_IsFreezePeriod(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_bFreezePeriod;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_bFreezePeriod);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_bFreezePeriod");
    #endif
  }

  return false;
}

public bool:Native_IsRoundStarted(const iPluginId, const iArgc) {
  return g_iGameState > GameState_NewRound;
}

public bool:Native_IsRoundEnd(const iPluginId, const iArgc) {
  return g_iGameState == GameState_RoundEnd;
}

public bool:Native_IsRoundTerminating(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_bRoundTerminating;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_bRoundTerminating);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating");
    #endif
  }

  return false;
}

public bool:Native_IsPlayersNeeded(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_bNeededPlayers;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_bNeededPlayers);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_bNeededPlayers");
    #endif
  }

  return false;
}

public bool:Native_IsCompleteReset(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    return g_bCompleteReset;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_bCompleteReset);
    #else
      return get_gamerules_int("CHalfLifeMultiplay", "m_bCompleteReset");
    #endif
  }

  return false;
}

public bool:Native_CheckWinConditions(const iPluginId, const iArgc) {
  if (g_bUseCustomRounds) {
    CheckWinConditions();
  } else {
    #if defined _reapi_included
      rg_check_win_conditions();
    #endif
  }
}

public bool:Native_IsExpired(const iPluginId, const iArgc) {
  return g_bExpired;
}

DispatchWin(iTeam, Float:flDelay = -1.0) {
  if (g_iGameState == GameState_RoundEnd) return;

  if (flDelay < 0.0) {
    flDelay = g_pCvarRoundEndDelay ? get_pcvar_float(g_pCvarRoundEndDelay) : 5.0;
  }

  if (g_bUseCustomRounds) {
    EndRound(flDelay, iTeam);
    return;
  }

  if (!g_bIsCStrike) return;
  if (!iTeam) return;
  if (iTeam > 3) return;

  #if !defined _reapi_included
    enum {
        WINSTATUS_CTS = 1,
        WINSTATUS_TERRORISTS,
        WINSTATUS_DRAW
    };
  #endif

  new iWinStatus = _:WINSTATUS_DRAW;

  switch (iTeam) {
    case 1: iWinStatus = _:WINSTATUS_TERRORISTS;
    case 2: iWinStatus = _:WINSTATUS_CTS;
    case 3: iWinStatus = _:WINSTATUS_DRAW;
  }

  #if defined _reapi_included
    new ScenarioEventEndRound:iEvent = ROUND_END_DRAW;
    if (iTeam == 1) {
      iEvent = ROUND_TERRORISTS_WIN;
    } else if (iTeam == 2) {
      iEvent = ROUND_CTS_WIN;
    }

    rg_round_end(flDelay, any:iWinStatus, iEvent, _, _, true);
    rg_update_teamscores(iTeam == 2 ? 1 : 0, iTeam == 1 ? 1 : 0);
  #else
    new iNumCTWins = get_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins");
    new iNumTerroristWins = get_gamerules_int("CHalfLifeMultiplay", "m_iNumTerroristWins");
  
    set_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus", iWinStatus);
    set_gamerules_float("CHalfLifeMultiplay", "m_flRestartRoundTime", g_flGameTime + flDelay);
    set_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating", true);

    set_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins", iTeam == 2 ? iNumCTWins + 1 : iNumCTWins);
    set_gamerules_int("CHalfLifeMultiplay", "m_iNumTerroristWins", iTeam == 1 ? iNumTerroristWins + 1 : iNumTerroristWins);
  #endif

  UpdateTeamScores();
}

SetTime(iTime) {
  if (g_bUseCustomRounds) {
    g_iRoundTime = iTime;
    g_iRoundTimeSecs = iTime;
    g_flRoundStartTime = g_flRoundStartTimeReal;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      new Float:flStartTime = get_member_game(m_fRoundStartTimeReal);
      set_member_game(m_iRoundTime, iTime);
      set_member_game(m_iRoundTimeSecs, iTime);
      set_member_game(m_fRoundStartTime, flStartTime);
    #else
      new Float:flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
      set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTime", iTime);
      set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs", iTime);
      set_gamerules_float("CHalfLifeMultiplay", "m_fRoundCount", flStartTime);
    #endif
  }

  UpdateTimer();
}

UpdateTimer() {
  static iRemainingTime; iRemainingTime = floatround(GetRoundRemainingTime(), floatround_floor);

  if (g_bIsCStrike) {
    static iMsgId = 0;
    if(!iMsgId) iMsgId = get_user_msgid("RoundTime");

    message_begin(MSG_ALL, iMsgId);
    write_short(iRemainingTime);
    message_end();
  }

  ExecuteForward(g_pfwUpdateTimer, _, iRemainingTime);
}

EndRound(const Float:flDelay, iTeam, const szMessage[] = "") {
  EndRoundMessage(szMessage);
  TerminateRound(flDelay, iTeam);
}

CheckWinConditions() {
  static Round_CheckResult:iCheckResult; ExecuteForward(g_pfwCheckWinConditions, _:iCheckResult);

  if (g_iRoundWinTeam) {
    InitializePlayerCounts();
    return;
  }

  if (iCheckResult != Round_CheckResult_Continue) return;
  if (g_bGameStarted && g_iRoundWinTeam) return;

  InitializePlayerCounts();

  g_bNeededPlayers = false;

  if (NeededPlayersCheck()) return;
}

RestartRound() {
  if (!g_bCompleteReset) {
    g_iTotalRoundsPlayed++;
  }

  if (g_bCompleteReset) {
    g_iTotalRoundsPlayed = 0;
    g_iMaxRounds = max(get_pcvar_num(g_pCvarMaxRounds), 0);
    g_iMaxRoundsWon = max(get_pcvar_num(g_pCvarWinLimits), 0);

    for (new i = 0; i < sizeof(g_rgiWinsNum); ++i) {
      g_rgiWinsNum[i] = 0;
    }
  }

  ExecuteForward(g_pfwRoundRestart);

  g_bFreezePeriod = true;
  g_bRoundTerminating = false;

  ReadMultiplayCvars();

  g_iRoundTimeSecs = g_iIntroRoundTime;
  g_flRoundStartTime = g_flRoundStartTimeReal = g_flGameTime;

  CleanUpMap();

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

    PlayerRoundRespawn(pPlayer);
  }

  CleanUpMap();

  g_flRestartRoundTime = 0.0;
  g_iRoundWinTeam = 0;
  g_bCompleteReset = false;
  g_bExpired = false;

  g_iGameState = GameState_NewRound;
  ExecuteForward(g_pfwNewRound);
}

RoundThink() {
  if (!g_flRoundStartTime) {
    g_flRoundStartTime = g_flRoundStartTimeReal = g_flGameTime;
  }

  if (CheckMaxRounds()) return;
  if (CheckWinLimit()) return;

  if (g_bFreezePeriod) {
    CheckFreezePeriodExpired();
  } else {
    CheckRoundTimeExpired();
  }

  if (g_flRestartRoundTime > 0.0 && g_flRestartRoundTime <= g_flGameTime) {
    RestartRound();
  }

  if (g_flNextPeriodicThink <= g_flGameTime) {
    CheckRestartRound();

    g_iMaxRounds = get_pcvar_num(g_pCvarMaxRounds);
    g_iMaxRoundsWon = get_pcvar_num(g_pCvarWinLimits);
    g_flNextPeriodicThink = g_flGameTime + 1.0;
  }
}

bool:CheckMaxRounds() {
  if (g_iMaxRounds && g_iTotalRoundsPlayed >= g_iMaxRounds) {
    GoToIntermission();
    return true;
  }

  return false;
}

bool:CheckWinLimit() {
  if (g_iMaxRoundsWon) {
    new iMaxWins = 0;
    for (new i = 0; i < sizeof(g_rgiWinsNum); ++i) {
      if (g_rgiWinsNum[i] > iMaxWins) iMaxWins = g_rgiWinsNum[i];
    }

    if (iMaxWins >= g_iMaxRoundsWon) {
      GoToIntermission();
      return true;
    }
  }

  return false;
}

CheckFreezePeriodExpired() {
  if (g_iGameState == GameState_RoundEnd) return;

  if (GetRoundRemainingTime() > 0.0) return;

  if (!CheckRoundStart()) {
    DelayRoundStart(1.0);
    return;
  }

  log_message("World triggered ^"Round_Start^"\n");

  g_bFreezePeriod = false;
  g_flRoundStartTimeReal = g_flRoundStartTime = g_flGameTime;
  g_iRoundTimeSecs = g_iRoundTime;

  // for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
  //   if (!is_user_connected(pPlayer)) continue;
  //   if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

  //   if (get_ent_data(pPlayer, "CBasePlayer", "m_iJoiningState") == JOINED) {
      
  //   }
  // }

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    // if (!is_user_connected(pPlayer)) continue;
    if (!is_user_alive(pPlayer)) continue;
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
  }

  g_iGameState = GameState_RoundStarted;
  ExecuteForward(g_pfwRoundStart);
}

CheckRoundTimeExpired() {
  if (!g_iRoundTime) return;
  if (!HasRoundTimeExpired()) return;

  g_flRoundStartTime = g_flGameTime + 60.0;
}

HasRoundTimeExpired() {
  if (!g_iRoundTime) return false;
  if (GetRoundRemainingTime() > 0 || g_iRoundWinTeam != 0) return false;

  return true;
}

// CheckLevelInitialized() {}

RestartRoundCheck(Float:flDelay) {
  log_message("World triggered ^"Restart_Round_(%d_%s)^"^n", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "second" : "seconds");

  // let the players know
  client_print(0, print_center, "The game will restart in %d %s", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");
  client_print(0, print_console, "The game will restart in %d %s", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");

  g_flRestartRoundTime = g_flGameTime + flDelay;
  g_bCompleteReset = true;

  set_pcvar_num(g_pCvarRestartRound, 0);
  set_pcvar_num(g_pCvarRestart, 0);
}

CheckRestartRound() {
  new iRestartDelay = get_pcvar_num(g_pCvarRestartRound);

  if (!iRestartDelay) {
    iRestartDelay = get_pcvar_num(g_pCvarRestart);
  }

  if (iRestartDelay) {
    RestartRoundCheck(float(iRestartDelay));
  }
}

GoToIntermission() {
  message_begin(MSG_ALL, SVC_INTERMISSION);
  message_end();
}

PlayerRoundRespawn(pPlayer) {
  #pragma unused pPlayer
}

CleanUpMap() {}

ReadMultiplayCvars() {
  g_iRoundTime = floatround(get_pcvar_float(g_pCvarRoundTime) * 60, floatround_floor);
  g_iIntroRoundTime = floatround(get_pcvar_float(g_pCvarFreezeTime), floatround_floor);
}

NeededPlayersCheck() {
  if (!g_iSpawnablePlayersNum) {
    // log_message("#Game_scoring");
    g_bNeededPlayers = true;
    g_bGameStarted = false;
  }

  if (!g_bGameStarted && g_iSpawnablePlayersNum) {
    g_bFreezePeriod = false;
    g_bCompleteReset = true;

    EndRoundMessage("Game Commencing!");
    TerminateRound(3.0, 0);

    g_bGameStarted = true;

    return true;
  }

  return false;
}

TerminateRound(Float:flDelay, iTeam) {
  if (g_iGameState == GameState_RoundEnd) return;

  g_iRoundWinTeam = iTeam;
  g_flRestartRoundTime = g_flGameTime + flDelay;
  g_bRoundTerminating = true;
  g_iGameState = GameState_RoundEnd;

  ExecuteForward(g_pfwRoundEnd, _, iTeam);
}

EndRoundMessage(const szSentence[]) {
  static szMessage[64];

  if (szSentence[0] == '#') {
    copy(szMessage, charsmax(szMessage), szSentence[1]);
  } else {
    copy(szMessage, charsmax(szMessage), szSentence);
  }

  if (!equal(szSentence, NULL_STRING)) {
    client_print(0, print_center, szSentence);
    log_message("World triggered ^"%s^"^n", szMessage);
  }

  log_message("World triggered ^"Round_End^"^n");
}

// GetRoundRemainingTimeReal() {
//   return float(g_iRoundTimeSecs) - g_flGameTime + g_flRoundStartTimeReal;
// }

InitializePlayerCounts() {
  g_iSpawnablePlayersNum = 0;

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    g_iSpawnablePlayersNum++;
  }
}

Float:GetRoundRemainingTime() {
  static Float:flStartTime;
  static iTime;

  if (g_bUseCustomRounds) {
    flStartTime = g_flRoundStartTimeReal;
    iTime = g_iRoundTimeSecs;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      flStartTime = get_member_game(m_fRoundStartTimeReal);
      iTime = get_member_game(m_iRoundTimeSecs);
    #else
      flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
      iTime = get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
    #endif
  } else {
    return 0.0;
  }

  return float(iTime) - g_flGameTime + flStartTime;
}

Float:GetStartTime() {
  if (g_bUseCustomRounds) {
    return g_flRoundStartTime;
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      return get_member_game(m_fRoundStartTime);
    #else
      return get_gamerules_float("CHalfLifeMultiplay", "m_fRoundCount");
    #endif
  }

  return 0.0;
}

bool:CheckRoundStart() {
  static Round_CheckResult:iResult; ExecuteForward(g_pfwCheckRoundStart, _:iResult);

  return iResult == Round_CheckResult_Continue;
}

DelayRoundStart(const Float:flDelay) {
  static Float:flDuration; flDuration = g_flGameTime - GetStartTime() + flDelay;

  if (g_bUseCustomRounds) {
    g_iRoundTimeSecs = floatround(flDuration, floatround_floor);
  } else if (g_bIsCStrike) {
    #if defined _reapi_included
      set_member_game(m_iRoundTimeSecs, floatround(flDuration, floatround_floor));
    #else
      set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs", floatround(flDuration, floatround_floor));
    #endif
  }
}

UpdateTeamScores() {
  if (!g_bIsCStrike) return;

  #if defined _reapi_included
    new iNumCTWins = get_member_game(m_iNumCTWins);
    new iNumTerroristWins = get_member_game(m_iNumTerroristWins);
  #else
    new iNumCTWins = get_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins");
    new iNumTerroristWins = get_gamerules_int("CHalfLifeMultiplay", "m_iNumTerroristWins");
  #endif

  message_begin(MSG_ALL, gmsgTeamScore);
  write_string("CT");
  write_short(iNumCTWins);
  message_end();

  message_begin(MSG_ALL, gmsgTeamScore);
  write_string("TERRORIST");
  write_short(iNumTerroristWins);
  message_end();
}
