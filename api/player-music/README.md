# 🎵 Player Music API

The **Player Music API** is a sophisticated system for managing MP3 music playback. It provides robust handling of music tracks with automatic duration detection, pause/resume functionality, and event forwarding capabilities.

---

## 🚀 Features

- **Smart Track Management**: Automatically detects MP3 duration and handles timing events
- **Activity Detection**: Automatically pauses music when players minimize the game
- **Volume Control**: Monitors and responds to player's MP3 volume changes
- **Event System**: Rich set of forwards for tracking music playback states
- **Pause/Resume Logic**: Maintains correct timing even through pauses
- **Automatic Resource Management**: Handles track precaching

---

## ⚙️ Loading and Playing Tracks

Load MP3 tracks and control playback with simple native calls.
All tracks must be loaded during `plugin_precache` phase.

```pawn
#include <api_player_music>

public plugin_precache() {
  // Load an MP3 track
  new PlayerMusic_Track:track = PlayerMusic_LoadTrack("media/Half-Life01.mp3");
}
```

Playing track for player:
```pawn
PlayerMusic_Player_PlayTrack(pPlayer, track);
```

Playing track for player with delayed start:
```pawn
// 1 second delay
PlayerMusic_Player_PlayTrack(pPlayer, track, 1.0); 
```

---

## 🎧 Playback Control

Control track playback with various native functions.

```pawn
// Stop current track
PlayerMusic_Player_StopTrack(pPlayer);

// Pause current track
PlayerMusic_Player_PauseTrack(pPlayer);

// Resume paused track
PlayerMusic_Player_ResumeTrack(pPlayer);

// Check if track is paused
if (PlayerMusic_Player_IsTrackPaused(pPlayer)) {
    // Handle paused state
}

// Check if track is looped
if (PlayerMusic_Player_IsTrackLooped(pPlayer)) {
    // Handle looped state
}

// Get remaining track time
new Float:timeLeft = PlayerMusic_Player_GetTrackTimeLeft(pPlayer);
```

---

## 📡 Event Forwards

Hook into various track events to implement custom behavior.

```pawn
#include <api_player_music>

// Called when a track is scheduled to play
public PlayerMusic_OnTrackScheduled(const pPlayer, const PlayerMusic_Track:track, bool:loop, Float:startTime) {
    // Handle track scheduling
}

// Called when a track starts playing
public PlayerMusic_OnTrackStart(const pPlayer, const PlayerMusic_Track:track) {
    // Handle track start
}

// Called when a track ends
public PlayerMusic_OnTrackEnd(const pPlayer, const PlayerMusic_Track:track, bool:bStopped) {
    // Handle track end
    // stopped = true if stopped manually, false if ended naturally
}

// Called when a track is paused
public PlayerMusic_OnTrackPause(const pPlayer, const PlayerMusic_Track:track) {
    // Handle track pause
}

// Called when a track is resumed
public PlayerMusic_OnTrackResume(const pPlayer, const PlayerMusic_Track:track) {
    // Handle track resume
}

// Called when a looped track starts a new iteration
public PlayerMusic_OnTrackLoop(const pPlayer, const PlayerMusic_Track:track) {
    // Handle track loop
}
```

---

## 🎮 Activity Detection

The API automatically handles various player states:

- **Game Minimization**: Automatically pauses when player minimizes the game
- **Volume Changes**: Responds to player's MP3 volume settings
- **Resume Logic**: Intelligently resumes playback when appropriate

---

## ⏱️ Timing Management

The API maintains precise timing even through pauses and volume changes:

- Tracks time elapsed during pauses
- Adjusts end times to account for pauses
- Maintains loop timing accuracy
- Provides accurate time remaining calculations

```pawn
// Get remaining track time (accounts for pauses)
new Float:timeLeft = PlayerMusic_Player_GetTrackTimeLeft(pPlayer);
```

---

## 🎵 Example: Mod Music System

```pawn
#pragma semicolon 1

#include <amxmodx>

#include <api_player_music>

#define TRACK_START_DELAY 5.0

new const g_rgszMusicList[][] = {
  "media/Half-Life05.mp3",
  "media/Half-Life01.mp3",
  "media/Half-Life02.mp3",
  "media/Half-Life03.mp3",
  "media/Half-Life04.mp3"
};

new PlayerMusic_Track:g_rgiTracks[sizeof(g_rgszMusicList)];

new g_pHudObj;

public plugin_precache() {
  for (new i = 0; i < sizeof(g_rgszMusicList); ++i) {
    g_rgiTracks[i] = PlayerMusic_LoadTrack(g_rgszMusicList[i]);
  }
}

public plugin_init() {
  register_plugin("Test Music System", "1.0.0", "Hedgehog Fog");

  g_pHudObj = CreateHudSyncObj();
}

public client_putinserver(pPlayer) {
  @Player_ScheduleTrack(pPlayer);

  set_task(1.0, "Task_ShowTrackInfo", pPlayer, _, _, "b");
}

public PlayerMusic_OnTrackEnd(const pPlayer, const PlayerMusic_Track:track, bool:bStopped) {
  @Player_ScheduleTrack(pPlayer);
}

@Player_ScheduleTrack(const &pPlayer) {
  PlayerMusic_Player_PlayTrack(pPlayer, g_rgiTracks[random(sizeof(g_rgszMusicList))], TRACK_START_DELAY);
}

public Task_ShowTrackInfo(const pPlayer) {
  new PlayerMusic_Track:track = PlayerMusic_Player_GetTrack(pPlayer);
  if (track == PlayerMusic_Track_Invalid) {
    ClearSyncHud(pPlayer, g_pHudObj);
    return;
  }

  static szTrackTitle[64]; PlayerMusic_GetTrackTitle(track, szTrackTitle, charsmax(szTrackTitle));
  static szArtist[64]; PlayerMusic_GetTrackArtist(track, szArtist, charsmax(szArtist));
  static szAlbum[64]; PlayerMusic_GetTrackAlbum(track, szAlbum, charsmax(szAlbum));

  new iYear = PlayerMusic_GetTrackYear(track);

  static szMessage[512];

  new iPos = 0;

  iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Currently playing: %s^n", szTrackTitle);
  iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Author: %s^n", szArtist);
  iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Album: %s^n", szAlbum);
  iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Year: %d^n", iYear);

  if (PlayerMusic_Player_IsTrackStarted(pPlayer)) {
    iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Time Left: %.0f seconds", PlayerMusic_Player_GetTrackTimeLeft(pPlayer));
  } else {
    iPos += format(szMessage[iPos], charsmax(szMessage) - iPos, "Time Left: Scheduled");
  }

  set_hudmessage(random(256), random(256), random(256), 0.025, 0.1, 0, 0.0, 1.25, 0.0, 0.0);
  ShowSyncHudMsg(pPlayer, g_pHudObj, szMessage);
}
```

---

## 📖 API Reference

See [`api_player_music.inc`](include/api_player_music.inc) and [`api_player_music_const.inc`](include/api_player_music_const.inc) for all available natives, forwards, and constants.
