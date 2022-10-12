defmodule TestToken do
  @moduledoc false
  @derive Pluggable.Token

  defstruct halted: false, assigns: %{}, data: %{}
end
