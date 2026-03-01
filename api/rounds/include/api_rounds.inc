#if defined _api_rounds_included
  #endinput
#endif
#define _api_rounds_included

#pragma reqlib api_rounds

#include <api_rounds_const>

/**
 * Enable custom rounds logic for games without a built-in round system.
 */
native Round_UseCustomManager();

/**
 * Dispatch a round win to a specific team after a delay.
 * @param iTeam Team ID to declare as the winner.
 * @param flDelay Delay in seconds before the win is dispatched.
 */
native Round_DispatchWin(iTeam, Float:flDelay = -1.0);

/**
 * Terminate the current round immediately or after a delay.
 * @param flDelay Delay in seconds before the round terminates.
 * @param winnerTeam Team ID to declare as the winner. Use 0 for no winner.
 */
native Round_Terminate(Float:fDelay = 0.0, iTeam = 0);

/**
 * Set the current round timer duration.
 * @param duration Duration in seconds to adjust the timer.
 */
native Round_SetTime(iTime);

/**
 * Get the configured round time.
 * @return Configured round time in seconds.
 */
native Round_GetTime();

/**
 * Get the configured intro time.
 * @return Configured intro time in seconds.
 */
native Round_GetIntroTime();

/**
 * Get the time when the round started.
 * @return Start time of the round.
 */
native Float:Round_GetStartTime();

/**
 * Get the restart time for the round.
 * @return Restart time in seconds.
 */
native Float:Round_GetRestartTime();

/**
 * Get the remaining time in the current round.
 * @return Remaining time in seconds.
 */
native Float:Round_GetRemainingTime();

/**
 * Check if the freeze period is active.
 * @return True if the freeze period is active.
 */
native bool:Round_IsFreezePeriod();

/**
 * Check if the round has started.
 * @return True if the round is started.
 */
native bool:Round_IsStarted();

/**
 * Check if the round has ended.
 * @return True if the round has ended.
 */
native bool:Round_IsEnd();

/**
 * Check if players are needed to start the round.
 * @return True if players are needed.
 */
native bool:Round_IsPlayersNeeded();

/**
 * Check if the game is restarted.
 * @return True if the game is restarted.
 */
native bool:Round_IsCompleteReset();

/**
 * Evaluate and handle the win conditions for the current round.
 * @return True if win conditions are met.
 */
native Round_CheckWinConditions();

/**
 * Check if the round has expired.
 * @return True if the round has expired.
 */
native bool:Round_IsExpired();

/**
 * Check if the round is currently terminating.
 * @return True if the round is terminating.
 */
native bool:Round_IsTerminating();

/**
 * Function called when a new round is initialized.
 */
forward Round_OnInit();

/**
 * Function called when the round starts.
 */
forward Round_OnStart();

/**
 * Function called when the round ends with a specified team as the winner.
 * @param iTeam Team ID of the winner.
 */
forward Round_OnEnd(iWinnerTeam);

/**
 * Function called when the round timer expires.
 */
forward Round_OnExpired();

/**
 * Function called when the round restarts.
 */
forward Round_OnRestart();

/**
 * Function called every second during the round timer.
 */
forward Round_OnTimerTick();

/**
 * Function called when the round timer updates.
 * @param iRemainingTime Remaining time in seconds.
 */
forward Round_OnUpdateTimer(iRemainingTime);

/**
 * Function called during check win conditions.
 */
forward Round_CheckResult:Round_OnCheckWinConditions();

/**
 * Function called when the round can start.
 */
forward Round_CheckResult:Round_OnCanStartCheck();
