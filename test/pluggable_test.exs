defmodule PluggableTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  #  Module under Test
  alias Pluggable, as: MUT

  defmodule Halter do
    def init(:opts), do: :inited
    def call(token, :inited), do: %{token | halted: true}
  end

  defmodule NotStep do
    def init(:opts), do: :inited
    def call(_token, :inited), do: %{}
  end

  defmodule Test.Step.AddFooToData do
    def init(opts), do: opts

    def call(%TestToken{data: data} = token, opts),
      do: %{token | data: Map.put(data, :foo, Keyword.get(opts, :value, :bar))}
  end

  def add_bar_to_data(%TestToken{data: data} = token, opts),
    do: %{token | data: Map.put(data, :bar, Keyword.get(opts, :value, :foo))}

  describe "run" do
    test "invokes steps" do
      token = MUT.run(%TestToken{}, [{Test.Step.AddFooToData, []}])
      assert token.data == %{foo: :bar}

      token =
        MUT.run(%TestToken{}, [{Test.Step.AddFooToData, []}, &add_bar_to_data(&1, value: :bar)])

      assert token.data == %{foo: :bar, bar: :bar}
    end

    test "does not invoke stepss if halted" do
      token = MUT.run(%{%TestToken{} | halted: true}, [&raise(inspect(&1))])
      assert token.halted
    end

    test "aborts if step halts" do
      token = MUT.run(%TestToken{}, [&%{&1 | halted: true}, &raise(inspect(&1))])
      assert token.halted
    end

    test "logs when halting" do
      assert capture_log(fn ->
               assert MUT.run(%TestToken{}, [{Halter, :opts}], log_on_halt: :error).halted
             end) =~ "[error] Pluggable pipeline halted in PluggableTest.Halter.call/2"

      halter = &%{&1 | halted: true}

      assert capture_log(fn ->
               assert MUT.run(%TestToken{}, [halter], log_on_halt: :error).halted
             end) =~ "[error] Pluggable pipeline halted in #{inspect(halter)}"
    end

    test "raise exception with invalid return" do
      msg = "expected PluggableTest.NotStep to return Pluggable.Token, got: %{}"

      assert_raise RuntimeError, msg, fn ->
        MUT.run(%TestToken{}, [{NotStep, :opts}])
      end

      not_step = fn _ -> %{} end
      msg = ~r/expected #Function.* to return Pluggable.Token, got: %{}/

      assert_raise RuntimeError, msg, fn ->
        MUT.run(%TestToken{}, [not_step])
      end
    end
  end
end
