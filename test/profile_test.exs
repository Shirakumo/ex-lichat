defmodule ProfileTest do
  use ExUnit.Case, async: true
  doctest Profile
  
  setup do
    {:ok, profiles} = Profile.start_link([])
    %{profiles: profiles}
  end

  test "maintain profiles", %{profiles: profiles} do
    assert Profile.lookup(profiles, "tester") == :not_registered
    assert Profile.check(profiles, "tester", "foo") == :not_registered

    Profile.register(profiles, %Profile{name: "tester", password: "foo"})
    assert {:ok, _profile} = Profile.lookup(profiles, "tester")
    assert Profile.check(profiles, "tester", "foo") == :ok
    assert Profile.check(profiles, "tester", "bar") == :bad_password
    
    Profile.register(profiles, %Profile{name: "tester", password: "bar"})
    assert Profile.check(profiles, "tester", "bar") == :ok
  end
end
