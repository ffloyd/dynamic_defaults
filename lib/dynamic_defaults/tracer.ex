defmodule DynamicDefaults.Tracer do
  @moduledoc """
  Enforces `forbid_literal_syntax` option by intercepting struct expansions at compile time.

  This tracer is responsible for detecting when a struct marked with `forbid_literal_syntax: true`
  is being created using literal syntax `%Module{}` and raising a compilation error to prevent it.

  Expects to be registered as a compiler tracer via `Code.put_compiler_option(:tracers, [DynamicDefaults.Tracer])`.
  Or by adding `elixirc_options: [tracers: [DynamicDefaults.Tracer]]` to the Mix project configuration.
  """

  @doc """
  Returns the module attribute name used to mark structs that forbid literal syntax.

  This attribute is set by DynamicDefaults when `forbid_literal_syntax: true` is configured,
  allowing the tracer to identify which structs should be protected.
  """
  def mod_attr_name, do: :dynamic_defaults_forbidden_literals

  @doc """
  Intercepts compiler events and enforces literal syntax prohibition.
  """
  @spec trace(tuple, Macro.Env.t()) :: :ok
  def trace(event, env)

  def trace({:struct_expansion, _meta, module, _keys}, env) do
    if module.__info__(:attributes)[mod_attr_name()] do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "Literal struct syntax is forbidden for #{inspect(module)}. " <>
            "Use #{inspect(module)}.new/0-1, struct!/1-2, struct/1-2 instead."
    end

    :ok
  end

  def trace(_, _), do: :ok
end
