defmodule MMO.GameStateTest do
  use ExUnit.Case, async: true
  doctest MMO.GameState

  alias MMO.GameState
  alias MMO.Actions.Move

  defp render_state(state) do
    GameState.render(state, GameState.player_renderer("me"))
  end

  defp assert_action(state, pre, action, post) do
    assert render_state(state) == pre
    state = GameState.apply_action(state, action)
    assert render_state(state) == post
  end

  describe "player movement" do
    setup do
      {:ok, board} = MMO.Board.new()

      %{
        state: GameState.new(board: board, player_positions: %{"me" => {1, 1}})
      }
    end

    test "can move to neighboring walkable cell", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 2}),
        """
        ##########
        # @      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move diagonally", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {2, 2}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move into wall", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 0}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move more than 1 cell", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 3}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "can move onto a cell containing another player", %{state: state} do
      state = %{state | player_positions: Map.put(state.player_positions, "other_player", {1, 2})}

      assert_action(
        state,
        """
        ##########
        #@1      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 2}),
        """
        ##########
        # @      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )

      players_on_cell =
        state
        |> GameState.apply_action(Move.new("me", {1, 2}))
        |> GameState.coalesce()
        |> Map.get({1, 2})

      assert MapSet.member?(players_on_cell, "me")
      assert MapSet.member?(players_on_cell, "other_player")
      assert MapSet.size(players_on_cell) == 2
    end
  end
end
