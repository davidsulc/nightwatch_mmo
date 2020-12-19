defmodule MMO.Game.StateTest do
  use ExUnit.Case, async: true
  doctest MMO.Game.State

  alias MMO.Game.State
  alias MMO.Actions.{Attack, Move}

  defp render_state(state) do
    State.render(state, State.player_renderer("me"))
  end

  defp assert_action(state, pre, action, post) do
    assert render_state(state) == pre
    state = State.apply_action(state, action)
    assert render_state(state) == post
  end

  describe "player movement" do
    setup do
      %{
        state: State.new() |> State.spawn_player_locations(%{"me" => {1, 1}})
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
      state = State.spawn_player_locations(state, %{"other_player" => {1, 2}})

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
        |> State.apply_action(Move.new("me", {1, 2}))
        |> State.coalesce()
        |> Map.get({1, 2})

      assert Map.has_key?(players_on_cell, "me")
      assert Map.has_key?(players_on_cell, "other_player")
      assert Enum.count(players_on_cell) == 2
    end
  end

  describe "player attack" do
    setup do
      state =
        State.new()
        |> State.spawn_player_locations(%{
          "me" => {2, 3},
          "a" => {1, 2},
          "b" => {1, 2},
          "c" => {2, 2},
          "d" => {2, 3},
          "e" => {3, 2},
          "f" => {3, 2},
          "g" => {3, 3},
          "z1" => {1, 4},
          "z2" => {1, 4},
          "z3" => {1, 4},
          "z4" => {1, 4},
          "z5" => {1, 4},
          "z6" => {1, 4},
          "z7" => {1, 4},
          "z8" => {1, 4},
          "z9" => {1, 4},
          "z10" => {1, 4},
          "out_of_reach_1" => {2, 5},
          "out_of_reach_2" => {8, 7}
        })

      %{state: state}
    end

    test "attacking kills all surrounding players, but no others", %{state: state} do
      assert_action(
        state,
        """
        ##########
        # 2 *    #
        # 1@ 1   #
        # 21     #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #      1 #
        ##########
        """,
        Attack.new("me"),
        """
        ##########
        # x x    #
        # x@ 1   #
        # xx     #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #      1 #
        ##########
        """
      )
    end

    test "attacking kills enemies on the same cell as the hero, but not the hero himself", %{
      state: state
    } do
      state =
        state
        |> State.apply_action(Attack.new("me"))
        |> State.coalesce()

      {alive, dead} =
        state
        |> Map.get({2, 3})
        |> Enum.split_with(fn {_player, status} -> status == :alive end)

      assert [{"me", :alive}] = alive
      assert Enum.count(dead) > 0
    end
  end
end
