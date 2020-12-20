defmodule MMO.GameState do
  # TODO document
  @moduledoc false

  import MMO.Board, only: [is_coord: 1]

  alias MMO.{Action, Board}
  alias MMO.Actions.{Attack, Move}

  @type t :: %__MODULE__{board: Board.t(), player_info: %{player => player_state}}
  @typep player_state :: %{position: coordinate, status: player_status}
  @type coordinate :: Board.coordinate()
  @typep player_status :: :alive | :dead
  @type coalesced_board :: %{coordinate => coalesced_cell}
  @type coalesced_cell :: empty_cell | cell_contents
  @type empty_cell :: Board.cell()
  @type cell_contents :: %{player => player_status}
  @typep player :: String.t()
  @typep player_renderer :: (cell_contents -> String.t())
  @type action :: Attack.t() | Move.t()
  @type action_error :: player_error | move_error
  @typep player_error :: :invalid_player | :dead_player
  @typep spawn_error :: :already_spawned
  @typep move_error :: :unwalkable_destination | :unreachable_destination

  @enforce_keys [:board, :player_info]
  defstruct [:board, :player_info]

  defguardp is_player(term) when is_binary(term)

  @doc """
  Creates a new game state.

  Options:

  * `:board`: the `MMO.Board.t/0` the game should use. If none is provided,
     a board instance will be created.
  * `:max_board_dimension`: a non-negative integer indicating the
     maximum dimension the board may have. If the board's height or
     width exceed this value, `{:error, :max_board_dimension_exceeded}` is returned.
     `{:error, {:invalid_option, :max_board_dimension}}` will be returned if an invalid
     value is provided.
  """
  @spec new(Keyword.t()) ::
          {:ok, t} | {:error, {:invalid_option, option :: atom} | :max_board_dimension_exceeded}
  def new(opts \\ []) when is_list(opts) do
    board = get_board(opts)

    with {:max_dim, true} <- {:max_dim, member_option_valid?(opts, :max_board_dimension)},
         {:board_dim, true} <-
           {:board_dim, board_dimensions_valid?(board, Keyword.get(opts, :max_board_dimension))} do
      {:ok, struct!(__MODULE__, %{board: board, player_info: %{}})}
    else
      {:max_dim, false} ->
        {:error, {:invalid_option, :max_board_dimension}}

      {:board_dim, false} ->
        {:error, :max_board_dimension_exceeded}
    end
  end

  @spec get_board(Keyword.t()) :: Board.t()
  defp get_board(opts) when is_list(opts) do
    case Keyword.get(opts, :board) do
      nil ->
        {:ok, board} = Board.new()
        board

      board ->
        board
    end
  end

  defp member_option_valid?(opts, name), do: option_valid?(name, Keyword.get(opts, name))

  defp option_valid?(:max_board_dimension, nil), do: true
  defp option_valid?(:max_board_dimension, dim) when is_integer(dim) and dim > 0, do: true
  defp option_valid?(:max_board_dimension, _), do: false

  @spec board_dimensions_valid?(Board.t(), non_neg_integer) :: boolean

  defp board_dimensions_valid?(_board, nil), do: true

  defp board_dimensions_valid?(board, max_dimension)
       when is_integer(max_dimension) and max_dimension > 0 do
    %{rows: rows, cols: cols} = Board.dimensions(board)
    rows <= max_dimension && cols <= max_dimension
  end

  @doc """
  Spawns the player in a random location.

  Players will only be spawned on walkable cells. Spawning an existing player will
  change his location.
  """
  @spec spawn_player(t, player) :: {:ok, t}
  def spawn_player(%__MODULE__{} = state, player) when is_binary(player),
    do: spawn_player_at(state, player, Board.random_walkable_cell(state.board))

  # If the player cannot be spawned at the desired location (e.g. cell isn't walkable),
  # he will be spawned in a random location instead
  @doc false
  @spec spawn_player_at(t, player, coordinate) :: {:ok, t} | {:error, spawn_error}
  def spawn_player_at(%__MODULE__{} = state, player, coord)
      when is_player(player) and is_coord(coord) do
    case Map.get(state.player_info, player) do
      nil ->
        player_state = %{position: sanitize_spawn_location(state, coord), status: :alive}

        {:ok, %{state | player_info: Map.put(state.player_info, player, player_state)}}

      _ ->
        {{:error, :already_spawned}, state}
    end
  end

  @spec sanitize_spawn_location(t, coordinate) :: coordinate
  defp sanitize_spawn_location(%__MODULE__{} = state, coord) when is_coord(coord) do
    case Board.walkable?(state.board, coord) do
      true -> coord
      false -> Board.random_walkable_cell(state.board)
    end
  end

  @spec apply_action(t, action) :: {:ok, t} | {{:error, action_error}, t}
  def apply_action(%__MODULE__{} = state, action), do: Action.apply(action, state)

  @doc false
  @spec move_player(t, player, coordinate) :: {:ok, t} | {{:error, action_error}, t}
  def move_player(%__MODULE__{board: board} = state, player, destination)
      when is_player(player) and is_coord(destination) do
    with {:valid_player, :ok} <- {:valid_player, verify_player(state, player)},
         {:walkable, true} <- {:walkable, Board.walkable?(board, destination)},
         # the tuple match is only here to placate dialyzer
         {:coord, origin} when not is_nil(origin) <- {:coord, current_position(state, player)},
         {:neighbor, true} <- {:neighbor, Board.neighbors?(origin, destination)} do
      {:ok, %{state | player_info: put_in(state.player_info, [player, :position], destination)}}
    else
      {:coord, _} -> raise "Unable to determine current player #{player}'s position"
      {:valid_player, {:error, _} = error} -> {error, state}
      {:live_player, false} -> {{:error, :dead_player}, state}
      {:walkable, false} -> {{:error, :unwalkable_destination}, state}
      {:neighbor, false} -> {{:error, :unreachable_destination}, state}
    end
  end

  @spec verify_player(t, player) :: :ok | {:error, player_error}
  defp verify_player(state, player) do
    with {:valid_player, true} <- {:valid_player, player_exists?(state, player)},
         {:live_player, true} <- {:live_player, player_alive?(state, player)} do
      :ok
    else
      {:valid_player, false} -> {:error, :invalid_player}
      {:live_player, false} -> {:error, :dead_player}
    end
  end

  @spec player_exists?(t, player) :: boolean
  defp player_exists?(%__MODULE__{player_info: player_info}, player) when is_player(player),
    do: Map.has_key?(player_info, player)

  @spec player_alive?(t, player) :: boolean
  defp player_alive?(%__MODULE__{player_info: player_info}, player) when is_player(player),
    do: get_in(player_info, [player, :status]) == :alive

  @spec current_position(t, player) :: coordinate
  defp current_position(%__MODULE__{player_info: player_info}, player),
    do: get_in(player_info, [player, :position])

  @doc false
  @spec player_attack(t, player) :: {:ok, t}
  def player_attack(%__MODULE__{} = state, player) when is_player(player) do
    case verify_player(state, player) do
      :ok ->
        {:ok,
         kill_players(state, get_in(state.player_info, [player, :position]), except: [player])}

      {:error, _} = error ->
        {error, state}
    end
  end

  @spec kill_players(t, coordinate, Keyword.t()) :: t
  defp kill_players(%__MODULE__{} = state, center, opts)
       when is_coord(center) and is_list(opts) do
    safe_players = opts |> Keyword.get(:except, []) |> MapSet.new()
    blast_radius = Board.blast_radius(state.board, center)

    player_info =
      state.player_info
      |> Enum.map(fn player_kv ->
        case player_exposed?(player_kv, blast_radius, safe_players) do
          true -> kill_player(player_kv)
          false -> player_kv
        end
      end)
      |> Enum.into(%{})

    %{state | player_info: player_info}
  end

  @spec kill_player({player, player_state}) :: {player, player_state}
  defp kill_player({player, player_state}), do: {player, %{player_state | status: :dead}}

  @spec player_exposed?({player, player_state}, MapSet.t(coordinate), MapSet.t(player)) :: boolean
  defp player_exposed?({player, player_state}, blast_radius, safe_players) do
    MapSet.member?(blast_radius, player_state.position) && !MapSet.member?(safe_players, player)
  end

  @spec coalesce(t) :: coalesced_board
  def coalesce(%__MODULE__{} = state) do
    board_cell_map = Board.cell_map(state.board)

    Enum.reduce(state.player_info, board_cell_map, fn {player, player_state}, acc ->
      %{position: pos, status: player_status} = player_state
      cell = Map.get(acc, pos)

      updated_cell =
        cond do
          cell == :floor -> %{player => player_status}
          %{} = cell -> Map.put(cell, player, player_status)
          true -> raise "Player '#{player}' located on unwalkable cell #{inspect(pos)}"
        end

      Map.put(acc, pos, updated_cell)
    end)
  end

  @doc false
  @spec render(t, player_renderer) :: String.t()
  def render(%__MODULE__{} = state, player_renderer) do
    %{rows: row_count, cols: col_count} = Board.dimensions(state.board)
    coalesced_board = coalesce(state)

    (row_count - 1)..0
    |> Enum.reduce([], fn row, acc ->
      [render_row(coalesced_board, row, col_count, player_renderer) | acc]
    end)
    |> IO.iodata_to_binary()
  end

  @spec render_row(Board.lookup_table(), non_neg_integer, non_neg_integer, player_renderer) ::
          iodata
  defp render_row(%{} = board_cell_map, row, col_count, player_renderer) do
    rendered_cells =
      Enum.map(
        0..(col_count - 1),
        fn col ->
          board_cell_map
          |> Map.get({row, col})
          |> render_cell(player_renderer)
        end
      )

    [rendered_cells | "\n"]
  end

  @spec render_cell(coalesced_cell, player_renderer) :: String.t()
  defp render_cell(:wall, _renderer), do: "#"
  defp render_cell(:floor, _renderer), do: " "
  defp render_cell(cell_contents, renderer), do: renderer.(cell_contents)

  @doc false
  @spec player_renderer(current_player :: player) :: player_renderer
  def player_renderer(current_player) when is_player(current_player) do
    fn players_in_cell ->
      case Map.get(players_in_cell, current_player) do
        nil -> render_other_players(players_in_cell)
        status -> render_current_player(status)
      end
    end
  end

  @spec render_current_player(player_status) :: String.t()
  defp render_current_player(:alive), do: "@"
  defp render_current_player(:dead), do: "&"

  @spec render_other_players(cell_contents) :: String.t()

  defp render_other_players(%{} = players) when map_size(players) == 0, do: " "

  defp render_other_players(%{} = players) do
    players
    |> Enum.filter(fn {_player, status} -> status == :alive end)
    |> Enum.count()
    |> case do
      # there are only dead players on the cell
      0 ->
        "x"

      # there are some alive players: don't count the dead ones (i.e. only the
      # live players are considered for rendering)
      count ->
        render_player_count(count)
    end
  end

  @spec render_player_count(pos_integer) :: String.t()
  defp render_player_count(count) when count > 9, do: "*"
  defp render_player_count(count), do: Integer.to_string(count)
end
