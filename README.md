# BetterStruct

This package aims to solve a design problem I often encounter when working with Elixir structs:

> Static and dynamic defaults for struct fields require different approaches.

For example, you need `created_at: DateTime.utc_now()` to be re-evaluated each time a new instance of a struct is created, but `defstruct created_at: DateTime.utc_now()` evaluates once at compile time, giving all instances the same _default value_ of `created_at`.

The idiomatic way to address this problem is to create a "factory function" that applies dynamic defaults at runtime:

```elixir
defmodule Example do
  defstruct static: "This #{System.os_time()} will be the same number each time we create a struct via %Example{}",
            dynamic: nil

  # a "factory function" to create structs with dynamic defaults
  def new(attrs \\ %{}) do
    final_attrs = Map.merge(%{
      dynamic: "This #{System.os_time()} will be a different number each time we create a struct via new()"
    }, attrs)

    struct!(__MODULE__, final_attrs)
  end
end
```

When you from the beginning always create your structs via the `new/1` function, this works fine and everyone is happy.
Ok, I'm not that happy because I do not like the fact that static and dynamic defaults are defined in different places and when I need to understand "what are the defaults for this struct?" I should always remember that there're at least 2 places for them and I need to merge defaults from all that places in my head.
In most cases, it's not a big deal, but sometimes it is really annoying and feels ugly.

But the really noticeable problem here, is that I see that developers usually do not introduce a `new/1` function until the first time they need a dynamic default.
At that point, they have to refactor all the places where they create the struct via `%Example{...}` to use `Example.new(...)` instead.
On small codebases, this is not a big deal.
On larger codebases, this can be an annoying and error-prone task.

Alternatively, developers often prefer to achieve their goal without dynamic defaults, which sometimes leads to a better architecture, sometimes not.

I believe that dynamic defaults are a convenient pattern that should be easier and more straightforward to implement.
If you are starting a new project, then you can accept convention always to use factory functions and you can code comfortably without this package.
But if you are working on an existing project, or if you just want to avoid the boilerplate of factory functions, then this package can help you.
The ideas it is based on are:

- static and dynamic defaults can be defined in the same place using similar syntax
- when creating a new struct, you either apply both types of defaults, or none
- a single way of creating a struct should be enforced throughout the codebase
- keep things as close to idiomatic Elixir as possible
- focus on the cases where support of dynamic defaults was overlooked in the past and now needs to be added
- let an engineer decide how far from standard Elixir behavior they want to go

## Usage

`BetterStruct` is designed to be injected into existing structs.
In its simplest form, it provides a `new/1` function that applies all defaults as dynamic ones.

Normally, `defstruct` evaluates default value expressions at compile time.
The `new/1` function takes the exact same AST (of expressions) and re-evaluates them at runtime, making them dynamic.

```elixir
defmodule Point do
  use BetterStruct # must be placed before `defstruct`

  defstruct x: System.os_time(),
            y: System.os_time()
end

defmodule Test do
  def via_literal, do: %Point{}
  def via_factory, do: Point.new()
end

iex> Test.via_literal() == Test.via_literal()
true # %Point{} created via literal has static defaults, like usual

iex> Test.via_factory() == Test.via_factory()
false # %Point{} created via Point.new() has dynamic defaults recalculated each call.
```

A good starting point, but a bit inconsistent.
Next step is to start enabling modifiers.

### `defstruct_behavior`

`BetterStruct` allows you to control how `defstruct` macro behaves via the `defstruct_behavior` option.

If you look into `defstruct` implementation, you will see that it creates a function called `__struct__/0` that is always used when creating structs.
When you use `%Point{}`, it calls `Point.__struct__/0` under the hood _at compile time_.
When you use `struct(Point)`, `struct(Point, ...)`, etc - it calls `Point.__struct__/0` _at runtime_.

Allowed values are:

- `:keep` - default one. Keeps the original behavior of `defstruct`.
- `:ignore_defaults` - defaults will be applied _only_ when using the factory function (e.g., `new/1`). Using `%Point{}` will create a struct with all fields set to `nil` (or will fail if `@enforce_keys` is used for some fields). It does _not_ directly modify `__struct__/0`, just removes defaults from the call to original `defstruct` macro. This option is safe and does not rely on any undocumented behavior.
- `:override` - makes `__struct__/0` be equivalent to the factory function (e.g., `new/0`).

Example of `:ignore_defaults` usage:

```elixir
defmodule Point do
  use BetterStruct, defstruct_behavior: :ignore_defaults

  defstruct x: System.os_time(),
            y: System.os_time()
end

defmodule Test do
  def via_literal, do: %Point{}
  def via_factory, do: Point.new()
end

iex> Test.via_literal() == %Point{x: nil, y: nil}
true # %Point{} created via literal has no static defaults

iex> Test.via_factory()
%Point{x: 1699876543210, y: 1699876543211} # numbers will vary each call
```

Example of `:override` usage:

```elixir
defmodule Point do
  use BetterStruct, defstruct_behavior: :override

  defstruct x: System.os_time(),
            y: System.os_time()
end

defmodule Test do
  def via_literal_a, do: %Point{}
  def via_literal_b, do: %Point{}
  def via_struct, do: struct!(Point)
  def via_factory, do: Point.new()
end

iex> Test.via_literal_a() == Test.via_literal_a()
true # because __struct__/0 called at compile time when use literal syntax

iex> Test.via_literal_a() == Test.via_literal_b()
false # because __struct__/0 called for each literal separately at compile time

iex> Test.via_struct() == Test.via_struct()
false # because __struct__/0 called at runtime when use struct!/1 and similar functions
```

Behavior of literal syntax when `defstruct_behavior: :override` is used may be counter-intuitive.
This can be addressed with the `forbid_literal_syntax` option.

### `forbid_literal_syntax`

When set to true, attempt to create a struct via literal syntax `%Point{}` will raise an error.
Only the functions `Point.new/1`, `struct!/1`, `struct!/2`, `struct/1`, `struct/2` are allowed to create structs.

**Note:** The `struct/struct!` functions are often used when the struct module is not known at compile time, such as `struct!(dynamic_module)` or `struct!(module, attrs)`.

When combined with `defstruct_behavior: :override`, it forbids literal syntax and makes all other ways of creating structs use dynamic defaults.
_As an outcome you have a guarantee that dynamic defaults are always applied!_

This option relies on undocumented behavior of Elixir, specifically how `__struct__/0` is created and used.
But it's not that scary in practice, because if it will not work in some future Elixir version, the worst that can happen is that you will need to add your own linter rule to forbid literal syntax.
(Which is less bulletproof because it does not check macro expansions.)

<!-- TODO: Add example of error message when literal syntax is forbidden -->

```elixir
defmodule Point do
  use BetterStruct, defstruct_behavior: :override, forbid_literal_syntax: true

  defstruct x: System.os_time(),
            y: System.os_time()
end
```

### `factory_fn`

Controls whether a factory function is created and what it's named.

Allowed values are:

- `:new` - default. Creates a `new/0` and `new/1` function.
- Any other atom - creates a factory function with that name (e.g., `factory_fn: :create` will create `create/0` and `create/1`).
- `false` - does not create a factory function.

Example:

```elixir
defmodule Point do
  use BetterStruct, factory_fn: :create

  defstruct x: System.os_time(),
            y: System.os_time()
end

iex> Point.create()
%Point{x: 1699876543210, y: 1699876543211}

iex> Point.create(%{x: 100})
%Point{x: 100, y: 1699876543215}
```


### Mixing static and dynamic defaults

You may notice that from the factory function's perspective, all defaults are dynamic.
To achieve mixing static and dynamic defaults use module attributes:

```elixir
defmodule Point do
  use BetterStruct

  @static_x System.os_time()

  defstruct x: @static_x,
            y: System.os_time()
end
```

It makes explicit which defaults are static and which are dynamic.
I would like to have this behavior built-in in Elixir, but it may be too opinionated.
And I found it less surprising for Elixir newcomers than "static by default behavior" when you do `defstruct x: calculate_something()` and after hours of nervous debugging you realize that the function was called only once at compile time.

### Global "configuration"

Instead of setting the options in each struct, you can create your own wrapper module around `BetterStruct` that sets these options for you:

```elixir
defmodule MyApp.BetterStruct do
  defmacro __using__(_opts) do
    quote do
      use BetterStruct,
        defstruct_behavior: :override,
        forbid_literal_syntax: true
    end
  end
end
```

Then `use MyApp.BetterStruct` in your structs instead of `use BetterStruct, ...`.

### Adoption strategy

I recommend choosing one of the following strategies to adopt `BetterStruct` in your codebase.

__1. Factory functions are the only place where defaults are applied__

This approach is close to what we have in Golang and relies only on documented Elixir behavior.

To achieve this, set `defstruct_behavior: :ignore_defaults` globally.
Then all structs created via literal syntax `%Struct{}` or `struct/1-2` will have all fields set to `nil` (unless explicitly provided in arguments).

The `new/0-1` function will be the only way to create structs with defaults applied.

The risks are that some libraries (like Ecto) or parts of your codebase may rely on literal syntax or `struct/1-2` to create structs with defaults.

__2. Dynamic defaults are always applied__

You can enforce the usage of dynamic defaults everywhere by setting `defstruct_behavior: :override` and `forbid_literal_syntax: true` globally.
You will need to get rid of all usages of literal syntax `%Struct{}` in your codebase.

The risks are:

- this setup relies on undocumented behavior of Elixir (how `__struct__/0` is created and used).
- some libraries may have macros that create your structs via literal syntax under the hood, causing compilation errors.

__3. Pick your own and tell me in the issues how it worked for you!__

If you have another idea of how to adopt `BetterStruct` in your codebase, please share it in the issues!

Do not hesitate to propose ideas for new features or improvements as well!

## Related discussions

Initially I tried to propose adding dynamic defaults support to Elixir core.
Outcomes of [the discussion](https://elixirforum.com/t/runtime-calculated-default-values-for-structs/73189/39) (you need to be logged in) and valuable feedback I got became a foundation for this package.

## Installation

```elixir
def deps do
  [
    {:better_struct, "~> 0.0.1"}
  ]
end
```
