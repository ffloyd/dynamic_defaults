defmodule BetterStruct do
  @moduledoc """
  Enables dynamic defaults for structs by re-evaluating default expressions at runtime.

  This module is responsible for solving the problem where struct defaults are evaluated
  only once at compile time, making it impossible to have truly dynamic defaults like
  timestamps without manual factory functions.

  It provides configurable approaches to struct creation, allowing you to choose
  between full compatibility with existing code and enforcing consistent dynamic defaults.
  """

  @type defstruct_behavior :: :keep | :ignore_defaults | :override
  @type factory_fn :: atom() | false
  @type option ::
          {:defstruct_behavior, defstruct_behavior()}
          | {:forbid_literal_syntax, boolean()}
          | {:factory_fn, factory_fn()}
  @type options :: [option()]

  @doc """
  Configures the module to use BetterStruct's dynamic defaults functionality.

  Responsible for setting up the chosen struct creation strategy by importing
  a custom `defstruct/1` macro that captures default expressions as AST for
  later re-evaluation.

  Expects to be called via `use BetterStruct` before `defstruct` is used in the module.

  ## Options

  - `:defstruct_behavior` - Controls how the original `defstruct` macro behaves:
    - `:keep` (default) - Preserves standard Elixir behavior
    - `:ignore_defaults` - Removes defaults from call to the original `defstruct`
    - `:override` - Re-evaluates defaults in `__struct__/0` / `__struct__/1` functions.

  - `:forbid_literal_syntax` - When `true`, raises compilation error on literal syntax `%Module{}`.
    Use when you want to enforce a single, consistent way of creating structs.
    Requires compiler tracer to be enabled in the compilation environment.
    Default: `false`.

  - `:factory_fn` - Controls factory function generation:
    - `:new` (default) - Creates `new/0` and `new/1`
    - Any atom - Creates factory with that name
    - `false` - Skips factory generation; use when you want to define your own factory

  ## Examples

      defmodule Point do
        use BetterStruct

        defstruct x: System.os_time(),
                  y: System.os_time()
      end

      Point.new()
      Point.new(%{x: 100})
  """
  @spec __using__(opts :: options()) :: Macro.t()
  defmacro __using__(opts \\ []) do
    full_opts = [
      defstruct_behavior: Keyword.get(opts, :defstruct_behavior, :keep),
      forbid_literal_syntax: Keyword.get(opts, :forbid_literal_syntax, false),
      factory_fn: Keyword.get(opts, :factory_fn, :new)
    ]

    :ok = Module.put_attribute(__CALLER__.module, :better_struct_options, full_opts)

    if full_opts[:forbid_literal_syntax] do
      marker_attr_name = BetterStruct.Tracer.mod_attr_name()

      :ok = Module.register_attribute(__CALLER__.module, marker_attr_name, persist: true)

      :ok =
        Module.put_attribute(
          __CALLER__.module,
          marker_attr_name,
          true
        )
    end

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

    defstruct_fields =
      case opts[:defstruct_behavior] do
        x when x in [:ignore_defaults, :override] ->
          Enum.map(fields, fn
            {k, _v} when is_atom(k) -> k
            k when is_atom(k) -> k
          end)

        _ ->
          fields
      end

    quote do
      Kernel.defstruct(unquote(defstruct_fields))

      if unquote(opts[:defstruct_behavior] == :override) do
        defoverridable(__struct__: 0, __struct__: 1)

        def __struct__, do: Map.merge(super(), unquote(defaults_map_ast))

        def __struct__(arg),
          do: __struct__() |> Map.merge(Map.new(arg))
      end

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
