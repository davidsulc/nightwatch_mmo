defmodule MMO.Actions.Attack do
  @moduledoc """
  A player's attack command.
  """

  alias MMO.{Action, GameState}

  @opaque t :: %__MODULE__{}

  @enforce_keys [:player]
  defstruct [:player]

  @doc "Encodes an attack command."
  @spec new(String.t()) :: t
  def new(player), do: %__MODULE__{player: player}

  defimpl Action do
    def apply(%MMO.Actions.Attack{} = attack, %GameState{} = state) do
      GameState.player_attack(state, attack)
    end
  end
end
