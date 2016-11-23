defmodule Ecto.Mnesia.Record.Ordering do
  @moduledoc """
  Since there are `order by` function in Mnesia,
  we need to generate function that will order data after fetching it from DB.
  """
  require Logger

  @doc """
  This function generates the ordering function that will be applied on a query result.
  """
  def get_ordering_fn([]), do: &(&1)
  def get_ordering_fn(nil), do: &(&1)
  def get_ordering_fn(ordering) do
    fn data ->
      data
      |> Enum.sort(&sort(&1, &2, ordering))
    end
  end

  defp sort([left], [right], ordering) do
    cmp(left, right, join_exprs(ordering)) == :lt
  end

  defp join_exprs([%{expr: exprs1}, %{expr: exprs2} | t]) do
    join_exprs([%{expr: Keyword.merge(exprs1, exprs2)} | t])
  end
  defp join_exprs([%{expr: exprs1}]), do: exprs1

  defp cmp(left, right, [{:asc, {{:., [], [{:&, [], [0]}, field]}, _,_}} | t]) do
    case {Map.get(left, field), Map.get(right, field)} do
      {l, r} when l < r ->
        :lt
      {l, r} when l > r ->
        :gt
      _eq ->
        cmp(left, right, t)
    end
  end

  defp cmp(left, right, [{:desc, {{:., [], [{:&, [], [0]}, field]}, _,_}} | t]) do
    case {Map.get(left, field), Map.get(right, field)} do
      {l, r} when l < r ->
        :gt
      {l, r} when l > r ->
        :lt
      _eq ->
        cmp(left, right, t)
    end
  end
end