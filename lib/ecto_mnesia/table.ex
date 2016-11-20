defmodule Ecto.Mnesia.Table do
  @moduledoc """
  This module provides interface to perform CRUD and select operations on a Mnesia table.
  """
  alias :mnesia, as: Mnesia

  @doc """
  Insert a record into Mnesia table.
  """
  def insert(table, record, _opts \\ []) when is_tuple(record) do
    table = table |> get_name()
    transaction(fn ->
      _insert(table, record)
    end)
  end

  defp _insert(table, record) do
    case Mnesia.write(table, record, :write) do
      :ok -> {:ok, record}
      error -> {:error, error}
    end
  end

  @doc """
  Read record from Mnesia table.
  """
  def get(table, key, _opts \\ []) do
    table = table |> get_name()
    transaction(fn ->
      _get(table, key)
    end)
  end

  defp _get(table, key, lock \\ :read) do
    case Mnesia.read(table, key, lock) do
      [] -> nil
      [res] -> res
    end
  end

  @doc """
  Read record in Mnesia table by key.

  You can partially update records by replacing values that you don't want to touch with `nil` values.
  This function will automatically merge changes stored in Mnesia and update.
  """
  def update(table, key, record, _opts \\ []) when is_tuple(record) do
    table = table |> get_name()
    transaction(fn ->
      case _get(table, key, :write) do
        nil ->
          {:error, :not_found}
        stored_record ->
          _insert(table, merge_records(stored_record, record))
      end
    end)
  end

  defp merge_records(v1, v2) do
    v1 = Tuple.to_list(v1)
    v2 = Tuple.to_list(v2)

    {_i, merged} = v1
    |> Enum.reduce({0, []}, fn el, {i, acc} ->
      case Enum.at(v2, i) do
        nil -> {i + 1, acc ++ [el]}
        val -> {i + 1, acc ++ [val]}
      end
    end)

    merged
    |> List.to_tuple
  end

  @doc """
  Delete record from Mnesia table by key.
  """
  def delete(table, key, _opts \\ []) do
    table = table |> get_name()
    transaction(fn ->
      :ok = Mnesia.delete(table, key, :write)
      {:ok, key}
    end)
  end

  @doc """
  Select all records that match MatchSpec. You can limit result by passing third optional argument.
  """
  def select(table, match_spec, limit \\ nil)

  def select(table, match_spec, nil) do
    table = table |> get_name()
    transaction(fn ->
      Mnesia.select(table, match_spec, :read)
    end)
  end

  def select(table, match_spec, limit) do
    table = table |> get_name()
    transaction(fn ->
      {result, _context} = Mnesia.select(table, match_spec, limit, :read)
      result
    end)
  end

  @doc """
  Get count of records in a Mnesia table.
  """
  def count(table), do: table |> get_name() |> Mnesia.table_info(:size)

  @doc """
  Returns auto-incremented integer ID for table in Mnesia.

  Sequence auto-generation is implemented as `mnesia:dirty_update_counter`.
  """
  def next_id(table, inc \\ 1)
  def next_id(table, inc) when is_binary(table), do: table |> get_name() |> next_id(inc)
  def next_id(table, inc) when is_atom(table), do: Mnesia.dirty_update_counter({:id_seq, table}, inc)

  @doc """
  Run function `fun` inside a Mnesia transaction with specific context.

  By default, context is `:async_dirty`.
  """
  def transaction(fun, context \\ :async_dirty) do
    try do
      case Mnesia.activity(context, fun) do
        {:aborted, error} -> {:error, error}
        {:atomic, r} -> r
        x -> x
      end
    catch
      :exit, {:aborted, {:no_exists, [schema, _id]}} -> raise RuntimeError, "Schema #{inspect schema} does not exist"
      :exit, {:aborted, reason} -> {:error, reason}
      :exit, reason -> {:error, reason}
    end
  end

  @doc """
  Get the first key in the table, see `mnesia:first`.
  """
  @spec first(atom) :: any | nil | no_return
  def first(table) do
    table = table |> get_name()
    case Mnesia.first(table) do
      :'$end_of_table' -> nil
      value -> value
    end
  end

  @doc """
  Get the next key in the table starting from the given key, see `mnesia:next`.
  """
  @spec next(atom, any) :: any | nil | no_return
  def next(table, key) do
    table = table |> get_name()
    case Mnesia.next(table, key) do
      :'$end_of_table' -> nil
      value -> value
    end
  end

  @doc """
  Get the previous key in the table starting from the given key, see
  `mnesia:prev`.
  """
  @spec prev(atom, any) :: any | nil | no_return
  def prev(table, key) do
    table = table |> get_name()
    case Mnesia.prev(table, key) do
      :'$end_of_table' -> nil
      value -> value
    end
  end

  @doc """
  Get the last key in the table, see `mnesia:last`.
  """
  @spec last(atom) :: any | nil | no_return
  def last(table) do
    table = table |> get_name()
    case Mnesia.last(table) do
      :'$end_of_table' -> nil
      value -> value
    end
  end

  @doc """
  Get Mnesia table name by binary or atom representation.
  """
  def get_name(table) when is_atom(table), do: table
  def get_name(table) when is_binary(table), do: table |> String.to_atom()
end