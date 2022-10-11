defmodule TestToken do
  @derive Pluggable.Token

  defstruct halted: false, assigns: %{}, data: %{}
end
