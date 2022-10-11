defmodule Pluggable.StepBuilderTest do
  defmodule Module do
    import Pluggable.Token

    def init(val) do
      {:init, val}
    end

    def call(token, opts) do
      stack = [{:call, opts} | token.assigns[:stack]]
      assign(token, :stack, stack)
    end
  end

  defmodule Sample do
    use Pluggable.StepBuilder, copy_opts_to_assign: :stack

    step(:fun, :step1)
    step(Module, :step2)
    step(Module, :step3)

    def fun(token, opts) do
      stack = [{:fun, opts} | token.assigns[:stack]]
      assign(token, :stack, stack)
    end
  end

  defmodule Overridable do
    use Pluggable.StepBuilder

    def call(token, opts) do
      try do
        super(token, opts)
      catch
        :throw, {:not_found, token} -> assign(token, :not_found, :caught)
      end
    end

    step(:boom)

    def boom(token, _opts) do
      token = assign(token, :entered_stack, true)
      throw({:not_found, token})
    end
  end

  defmodule Halter do
    use Pluggable.StepBuilder

    step(:set_step, :first)
    step(:set_step, :second)
    step(:authorize)
    step(:set_step, :end_of_chain_reached)

    def set_step(token, step), do: assign(token, step, true)

    def authorize(token, _) do
      token
      |> assign(:authorize_reached, true)
      |> halt()
    end
  end

  defmodule FaultyModuleStep do
    defmodule FaultyStep do
      def init([]), do: []

      # Doesn't return a Pluggable.Token
      def call(_token, _opts), do: "foo"
    end

    use Pluggable.StepBuilder
    step(FaultyStep)
  end

  defmodule FaultyFunctionStep do
    use Pluggable.StepBuilder
    step(:faulty_function)

    # Doesn't return a Pluggable.Token
    def faulty_function(_token, _opts), do: "foo"
  end

  use ExUnit.Case, async: true

  test "exports the init/1 function" do
    assert Sample.init(:ok) == :ok
  end

  test "builds step stack in the order" do
    token = %TestToken{}

    assert Sample.call(token, []).assigns[:stack] == [
             call: {:init, :step3},
             call: {:init, :step2},
             fun: :step1
           ]

    assert Sample.call(token, [:initial]).assigns[:stack] == [
             {:call, {:init, :step3}},
             {:call, {:init, :step2}},
             {:fun, :step1},
             :initial
           ]
  end

  test "allows call/2 to be overridden with super" do
    token = Overridable.call(%TestToken{}, [])
    assert token.assigns[:not_found] == :caught
    assert token.assigns[:entered_stack] == true
  end

  test "halt/2 halts the step stack" do
    token = Halter.call(%TestToken{}, [])
    assert token.halted
    assert token.assigns[:first]
    assert token.assigns[:second]
    assert token.assigns[:authorize_reached]
    refute token.assigns[:end_of_chain_reached]
  end

  test "an exception is raised if a step doesn't return a stepection" do
    assert_raise RuntimeError, fn ->
      FaultyModuleStep.call(%TestToken{}, [])
    end

    assert_raise RuntimeError, fn ->
      FaultyFunctionStep.call(%TestToken{}, [])
    end
  end

  test "an exception is raised at compile time if a step with no call/2 function is plugged" do
    assert_raise ArgumentError, fn ->
      defmodule BadStep do
        defmodule Bad do
          def init(opts), do: opts
        end

        use Pluggable.StepBuilder
        step(Bad)
      end
    end
  end

  test "compile and runtime init modes" do
    {:ok, _agent} = Agent.start_link(fn -> :compile end, name: :plug_init)

    defmodule Assigner do
      use Pluggable.StepBuilder

      def init(agent), do: {:init, Agent.get(agent, & &1)}

      def call(token, opts), do: assign(token, :opts, opts)
    end

    defmodule CompileInit do
      use Pluggable.StepBuilder

      var = :plug_init
      step(Assigner, var)
    end

    defmodule RuntimeInit do
      use Pluggable.StepBuilder, init_mode: :runtime

      var = :plug_init
      step(Assigner, var)
    end

    :ok = Agent.update(:plug_init, fn :compile -> :runtime end)

    assert CompileInit.call(%TestToken{}, :plug_init).assigns.opts == {:init, :compile}
    assert RuntimeInit.call(%TestToken{}, :plug_init).assigns.opts == {:init, :runtime}
  end
end
