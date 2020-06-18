defmodule UpdateTest do
  use ExUnit.Case
  doctest Update
  
  test "from list" do
    assert_raise RuntimeError, fn->Update.parse("()") end
    assert_raise RuntimeError, fn->Update.parse("(ping)") end
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Ping{}}
    == Update.parse("(ping :id 0 :clock 0 :from \"\")")
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Message{channel: "a", text: "b"}}
    == Update.parse("(message :id 0 :clock 0 :from \"\" :channel \"a\" :text \"b\")")
  end
end
