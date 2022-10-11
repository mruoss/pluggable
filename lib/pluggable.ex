defmodule Pluggable do
  @moduledoc """
  The step specification.

  There are two kind of steps: function steps and module steps.

  #### Function steps

  A function step is any function that receives a token and a set of
  options and returns a token. Its type signature must be:

      (Pluggable.Token.t, Pluggable.opts) :: Pluggable.Token.t

  #### Module steps

  A module step is an extension of the function step. It is a module that must
  export:

    * a `c:call/2` function with the signature defined above
    * an `c:init/1` function which takes a set of options and initializes it.

  The result returned by `c:init/1` is passed as second argument to `c:call/2`. Note
  that `c:init/1` may be called during compilation and as such it must not return
  pids, ports or values that are specific to the runtime.

  The API expected by a module step is defined as a behaviour by the
  `Pluggable` module (this module).

  ## Examples

  Here's an example of a function step:

      def json_header_step(token, _opts) do
        My.Token.put_data(token, "some_data")
      end

  Here's an example of a module step:

      defmodule PutSomeData do
        def init(opts) do
          opts
        end

        def call(token, _opts) do
          My.Token.put_data(token, "some_data")
        end
      end

  ## The Pluggable Step pipeline

  The `Pluggable.StepBuilder` module provides conveniences for building
  pluggable step pipelines.
  """

  @type opts ::
          binary
          | tuple
          | atom
          | integer
          | float
          | [opts]
          | %{optional(opts) => opts}
          | MapSet.t()

  @callback init(opts) :: opts
  @callback call(token :: Pluggable.Token.t(), opts) :: Pluggable.Token.t()

  require Logger

  @doc """
  Run a series of pluggable steps at runtime.

  The steps given here can be either a tuple, representing a module step
  and their options, or a simple function that receives a token and
  returns a token.

  If any of the steps halt, the remaining steps are not invoked. If the
  given token was already halted, none of the steps are invoked
  either.

  While `Pluggable.StepBuilder` works at compile-time, this is a
  straight-forward alternative that works at runtime.

  ## Examples

      Pluggable.run(token, [{My.Step, []}, &IO.inspect/1])

  ## Options

    * `:log_on_halt` - a log level to be used if a pipeline halts

  """
  @spec run(
          Pluggable.Token.t(),
          [{module, opts} | (Pluggable.Token.t() -> Pluggable.Token.t())],
          Keyword.t()
        ) ::
          Pluggable.Token.t()
  def run(token, steps, opts \\ []) do
    if Pluggable.Token.halted?(token),
      do: token,
      else: do_run(token, steps, Keyword.get(opts, :log_on_halt))
  end

  defp do_run(token, [{mod, opts} | steps], level) when is_atom(mod) do
    next_token = mod.call(token, mod.init(opts))

    if !Pluggable.Token.impl_for(next_token),
      do: raise("expected #{inspect(mod)} to return Pluggable.Token, got: #{inspect(next_token)}")

    if Pluggable.Token.halted?(next_token) do
      level && Logger.log(level, "Pluggable pipeline halted in #{inspect(mod)}.call/2")
      next_token
    else
      do_run(next_token, steps, level)
    end
  end

  defp do_run(token, [fun | steps], level) when is_function(fun, 1) do
    next_token = fun.(token)

    if !Pluggable.Token.impl_for(next_token),
      do: raise("expected #{inspect(fun)} to return Pluggable.Token, got: #{inspect(next_token)}")

    if Pluggable.Token.halted?(next_token) do
      level && Logger.log(level, "Pluggable pipeline halted in #{inspect(fun)}")
      next_token
    else
      do_run(next_token, steps, level)
    end
  end

  defp do_run(token, [], _level), do: token
end
