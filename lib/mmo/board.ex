defmodule MMO.Board do
  @moduledoc """
  Defines the game board.

  Cells are referenced by {row, col} `t:coordinate/0` tuples, where each value is a non-negative integer.
  """

  alias __MODULE__.{Serialization, Validation}

  @typedoc "A game board instance."
  @opaque t :: %__MODULE__{}

  @typedoc "Board cell types"
  @type cell :: :wall | :floor

  @typedoc false
  @type row :: [cell(), ...]

  @typedoc false
  @type matrix :: [row(), ...]

  @typedoc false
  @type lookup_table :: %{coordinate => cell}

  @typedoc """
  Represents a coordinate on the board.

  `{0, 0}` refers to the top-left corner

  `{1, 0}` refers to the left-most cell on the 2nd row
  """
  @type coordinate :: {row :: non_neg_integer, col :: non_neg_integer}

  @type validation_error :: :non_rectangular | :not_enclosed | :unwalkable

  @default_board """
  ##########
  #        #
  #        #
  #        #
  ## ####  #
  #   #    #
  #   #    #
  #   #    #
  #        #
  ##########
  """

  @enforce_keys [:cells, :cell_map, :dimensions]
  defstruct [:cells, :cell_map, :dimensions]

  @doc """
  Creates a new board.

  The provided string representation is parsed into an `t:MMO.Board.t/0` instance:

  * every line represents a row
  * every character in the row represents a cell: walls are depicted with the `#` character, while walkable cells are a space `\u2423` character. Any other character is treated as a walkable cell.

  Boards must be completely enclosed in walls, be of rectangular shape, and have at least one walkable cell.

  Although not recommended, boards are allowed to have walls sectioning off areas.

  ## Examples

      iex> {:ok, %MMO.Board{}} = MMO.Board.new(\"""
      ...>  ####
      ...>  #  #
      ...>  ####
      ...>  \""")

      iex> MMO.Board.new(\"""
      ...>  ####
      ...>  #    #
      ...>  ####
      ...>  \""")
      {:error, :non_rectangular}

      iex> MMO.Board.new(\"""
      ...>  ##
      ...>  ##
      ...>  \""")
      {:error, :unwalkable}

      iex> MMO.Board.new(\"""
      ...>  ####
      ...>     #
      ...>  ####
      ...>  \""")
      {:error, :not_enclosed}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, validation_error}
  def new(board_string) when is_binary(board_string) do
    fields = Serialization.from_string(board_string)

    fields
    |> Keyword.fetch!(:cells)
    |> validate()
    |> case do
      :ok -> {:ok, struct!(__MODULE__, Enum.into(fields, %{}))}
      error -> {:error, error}
    end
  end

  @doc """
  Creates a default board.

  The board configuration is the following:
  ```
  #{@default_board}
  ```
  """
  @spec new() :: {:ok, t()} | {:error, validation_error}
  def new(), do: new(@default_board)

  @doc """
  Returns true if the given coordinate is walkable.

  Coordinates outside the map are considered walls (i.e. non-walkable)

  ## Examples

      iex> alias MMO.Board
      iex> {:ok, board} = Board.new(\"""
      ...>  ####
      ...>  #  #
      ...>  ####
      ...>  \""")
      iex> Board.walkable?(board, {0, 0})
      false
      iex> Board.walkable?(board, {1, 1})
      true
      iex> Board.walkable?(board, {1, 2})
      true
      iex> Board.walkable?(board, {99, 99})
      false
  """
  @spec walkable?(t, coordinate) :: boolean
  def walkable?(%__MODULE__{} = board, {row, col} = coord)
      when is_integer(row) and row >= 0
      when is_integer(col) and col >= 0 do
    board
    |> cell_map
    |> Map.get(coord, :wall)
    |> case do
      :wall -> false
      _ -> true
    end
  end

  @doc "Returns the `MMO.Board.coordinate/0` of a random walkable cell on the board"
  @spec random_walkable_cell(t) :: coordinate
  def random_walkable_cell(%__MODULE__{} = board) do
    {coord, :floor} =
      board
      |> cell_map()
      |> Enum.shuffle()
      |> Enum.find(fn {_coord, cell_type} -> cell_type == :floor end)

    coord
  end

  @doc """
  Returns true if the 2 coordinates are next to each other.

  Diagonally-positioned coordinates are not considered to be neighbors.

  ## Examples

      iex> alias MMO.Board
      iex> Board.neighbors?({0, 0}, {0, 1})
      true
      iex> Board.neighbors?({0, 0}, {0, 0})
      true
      iex> Board.neighbors?({0, 0}, {1, 1})
      false
      iex> Board.neighbors?({0, 0}, {0, 2})
      false
  """
  @spec neighbors?(coordinate, coordinate) :: boolean
  def neighbors?({x, y}, {x, y}), do: true
  def neighbors?({row, left}, {row, right}), do: touching?(left, right)
  def neighbors?({left, col}, {right, col}), do: touching?(left, right)
  def neighbors?({_, _}, {_, _}), do: false

  @doc false
  @spec touching?(non_neg_integer, non_neg_integer) :: boolean
  defp touching?(left, right), do: abs(left - right) == 1

  @doc false
  @spec blast_radius(t, coordinate) :: MapSet.t(coordinate)
  def blast_radius(board, {x, y}) do
    %{rows: rows, cols: cols} = dimensions(board)

    for row <- (x - 1)..(x + 1),
        row >= 0,
        row < rows,
        col <- (y - 1)..(y + 1),
        col >= 0,
        col < cols do
      {row, col}
    end
    |> MapSet.new()
  end

  @doc false
  @spec cells(t) :: matrix
  def cells(%__MODULE__{cells: cells}), do: cells

  @doc """
  Returns a map with coordinate keys refering to cells.
  """
  @spec cell_map(t) :: lookup_table
  def cell_map(%__MODULE__{cell_map: cell_map}), do: cell_map

  @doc """
  Returns the board's dimensions.
  """
  @spec dimensions(t) :: %{rows: non_neg_integer, cols: non_neg_integer}
  def dimensions(%__MODULE__{dimensions: dimensions}), do: dimensions

  @spec validate(matrix) :: :ok | validation_error
  defp validate(cells) do
    with {:rectangular, true} <- {:rectangular, Validation.rectangular?(cells)},
         {:enclosed, true} <- {:enclosed, Validation.fully_enclosed?(cells)},
         {:walkable, true} <- {:walkable, Validation.has_floor?(cells)} do
      :ok
    else
      {:rectangular, _} -> :non_rectangular
      {:enclosed, _} -> :not_enclosed
      {:walkable, _} -> :unwalkable
    end
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(board),
      do: board |> MMO.Board.cells() |> Serialization.to_string()
  end
end
