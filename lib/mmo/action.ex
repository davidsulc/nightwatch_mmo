defprotocol MMO.Action do
  @doc "Applies the given action instance to the game's state."
  @spec apply(t, MMO.GameState.t()) ::
          {:ok, MMO.GameState.t()} | {{:error, reason}, MMO.GameState.t()}
        when reason: atom
  def apply(action, game_state)
end
