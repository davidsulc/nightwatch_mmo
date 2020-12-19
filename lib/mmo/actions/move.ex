defmodule MMO.Actions.Move do
  @moduledoc """
  A player's move information.

  This simply encodes the move "request": it won't necessarily be applied to the game state.
  """

  alias MMO.{Action, Board}
  alias MMO.GameState

  @opaque t :: %__MODULE__{}

  @enforce_keys [:player, :to]
  defstruct [:player, :to]

  @doc "Encodes a move attempt for the given player to the given coordinate."
  @spec new(String.t(), Board.coordinate()) :: t
  def new(player, coord), do: %__MODULE__{player: player, to: coord}

  defimpl Action do
    def apply(%MMO.Actions.Move{} = move, %GameState{} = state) do
      %{player: player, to: destination} = move
      GameState.move_player(state, player, destination)
    end
  end
end
