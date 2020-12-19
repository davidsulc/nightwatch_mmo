defmodule MMO.Game do
  use GenServer

  alias MMO.GameState
  alias MMO.Actions.{Attack, Move}

  @type game_name :: atom
  @type player :: String.t()
  @type coordinate :: MMO.Board.coordinate()

  @name __MODULE__

  def start_link(name \\ @name, opts \\ []) when is_atom(name) and is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def join(game \\ @name, player) do
    GenServer.call(game, {:join, player})
  end

  def move(game \\ @name, player, destination) do
    GenServer.call(game, {:move, player, destination})
  end

  def attack(game \\ @name, player) do
    GenServer.call(game, {:attack, player})
  end

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
