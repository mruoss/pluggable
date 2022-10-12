defprotocol Pluggable.Token do
  @moduledoc """
  Token protocol to be used with the `Pluggable` and `Pluggable.Builder` modules.

  When implementing pipelines using this library, a token holds the state and is
  passed on from step to step within the pipeline.

  ## Deriving Pluggable.Token

  The simplest way to use this library is to define a token module which derives
  `Pluggable.Token` and defines a struct which, among others defines the keys:

   * `:halted` - the boolean status on whether the pipeline was halted
   * `:assigns` - shared user data as a map

   Example:

      defmodule MyPipeline.Token do
        @derive Pluggable.Token
        defstruct [
          halted: false,
          assigns: %{},
          # other state
        ]
      end

  If the fields holding these two states are named differently, pass the fields
  as options to `@derive`:

      defmodule MyPipeline.Token do
        @derive {Pluggable.Token, halted_key: :stopped, assigns_key: :shared_state}
        defstruct [
          stopped: false,
          shared_state: %{},
          # other state
        ]
      end

  ## Implementing Pluggable.Token

  `Pluggable.Token` can be implemented. The following is the default implementation
  when deriving `Pluggable.Token`

      defmodule MyPipeline.Token do
        defstruct [
          halted: nil,
          assigns: %{},
          # other state
        ]
      end

      defimpl Pluggable.Token, for: MyPipeline.Token do
        def halted?(token), do: token.halted

        def halt(token), do: %{token | halted: true}

        def assign(%MyPipeline.Token{assigns: assigns} = token, key, value) when is_atom(key) do
          %{token | assigns: Map.put(assigns, key, value)}
        end
      end
  """

  @doc """
  Returns the boolean status on whether the pipeline was halted
  """
  @spec halted?(t()) :: boolean()
  def halted?(token)

  @doc """
  Halts the Pluggable pipeline by preventing further steps downstream from being
  invoked. See the docs for `Pluggable.Builder` for more information on halting a
  Pluggable pipeline.
  """
  @spec halt(t()) :: t()
  def halt(token)

  @doc """
  Assigns a value to a key in the shared user data map.
  """
  @spec assign(t(), atom(), term()) :: t()
  def assign(token, key, value)
end

defimpl Pluggable.Token, for: Any do
  defmacro __deriving__(module, struct, options) do
    halted_key = Keyword.get(options, :halted_key, :halted)
    assigns_key = Keyword.get(options, :assigns_key, :assigns)

    if !Map.has_key?(struct, halted_key),
      do:
        raise(ArgumentError,
          message:
            "Key #{inspect(halted_key)} does not exist in struct #{inspect(struct)}. Please define a key describing the :halted state."
        )

    if !Map.has_key?(struct, assigns_key),
      do:
        raise(ArgumentError,
          message:
            "Key #{inspect(assigns_key)} does not exist in struct #{inspect(struct)}. Please define a key holding assigns."
        )

    quote do
      defimpl Pluggable.Token, for: unquote(module) do
        def halted?(token), do: token.unquote(halted_key)

        def halt(token), do: %{token | unquote(halted_key) => true}

        def assign(%module{unquote(assigns_key) => assigns} = token, key, value)
            when is_atom(key) do
          %{token | unquote(assigns_key) => Map.put(assigns, key, value)}
        end
      end
    end
  end

  # coveralls-ignore-start No logic to test
  def halted?(_token), do: false
  def halt(token), do: token
  def assign(token, _key, _value), do: token
  # coveralls-ignore-stop
end
