defmodule MMO.Game do
  use GenServer

  alias MMO.GameState
  alias MMO.Actions.{Attack, Move}
  alias MMO.Game.State

  @type game_name :: atom

  @typedoc false
  @type player :: String.t()

  @typedoc false
  @type coordinate :: MMO.Board.coordinate()

  @name __MODULE__
  @registry Registry.MMO.Games
  @respawn_delay if Mix.env() == :test, do: 100, else: 5_000

  @doc false
  def start_link(opts \\ []) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  @doc false
  def join(game \\ @name, player), do: call(game, {:join, player})

  @doc false
  def move(game \\ @name, player, destination), do: call(game, {:move, player, destination})

  @doc false
  def attack(game \\ @name, player), do: call(game, {:attack, player})

  @doc "Returns a game's pid"
  @spec whereis(game_name) :: nil | pid
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

  @doc false
  def init(opts) do
    case Keyword.get(opts, :state) do
      nil ->
        case build_state(opts) do
          {:ok, state} -> {:ok, state}
          error -> {:stop, error}
        end

      state ->
        {:ok, state}
    end
  end

  @spec build_state(Keyword.t()) :: {:ok, State.t()} | {:error, term}
  defp build_state(opts) do
    with {:ok, game_state} <- GameState.new(opts),
         {:ok, state} <- State.new(game_state) do
      {:ok, state}
    else
      {:error, _reason} = error -> error
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
    player_pids
    |> Map.values()
    |> Enum.each(
      &(&1
        |> MapSet.to_list()
        |> Enum.each(fn pid -> send_frame(pid, to_frame(game_state)) end))
    )

    state
  end

  defp send_frame(pid, frame) when is_pid(pid), do: send(pid, {:board_state, frame})

  defp to_frame(%GameState{} = game_state),
    do: {:erlang.system_time(:nano_seconds), GameState.to_frame(game_state)}
end
