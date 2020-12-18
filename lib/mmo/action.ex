defprotocol MMO.Action do
  @spec apply(t, MMO.GameState.t()) :: MMO.GameState.t()
  def apply(action, game_state)
end
