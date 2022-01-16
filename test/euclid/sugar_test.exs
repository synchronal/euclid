defmodule Euclid.SugarTest do
  use ExUnit.Case, async: true
  doctest Euclid.Sugar

  describe "error" do
    test "wraps the given term in an :error tuple" do
      assert Euclid.Sugar.error(1) == {:error, 1}
    end
  end

  describe "noreply" do
    test "wraps the given term in a :noreply tuple" do
      assert Euclid.Sugar.noreply(1) == {:noreply, 1}
    end
  end

  describe "ok" do
    test "wraps the given term in an :ok tuple" do
      assert Euclid.Sugar.ok(1) == {:ok, 1}
    end
  end

  describe "returning" do
    test "accepts two values and returns the second" do
      assert Euclid.Sugar.returning(1, 2) == 2
    end
  end
end
