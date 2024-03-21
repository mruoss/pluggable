defmodule Pluggable.PipelineBuilderTest do
  use ExUnit.Case, async: true

  defmodule Module do
    import Pluggable.Token

    def init(val) do
      {:init, val}
    end

    def call(token, opts) do
      stack = [{:call, opts} | List.wrap(token.assigns[:stack])]
      assign(token, :stack, stack)
    end
  end

  defmodule Pipeline do
    use Pluggable.PipelineBuilder

    pipeline :foo do
      step Module, :step2
      step Module, :step3
    end
  end

  defmodule Foo do
    def foo(x, y), do: x + y
  end

  test "runs the pipeline" do
    assert Pluggable.run(%TestToken{}, [&Pipeline.foo(&1, [])]).assigns[:stack] == [
             call: {:init, :step3},
             call: {:init, :step2}
           ]
  end

  test "raises" do
    assert_raise(
      ArgumentError,
      "cannot define pipeline named :foo because there is an import from Pluggable.PipelineBuilderTest.Foo with the same name",
      fn ->
        defmodule FaultyPipeline do
          use Pluggable.PipelineBuilder

          import Foo

          pipeline :foo do
            step Module, :step2
            step Module, :step3
          end
        end
      end
    )
  end
end
