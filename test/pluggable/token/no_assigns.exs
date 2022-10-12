defmodule Pluggable.TokenTestTokenNoAssigns do
  @derive Pluggable.Token

  defstruct halted: false
end
