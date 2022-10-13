defmodule Pluggable.StepBuilder do
  @moduledoc """
  Conveniences for building pipelines.

      defmodule MyApp do
        use Pluggable.StepBuilder

        step SomeLibrary.Logger
        step :hello, upper: true

        # A function from another module can be plugged too, provided it's
        # imported into the current module first.
        import AnotherModule, only: [interesting_step: 2]
        step :interesting_step

        def hello(token, opts) do
          body = if opts[:upper], do: "WORLD", else: "world"
          send_resp(token, 200, body)
        end
      end

  Multiple steps can be defined with the `step/2` macro, forming a pipeline.
  The steps in the pipeline will be executed in the order they've been added
  through the `step/2` macro. In the example above, `SomeLibrary.Logger` will
  be called first and then the `:hello` function step will be called on the
  resulting token.

  ## Options

  When used, the following options are accepted by `Pluggable.StepBuilder`:

    * `:init_mode` - the environment to initialize the step's options, one of
      `:compile` or `:runtime`. Defaults `:compile`.

    * `:log_on_halt` - accepts the level to log whenever the request is halted

    * `:copy_opts_to_assign` - an `atom` representing an assign. When supplied,
      it will copy the options given to the Step initialization to the given
      token assign

  ## step behaviour

  Internally, `Pluggable.StepBuilder` implements the `Pluggable` behaviour, which
  means both the `init/1` and `call/2` functions are defined.

  By implementing the Pluggable API, `Pluggable.StepBuilder` guarantees this module
  is a  pluggable step and can be run via `Pluggable.run/3` or used as part of
  another pipeline.

  ## Overriding the default Pluggable API functions

  Both the `init/1` and `call/2` functions defined by `Pluggable.StepBuilder` can
  be manually overridden. For example, the `init/1` function provided by
  `Pluggable.StepBuilder` returns the options that it receives as an argument, but
  its behaviour can be customized:

      defmodule StepWithCustomOptions do
        use Pluggable.StepBuilder
        step SomeLibrary.Logger

        def init(opts) do
          opts
        end
      end

  The `call/2` function that `Pluggable.StepBuilder` provides is used internally to
  execute all the steps listed using the `step` macro, so overriding the
  `call/2` function generally implies using `super` in order to still call the
  step chain:

      defmodule StepWithCustomCall do
        use Pluggable.StepBuilder
        step SomeLibrary.Logger
        step SomeLibrary.AddMeta

        def call(token, opts) do
          token
          |> super(opts) # calls SomeLibrary.Logger and SomeLibrary.AddMeta
          |> assign(:called_all_steps, true)
        end
      end

  ## Halting a pluggable step pipeline

  A pluggable step pipeline can be halted with `Pluggable.Token.halt/1`. The builder
  will prevent further steps downstream from being invoked and return the
  current token. In the following example, the `SomeLibrary.Logger` step never
  gets called:

      defmodule StepUsingHalt do
        use Pluggable.StepBuilder

        step :stopper
        step SomeLibrary.Logger

        def stopper(token, _opts) do
          halt(token)
        end
      end
  """

  @type step :: module | atom

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Pluggable
      @pluggable_builder_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(token, opts) do
        pluggable_builder_call(token, opts)
      end

      defoverridable Pluggable

      import Pluggable.Token
      import Pluggable.StepBuilder, only: [step: 1, step: 2]

      Module.register_attribute(__MODULE__, :steps, accumulate: true)
      @before_compile Pluggable.StepBuilder
    end
  end

  @spec __before_compile__(Macro.Env.t()) :: {:__block__, [], maybe_improper_list}
  @doc false
  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :steps)
    builder_opts = Module.get_attribute(env.module, :pluggable_builder_opts)
    {token, body} = Pluggable.StepBuilder.compile(env, steps, builder_opts)

    compile_time =
      if builder_opts[:init_mode] == :runtime do
        []
      else
        for triplet <- steps,
            {step, _, _} = triplet,
            module_step?(step) do
          quote(do: unquote(step).__info__(:module))
        end
      end

    pluggable_builder_call =
      if assign = builder_opts[:copy_opts_to_assign] do
        quote do
          defp pluggable_builder_call(token, opts) do
            unquote(token) = Pluggable.Token.assign(token, unquote(assign), opts)
            unquote(body)
          end
        end
      else
        quote do
          defp pluggable_builder_call(unquote(token), opts), do: unquote(body)
        end
      end

    quote do
      unquote_splicing(compile_time)
      unquote(pluggable_builder_call)
    end
  end

  @doc """
  A macro that stores a new step. `opts` will be passed unchanged to the new
  step.

  This macro doesn't add any guards when adding the new step to the pipeline;
  for more information about adding steps with guards see `compile/3`.

  ## Examples

      step SomeLibrary.Logger               # step module
      step :foo, some_options: true  # step function

  """
  defmacro step(step, opts \\ []) do
    # We always expand it but the @before_compile callback adds compile
    # time dependencies back depending on the builder's init mode.
    step = expand_alias(step, __CALLER__)

    # If we are sure we don't have a module step, the options are all
    # runtime options too.
    opts =
      if is_atom(step) and not module_step?(step) and Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote do
      @steps {unquote(step), unquote(opts), true}
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  @doc """
  Compiles a pluggable step pipeline.

  Each element of the pluggable step pipeline (according to the type signature of this
  function) has the form:

      {step_name, options, guards}

  Note that this function expects a reversed pipeline (with the last step that
  has to be called coming first in the pipeline).

  The function returns a tuple with the first element being a quoted reference
  to the token and the second element being the compiled quoted pipeline.

  ## Examples

      Pluggable.StepBuilder.compile(env, [
        {SomeLibrary.Logger, [], true}, # no guards, as added by the Pluggable.StepBuilder.step/2 macro
        {SomeLibrary.AddMeta, [], quote(do: a when is_binary(a))}
      ], [])

  """
  @spec compile(Macro.Env.t(), [{step, Pluggable.opts(), Macro.t()}], Keyword.t()) ::
          {Macro.t(), Macro.t()}
  def compile(env, pipeline, builder_opts) do
    token = quote do: token
    init_mode = builder_opts[:init_mode] || :compile

    unless init_mode in [:compile, :runtime] do
      raise ArgumentError, """
      invalid :init_mode when compiling #{inspect(env.module)}.

      Supported values include :compile or :runtime. Got: #{inspect(init_mode)}
      """
    end

    ast =
      Enum.reduce(pipeline, token, fn {step, opts, guards}, acc ->
        {step, opts, guards}
        |> init_step(init_mode)
        |> quote_step(init_mode, acc, env, builder_opts)
      end)

    {token, ast}
  end

  defp module_step?(step), do: match?(~c"Elixir." ++ _, Atom.to_charlist(step))

  # Initializes the options of a step in the configured init_mode.
  defp init_step({step, opts, guards}, init_mode) do
    if module_step?(step) do
      init_module_step(step, opts, guards, init_mode)
    else
      init_fun_step(step, opts, guards)
    end
  end

  defp init_module_step(step, opts, guards, :compile) do
    initialized_opts = step.init(opts)

    if function_exported?(step, :call, 2) do
      {:module, step, escape(initialized_opts), guards}
    else
      raise ArgumentError, "#{inspect(step)} step must implement call/2"
    end
  end

  defp init_module_step(step, opts, guards, :runtime) do
    {:module, step, quote(do: unquote(step).init(unquote(escape(opts)))), guards}
  end

  defp init_fun_step(step, opts, guards) do
    {:function, step, escape(opts), guards}
  end

  defp escape(opts) do
    Macro.escape(opts, unquote: true)
  end

  defp quote_step({:module, step, opts, guards}, :compile, acc, env, builder_opts) do
    # require no longer adds a compile time dependency, which is
    # required by stepgable.Builder. So we build the alias an we expand it.
    parts = [:"Elixir" | Enum.map(Module.split(step), &String.to_atom/1)]
    alias = {:__aliases__, [line: env.line], parts}
    _ = Macro.expand(alias, env)

    quote_step(:module, step, opts, guards, acc, env, builder_opts)
  end

  defp quote_step({step_type, step, opts, guards}, _init_mode, acc, env, builder_opts) do
    quote_step(step_type, step, opts, guards, acc, env, builder_opts)
  end

  # `acc` is a series of nested step calls in the form of step3(step2(step1(token))).
  # `quote_step` wraps a new step around that series of calls.
  defp quote_step(step_type, step, opts, guards, acc, env, builder_opts) do
    call = quote_step_call(step_type, step, opts)

    error_message =
      case step_type do
        :module -> "expected #{inspect(step)}.call/2 to return a Pluggable.Token"
        :function -> "expected #{step}/2 to return a Pluggable.Token"
      end <> ", all steps must receive a token and return a token"

    quote generated: true do
      token = unquote(compile_guards(call, guards))

      if !Pluggable.Token.impl_for(token),
        do: raise(unquote(error_message) <> ", got: #{inspect(token)}")

      if Pluggable.Token.halted?(token) do
        unquote(log_halt(step_type, step, env, builder_opts))
        token
      else
        unquote(acc)
      end
    end
  end

  defp quote_step_call(:function, step, opts) do
    quote do: unquote(step)(token, unquote(opts))
  end

  defp quote_step_call(:module, step, opts) do
    quote do: unquote(step).call(token, unquote(opts))
  end

  defp compile_guards(call, true) do
    call
  end

  defp compile_guards(call, guards) do
    quote do
      case true do
        true when unquote(guards) -> unquote(call)
        true -> token
      end
    end
  end

  defp log_halt(step_type, step, env, builder_opts) do
    if level = builder_opts[:log_on_halt] do
      message =
        case step_type do
          :module -> "#{inspect(env.module)} halted in #{inspect(step)}.call/2"
          :function -> "#{inspect(env.module)} halted in #{inspect(step)}/2"
        end

      quote do
        require Logger
        # Matching, to make Dialyzer happy on code executing Pluggable.StepBuilder.compile/3
        _ = Logger.unquote(level)(unquote(message))
      end
    else
      nil
    end
  end
end
