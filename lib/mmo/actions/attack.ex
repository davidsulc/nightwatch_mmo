defmodule MMO.Actions.Attack do
  @moduledoc """
  A player's attack command.
  """

  alias MMO.Action
  alias MMO.Game.State

  @opaque t :: %__MODULE__{player: binary}

  @enforce_keys [:player]
  defstruct [:player]

  @doc "Encodes an attack command."
  @spec new(String.t()) :: t
  def new(player), do: %__MODULE__{player: player}

  defimpl Action do
    def apply(%MMO.Actions.Attack{player: player}, %State{} = state) do
      State.player_attack(state, player)
    end
  end
end
