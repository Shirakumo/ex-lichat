defmodule ProfileTest do
  use ExUnit.Case, async: true
  doctest Profile

  test "maintain profiles" do
    assert Profile.lookup("tester") == :not_registered
    assert Profile.check("tester", "foo") == :not_registered

    Profile.register("tester", "foo")
    assert Profile.lookup("tester") == :ok
    assert Profile.check("tester", "foo") == :ok
    assert Profile.check("tester", "bar") == :bad_password
    
    Profile.register("tester", "bar")
    assert Profile.check("tester", "bar") == :ok
  end
end
