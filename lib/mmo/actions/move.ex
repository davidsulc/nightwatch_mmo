defmodule MMO.Actions.Move do
  @moduledoc """
  A player's move information.

  This simply encodes the move "request": it won't necessarily be applied to the game state.
  """

  alias MMO.Action
  alias MMO.GameState

  @opaque t :: %__MODULE__{}

  @typedoc """
  Represents a coordinate on the board.

  `{0, 0}` refers to the top-left corner

  `{1, 0}` refers to the left-most cell on the 2nd row
  """
  @type coordinate :: {row :: non_neg_integer, col :: non_neg_integer}

  @enforce_keys [:player, :to]
  defstruct [:player, :to]

  @doc "Encodes a move attempt for the given player to the given coordinate."
  @spec new(String.t(), coordinate) :: t
  def new(player, coord), do: %__MODULE__{player: player, to: coord}

  defimpl Action do
    def apply(%MMO.Actions.Move{} = move, %GameState{} = state) do
      %{player: player, to: destination} = move
      GameState.move_player(state, player, destination)
    end
  end
end
