setup_demo = fn ->
  MMO.new("game")

  sessions =
    1..20
    |> Enum.reduce(%{}, fn x, acc ->
      {:ok, pid} = MMO.start_link("game", Integer.to_string(x))
      Map.put(acc, x, pid)
    end)

  {:ok, me} = MMO.start_link("game", "me")
  MMO.puts(me)
  {me, sessions}
end
