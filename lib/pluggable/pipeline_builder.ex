defmodule Pluggable.PipelineBuilder do
  @moduledoc """
  Build pluggable steps as pipelines of other steps. Use this only if you need
  to define and run multiple distinct pipelines in the same module.

  ## Examples
      defmodule MyPipeline do
        pipeline :foo do
          plug SomePluggableStep
          plug :inline_step
        end

        pipeline :bar do
          plug AnotherPluggableStep
          plug :inline_step
        end
      end

  These pipelines can be run from within the same module:

      Pluggable.run(token, [&foo(&1, [])])
      Pluggable.run(another_token, [&bar(&1, [])])

  Or they can be run from outside

      Pluggable.run(token, [&MyPipeline.foo(&1, [])])
      Pluggable.run(another_token, [&MyPipeline.bar(&1, [])])
  """

  defmacro __using__(_opts) do
    quote do
      @pluggable_pipeline nil

      import Pluggable.Token
      import Pluggable.PipelineBuilder, only: [step: 1, step: 2, pipeline: 2]
    end
  end

  @doc """
  Defines a step inside a pipeline.

  See module doc for more information.
  """
  defmacro step(step, opts \\ []) do
    quote do
      if pipeline = @pluggable_pipeline do
        @pluggable_pipeline [{unquote(step), unquote(opts), true} | pipeline]
      else
        raise "cannot define step at the PipelineBuilder level, step must be defined inside a pipeline"
      end
    end
  end

  @doc """
  Defines a pluggable step as a pipeline of other steps.

  See module doc for more information.
  """
  defmacro pipeline(step, do: block) do
    with true <- is_atom(step),
         imports = __CALLER__.macros ++ __CALLER__.functions,
         {mod, _} <- Enum.find(imports, fn {_, imports} -> {step, 2} in imports end) do
      raise ArgumentError,
            "cannot define pipeline named #{inspect(step)} " <>
              "because there is an import from #{inspect(mod)} with the same name"
    end

    block =
      quote do
        step = unquote(step)
        @pluggable_pipeline []
        unquote(block)
      end

    compiler =
      quote unquote: false do
        {token, body} = Pluggable.StepBuilder.compile(__ENV__, @pluggable_pipeline, [])

        def unquote(step)(unquote(token), _), do: unquote(body)

        @pluggable_pipeline nil
      end

    quote do
      try do
        unquote(block)
        unquote(compiler)
      after
        :ok
      end
    end
  end
end
