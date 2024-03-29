defmodule UpdateTest do
  use ExUnit.Case
  doctest Update
  
  test "parse" do
    assert_raise Error.ParseFailure, fn->Update.parse("()") end
    assert_raise Error.ParseFailure, fn->Update.parse("(ping)") end
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Ping{}}
    == Update.parse("(ping :id 0 :clock 0 :from \"\")")
    assert %Update{id: 0, clock: 0, from: "", type: %Update.Message{channel: "a", text: "b"}}
    == Update.parse("(message :id 0 :clock 0 :from \"\" :channel \"a\" :text \"b\")")
    assert %Update{id: 0, clock: 0, from: nil, type: %Update.Ping{}}
    == Update.parse("(ping :id 0 :clock 0 :foobar 0)")
    assert %Update{id: 0, clock: 0, from: nil, type: %Update.Ping{}}
    == Update.parse(Update.print(%Update{id: 0, clock: 0, from: nil, type: %Update.Ping{}}))
  end

  test "print" do
    assert "(ping :id 0 :clock 0 :from \"\")\n\0"
    == Update.print(%Update{id: 0, clock: 0, from: "", type: %Update.Ping{}})
    assert "(message :id 0 :clock 0 :from \"\" :channel \"a\" :text \"b\")\n\0"
    == Update.print(%Update{id: 0, clock: 0, from: "", type: %Update.Message{channel: "a", text: "b"}})
  end
end
