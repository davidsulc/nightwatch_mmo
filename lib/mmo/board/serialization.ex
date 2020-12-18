defmodule MMO.Board.Serialization do
  @moduledoc false

  alias MMO.Board

  @spec from_string(String.t()) :: Keyword.t()
  def from_string(board_string) do
    matrix =
      board_string
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_row/1)

    [
      cells: matrix,
      cell_map: to_map(matrix),
      dimensions: %{rows: Enum.count(matrix), cols: matrix |> hd() |> Enum.count()}
    ]
  end

  @spec to_string(Board.matrix()) :: String.t()
  def to_string(matrix) do
    matrix
    |> Enum.map(fn row -> [Enum.map(row, &serialize_cell/1), "\n"] end)
    |> IO.iodata_to_binary()
  end

  @spec to_map(Board.matrix()) :: Board.lookup_table()
  defp to_map(rows) do
    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, row_index} -> to_map(row, row_index) end)
    |> Enum.reduce(%{}, fn row_map, board_map -> Map.merge(board_map, row_map) end)
  end

  @spec to_map(Board.row(), non_neg_integer) :: Board.lookup_table()
  defp to_map(cells_in_row, row_index) do
    cells_in_row
    |> Enum.with_index()
    |> Enum.map(fn {cell, col_index} -> {{row_index, col_index}, cell} end)
    |> Enum.into(%{})
  end

  @spec parse_row(String.t()) :: Board.row()
  defp parse_row(row) when is_binary(row) do
    row
    |> String.graphemes()
    |> Enum.map(&parse_cell/1)
  end

  @spec parse_cell(String.t()) :: Board.cell()
  defp parse_cell("#"), do: :wall
  defp parse_cell(_), do: :floor

  @spec serialize_cell(Board.cell()) :: String.t()
  defp serialize_cell(:wall), do: "#"
  defp serialize_cell(:floor), do: " "
end
