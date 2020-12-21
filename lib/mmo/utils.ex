defmodule MMO.Utils do
  @type lookup_table :: MMO.Board.lookup_table()
  @type coordinate :: MMO.Board.coordinate()
  @typep player_status :: :alive | :dead
  @type coalesced_board :: %{coordinate => coalesced_cell}
  @type coalesced_cell :: empty_cell | cell_contents
  @type empty_cell :: MMO.Board.cell()
  @type cell_contents :: %{player => player_status}
  @typep player :: String.t()
  @typep player_renderer :: (cell_contents -> String.t())
  @type board_dimensions :: MMO.Board.dimensions()

  @spec render(coalesced_board, board_dimensions, player) :: String.t()
  def render(%{} = coalesced_board, %{rows: _, cols: _} = dimensions, player)
      when is_binary(player),
      do: render(coalesced_board, dimensions, player_renderer(player))

  @spec render(coalesced_board, board_dimensions, player_renderer) :: String.t()
  def render(%{} = coalesced_board, %{rows: row_count, cols: col_count}, player_renderer)
      when is_integer(row_count) and row_count >= 0
      when is_integer(col_count) and col_count >= 0
      when is_function(player_renderer, 1) do
    (row_count - 1)..0
    |> Enum.reduce([], fn row, acc ->
      [render_row(coalesced_board, row, col_count, player_renderer) | acc]
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
