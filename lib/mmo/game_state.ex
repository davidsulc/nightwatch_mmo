defmodule MMO.GameState do
  @doc """
  A game's state: board configuration, player coordinates, etc.
  """

  import MMO.Board, only: [is_coord: 1]

  alias MMO.{Action, Board}
  alias MMO.Actions.{Attack, Move}

  @type t :: %__MODULE__{board: Board.t(), player_info: %{player => player_state}}

  @typedoc false
  @typep player_state :: %{position: coordinate, status: player_status}

  @typedoc false
  @type coordinate :: Board.coordinate()

  @typedoc false
  @typep player_status :: :alive | :dead

  @typedoc false
  @type coalesced_board :: %{coordinate => coalesced_cell}

  @typedoc false
  @type coalesced_cell :: empty_cell | cell_contents

  @typedoc false
  @type empty_cell :: Board.cell()

  @typedoc false
  @type cell_contents :: %{player => player_status}

  @typedoc false
  @typep player :: String.t()

  @typedoc false
  @type action :: Attack.t() | Move.t()

  @typedoc false
  @type action_error :: player_error | move_error

  @typedoc false
  @typep player_error :: :invalid_player | :dead_player

  @typedoc false
  @typep spawn_error :: :already_spawned | :max_players

  @typedoc false
  @typep move_error :: :unwalkable_destination | :unreachable_destination

  @enforce_keys [:board, :player_info, :max_player_count]
  defstruct [:board, :player_info, :max_player_count, :meta]

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
  * `:max_players`: a non-negative integer greater than 1 indicating the
     maximum number of players the board may have. Once the player count has been reached,
     it will not be possible to spawn a new player (see `MMO.GameState.spawn_player/2`).
     `{:error, {:invalid_option, :max_players}}` will be returned if an invalid
     value is provided.
  """
  @doc false
  @spec new(Keyword.t()) ::
          {:ok, t} | {:error, {:invalid_option, option :: atom} | :max_board_dimension_exceeded}
  def new(opts \\ []) when is_list(opts) do
    board = get_board(opts)

    with {:max_players, true} <- {:max_players, member_option_valid?(opts, :max_players)},
         {:max_board_dimension, true} <-
           {:max_board_dimension, member_option_valid?(opts, :max_board_dimension)},
         {:board_dim, true} <-
           {:board_dim, board_dimensions_valid?(board, Keyword.get(opts, :max_board_dimension))} do
      {:ok,
       struct!(__MODULE__, %{
         board: board,
         player_info: %{},
         max_player_count: Keyword.get(opts, :max_players)
       })}
    else
      {:board_dim, false} ->
        {:error, :max_board_dimension_exceeded}

      {invalid_option_name, false} when is_atom(invalid_option_name) ->
        {:error, {:invalid_option, invalid_option_name}}
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
  defp option_valid?(:max_players, nil), do: true
  defp option_valid?(:max_players, max) when is_integer(max) and max > 1, do: true
  defp option_valid?(:max_players, _), do: false

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

  Errors:

  * `:already_spawned` if the player is already in the game
  * `:max_players` if the maximum player count for the game has been reached
  """
  @doc false
  @spec spawn_player(t, player) :: {:ok, t} | {{:error, spawn_error}, t}
  def spawn_player(%__MODULE__{} = state, player) when is_player(player),
    do: spawn_player_at(state, player, Board.random_walkable_cell(state.board))

  # If the player cannot be spawned at the desired location (e.g. cell isn't walkable),
  # he will be spawned in a random location instead
  @doc false
  @spec spawn_player_at(t, player, coordinate) :: {:ok, t} | {{:error, spawn_error}, t}

  def spawn_player_at(
        %__MODULE__{max_player_count: max, player_info: %{} = player_info} = state,
        _player,
        _coord
      )
      when not is_nil(max) and map_size(player_info) >= max,
      do: {{:error, :max_players}, state}

  def spawn_player_at(%__MODULE__{} = state, player, coord)
      when is_player(player) and is_coord(coord) do
    case Map.get(state.player_info, player) do
      nil -> {:ok, position_player_at(state, player, coord)}
      _ -> {{:error, :already_spawned}, state}
    end
  end

  @doc false
  @spec respawn_player(t, player) :: {:ok, t} | {{:error, :invalid_player}, t}
  def respawn_player(%__MODULE__{} = state, player) when is_player(player),
    do: respawn_player_at(state, player, Board.random_walkable_cell(state.board))

  @doc false
  @spec respawn_player_at(t, player, coordinate) :: {:ok, t} | {{:error, :invalid_player}, t}
  def respawn_player_at(%__MODULE__{} = state, player, coord)
      when is_player(player) and is_coord(coord) do
    case player_exists?(state, player) do
      true -> {:ok, position_player_at(state, player, coord)}
      false -> {{:error, :invalid_player}, state}
    end
  end

  @spec position_player_at(t, player, coordinate) :: t
  defp position_player_at(%__MODULE__{} = state, player, coord) do
    player_state = %{position: sanitize_spawn_location(state, coord), status: :alive}
    %{state | player_info: Map.put(state.player_info, player, player_state)}
  end

  @spec sanitize_spawn_location(t, coordinate) :: coordinate
  defp sanitize_spawn_location(%__MODULE__{} = state, coord) when is_coord(coord) do
    case Board.walkable?(state.board, coord) do
      true -> coord
      false -> Board.random_walkable_cell(state.board)
    end
  end

  @doc false
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
  @spec player_attack(t, player) :: {:ok, t} | {:error, player_error}
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

    player_kvs_to_kill =
      Enum.reduce(state.player_info, [], fn player_kv, acc ->
        case player_exposed?(player_kv, blast_radius, safe_players) do
          true -> [player_kv | acc]
          false -> acc
        end
      end)

    player_info =
      Enum.reduce(player_kvs_to_kill, state.player_info, fn {player, player_state}, player_info ->
        Map.put(player_info, player, kill_player(player_state))
      end)

    %{state | player_info: player_info}
    |> Map.put(:meta, %{players_killed: Enum.map(player_kvs_to_kill, fn {k, _v} -> k end)})
  end

  @spec kill_player(player_state) :: player_state
  defp kill_player(player_state), do: %{player_state | status: :dead}

  @spec player_exposed?({player, player_state}, MapSet.t(coordinate), MapSet.t(player)) :: boolean
  defp player_exposed?({player, player_state}, blast_radius, safe_players) do
    MapSet.member?(blast_radius, player_state.position) && !MapSet.member?(safe_players, player)
  end

  @doc false
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
  @spec drop_players(t, [player]) :: t
  def drop_players(%__MODULE__{} = state, players) when is_list(players),
    do: %{state | player_info: Map.drop(state.player_info, players)}

  @doc false
  @spec to_frame(t) :: %{board_state: coalesced_board, dimensions: Board.dimensions()}
  def to_frame(%__MODULE__{board: board} = state) do
    %{
      board_state: coalesce(state),
      dimensions: Board.dimensions(board)
    }
  end

  @doc false
  @spec render(t, player) :: String.t()
  def render(%__MODULE__{board: board} = state, current_player) do
    MMO.Utils.render(
      coalesce(state),
      Board.dimensions(board),
      MMO.Utils.player_renderer(current_player)
    )
  end
end
