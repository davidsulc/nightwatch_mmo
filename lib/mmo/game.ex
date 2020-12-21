defmodule MMO.Game do
  use GenServer

  alias MMO.GameState
  alias MMO.Actions.{Attack, Move}

  @type game_name :: atom
  @type player :: String.t()
  @type coordinate :: MMO.Board.coordinate()

  @name __MODULE__
  @registry Registry.MMO.Games
  @respawn_delay 5_000

  defmodule State do
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

    def handle_down_message(%State{} = state, {:DOWN, ref, :process, pid, _reason}) do
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

  def start_link(opts \\ []) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def join(game \\ @name, player), do: call(game, {:join, player})

  def move(game \\ @name, player, destination), do: call(game, {:move, player, destination})

  def attack(game \\ @name, player), do: call(game, {:attack, player})

  def whereis(game \\ @name) do
    case lookup(game) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @spec call(game, message :: any) :: any when game: String.t() | GenServer.server()

  defp call(game, message) when is_binary(game) do
    case lookup(game) do
      [{pid, _}] -> call(pid, message)
      [] -> {:error, :invalid_game}
    end
  end

  defp call(server, message), do: GenServer.call(server, message)

  defp lookup(game), do: Registry.lookup(@registry, game)

  def init(opts) do
    with {:ok, game_state} <- GameState.new(opts),
         {:ok, state} <- State.new(game_state) do
      {:ok, state}
    else
      error -> {:stop, error}
    end
  end

  def handle_call({:join, player}, {pid, _ref} = _from, %State{game_state: game_state} = state) do
    case GameState.spawn_player(game_state, player) do
      {{:error, :max_players}, _} = error ->
        {:reply, error, state}

      {_result, updated_game_state} ->
        state = update_game(state, updated_game_state, player, pid)

        broadcast_state_changes(state)

        {:reply, {:ok, to_frame(state.game_state)}, state}
    end
  end

  def handle_call({:move, player, destination}, {pid, _ref} = _from, state) do
    {result, game_state} = GameState.apply_action(state.game_state, Move.new(player, destination))

    state = update_game(state, game_state, player, pid)

    broadcast_state_changes(state)

    {:reply, result, state}
  end

  def handle_call({:attack, player}, {pid, _ref} = _from, state) do
    {result, game_state} = GameState.apply_action(state.game_state, Attack.new(player))

    with :ok <- result,
         %{players_killed: players} <- Map.get(game_state, :meta) do
      Process.send_after(self(), {:respawn, players}, @respawn_delay)
    end

    state = update_game(state, game_state, player, pid)

    broadcast_state_changes(state)

    {:reply, result, state}
  end

  def handle_info({:respawn, players}, %State{} = state) do
    state =
      state
      |> State.purge_disconnected_players()
      |> State.respawn_players(players)

    broadcast_state_changes(state)

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, _, _} = down_message, state),
    do: State.handle_down_message(state, down_message)

  def handle_info(msg, %State{} = state) do
    :logger.error("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp update_game(%State{} = state, game_state, player, pid) when is_pid(pid) do
    state
    |> State.update_game_state(Map.delete(game_state, :meta))
    |> State.add_player_pid(player, pid)
  end

  defp broadcast_state_changes(%State{player_pids: player_pids, game_state: game_state} = state) do
    game_state_frame = to_frame(game_state)

    player_pids
    |> Map.values()
    |> Enum.each(
      &(&1
        |> MapSet.to_list()
        |> Enum.each(fn pid -> send_frame(pid, game_state_frame) end))
    )

    state
  end

  defp send_frame(pid, frame) when is_pid(pid), do: send(pid, {:game_state, frame})

  defp to_frame(%GameState{} = game_state),
    do: {:erlang.system_time(:nano_seconds), GameState.coalesce(game_state)}
end
