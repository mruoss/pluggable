defmodule Pluggable.TokenTest do
  use ExUnit.Case, async: true
  alias Pluggable.Token, as: MUT

  test "raises if required keys don't exists" do
    assert_raise ArgumentError, fn ->
      Code.eval_file("test/pluggable/token/no_halted.exs")
    end

    assert_raise ArgumentError, fn ->
      Code.eval_file("test/pluggable/token/no_assigns.exs")
    end
  end
end
