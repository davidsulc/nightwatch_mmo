defmodule MMO.PlaySession do
  use GenServer

  @reconnect_attempts 3
  @reconnect_delay 100

  @type coalesced_board :: %{coordinate => coalesced_cell}

  @typedoc """
  Represents a coordinate on the board.

  `{0, 0}` refers to the top-left corner

  `{1, 0}` refers to the left-most cell on the 2nd row
  """
  @type coordinate :: {row :: non_neg_integer, col :: non_neg_integer}

  @type coalesced_cell :: empty_cell | cell_contents
  @type empty_cell :: :floor | :wall
  @type cell_contents :: %{player => player_status}
  @type player :: String.t()
  @type player_status :: :alive | :dead

  @type game_name :: String.t()
  @type player_id :: String.t()
  @type direction :: :left | :right | :up | :down
  @type action_error :: player_error | move_error
  @type player_error :: :invalid_player | :dead_player
  @type move_error :: :unwalkable_destination | :unreachable_destination

  alias MMO.Game

  defmodule State do
    @moduledoc false

    defstruct [
      :player_id,
      :player_state,
      :game,
      :board_state,
      :board_dimensions,
      :latest_frame_number
    ]
  end

  defguardp is_direction(term) when term in [:left, :right, :up, :down]

  @doc "Joins the `game_name` game with a random player name"
  @spec start_link(game_name) :: GenServer.on_start()
  def start_link(game_name) when is_binary(game_name) do
    GenServer.start_link(__MODULE__, game_name: game_name, player_id: inspect(make_ref()))
  end

  @doc "Joins the `game_name` game with `player_id` as the player name"
  @spec start_link(game_name, player_id) :: GenServer.on_start()
  def start_link(game_name, player_id) when is_binary(game_name) and is_binary(player_id) do
    GenServer.start_link(__MODULE__, game_name: game_name, player_id: player_id)
  end

  @doc "Moves the player in `direction` direction, if possible."
  @spec move(pid, direction) :: :ok | {:error, action_error}
  def move(session, direction) when is_direction(direction) do
    GenServer.call(session, {:move, direction})
  end

  @doc "Makes the player attack."
  @spec attack(pid) :: :ok | {:error, player_error}
  def attack(session), do: GenServer.call(session, :attack)

  @doc "Returns the player state."
  @spec player_state(pid) :: %{position: coordinate, status: :alive | :dead}
  def player_state(session), do: GenServer.call(session, :player_state)

  @doc "Returns the game's state information."
  @spec game_info(pid) :: %{
          board_dimensions: %{cols: non_neg_integer, rows: non_neg_integer},
          state: coalesced_board
        }
  def game_info(session), do: GenServer.call(session, :game_info)

  @doc "Returns a string representation of the game."
  @spec to_string(pid) :: String.t()
  def to_string(session), do: GenServer.call(session, :render_to_string)

  @doc false
  def init(args) do
    game_name = Keyword.fetch!(args, :game_name)
    player_id = Keyword.fetch!(args, :player_id)

    case join_game(%State{player_id: player_id, game: game_name}) do
      {:ok, state} -> {:ok, state}
      {:error, _} = error -> {:stop, error}
    end
  end

  def handle_call({:move, direction}, _from, %State{} = state) when is_direction(direction) do
    destination = compute_coord(state, direction)

    {:reply, Game.move(state.game, state.player_id, destination), state}
  end

  def handle_call(:attack, _from, %State{} = state),
    do: {:reply, Game.attack(state.game, state.player_id), state}

  def handle_call(:player_state, _from, %State{player_state: player_state} = state),
    do: {:reply, player_state, state}

  def handle_call(:game_info, _from, %State{} = state) do
    %{board_state: board_state, board_dimensions: board_dimensions} = state
    {:reply, %{state: board_state, board_dimensions: board_dimensions}, state}
  end

  def handle_call(:render_to_string, _from, %State{} = state) do
    %{board_state: board_state, board_dimensions: dimensions, player_id: player_id} = state
    {:reply, MMO.Utils.render(board_state, dimensions, player_id), state}
  end

  def handle_info({:board_state, frame}, %State{} = state) do
    {:noreply, update_game(state, frame)}
  end

  def handle_info({:reconnect, failed_attempts}, %State{} = state) do
    case join_game(state) do
      {:ok, state} ->
        {:noreply, state}

      {:error, _} = error when failed_attempts + 1 >= @reconnect_attempts ->
        {:stop, error, state}

      {:error, _} ->
        Process.send_after(self(), {:reconnect, failed_attempts + 1}, @reconnect_delay)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, _, _, _}, %State{} = state) do
    Process.send_after(self(), {:reconnect, 0}, @reconnect_delay)

    {:noreply, state}
  end

  def handle_info(msg, %State{} = state) do
    :logger.error("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp join_game(%State{game: game, player_id: player_id} = state) do
    case Game.join(game, player_id) do
      {:ok, {frame_number, %{board_state: board_state, dimensions: board_dimensions}}} ->
        game
        |> MMO.whereis()
        |> Process.monitor()

        state =
          state
          |> Map.replace!(:board_state, board_state)
          |> Map.replace!(:board_dimensions, board_dimensions)
          |> Map.replace!(:latest_frame_number, frame_number)
          |> update_player_state()

        {:ok, state}

      {:error, _} = error ->
        error
    end
  end

  defp update_player_state(%State{player_id: player_id, board_state: board_state} = state) do
    {coord, players_in_cell} =
      Enum.find(board_state, fn
        {_coord, empty_cell} when is_atom(empty_cell) ->
          false

        {_coord, cell_contents} ->
          Map.has_key?(cell_contents, player_id)
      end)

    %{state | player_state: %{position: coord, status: Map.get(players_in_cell, player_id)}}
  end

  defp update_game(%State{latest_frame_number: latest_number} = state, {frame_number, update}) do
    case frame_number > latest_number do
      true ->
        %{board_state: board_state, dimensions: board_dimensions} = update

        update_player_state(%{
          state
          | latest_frame_number: frame_number,
            board_state: board_state,
            board_dimensions: board_dimensions
        })

      false ->
        # we silently drop game update info that is obsolete (e.g. delayed message)
        state
    end
  end

  defp compute_coord(%State{player_state: %{position: pos}}, direction)
       when is_direction(direction) do
    neighbor_coord(pos, direction)
  end

  defp compute_coord(%State{}, _invalid_direction), do: :error

  defp neighbor_coord({row, col}, :up), do: {row - 1, col}
  defp neighbor_coord({row, col}, :down), do: {row + 1, col}
  defp neighbor_coord({row, col}, :left), do: {row, col - 1}
  defp neighbor_coord({row, col}, :right), do: {row, col + 1}
end
