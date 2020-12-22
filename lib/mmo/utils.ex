defmodule MMO.Utils do
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
  @type player_renderer :: (cell_contents -> rendered_cell)
  @type rendered_cell :: rendered_tile | rendered_contents
  @type rendered_tile :: rendered_wall | rendered_floor

  @typedoc ~S(The `"#"` string.)
  @type rendered_wall :: String.t()

  @typedoc ~S{The `" "` (space character) string.}
  @type rendered_floor :: String.t()

  @type rendered_contents :: rendered_current_player | rendered_other_players
  @type rendered_current_player :: current_player_alive | current_player_dead

  @typedoc ~S(The `"@"` string.)
  @type current_player_alive :: String.t()

  @typedoc ~S(The `"&"` string.)
  @type current_player_dead :: String.t()

  @type rendered_other_players :: only_dead_players | few_live_players | many_live_players

  @typedoc ~S(The `"x"` string.)
  @type only_dead_players :: String.t()

  @typedoc "A digit from 1 to 9 in string format."
  @type few_live_players :: String.t()

  @typedoc ~S(The `"*"` string.)
  @type many_live_players :: String.t()

  @typedoc """
  A board's dimensions.

  A board with 7 rows and 9 columns will have `%{rows: 7, cols: 9}` dimensions.
  """
  @type board_dimensions :: %{rows: non_neg_integer, cols: non_neg_integer}

  @typep lookup_table :: MMO.Board.lookup_table()

  @doc """
  Renders a coalesced board state into a string.

  Example output:

  ```
  ##########
  # @x1    #
  #xx 1  * #
  #   1 1 1#
  ## #### 1#
  # 11# 1  #
  #  1#    #
  #   #    #
  # 211 1 1#
  ##########
  ```

  Where:

  * `#` is a cell containing a wall and is therefore not walkable
  * `\u2423` (i.e. "nothing") is a walkable cell containing no players
  * `@` is the cell containing the current player (and any number of other alive/dead players)
  * `&` is the cell containing the current player if they are dead (and any number of other alive/dead players)
  * `x` is a cell containing only dead players, and any number of them
  * any 1-9 digit is a cell containing that amount of live players if they are dead)
  * `*` is a cell containing over 9 live players (and any number of dead players)
  """
  @spec render(coalesced_board, board_dimensions, player) :: String.t()
  def render(%{} = coalesced_board, %{rows: _, cols: _} = dimensions, player_or_player_renderer)
      when is_binary(player_or_player_renderer),
      do: render(coalesced_board, dimensions, player_renderer(player_or_player_renderer))

  @spec render(coalesced_board, board_dimensions, player_renderer) :: String.t()
  def render(
        %{} = coalesced_board,
        %{rows: row_count, cols: col_count},
        player_or_player_renderer
      )
      when is_integer(row_count) and row_count >= 0
      when is_integer(col_count) and col_count >= 0
      when is_function(player_or_player_renderer, 1) do
    (row_count - 1)..0
    |> Enum.reduce([], fn row, acc ->
      [render_row(coalesced_board, row, col_count, player_or_player_renderer) | acc]
    end)
    |> IO.iodata_to_binary()
  end

  @spec render_row(lookup_table, non_neg_integer, non_neg_integer, player_renderer) ::
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
  @spec player_renderer(current_player :: player | :none) :: player_renderer
  def player_renderer(current_player) when is_binary(current_player) do
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
