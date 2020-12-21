defmodule MMO.Game.State do
  alias MMO.GameState

  @enforce_keys [:game_state, :player_pids, :player_monitors]
  defstruct [:game_state, :player_pids, :player_monitors]

  def new(%GameState{} = game_state) do
    {:ok,
     %__MODULE__{
       game_state: game_state,
       player_pids: %{},
       player_monitors: %{}
     }}
  end

  def respawn_players(%__MODULE__{game_state: game_state} = state, players)
      when is_list(players) do
    game_state =
      Enum.reduce(players, game_state, fn p, acc ->
        case GameState.respawn_player(acc, p) do
          {:ok, acc} -> acc
          # player was removed from game (e.g. disconnected) so we don't respawn him
          {{:error, :invalid_player}, acc} -> acc
        end
      end)

    %{state | game_state: game_state}
  end

  def update_game_state(%__MODULE__{} = state, %GameState{} = game_state),
    do: %{state | game_state: game_state}

  def add_player_pid(%__MODULE__{player_pids: player_pids} = state, player, pid) do
    case player_pid_present?(state, player, pid) do
      true ->
        state

      false ->
        player_pids =
          Map.update(
            player_pids,
            player,
            MapSet.new([pid]),
            &MapSet.put(&1, pid)
          )

        monitor_ref = Process.monitor(pid)
        player_monitors = Map.put(state.player_monitors, monitor_ref, player)

        %{state | player_pids: player_pids, player_monitors: player_monitors}
    end
  end

  defp player_pid_present?(%__MODULE__{player_pids: player_pids}, player, pid) do
    player_pids
    |> Map.get(player)
    |> case do
      nil -> false
      pids -> MapSet.member?(pids, pid)
    end
  end

  def handle_down_message(%__MODULE__{} = state, {:DOWN, ref, :process, pid, _reason}) do
    %{player_pids: player_pids, player_monitors: player_monitors} = state

    player = Map.get(player_monitors, ref)
    pids_for_player = player_pids |> Map.get(player) |> MapSet.delete(pid)
    player_pids = Map.put(player_pids, player, pids_for_player)

    %{state | player_pids: player_pids, player_monitors: Map.delete(player_monitors, ref)}
  end

  def purge_disconnected_players(%__MODULE__{player_pids: player_pids} = state) do
    {disconnected, connected} =
      Enum.split_with(player_pids, fn {_player, pids} -> MapSet.size(pids) == 0 end)

    disconnected_players = Enum.map(disconnected, fn {player, _} -> player end)

    %{
      state
      | player_pids: Enum.into(connected, %{}),
        game_state: GameState.drop_players(state.game_state, disconnected_players)
    }
  end
end
