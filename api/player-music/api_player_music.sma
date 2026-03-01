#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <mp3_util>

#if AMXX_VERSION_NUM < 183
  #define client_disconnected client_disconnect
#endif

#define LOG_PREFIX "[Player Music]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

/*--------------------------------[ Constants ]--------------------------------*/

#define MAX_TRACKS 256
#define ACTIVITY_CHECK_INTERVAL 0.25
#define TRACK_CHECK_INTERVAL 0.125
#define VOLUME_CHECK_INTERVAL 1.0
#define MAX_TRACK_TITLE_LENGTH 128
#define MAX_TRACK_ARTIST_LENGTH 128
#define MAX_TRACK_ALBUM_LENGTH 128

enum TrackState {
  TrackState_None = 0,
  TrackState_Scheduled,
  TrackState_Playing,
  TrackState_Paused,
  TrackState_Ended,
  TrackState_Stopped
};

enum PlayerFlag (<<=1) {
  PlayerFlag_None = 0,
  PlayerFlag_Connected = 1,
  PlayerFlag_Active,
  PlayerFlag_TrackLooped,
  PlayerFlag_ResumeTrackOnActive,
  PlayerFlag_ResumeTrackOnVolumeChange
};

/*--------------------------------[ Forward Pointers ]--------------------------------*/

new g_pfwTrackScheduled;
new g_pfwTrackStart;
new g_pfwTrackEnd;
new g_pfwTrackPause;
new g_pfwTrackResume;
new g_pfwTrackLoop;

/*--------------------------------[ Plugin State ]--------------------------------*/

new Trie:g_itTrack = Invalid_Trie;
new g_rgszTrackPath[MAX_TRACKS][MAX_RESOURCE_PATH_LENGTH];
new Float:g_rgflTrackDuration[MAX_TRACKS];
new g_rgszTrackTitle[MAX_TRACKS][MAX_TRACK_TITLE_LENGTH];
new g_rgszTrackArtist[MAX_TRACKS][MAX_TRACK_ARTIST_LENGTH];
new g_rgszTrackAlbum[MAX_TRACKS][MAX_TRACK_ALBUM_LENGTH];
new g_rgiTrackYear[MAX_TRACKS];
new g_iTracksNum = 0;

new Float:g_flGameTime = 0.0;

/*--------------------------------[ Players Shared State ]--------------------------------*/

new PlayerFlag:g_rgiPlayerFlag[MAX_PLAYERS + 1];

/*--------------------------------[ Players Activity State ]--------------------------------*/

new Float:g_rgflPlayerNextActivityCheck[MAX_PLAYERS + 1];
new Float:g_rgflPlayerButtonsChangeTime[MAX_PLAYERS + 1];
new g_rgiPlayerMinMsec[MAX_PLAYERS + 1];

/*--------------------------------[ Players Track State ]--------------------------------*/

new g_rgiPlayerTrack[MAX_PLAYERS + 1];
new Float:g_rgflPlayerTrackStartTime[MAX_PLAYERS + 1];
new Float:g_rgflPlayerTrackEndTime[MAX_PLAYERS + 1];
new Float:g_rgflPlayerTrackPauseTime[MAX_PLAYERS + 1];
new TrackState:g_rgiPlayerTrackState[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextTrackUpdate[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextVolumeCheck[MAX_PLAYERS + 1];
new g_rgiPlayerMP3Volume[MAX_PLAYERS + 1];

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  g_itTrack = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] Player Music", "1.0.0", "Hedgehog Fog");

  g_pfwTrackScheduled = CreateMultiForward("PlayerMusic_OnTrackScheduled", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT);
  g_pfwTrackStart = CreateMultiForward("PlayerMusic_OnTrackStart", ET_IGNORE, FP_CELL, FP_CELL);
  g_pfwTrackEnd = CreateMultiForward("PlayerMusic_OnTrackEnd", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
  g_pfwTrackPause = CreateMultiForward("PlayerMusic_OnTrackPause", ET_IGNORE, FP_CELL, FP_CELL);
  g_pfwTrackResume = CreateMultiForward("PlayerMusic_OnTrackResume", ET_IGNORE, FP_CELL, FP_CELL);
  g_pfwTrackLoop = CreateMultiForward("PlayerMusic_OnTrackLoop", ET_IGNORE, FP_CELL, FP_CELL);

  register_forward(FM_CmdStart, "FMHook_CmdStart");

  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
}

public plugin_end() {
  TrieDestroy(g_itTrack);
}

public plugin_natives() {
  register_library("api_player_music");

  register_native("PlayerMusic_LoadTrack", "Native_LoadTrack");
  register_native("PlayerMusic_GetTrackDuration", "Native_GetTrackDuration");
  register_native("PlayerMusic_GetTrackPath", "Native_GetTrackPath");
  register_native("PlayerMusic_GetTrackTitle", "Native_GetTrackTitle");
  register_native("PlayerMusic_GetTrackArtist", "Native_GetTrackArtist");
  register_native("PlayerMusic_GetTrackAlbum", "Native_GetTrackAlbum");
  register_native("PlayerMusic_GetTrackYear", "Native_GetTrackYear");

  register_native("PlayerMusic_Player_PlayTrack", "Native_PlayTrack");
  register_native("PlayerMusic_Player_IsTrackStarted", "Native_IsTrackStarted");
  register_native("PlayerMusic_Player_IsTrackPaused", "Native_IsTrackPaused");
  register_native("PlayerMusic_Player_GetTrack", "Native_GetTrack");
  register_native("PlayerMusic_Player_StopTrack", "Native_StopTrack");
  register_native("PlayerMusic_Player_PauseTrack", "Native_PauseTrack");
  register_native("PlayerMusic_Player_ResumeTrack", "Native_ResumeTrack");
  register_native("PlayerMusic_Player_IsTrackLooped", "Native_IsTrackLooped");
  register_native("PlayerMusic_Player_GetTrackStartTime", "Native_GetTrackStartTime");
  register_native("PlayerMusic_Player_GetTrackTimeLeft", "Native_GetTrackTimeLeft");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_LoadTrack(const iPluginId, const iArgc) {
  new szPath[MAX_RESOURCE_PATH_LENGTH]; get_string(1, szPath, charsmax(szPath));

  return LoadTrack(szPath);
}

public Native_GetTrackPath(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  set_string(2, g_rgszTrackPath[iId], get_param(3));
}

public Float:Native_GetTrackDuration(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  return g_rgflTrackDuration[iId];
}

public Native_GetTrackTitle(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  set_string(2, g_rgszTrackTitle[iId], get_param(3));
}

public Native_GetTrackArtist(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  set_string(2, g_rgszTrackArtist[iId], get_param(3));
}

public Native_GetTrackAlbum(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  set_string(2, g_rgszTrackAlbum[iId], get_param(3));
}

public Native_GetTrackYear(const iPluginId, const iArgc) {
  static iId; iId = get_param(1);

  return g_rgiTrackYear[iId];
}

public Native_GetTrack(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return -1;

  return g_rgiPlayerTrack[pPlayer];
}

public Native_PlayTrack(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static iId; iId = get_param(2);
  static Float:flDelay; flDelay = get_param_f(3);
  static bool:bLoop; bLoop = bool:get_param(4);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return @Player_ScheduleTrack(pPlayer, iId, bLoop, g_flGameTime + flDelay);
}

public bool:Native_StopTrack(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return @Player_StopTrack(pPlayer);
}

public bool:Native_PauseTrack(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  
  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return @Player_PauseTrack(pPlayer, 0.0);
}

public bool:Native_ResumeTrack(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return @Player_ResumeTrack(pPlayer);
}

public bool:Native_IsTrackStarted(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return g_rgiPlayerTrackState[pPlayer] > TrackState_Scheduled;
}

public bool:Native_IsTrackPaused(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return g_rgiPlayerTrackState[pPlayer] == TrackState_Paused;
}

public bool:Native_IsTrackLooped(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return false;

  return !!(g_rgiPlayerFlag[pPlayer] & PlayerFlag_TrackLooped);
}

public Float:Native_GetTrackStartTime(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return 0.0;
  if (g_rgiPlayerTrack[pPlayer] == -1) return 0.0;

  return g_rgflPlayerTrackStartTime[pPlayer];
}

public Float:Native_GetTrackTimeLeft(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (~g_rgiPlayerFlag[pPlayer] & PlayerFlag_Connected) return 0.0;
  if (g_rgiPlayerTrack[pPlayer] == -1) return 0.0;
  if (g_rgiPlayerTrackState[pPlayer] != TrackState_Playing && g_rgiPlayerTrackState[pPlayer] != TrackState_Paused) return 0.0;

  if (g_rgiPlayerTrackState[pPlayer] == TrackState_Paused) {
    return g_rgflPlayerTrackEndTime[pPlayer] - g_rgflPlayerTrackPauseTime[pPlayer];
  }

  return floatmax(g_rgflPlayerTrackEndTime[pPlayer] - g_flGameTime, 0.0);
}

/*--------------------------------[ Engine Forwards ]--------------------------------*/

public server_frame() {
  g_flGameTime = get_gametime();
}

/*--------------------------------[ Client Forwards ]--------------------------------*/

public client_connect(pPlayer) {
  g_rgflPlayerNextActivityCheck[pPlayer] = 0.0;
  g_rgflPlayerButtonsChangeTime[pPlayer] = 0.0;
  g_rgiPlayerMinMsec[pPlayer] = 99999;
  g_rgiPlayerTrack[pPlayer] = -1;
  g_rgiPlayerFlag[pPlayer] = PlayerFlag_Connected;
  g_rgflPlayerTrackStartTime[pPlayer] = 0.0;
  g_rgflPlayerTrackEndTime[pPlayer] = 0.0;
  g_rgflPlayerTrackPauseTime[pPlayer] = 0.0;
  g_rgflPlayerNextTrackUpdate[pPlayer] = 0.0;
  g_rgiPlayerTrackState[pPlayer] = TrackState_None;
}

public client_disconnected(pPlayer) {
  g_rgiPlayerFlag[pPlayer] &= ~PlayerFlag_Connected;

  if (g_rgiPlayerTrackState[pPlayer] == TrackState_Playing) {
    @Player_StopTrack(pPlayer);
  }
}

/*--------------------------------[ Player Methods ]--------------------------------*/

bool:@Player_ScheduleTrack(const &this, const iId, bool:bLoop, Float:flStartTime) {
  if (is_user_bot(this)) return false;

  if (g_rgiPlayerTrackState[this] == TrackState_Playing || g_rgiPlayerTrackState[this] == TrackState_Paused) {
    @Player_StopTrack(this);
  }

  g_rgiPlayerTrack[this] = iId;
  g_rgflPlayerTrackStartTime[this] = flStartTime;
  g_rgflPlayerTrackEndTime[this] = 0.0;
  g_rgiPlayerTrackState[this] = TrackState_Scheduled;

  if (bLoop) {
    g_rgiPlayerFlag[this] |= PlayerFlag_TrackLooped;
  } else {
    g_rgiPlayerFlag[this] &= ~PlayerFlag_TrackLooped;
  }

  ExecuteForward(g_pfwTrackScheduled, _, this, g_rgiPlayerTrack[this], bLoop, g_rgflPlayerTrackStartTime[this]);

  return true;
}

bool:@Player_StartTrack(const &this) {
  if (g_rgiPlayerTrack[this] == -1) return false;
  if (g_rgiPlayerTrackState[this] != TrackState_Scheduled) return false;

  new iId = g_rgiPlayerTrack[this];

  static szCommand[16 + MAX_RESOURCE_PATH_LENGTH];
  format(szCommand, charsmax(szCommand), "mp3 %s ^"%s^"", g_rgiPlayerFlag[this] & PlayerFlag_TrackLooped ? "loop" : "play", g_rgszTrackPath[iId]);
  client_cmd(this, szCommand);

  g_rgflPlayerTrackStartTime[this] = g_flGameTime;
  g_rgflPlayerTrackEndTime[this] = g_rgflPlayerTrackStartTime[this] + g_rgflTrackDuration[iId];
  g_rgiPlayerTrackState[this] = TrackState_Playing;

  ExecuteForward(g_pfwTrackStart, _, this, g_rgiPlayerTrack[this]);

  return true;
}

bool:@Player_LoopTrack(const &this) {
  if (g_rgiPlayerTrack[this] == -1) return false;

  new iId = g_rgiPlayerTrack[this];

  g_rgflPlayerTrackEndTime[this] = g_flGameTime + g_rgflTrackDuration[iId];
  g_rgiPlayerTrackState[this] = TrackState_Playing;

  ExecuteForward(g_pfwTrackLoop, _, this, g_rgiPlayerTrack[this]);

  return true;
}

bool:@Player_EndTrack(const &this) {
  if (g_rgiPlayerTrack[this] == -1) return false;
  if (g_rgiPlayerTrackState[this] != TrackState_Playing) return false;

  g_rgiPlayerTrackState[this] = TrackState_Ended;

  ExecuteForward(g_pfwTrackEnd, _, this, g_rgiPlayerTrack[this], false);

  return true;
}

bool:@Player_StopTrack(const &this) {
  if (g_rgiPlayerTrack[this] == -1) return false;
  if (g_rgiPlayerTrackState[this] != TrackState_Playing && g_rgiPlayerTrackState[this] != TrackState_Paused) {
    if (g_rgiPlayerTrackState[this] == TrackState_Scheduled) {
      g_rgiPlayerTrackState[this] = TrackState_None;

      return true;
    }

    return false;
  }

  client_cmd(this, "mp3 stop");
  g_rgiPlayerTrackState[this] = TrackState_Stopped;

  ExecuteForward(g_pfwTrackEnd, _, this, g_rgiPlayerTrack[this], true);

  return true;
}

bool:@Player_PauseTrack(const &this, Float:flTimeOffset) {
  if (g_rgiPlayerTrack[this] == -1) return false;
  if (g_rgiPlayerTrackState[this] != TrackState_Playing) return false;

  client_cmd(this, "mp3 pause");

  g_rgflPlayerTrackPauseTime[this] = g_flGameTime + flTimeOffset;
  g_rgiPlayerTrackState[this] = TrackState_Paused;

  ExecuteForward(g_pfwTrackPause, _, this, g_rgiPlayerTrack[this]);

  return true;
}

bool:@Player_ResumeTrack(const &this) {
  if (g_rgiPlayerTrack[this] == -1) return false;
  if (g_rgiPlayerTrackState[this] != TrackState_Paused) return false;

  new Float:flPauseTime = g_flGameTime - g_rgflPlayerTrackPauseTime[this];

  client_cmd(this, "mp3 resume");

  g_rgflPlayerTrackEndTime[this] += flPauseTime;
  g_rgflPlayerTrackPauseTime[this] = 0.0;
  g_rgiPlayerTrackState[this] = TrackState_Playing;
  g_rgiPlayerFlag[this] &= ~(PlayerFlag_ResumeTrackOnActive | PlayerFlag_ResumeTrackOnVolumeChange);

  ExecuteForward(g_pfwTrackResume, _, this, g_rgiPlayerTrack[this]);

  return true;
}

@Player_UpdateActivityStatus(const &this) {
  static bool:bActive; bActive = (
    g_rgiPlayerMinMsec[this] < 20 ||
    (g_flGameTime - g_rgflPlayerButtonsChangeTime[this]) < ACTIVITY_CHECK_INTERVAL
  );

  if (!!(g_rgiPlayerFlag[this] & PlayerFlag_Active) != bActive) {
    if (bActive) {
      g_rgiPlayerFlag[this] |= PlayerFlag_Active;
    } else {
      g_rgiPlayerFlag[this] &= ~PlayerFlag_Active;
    }
  }
}

@Player_UpdateTrackState(const &this) {
  if (g_rgiPlayerTrack[this] == -1) {
    g_rgiPlayerTrackState[this] = TrackState_None;
    return;
  }

  switch (g_rgiPlayerTrackState[this]) {
    case TrackState_Scheduled: {
      if (g_rgflPlayerTrackStartTime[this] <= g_flGameTime) {
        if ((g_rgiPlayerFlag[this] & PlayerFlag_Active) && g_rgiPlayerMP3Volume[this]) {
          @Player_StartTrack(this);
        }
      }
    }
    case TrackState_Playing: {
      if (g_rgflPlayerTrackEndTime[this] > g_flGameTime) {
        /*
          MP3 music paused by default when player minimized the game window,
          however we want to make sure about that flow, so we handle it manually.
        */
        if (g_rgiPlayerFlag[this] & PlayerFlag_Active) {
          if (!g_rgiPlayerMP3Volume[this]) {
            g_rgiPlayerFlag[this] |= PlayerFlag_ResumeTrackOnVolumeChange;
            @Player_PauseTrack(this, -TRACK_CHECK_INTERVAL);
          }
        } else {
          g_rgiPlayerFlag[this] |= PlayerFlag_ResumeTrackOnActive;
          @Player_PauseTrack(this, -TRACK_CHECK_INTERVAL);
        }
      } else {
        if (g_rgiPlayerFlag[this] & PlayerFlag_TrackLooped) {
          @Player_LoopTrack(this);
        } else {
          @Player_EndTrack(this);
        }
      }
    }
    case TrackState_Paused: {
      static bool:bResume; bResume = false;

      if (g_rgiPlayerFlag[this] & (PlayerFlag_ResumeTrackOnVolumeChange | PlayerFlag_ResumeTrackOnActive)) {
        bResume = true;

        if (g_rgiPlayerFlag[this] & PlayerFlag_ResumeTrackOnVolumeChange) {
          bResume = bResume && g_rgiPlayerMP3Volume[this] > 0;
        }

        if (g_rgiPlayerFlag[this] & PlayerFlag_ResumeTrackOnActive) {
          bResume = bResume && (g_rgiPlayerFlag[this] & PlayerFlag_Active);
        }
      }

      if (bResume) {
        @Player_ResumeTrack(this);
      }
    }
  }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_CmdStart(const pPlayer, const pCmd) {
  g_rgiPlayerMinMsec[pPlayer] = min(g_rgiPlayerMinMsec[pPlayer], get_uc(pCmd, UC_Msec));

  if (get_uc(pCmd, UC_Buttons) != pev(pPlayer, pev_oldbuttons)) {
    g_rgflPlayerButtonsChangeTime[pPlayer] = g_flGameTime;
  }

  if (g_rgflPlayerNextActivityCheck[pPlayer] <= g_flGameTime) {
    @Player_UpdateActivityStatus(pPlayer);
    g_rgiPlayerMinMsec[pPlayer] = 99999;
    g_rgflPlayerNextActivityCheck[pPlayer] = g_flGameTime + ACTIVITY_CHECK_INTERVAL;
  }
}

public HamHook_Player_PostThink_Post(const pPlayer) {
  if (is_user_bot(pPlayer)) return;

  if (g_rgflPlayerNextTrackUpdate[pPlayer] <= g_flGameTime) {
    @Player_UpdateTrackState(pPlayer);
    g_rgflPlayerNextTrackUpdate[pPlayer] = g_flGameTime + TRACK_CHECK_INTERVAL;
  }

  if (g_rgflPlayerNextVolumeCheck[pPlayer] <= g_flGameTime) {
    query_client_cvar(pPlayer, "MP3Volume", "Callback_ClientCvar_MP3Volume");
    g_rgflPlayerNextVolumeCheck[pPlayer] = g_flGameTime + VOLUME_CHECK_INTERVAL;
  }
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public Callback_ClientCvar_MP3Volume(const pPlayer, const szCvar[], const szValue[]) {
  g_rgiPlayerMP3Volume[pPlayer] = str_to_num(szValue);
}

/*--------------------------------[ Functions ]--------------------------------*/

LoadTrack(const szPath[]) {
  new iId;

  if (!TrieGetCell(g_itTrack, szPath, iId)) {
    if (!file_exists(szPath, true)) {
      LOG_ERROR("Could not load ^"%s^" file. File is not exists!", szPath);
      return false;
    }
    
    iId = g_iTracksNum;

    if (
      !MP3_GetInfo(
        szPath,
        g_rgflTrackDuration[iId],
        g_rgszTrackTitle[iId],
        charsmax(g_rgszTrackTitle[]),
        g_rgszTrackArtist[iId],
        charsmax(g_rgszTrackArtist[]),
        g_rgszTrackAlbum[iId],
        charsmax(g_rgszTrackAlbum[]),
        g_rgiTrackYear[iId]
      )
    ) {
      LOG_ERROR("Failed to get track info for ^"%s^" file", szPath);
      return false;
    }

    precache_generic(szPath);

    copy(g_rgszTrackPath[iId], charsmax(g_rgszTrackPath[]), szPath);

    TrieSetCell(g_itTrack, szPath, iId);

    g_iTracksNum++;
  }

  return iId;
}
