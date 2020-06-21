defmodule UpdateTest do
  use ExUnit.Case
  doctest Update
  
  test "parse" do
    assert_raise RuntimeError, fn->Update.parse("()") end
    assert_raise RuntimeError, fn->Update.parse("(ping)") end
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Ping{}}
    == Update.parse("(ping :id 0 :clock 0 :from \"\")")
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Message{channel: "a", text: "b"}}
    == Update.parse("(message :id 0 :clock 0 :from \"\" :channel \"a\" :text \"b\")")
  end

  test "print" do
    assert "(ping :id 0 :clock 0 :from \"\")\0"
    == Update.print(%Update{id: 0, clock: 0, from: "", type: %Update.Ping{}})
    assert "(message :id 0 :clock 0 :from \"\" :channel \"a\" :text \"b\")\0"
    == Update.print(%Update{id: 0, clock: 0, from: "", type: %Update.Message{channel: "a", text: "b"}})
  end
end
