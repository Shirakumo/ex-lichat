defmodule WireFormatTest do
  use ExUnit.Case
  doctest WireFormat

  test "symbol parse" do
    assert {:ok, true} = WireFormat.parse1("T")
    assert {:ok, true} = WireFormat.parse1("t")
    assert {:ok, true} = WireFormat.parse1("\\T")
    assert {:ok, false} = WireFormat.parse1("NIL")
    assert {:ok, false} = WireFormat.parse1("Nil")
    assert {:ok, false} = WireFormat.parse1("nil")
    assert {:ok, %Symbol{name: "A", package: :keyword}} = WireFormat.parse1(":a")
    assert {:ok, %Symbol{name: "A", package: :lichat}} = WireFormat.parse1("a")
    assert {:ok, %Symbol{name: "A", package: "B"}} = WireFormat.parse1("b:a")
    assert {:ok, %Symbol{name: "Aa", package: :lichat}} = WireFormat.parse1("a\\a")
    assert {:ok, %Symbol{name: ":A", package: :lichat}} = WireFormat.parse1("\\:a")
    assert {:ok, %Symbol{name: "B:A", package: :lichat}} = WireFormat.parse1("b\\:a")
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
    assert {:ok, [%Symbol{name: "A", package: :lichat}]} = WireFormat.parse1("(a)")
    assert {:ok, [0]} = WireFormat.parse1("(0)")
    assert {:ok, [0,1]} = WireFormat.parse1("(0 1)")
  end

  test "update parse" do
    assert {:ok, [%Symbol{name: "FOO", package: :lichat}]} = WireFormat.update1("(foo)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat}]} = WireFormat.update1("(foo )")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat}]} = WireFormat.update1("( foo)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword}, 0]} = WireFormat.update1("(foo :bar 0)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword}, 0,
                  %Symbol{name: "BAZ", package: :keyword}, 1]} = WireFormat.update1("(foo :bar 0 :baz 1)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword}, "a"]} = WireFormat.update1("(foo :bar \"a\")")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword},
                  %Symbol{name: "A", package: :lichat}]} = WireFormat.update1("(foo :bar a)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword},
                  %Symbol{name: "A", package: :keyword}]} = WireFormat.update1("(foo :bar :a)")
    assert {:ok, [%Symbol{name: "FOO", package: :lichat},
                  %Symbol{name: "BAR", package: :keyword},
                  %Symbol{name: "B", package: "A"}]} = WireFormat.update1("(foo :bar a:b)")
  end

  test "printer" do
    assert "0\0" == WireFormat.print1(0)
    assert "0.0\0" == WireFormat.print1(0.0)
    assert "\"a\"\0" == WireFormat.print1("a")
    assert "\"\\\\a\"\0" == WireFormat.print1("\\a")
    assert "\"\\\"a\"\0" == WireFormat.print1("\"a")
    assert "a\0" == WireFormat.print1(Symbol.li("A"))
    assert "\\a\0" == WireFormat.print1(Symbol.li("a"))
    assert "a\\a\0" == WireFormat.print1(Symbol.li("Aa"))
    assert ":a\0" == WireFormat.print1(Symbol.kw("A"))
    assert "b:a\0" == WireFormat.print1(Symbol.intern("A", "B"))
    assert "()\0" == WireFormat.print1([])
    assert "(0)\0" == WireFormat.print1([0])
    assert "(\"a\")\0" == WireFormat.print1(["a"])
    assert "(())\0" == WireFormat.print1([[]])
    assert "(0 1)\0" == WireFormat.print1([0,1])
    assert "(0 1 2)\0" == WireFormat.print1([0,1,2])
  end
end
