defprotocol MMO.Action do
  @spec apply(t, MMO.Game.State.t()) :: MMO.Game.State.t()
  def apply(action, game_state)
end
