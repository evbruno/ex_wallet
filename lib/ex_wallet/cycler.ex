defmodule ExWallet.Cycler do
  use Agent

  def start_link(name, elements) do
    Agent.start_link(
      fn -> %{elements: elements, current: 0, name: name} end,
      name: name_for(name)
    )
  end

  defp name_for(name), do: :"#{__MODULE__}_#{name}"

  def next(name) do
    Agent.get_and_update(name_for(name), fn %{elements: elements, current: current} = state ->
      current_element = Enum.at(elements, current)
      next = rem(current + 1, length(elements))
      {current_element, %{state | current: next}}
    end)
  end
end
