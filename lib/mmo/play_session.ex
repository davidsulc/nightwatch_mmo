defmodule MMO.PlaySession do
  use GenServer

  @type game_name :: String.t()
  @type player_id :: String.t()

  alias MMO.Game

  defmodule State do
    defstruct [
      :player_id,
      :player_position,
      :player_status,
      :game,
      :game_state,
      :latest_frame_number
    ]
  end

  defguardp is_direction(term) when term in [:left, :right, :up, :down]

  def start_link(game_name, player_id) when is_binary(game_name) and is_binary(player_id) do
    GenServer.start_link(__MODULE__, game_name: game_name, player_id: player_id)
  end

  def move(session, direction) when is_direction(direction) do
    GenServer.call(session, {:move, direction})
  end

  def attack(session), do: GenServer.call(session, :attack)

  def init(args) do
    # TODO monitor game -> rejoin on crash
    game_name = Keyword.fetch!(args, :game_name)
    player_id = Keyword.fetch!(args, :player_id)

    case MMO.join(game_name, player_id) do
      {:ok, {frame_number, game_state}} ->
        initial_state = %State{
          player_id: player_id,
          game: game_name,
          game_state: game_state,
          latest_frame_number: frame_number
        }

        {:ok, update_player_info(initial_state)}

      {:error, _} = error ->
        {:stop, error}
    end
  end

  def handle_call({:move, direction}, _from, state) when is_direction(direction) do
    destination = compute_coord(state, direction)

    {:reply, Game.move(state.game, state.player_id, destination), state}
  end

  def handle_call(:attack, _from, state),
    do: {:reply, Game.attack(state.game, state.player_id), state}

  def handle_info({:game_state, frame}, state) do
    {:noreply, update_game(state, frame)}
  end

  def handle_info(msg, state) do
    :logger.error("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp update_player_info(%State{player_id: player_id, game_state: game_state} = state) do
    {coord, players_in_cell} =
      Enum.find(game_state, fn
        {_coord, empty_cell} when is_atom(empty_cell) ->
          false

        {_coord, cell_contents} ->
          Map.has_key?(cell_contents, player_id)
      end)

    %{state | player_status: Map.get(players_in_cell, player_id), player_position: coord}
  end

  defp update_game(%State{latest_frame_number: latest_number} = state, {frame_number, game_state})
       when frame_number > latest_number,
       do:
         update_player_info(%{state | latest_frame_number: frame_number, game_state: game_state})

  # we silently drop game update info that is obsolete (e.g. delayed message)
  defp update_game(%State{} = state, _old_frame), do: state

  defp compute_coord(%State{player_position: pos}, direction)
       when is_direction(direction),
       do: neighbor_coord(pos, direction)

  defp neighbor_coord({row, col}, :up), do: {row - 1, col}
  defp neighbor_coord({row, col}, :down), do: {row + 1, col}
  defp neighbor_coord({row, col}, :left), do: {row, col - 1}
  defp neighbor_coord({row, col}, :right), do: {row, col + 1}
end
