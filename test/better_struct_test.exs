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

  describe "factory_fn option" do
    defmodule DefaultFactoryName do
      use BetterStruct

      defstruct value: "default"
    end

    defmodule CustomFactoryName do
      use BetterStruct, factory_fn: :create

      defstruct value: "custom"
    end

    defmodule NoFactory do
      use BetterStruct, factory_fn: false

      defstruct value: "no_factory"
    end

    test "default factory_fn creates new/0 and new/1" do
      assert function_exported?(DefaultFactoryName, :new, 0)
      assert function_exported?(DefaultFactoryName, :new, 1)

      result = DefaultFactoryName.new()
      assert %DefaultFactoryName{value: "default"} = result
    end

    test "custom factory_fn creates functions with specified name" do
      assert function_exported?(CustomFactoryName, :create, 0)
      assert function_exported?(CustomFactoryName, :create, 1)

      refute function_exported?(CustomFactoryName, :new, 0)
      refute function_exported?(CustomFactoryName, :new, 1)

      result = CustomFactoryName.create()
      assert %CustomFactoryName{value: "custom"} = result
    end

    test "custom factory_fn accepts attributes" do
      result = CustomFactoryName.create(%{value: "overridden"})

      assert %CustomFactoryName{value: "overridden"} = result
    end

    test "factory_fn: false does not create any factory function" do
      refute function_exported?(NoFactory, :new, 0)
      refute function_exported?(NoFactory, :new, 1)
    end

    test "factory_fn: false still allows struct literal syntax" do
      result = %NoFactory{value: "literal"}

      assert %NoFactory{value: "literal"} = result
    end
  end

  describe "defstruct_behavior: :ignore_defaults" do
    defmodule IgnoreDefaults do
      use BetterStruct, defstruct_behavior: :ignore_defaults

      defstruct name: "default_name", count: 42
    end

    test "struct literal syntax has nil defaults" do
      result = %IgnoreDefaults{}

      assert %IgnoreDefaults{name: nil, count: nil} = result
    end

    test "struct literal with explicit values works" do
      result = %IgnoreDefaults{name: "custom", count: 100}

      assert %IgnoreDefaults{name: "custom", count: 100} = result
    end

    test "__struct__/0 returns struct with nil defaults" do
      result = IgnoreDefaults.__struct__()

      assert %IgnoreDefaults{name: nil, count: nil} = result
    end
  end

  describe "defstruct_behavior: :override" do
    defmodule OverrideDynamic do
      use BetterStruct, defstruct_behavior: :override

      defstruct timestamp: System.os_time()

      def literal_a, do: %OverrideDynamic{}
      def literal_b, do: %OverrideDynamic{}
    end

    test "struct literals from different location has different defaults" do
      assert OverrideDynamic.literal_a().timestamp != OverrideDynamic.literal_b().timestamp
    end

    test "struct literal default fixed after compilation" do
      first = OverrideDynamic.literal_a()
      second = OverrideDynamic.literal_a()

      assert first.timestamp == second.timestamp
    end

    test "struct!/0 re-evaluates dynamic defaults on each call" do
      first = struct!(OverrideDynamic)
      second = struct!(OverrideDynamic)

      assert first.timestamp != second.timestamp
    end

    test "struct literal with explicit values overrides defaults" do
      result = %OverrideDynamic{timestamp: 12_345}

      assert %OverrideDynamic{timestamp: 12_345} = result
    end
  end
end
