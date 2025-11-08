defmodule BetterStruct do
  @moduledoc """
  Provides enhanced struct functionality with support for dynamic defaults.

  `BetterStruct` allows you to define struct defaults that are re-evaluated
  at runtime, making them truly dynamic.
  """

  @doc """
  Injects BetterStruct functionality into a module.

  ## Options

  - `:defstruct_behavior` - Controls how `defstruct` macro behaves.
    - `:keep` (default) - Keeps the original behavior of `defstruct`.
    - `:ignore_defaults` - Defaults applied only via factory function.
    - `:override` - Makes `__struct__/0` equivalent to factory function.

  - `:forbid_literal_syntax` - When `true`, raises error on literal syntax `%Module{}`.
    Default: `false`.

  - `:factory_fn` - Controls factory function name.
    - `:new` (default) - Creates `new/0` and `new/1`.
    - Any atom - Creates factory with that name.
    - `false` - Does not create factory function.

  ## Examples

      defmodule Point do
        use BetterStruct

        defstruct x: System.os_time(),
                  y: System.os_time()
      end

      Point.new()
      Point.new(%{x: 100})
  """
  defmacro __using__(opts \\ []) do
    full_opts = [
      defstruct_behavior: Keyword.get(opts, :defstruct_behavior, :keep),
      forbid_literal_syntax: Keyword.get(opts, :forbid_literal_syntax, false),
      factory_fn: Keyword.get(opts, :factory_fn, :new)
    ]

    :ok = Module.put_attribute(__CALLER__.module, :better_struct_options, full_opts)

    quote do
      import Kernel, except: [defstruct: 1]
      import unquote(__MODULE__), only: [defstruct: 1]
    end
  end

  defmacro defstruct(fields) do
    defaults_map_ast =
      {:%{}, [],
       Enum.filter(fields, fn
         {k, _v} when is_atom(k) -> true
         _ -> false
       end)}

    opts = Module.get_attribute(__CALLER__.module, :better_struct_options)

    defstruct_fileds =
      case opts[:defstruct_behavior] do
        :ignore_defaults ->
          Enum.map(fields, fn
            {k, _v} when is_atom(k) -> k
            k when is_atom(k) -> k
          end)

        _ ->
          fields
      end

    quote do
      Kernel.defstruct(unquote(defstruct_fileds))

      if unquote(opts[:factory_fn]) do
        def unquote(opts[:factory_fn])(attrs \\ %{}) do
          final_attrs =
            Map.merge(
              unquote(defaults_map_ast),
              Map.new(attrs)
            )

          struct!(__MODULE__, final_attrs)
        end
      end
    end
  end
end
