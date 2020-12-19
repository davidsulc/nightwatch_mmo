defprotocol MMO.Action do
  @spec apply(t, MMO.GameState.t()) ::
          {:ok, MMO.GameState.t()} | {{:error, reason}, MMO.GameState.t()}
        when reason: atom
  def apply(action, game_state)
end
