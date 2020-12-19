defmodule MMO.Board.Validation do
  @moduledoc false

  alias MMO.Board

  @spec rectangular?(Board.matrix()) :: boolean
  def rectangular?([h | _] = cells) do
    cells
    |> Enum.reduce_while(Enum.count(h), fn row, acc ->
      case Enum.count(row) do
        ^acc -> {:cont, acc}
        _ -> {:halt, :halted}
      end
    end)
    |> case do
      :halted -> false
      _ -> true
    end
  end

  @spec fully_enclosed?(Board.matrix()) :: boolean
  def fully_enclosed?(matrix) do
    with true <- matrix |> hd() |> only_wall?(),
         true <- matrix |> List.last() |> only_wall?(),
         true <- Enum.all?(matrix, &wall_bookends?/1) do
      true
    else
      _ -> false
    end
  end

  @spec only_wall?(Board.row()) :: boolean
  defp only_wall?(cells) do
    Enum.all?(cells, fn
      :wall -> true
      _ -> false
    end)
  end

  @spec wall_bookends?(Board.row()) :: boolean
  defp wall_bookends?([non_wall | _]) when non_wall != :wall, do: false
  defp wall_bookends?(row), do: List.last(row) == :wall

  @spec has_floor?(Board.matrix()) :: boolean
  def has_floor?(matrix), do: Enum.any?(matrix, &floor_cell_in_row?/1)

  @spec floor_cell_in_row?(Board.row()) :: boolean
  defp floor_cell_in_row?(row) do
    Enum.any?(row, fn
      :floor -> true
      _ -> false
    end)
  end

  @spec has_non_border_walls?(Board.matrix()) :: boolean
  def has_non_border_walls?(matrix) do
    matrix
    |> remove_bookends()
    |> Enum.map(&remove_bookends/1)
    |> List.flatten()
    |> Enum.reduce_while(0, fn
      _cell, 2 -> {:halt, 2}
      :wall, acc -> {:cont, acc + 1}
      :floor, acc -> {:cont, acc}
    end)
    |> case do
      insufficient_count when insufficient_count < 2 -> false
      _ -> true
    end
  end

  # Removes the first and last elements of the given enumerable.
  # Note that the order of elements is not preserved.
  @spec remove_bookends(Enumerable.t()) :: Enumerable.t()
  defp remove_bookends(enumerable) do
    enumerable
    |> tl()
    |> Enum.reverse()
    |> tl()
  end
end
