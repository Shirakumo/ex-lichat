defmodule Backlog do
  defstruct elements: {}, index: 0, size: 0

  def new(size) do
    %Backlog{elements: Tuple.duplicate(nil, size), index: 0, size: size}
  end

  def push(backlog, update) do
    %{backlog |
      elements: Tuple.insert_at(backlog.elements, backlog.index, update),
      index: rem(1+backlog.index, backlog.size)}
  end

  def each(backlog, func) do
    start = rem(backlog.size+backlog.index-1, backlog.size)
    Stream.concat(start..0, backlog.size-1..start)
    |> Stream.take_while(fn i ->
      update = elem(backlog.elements, i)
      update != nil and func.(update)
    end)
    |> Stream.run()
  end
end
