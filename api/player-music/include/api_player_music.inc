#if defined _api_player_music_included
  #endinput
#endif

#define _api_player_music_included

#include <api_player_music_const>

/**
 * Loads a track from the given path.
 *
 * @param szPath    The path to the track file.
 * @return          The track handle.
 */
native PlayerMusic_Track:PlayerMusic_LoadTrack(const szPath[]);

/**
 * Gets the duration of a track.
 *
 * @param track     The track handle.
 * @return          The duration of the track.
 */
native PlayerMusic_GetTrackDuration(const PlayerMusic_Track:track);

/**
 * Gets the path of a track.
 *
 * @param track     The track handle.
 * @param szOut     The output buffer.
 * @param iMaxLen   The maximum length of the output buffer.
 */
native PlayerMusic_GetTrackPath(const PlayerMusic_Track:track, szOut[], iMaxLen);

/**
 * Gets the title of a track.
 *
 * @param track     The track handle.
 * @param szOut     The output buffer.
 * @param iMaxLen   The maximum length of the output buffer.
 */
native PlayerMusic_GetTrackTitle(const PlayerMusic_Track:track, szOut[], iMaxLen);

/**
 * Gets the artist of a track.
 *
 * @param track     The track handle.
 * @param szOut     The output buffer.
 * @param iMaxLen   The maximum length of the output buffer.
 */
native PlayerMusic_GetTrackArtist(const PlayerMusic_Track:track, szOut[], iMaxLen);

/**
 * Gets the album of a track.
 *
 * @param track     The track handle.
 * @param szOut     The output buffer.
 * @param iMaxLen   The maximum length of the output buffer.
 */
native PlayerMusic_GetTrackAlbum(const PlayerMusic_Track:track, szOut[], iMaxLen);

/**
 * Gets the release year of a track.
 *
 * @param track     The track handle.
 * @return          The release year of the track.
 */
native PlayerMusic_GetTrackYear(const PlayerMusic_Track:track);

/**
 * Plays a track for a player.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 * @param flStartDelay The start delay.
 * @param bLoop       Whether to loop the track.
 */
native PlayerMusic_Player_PlayTrack(const pPlayer, const PlayerMusic_Track:track, Float:flStartDelay = 0.0, bool:bLoop = false);

/**
 * Stops a track for a player.
 *
 * @param pPlayer     The player.
 */
native PlayerMusic_Player_StopTrack(const pPlayer);

/**
 * Pauses a track for a player.
 *
 * @param pPlayer     The player.
 */
native PlayerMusic_Player_PauseTrack(const pPlayer);

/**
 * Resumes a track for a player.
 *
 * @param pPlayer     The player.
 */
native PlayerMusic_Player_ResumeTrack(const pPlayer);

/**
 * Gets the track for a player.
 *
 * @param pPlayer     The player.
 * @return            The track handle.
 */
native PlayerMusic_Track:PlayerMusic_Player_GetTrack(const pPlayer);

/**
 * Checks if a track is started for a player.
 *
 * @param pPlayer     The player.
 * @return            True if the track is started, false otherwise.
 */
native bool:PlayerMusic_Player_IsTrackStarted(const pPlayer);

/**
 * Checks if a track is paused for a player.
 *
 * @param pPlayer     The player.
 * @return            True if the track is paused, false otherwise.
 */
native bool:PlayerMusic_Player_IsTrackPaused(const pPlayer);

/**
 * Checks if a track is looped for a player.
 *
 * @param pPlayer     The player.
 * @return            True if the track is looped, false otherwise.
 */
native bool:PlayerMusic_Player_IsTrackLooped(const pPlayer);

/**
 * Gets the time left for a track for a player.
 *
 * @param pPlayer     The player.
 * @return            The time left for the track.
 */
native Float:PlayerMusic_Player_GetTrackTimeLeft(const pPlayer);

/**
 * Gets the start time of the current track for a player.
 *
 * @param pPlayer     The player.
 * @return            The start time of the track.
 */
native Float:PlayerMusic_Player_GetTrackStartTime(const pPlayer);

/**
 * Called when a track is scheduled.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 * @param bLoop       Whether to loop the track.
 * @param flStartTime The start time of the track.
 */
forward PlayerMusic_OnTrackScheduled(const pPlayer, const PlayerMusic_Track:track, bool:bLoop, Float:flStartTime);

/**
 * Called when a track starts.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 */
forward PlayerMusic_OnTrackStart(const pPlayer, const PlayerMusic_Track:track);

/**
 * Called when a track ends.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 * @param bStopped     Whether the track was stopped.
 */
forward PlayerMusic_OnTrackEnd(const pPlayer, const PlayerMusic_Track:track, bool:bStopped);

/**
 * Called when a track is paused.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 */
forward PlayerMusic_OnTrackPause(const pPlayer, const PlayerMusic_Track:track);

/**
 * Called when a track is resumed.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 */
forward PlayerMusic_OnTrackResume(const pPlayer, const PlayerMusic_Track:track);

/**
 * Called when a track is looped.
 *
 * @param pPlayer     The player.
 * @param track       The track handle.
 */
forward PlayerMusic_OnTrackLoop(const pPlayer, const PlayerMusic_Track:track);
