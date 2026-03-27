---
name: amxx-modding-kit-api-player-music
description: Helps with Player Music API usage for MP3 music playback with automatic duration detection, pause/resume, and activity detection.
---

# Player Music API (`api_player_music`)

The Player Music API provides sophisticated MP3 music management with automatic duration detection, pause/resume functionality, activity detection, and event forwarding.

> **Reference**: See [README.md](https://github.com/hedgefog/amxx-modding-kit/api/player-music/README.md) for complete documentation and examples.

---

## Overview

This API allows you to:
- Load and play MP3 tracks with automatic duration detection
- Pause and resume playback
- Handle player activity (game minimization)
- Track playback events via forwards
- Loop tracks automatically

---

## Track Loading

### Load Tracks in Precache

All tracks MUST be loaded during `plugin_precache`:

```pawn
new PlayerMusic_Track:g_track;

public plugin_precache() {
  g_track = PlayerMusic_LoadTrack("media/Half-Life01.mp3");
}
```

### Load Multiple Tracks

```pawn
new const g_rgszMusicList[][] = {
  "media/ambient01.mp3",
  "media/ambient02.mp3",
  "media/ambient03.mp3"
};

new PlayerMusic_Track:g_rgTracks[sizeof(g_rgszMusicList)];

public plugin_precache() {
  for (new i = 0; i < sizeof(g_rgszMusicList); ++i) {
    g_rgTracks[i] = PlayerMusic_LoadTrack(g_rgszMusicList[i]);
  }
}
```

---

## Playback Control

### Play Track

```pawn
// Play immediately
PlayerMusic_Player_PlayTrack(pPlayer, g_track);

// Play with delay
PlayerMusic_Player_PlayTrack(pPlayer, g_track, 5.0); // 5 second delay

// Play looped
PlayerMusic_Player_PlayTrack(pPlayer, g_track, 0.0, true);
```

### Stop/Pause/Resume

```pawn
// Stop current track
PlayerMusic_Player_StopTrack(pPlayer);

// Pause current track
PlayerMusic_Player_PauseTrack(pPlayer);

// Resume paused track
PlayerMusic_Player_ResumeTrack(pPlayer);
```

### Query State

```pawn
// Check if track is paused
if (PlayerMusic_Player_IsTrackPaused(pPlayer)) {
  // Handle paused state
}

// Check if track is looped
if (PlayerMusic_Player_IsTrackLooped(pPlayer)) {
  // Handle looped state
}

// Check if track has started playing
if (PlayerMusic_Player_IsTrackStarted(pPlayer)) {
  // Track is actively playing
}

// Get remaining time
new Float:flTimeLeft = PlayerMusic_Player_GetTrackTimeLeft(pPlayer);
```

### Get Current Track

```pawn
new PlayerMusic_Track:track = PlayerMusic_Player_GetTrack(pPlayer);
if (track == PlayerMusic_Track_Invalid) {
  // No track playing
}
```

---

## Track Information

```pawn
new szTitle[64]; PlayerMusic_GetTrackTitle(track, szTitle, charsmax(szTitle));
new szArtist[64]; PlayerMusic_GetTrackArtist(track, szArtist, charsmax(szArtist));
new szAlbum[64]; PlayerMusic_GetTrackAlbum(track, szAlbum, charsmax(szAlbum));
new iYear = PlayerMusic_GetTrackYear(track);
```

---

## Event Forwards

Hook into playback events:

```pawn
// Called when track is scheduled
public PlayerMusic_OnTrackScheduled(pPlayer, PlayerMusic_Track:track, bool:bLoop, Float:flStartTime) {
  // Track scheduled for playback
}

// Called when track starts playing
public PlayerMusic_OnTrackStart(pPlayer, PlayerMusic_Track:track) {
  // Track playback started
}

// Called when track ends
public PlayerMusic_OnTrackEnd(pPlayer, PlayerMusic_Track:track, bool:bStopped) {
  // bStopped = true if manually stopped, false if ended naturally
  
  if (!bStopped) {
    // Play next track in queue
    PlayNextTrack(pPlayer);
  }
}

// Called when track is paused
public PlayerMusic_OnTrackPause(pPlayer, PlayerMusic_Track:track) {
  // Handle pause
}

// Called when track is resumed
public PlayerMusic_OnTrackResume(pPlayer, PlayerMusic_Track:track) {
  // Handle resume
}

// Called when looped track restarts
public PlayerMusic_OnTrackLoop(pPlayer, PlayerMusic_Track:track) {
  // Track looped to beginning
}
```

---

## Common Patterns

### Auto-Play on Connect

```pawn
public client_putinserver(pPlayer) {
  // Schedule random track with delay
  new iTrackIndex = random(sizeof(g_rgTracks));
  PlayerMusic_Player_PlayTrack(pPlayer, g_rgTracks[iTrackIndex], 5.0);
}
```

### Continuous Playlist

```pawn
public PlayerMusic_OnTrackEnd(pPlayer, PlayerMusic_Track:track, bool:bStopped) {
  if (bStopped) return;
  
  // Play next random track
  new iNext = random(sizeof(g_rgTracks));
  PlayerMusic_Player_PlayTrack(pPlayer, g_rgTracks[iNext], 2.0);
}
```

### Round-Based Music

```pawn
public Round_OnStart() {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    
    PlayerMusic_Player_PlayTrack(pPlayer, g_trackRoundStart);
  }
}

public Round_OnEnd(iTeam) {
  new PlayerMusic_Track:track = (iTeam == TEAM_WIN) ? g_trackVictory : g_trackDefeat;
  
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    
    PlayerMusic_Player_StopTrack(pPlayer);
    PlayerMusic_Player_PlayTrack(pPlayer, track);
  }
}
```

### Display Track Info HUD

```pawn
new g_pHudObj;

public plugin_init() {
  g_pHudObj = CreateHudSyncObj();
  set_task(1.0, "Task_ShowTrackInfo", 0, _, _, "b");
}

public Task_ShowTrackInfo() {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    
    new PlayerMusic_Track:track = PlayerMusic_Player_GetTrack(pPlayer);
    if (track == PlayerMusic_Track_Invalid) continue;
    
    static szTitle[64]; PlayerMusic_GetTrackTitle(track, szTitle, charsmax(szTitle));
    static Float:flTimeLeft; flTimeLeft = PlayerMusic_Player_GetTrackTimeLeft(pPlayer);
    
    set_hudmessage(255, 255, 255, 0.02, 0.9, 0, 0.0, 1.1, 0.0, 0.0);
    ShowSyncHudMsg(pPlayer, g_pHudObj, "Now Playing: %s (%.0fs)", szTitle, flTimeLeft);
  }
}
```

---

## Automatic Features

The API automatically handles:
- **Game Minimization**: Pauses music when player minimizes game
- **Volume Changes**: Responds to MP3 volume setting changes
- **Resume Logic**: Intelligently resumes at correct position
- **Timing Accuracy**: Maintains precise timing through pauses

---

## Checklist

- [ ] Load all tracks in `plugin_precache`
- [ ] Handle `PlayerMusic_OnTrackEnd` for playlists
- [ ] Check `PlayerMusic_Track_Invalid` when getting current track
- [ ] Consider delayed start for connect music
- [ ] Use forwards to react to playback events
