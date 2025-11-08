defmodule BetterStructTest do
  use ExUnit.Case
  doctest BetterStruct

  describe "factory function behavior" do
    defmodule KeywordWithDefaults do
      use BetterStruct

      defstruct name: "default", count: 0
    end

    defmodule ListSyntax do
      use BetterStruct

      defstruct [:x, :y]
    end

    defmodule MixedSyntax do
      use BetterStruct

      defstruct [:x, y: "default_y"]
    end

    defmodule DynamicDefaults do
      use BetterStruct

      defstruct dyn_x: System.os_time(), dyn_y: System.os_time()
    end

    test "works with keyword list syntax (key: value)" do
      result = KeywordWithDefaults.new()

      assert %KeywordWithDefaults{name: "default", count: 0} = result
    end

    test "works with list syntax [:field]" do
      result = ListSyntax.new()

      assert %ListSyntax{x: nil, y: nil} = result
    end

    test "works with mixed syntax [:field, field: value]" do
      result = MixedSyntax.new()

      assert %MixedSyntax{x: nil, y: "default_y"} = result
    end

    test "re-evaluates dynamic defaults on each call to new/0" do
      first = DynamicDefaults.new()
      second = DynamicDefaults.new()

      # dyn_x and dyn_y should be different because System.os_time() is re-evaluated
      refute first.dyn_x == second.dyn_x
      refute first.dyn_y == second.dyn_y
    end

    test "new/1 accepts attributes map and merges with defaults" do
      result = KeywordWithDefaults.new(%{name: "custom"})

      assert %KeywordWithDefaults{name: "custom", count: 0} = result
    end

    test "new/1 accepts attributes keyword list" do
      result = KeywordWithDefaults.new(name: "custom", count: 42)

      assert %KeywordWithDefaults{name: "custom", count: 42} = result
    end

    test "new/1 raises on invalid attributes" do
      assert_raise KeyError, fn ->
        KeywordWithDefaults.new(%{invalid_field: "value"})
      end
    end

    test "new/1 overrides dynamic defaults when provided" do
      fixed_time = 123_456_789

      result = DynamicDefaults.new(%{dyn_x: fixed_time})

      assert result.dyn_x == fixed_time
    end
  end
end
