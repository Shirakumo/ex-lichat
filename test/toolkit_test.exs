defmodule ToolkitTest do
  use ExUnit.Case
  doctest Toolkit

  test "valid usernames" do
    assert true == Toolkit.valid_name?("a")
    assert false == Toolkit.valid_name?("abcdefghijklmnopqrstuvwxyz0123456789")
    assert false == Toolkit.valid_name?(" a")
    assert false == Toolkit.valid_name?("b ")
    assert true == Toolkit.valid_name?("b a")
    assert false == Toolkit.valid_name?("b\nb")
    assert false == Toolkit.valid_name?("\0")
  end
end
