defmodule MMO.Game do
  use GenServer

  alias MMO.GameState
  alias MMO.Actions.{Attack, Move}

  @type game_name :: atom
  @type player :: String.t()
  @type coordinate :: MMO.Board.coordinate()

  @name __MODULE__
  @registry Registry.MMO.Games

  def start_link(opts \\ []) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}

  def join(game \\ @name, player), do: call(game, {:join, player})

  def move(game \\ @name, player, destination), do: call(game, {:move, player, destination})

  def attack(game \\ @name, player), do: call(game, {:attack, player})

  @spec call(game, message :: any) :: any when game: String.t() | GenServer.server()

  defp call(game, message) when is_binary(game) do
    case lookup(game) do
      [{pid, _}] -> call(pid, message)
      [] -> {:error, :invalid_game}
    end
  end

  defp call(server, message), do: GenServer.call(server, message)

  defp lookup(game), do: Registry.lookup(@registry, game)

  def monitor(game), do: game |> lookup() |> Process.monitor()

  def init(opts) do
    GameState.new(opts)
  end

  def handle_call({:join, player}, _from, state) do
    {result, state} = GameState.spawn_player(state, player)
    {:reply, {result, GameState.coalesce(state)}, state}
  end

  def handle_call({:move, player, destination}, _from, state) do
    {result, state} = GameState.apply_action(state, Move.new(player, destination))
    {:reply, {result, GameState.coalesce(state)}, state}
  end

  # TODO respawn dead players
  def handle_call({:attack, player}, _from, state) do
    {result, state} = GameState.apply_action(state, Attack.new(player))
    {:reply, {result, GameState.coalesce(state)}, state}
  end
end
