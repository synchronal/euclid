defmodule Euclid.Assertions do
  @moduledoc "Some ExUnit assertions"

  import ExUnit.Assertions

  @type assert_eq_opts() :: [returning: any()]

  @deprecated "Use `assert_eq(left, right, within: {delta, unit})` instead"
  def assert_datetime_approximate(left, right, delta \\ 1) do
    cond do
      NaiveDateTime.compare(right, NaiveDateTime.add(left, -delta, :second)) == :lt ->
        "Expected #{right} to be within #{delta} seconds of #{left}"
        |> flunk()

      NaiveDateTime.compare(right, NaiveDateTime.add(left, delta, :second)) == :gt ->
        "Expected #{right} to be within #{delta} seconds of #{left}"
        |> flunk()

      true ->
        left
    end
  end

  @doc """
  Asserts that the `left` and `right` values are equal. Returns the `left` value unless the assertion fails,
  or if the `:returning` option is used. Uses `assert left == right` under the hood, but works nicely in a pipeline.

  Options:

  * `ignore_order: boolean` - if the `left` and `right` values are lists, ignores the order when checking equality.
  * `returning: value` - returns `value` if the assertion passes, rather than returning the `left` value.
  * `within: delta` - asserts that the `left` and `right` values are within `delta` of each other rather than strictly equal.
  * `within: {delta, time_unit}` - like `within: delta` but performs time comparisons in the specified `time_unit`.
    If `left` and `right` are strings, they are parsed as ISO8601 dates.
  """
  @spec assert_eq(left :: any(), right :: any(), opts :: assert_eq_opts()) :: any()
  def assert_eq(left, right, opts \\ [])

  def assert_eq(left, right, opts) when is_list(left) and is_list(right) do
    {left, right} =
      if Keyword.get(opts, :ignore_order, false),
        do: {Enum.sort(left), Enum.sort(right)},
        else: {left, right}

    assert left == right
    returning(opts, left)
  end

  def assert_eq(string, %Regex{} = regex, opts) when is_binary(string) do
    unless string =~ regex do
      ExUnit.Assertions.flunk("""
        Expected string to match regex
        left (string): #{string}
        right (regex): #{regex |> inspect}
      """)
    end

    returning(opts, string)
  end

  def assert_eq(left, right, opts) do
    cond do
      Keyword.has_key?(opts, :within) ->
        assert_within(left, right, Keyword.get(opts, :within))

      is_map(left) and is_map(right) ->
        {filtered_left, filtered_right} = filter_map(left, right, Keyword.get(opts, :only, :all), Keyword.get(opts, :except, :none))
        assert filtered_left == filtered_right

      true ->
        assert left == right
    end

    returning(opts, left)
  end

  defp assert_within(left, right, {delta, unit}) do
    assert abs(Euclid.Difference.diff(left, right)) <= Euclid.Duration.convert({delta, unit}, :microsecond),
           ~s|Expected "#{left}" to be within #{Euclid.Duration.to_string({delta, unit})} of "#{right}"|
  end

  defp assert_within(left, right, delta) do
    assert abs(Euclid.Difference.diff(left, right)) <= delta,
           ~s|Expected "#{left}" to be within #{delta} of "#{right}"|
  end

  defp returning(opts, default) when is_list(opts),
    do: opts |> Keyword.get(:returning, default)

  defp filter_map(left, right, :all, :none), do: {left, right}
  defp filter_map(left, right, :right_keys, :none), do: filter_map(left, right, Map.keys(right), :none)
  defp filter_map(left, right, keys, :none) when is_list(keys), do: {Map.take(left, keys), Map.take(right, keys)}
  defp filter_map(left, right, :all, keys) when is_list(keys), do: {Map.drop(left, keys), Map.drop(right, keys)}

  @doc "Asserts that a `NaiveDateTime` or `DateTime` is no more than 30 seconds ago."
  def assert_recent(nil),
    do: flunk("Expected timestamp to be recent, but was nil")

  def assert_recent(%NaiveDateTime{} = timestamp) do
    timestamp = timestamp |> NaiveDateTime.truncate(:second)
    now = NaiveDateTime.local_now()

    cond do
      NaiveDateTime.compare(timestamp, NaiveDateTime.add(now, -30, :second)) == :lt ->
        "Expected #{timestamp} to be recent, but was older than 30 seconds ago (as of #{now})"
        |> flunk()

      NaiveDateTime.compare(timestamp, NaiveDateTime.add(now, 1, :second)) == :gt ->
        "Expected #{timestamp} to be recent, but was more than 1 second into the future (as of #{now})"
        |> flunk()

      true ->
        timestamp
    end
  end

  def assert_recent(%DateTime{} = timestamp) do
    timestamp = timestamp |> DateTime.truncate(:second)
    now = DateTime.utc_now()

    cond do
      DateTime.compare(timestamp, DateTime.add(now, -30, :second)) == :lt ->
        "Expected #{timestamp} to be recent, but was older than 30 seconds ago (as of #{now})"
        |> flunk()

      DateTime.compare(timestamp, DateTime.add(now, 1, :second)) == :gt ->
        "Expected #{timestamp} to be recent, but was more than 1 second into the future (as of #{now})"
        |> flunk()

      true ->
        timestamp
    end
  end

  def assert_recent(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, 0} ->
        assert_recent(datetime)

      {:error, reason} ->
        "Expected DateTime “#{datetime_string}” to be recent, but it wasn't a valid DateTime in ISO8601 format: #{inspect(reason)}"
        |> flunk()
    end
  end

  @doc """
  Asserts a pre-condition and a post-condition are true after performing an action.

  ## Examples

  ```
  {:ok, agent} = Agent.start(fn -> 0 end)

  assert_that(Agent.update(agent, fn s -> s + 1 end),
    changes: Agent.get(agent, fn s -> s end),
    from: 0,
    to: 1
  )
  ```
  """
  @spec assert_that(any, [{:changes, any} | {:from, any} | {:to, any}, ...]) :: {:__block__, [], [...]}
  defmacro assert_that(command, changes: check, from: from, to: to) do
    quote do
      try do
        assert unquote(check) == unquote(from)
      rescue
        error in ExUnit.AssertionError ->
          reraise %{error | message: "Pre-condition failed"}, __STACKTRACE__
      end

      unquote(command)

      try do
        assert unquote(check) == unquote(to)
      rescue
        error in ExUnit.AssertionError ->
          reraise %{error | message: "Post-condition failed"}, __STACKTRACE__
      end
    end
  end
end
