defprotocol MMO.Action do
  @spec apply(t, MMO.Game.State.t()) ::
          {:ok, MMO.Game.State.t()} | {{:error, reason}, MMO.Game.State.t()}
        when reason: atom
  def apply(action, game_state)
end
