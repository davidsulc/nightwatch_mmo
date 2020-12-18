defmodule MMO.GameState do
  @moduledoc false

  alias MMO.{Action, Board}
  alias MMO.Actions.Move

  @type t :: %__MODULE__{board: Board.t(), player_info: %{player => player_state}}
  @typep player_state :: %{position: Board.coordinate(), status: player_status}
  @typep player_status :: :alive | :dead
  @type coalesced_board :: %{Board.coordinate() => coalesced_cell}
  @type coalesced_cell :: empty_cell | cell_contents
  @type empty_cell :: Board.cell()
  @type cell_contents :: %{player => player_status}
  @typep player :: String.t()
  @typep player_renderer :: (cell_contents -> String.t())
  @type action :: Move.t()

  @enforce_keys [:board, :player_info]
  defstruct [:board, :player_info]

  @spec new(Keyword.t()) :: t
  def new(fields) do
    struct!(__MODULE__, Enum.into(fields, %{}))
  end

  @spec apply_action(t, action) :: t
  def apply_action(%__MODULE__{} = state, action), do: Action.apply(action, state)

  @doc false
  def move_player(%__MODULE__{board: board} = state, %Move{player: player, to: destination}) do
    with true <- Board.walkable?(board, destination),
         origin when not is_nil(origin) <- current_position(state, player),
         true <- Board.neighbors?(origin, destination) do
      %{state | player_info: put_in(state.player_info, [player, :position], destination)}
    else
      # We can't move the player, so we don't.
      # This could for example happen if a player is attempting to walk into a wall, or a
      # later move message get received out of turn (i.e. it appears the player is trying
      # to move too far in a single step).
      # By ignoring those messages, we should eventually receive a valid move that can be applied
      # (either because the out of turn move was received, or the player submitted a new move request).
      # The only consequence for the player would be a percepetion of "lag" and his most logical
      # course of action would be attempting to move again.
      _ -> state
    end
  end

  @spec current_position(t, player) :: Board.coordinate()
  defp current_position(%__MODULE__{player_info: player_info}, player),
    do: get_in(player_info, [player, :position])

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
  defp render_row(board_cell_map, row, col_count, player_renderer) do
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
  def player_renderer(current_player) do
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

  defp render_other_players(players) do
    players
    |> Enum.filter(fn {_player, status} -> status == :alive end)
    |> Enum.count()
    |> case do
      # there are only dead players on the cell
      0 ->
        "x"

      # there are some alive players: don't count the dead ones
      count ->
        render_player_count(count)
    end
  end

  @spec render_player_count(pos_integer) :: String.t()
  defp render_player_count(count) when count > 9, do: "*"
  defp render_player_count(count), do: Integer.to_string(count)
end
