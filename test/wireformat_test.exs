defmodule WireFormatTest do
  use ExUnit.Case
  doctest WireFormat

  test "symbol parse" do
    assert {:ok, %Symbol{name: "a", package: :keyword}} = WireFormat.parse1(":a")
    assert {:ok, %Symbol{name: "a", package: :lichat}} = WireFormat.parse1("a")
    assert {:ok, %Symbol{name: "a", package: "b"}} = WireFormat.parse1("b:a")
    assert {:ok, %Symbol{name: "aa", package: :lichat}} = WireFormat.parse1("a\\a")
    assert {:ok, %Symbol{name: ":a", package: :lichat}} = WireFormat.parse1("\\:a")
    assert {:ok, %Symbol{name: "b:a", package: :lichat}} = WireFormat.parse1("b\\:a")
  end

  test "string parse" do
    assert {:ok, ""} = WireFormat.parse1("\"\"")
    assert {:ok, "a"} = WireFormat.parse1("\"a\"")
    assert {:ok, "aa"} = WireFormat.parse1("\"a\\a\"")
    assert {:ok, "a\"a"} = WireFormat.parse1("\"a\\\"a\"")
  end

  test "number parse" do
    assert {:ok, 1} = WireFormat.parse1("1")
    assert {:ok, 1.0} = WireFormat.parse1("1.")
    assert {:ok, 1.0} = WireFormat.parse1("1.0")
    assert {:ok, 1.0} = WireFormat.parse1("01.")
    assert {:ok, 0.0} = WireFormat.parse1(".0")
    assert {:ok, 0.0} = WireFormat.parse1(".")
  end

  test "list parse" do
    assert {:ok, []} = WireFormat.parse1("()")
    assert {:ok, []} = WireFormat.parse1("(  )")
    assert {:ok, [[]]} = WireFormat.parse1("(())")
    assert {:ok, [[],[]]} = WireFormat.parse1("(()())")
    assert {:ok, [[],[]]} = WireFormat.parse1("(() ())")
    assert {:ok, ["a"]} = WireFormat.parse1("(\"a\")")
    assert {:ok, [%Symbol{name: "a", package: :lichat}]} = WireFormat.parse1("(a)")
    assert {:ok, [0]} = WireFormat.parse1("(0)")
    assert {:ok, [0,1]} = WireFormat.parse1("(0 1)")
  end

  test "update parse" do
    assert {:ok, [object], _, _, _, _} = WireFormat.update("(foo)")
  end
end
