defmodule MMO.Board.SerializationTest do
  use ExUnit.Case, async: true
  doctest MMO.Board.Serialization

  alias MMO.Board.Serialization

  @board_string """
  ##########
  #        #
  #        #
  #        #
  ## ####  #
  #   #    #
  #   #    #
  #   #    #
  #        #
  ##########
  """

  test "serialization" do
    with {:ok, fields} <- Serialization.from_string(@board_string) do
      actual =
        fields
        |> Keyword.fetch!(:cells)
        |> Serialization.to_string()

      assert actual == @board_string
    end
  end
end
