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
    assert {:ok, [%Symbol{name: "foo", package: :lichat}]} = WireFormat.update1("(foo)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat}]} = WireFormat.update1("(foo )")
    assert {:ok, [%Symbol{name: "foo", package: :lichat}]} = WireFormat.update1("( foo)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword}, 0]} = WireFormat.update1("(foo :bar 0)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword}, 0,
                  %Symbol{name: "baz", package: :keyword}, 1]} = WireFormat.update1("(foo :bar 0 :baz 1)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword}, "a"]} = WireFormat.update1("(foo :bar \"a\")")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword},
                  %Symbol{name: "a", package: :lichat}]} = WireFormat.update1("(foo :bar a)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword},
                  %Symbol{name: "a", package: :keyword}]} = WireFormat.update1("(foo :bar :a)")
    assert {:ok, [%Symbol{name: "foo", package: :lichat},
                  %Symbol{name: "bar", package: :keyword},
                  %Symbol{name: "b", package: "a"}]} = WireFormat.update1("(foo :bar a:b)")
  end

  test "printer" do
    assert "0" == WireFormat.print1(0)
    assert "0.0" == WireFormat.print1(0.0)
    assert "\"a\"" == WireFormat.print1("a")
    assert "\"\\\\a\"" == WireFormat.print1("\\a")
    assert "\"\\\"a\"" == WireFormat.print1("\"a")
    assert "a" == WireFormat.print1(Symbol.li("a"))
    assert ":a" == WireFormat.print1(Symbol.kw("a"))
    assert "b:a" == WireFormat.print1(Symbol.intern("a", "b"))
    assert "()" == WireFormat.print1([])
    assert "(0)" == WireFormat.print1([0])
    assert "(\"a\")" == WireFormat.print1(["a"])
    assert "(())" == WireFormat.print1([[]])
    assert "(0 1)" == WireFormat.print1([0,1])
    assert "(0 1 2)" == WireFormat.print1([0,1,2])
  end
end
