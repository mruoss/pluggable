# Pluggable

[![Module Version](https://img.shields.io/hexpm/v/pluggable.svg)](https://hex.pm/packages/pluggable)
[![Coverage Status](https://coveralls.io/repos/github/mruoss/pluggable/badge.svg?branch=main)](https://coveralls.io/github/mruoss/pluggable?branch=main)
[![Last Updated](https://img.shields.io/github/last-commit/mruoss/pluggable.svg)](https://github.com/mruoss/pluggable/commits/main)

[![Build Status CI](https://github.com/mruoss/pluggable/actions/workflows/ci.yaml/badge.svg)](https://github.com/mruoss/pluggable/actions/workflows/ci.yaml)
[![Build Status Elixir](https://github.com/mruoss/pluggable/actions/workflows/elixir_matrix.yaml/badge.svg)](https://github.com/mruoss/pluggable/actions/workflows/elixir_matrix.yaml)

[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/pluggable/)
[![Total Download](https://img.shields.io/hexpm/dt/pluggable.svg)](https://hex.pm/packages/pluggable)
[![License](https://img.shields.io/hexpm/l/pluggable.svg)](https://github.com/mruoss/pluggable/blob/main/LICENSE)

Pluggable helps to define `Plug` like pipelines but with arbitrary tokens.
The library comes with almost exact copies of the module `Plug` and
`Plug.Builder`. However, instead of passing around a `%Plug.Conn{}` struct,
this library passes around a Token you define in your project.

## Credits

Most of the code in this module was copied from the
[`:plug`](https://github.com/elixir-plug/plug/) library so credits go to the
creators and maintainers of `:plug`.

## Installation

The package can be installed by adding `pluggable` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:pluggable, "~> 1.0"}
  ]
end
```

## Usage

To use this library, you first have to define your token. Once that
is done, use `Pluggable.StepBuilder` to build steps and pipelines.

### Deriving Pluggable.Token

The easiest way to define a token is to create a module which derives
`Pluggable.Token` and defines a struct which, among others defines the keys:

- `:halted` - the boolean status on whether the pipeline was halted
- `:assigns` - shared user data as a map

Example:

```elixir
defmodule MyPipeline.Token do
  @derive Pluggable.Token
  defstruct [
    halted: false,
    assigns: %{},
    # other state
  ]
end
```

If the fields holding these two states are named differently, pass the fields
as options to `@derive`:

```elixir
defmodule MyPipeline.Token do
  @derive {Pluggable.Token, halted_key: :stopped, assigns_key: :shared_state}
  defstruct [
    stopped: false,
    shared_state: %{},
    # other state
  ]
end
```

### Implementing Pluggable.Token

`Pluggable.Token` can be implemented. The following is the default implementation
when deriving `Pluggable.Token`

```elixir
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
```

## Building Pipelines

`Pluggable.StepBuilder` works just like `Plug.Builder`. See the
module documentation for instructions.

## Code Formatting

When using the `Pluggable.StepBuilder`, you might want to format the usage
of the `step` macro without parens. To configure the formatter not to add
parens, add this to your `.formatter.exs`:

```elixir
# .formatter.exs
[
  import_deps: [:pluggable]
]
```
