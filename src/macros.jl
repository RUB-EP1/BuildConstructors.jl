"""Normalize RHS of `name -> RHS` into a `:block` (handles `begin ... end` sugar)."""
function normalize_lambda_rhs(rhs)
    rhs isa Expr || return Expr(:block, rhs)
    if rhs.head == :block
        return rhs
    end
    if rhs.head == :call && length(rhs.args) >= 1 && rhs.args[1] == :begin
        return Expr(:block, rhs.args[2:end]...)
    end
    return Expr(:block, rhs)
end

"""Detect old bare-`begin` body (rejected): used only for migration error messages."""
function looks_like_plain_body(expr)
    expr isa Expr || return false
    expr.head == :block && return true
    return expr.head == :call && length(expr.args) >= 1 && expr.args[1] == :begin
end

"""Parse `name -> rhs` model body; returns `(pars_sym, body_block::Expr)`."""
function parse_model_body_syntax(expr::Expr)
    if expr.head !== :(->)
        error(
            "@with_parameters requires the model body as a unary lambda, e.g. `other_pars -> begin ... end`. Got: `$expr`",
        )
    end
    length(expr.args) == 2 ||
        error("@with_parameters: invalid `->` expression (expected unary lambda): `$expr`")
    lhs, rhs = expr.args[1], expr.args[2]
    pars_sym = parse_lambda_lhs(lhs)
    blk = normalize_lambda_rhs(rhs)
    return (pars_sym, blk)
end

function parse_model_body_syntax(::Any)
    error(
        "@with_parameters requires the model body as a unary lambda (`other_pars -> expr` or `other_pars -> begin ... end`).",
    )
end

function parse_lambda_lhs(lhs)
    lhs isa Symbol && return lhs
    lhs isa Expr && lhs.head == :tuple &&
        error(
            "@with_parameters: parameter binding must be a single name (e.g. `other_pars -> ...`), not a tuple destructuring.",
        )
    if lhs isa Expr && lhs.head == :(::)
        error(
            "@with_parameters: do not type-annotate the `build_model` parameter (use `θ ->`, not `θ::SomeType ->`); values may be NamedTuples, ComponentArrays, or other types.",
        )
    end
    error("@with_parameters: parameter binding must be a single symbol (e.g. `other_pars -> ...`); got `$lhs`")
end

# Parsed field roles for `@with_parameters` (same payload shape, different lowering — kept
# as distinct types so dispatch selects struct generation and build_model extraction).
"""Bare `field` in the macro list → struct slot `field::Pi` (unconstrained type param); in the body use bare `field`."""
struct ParametricField
    name::Symbol
end

"""`field::P` → struct slot `description_of_field::Ti` with `Ti <: AbstractParameter`; `field` in the body is the resolved value."""
struct DescriptorField
    name::Symbol
end

struct ConstantField
    name::Symbol
    type_expr::Union{Symbol,Expr}
end

# Helper: Parse a single field declaration
function parse_field(expr)
    if expr isa Symbol
        # No type annotation → parametric field
        return ParametricField(expr)
    elseif expr isa Expr && expr.head == :(::) && length(expr.args) == 2
        field_name = expr.args[1]
        field_type = expr.args[2]

        if !(field_name isa Symbol)
            error("Field name must be a symbol, got: $field_name")
        end

        # Check if type is :P (parameter field)
        if field_type == :P
            return DescriptorField(field_name)
        else
            # Any other type → constant field
            return ConstantField(field_name, field_type)
        end
    else
        error(
            "Invalid field declaration. Expected 'field', 'field::P', or 'field::Type', got: $expr",
        )
    end
end

# Helper: Generate type parameters for struct
# Returns (param_type_params, parametric_type_params) where:
# - param_type_params: type parameters for AbstractParameter fields (T1, T2, ...)
# - parametric_type_params: type parameters for parametric fields (P1, P2, ...)
function generate_type_parameters(n_params, n_parametric_fields)
    # Use fully qualified BuildConstructors.AbstractParameter
    abstract_param_ref = Expr(:., :BuildConstructors, QuoteNode(:AbstractParameter))

    # Type parameters for parametric fields: P1, P2, ... (no constraint)
    parametric_type_params = Any[]
    for i = 1:n_parametric_fields
        type_param = Symbol("P", i)
        push!(parametric_type_params, type_param)
    end

    # Type parameters for parameter fields: T1<:AbstractParameter, T2<:AbstractParameter, ...
    param_type_params = Expr[]
    for i = 1:n_params
        type_param = Symbol("T", i)
        push!(param_type_params, Expr(:<:, type_param, abstract_param_ref))
    end

    return param_type_params, parametric_type_params
end

# Multiple dispatch: Add struct field definition based on field type
# Mutates struct_fields
function add_struct_field!(struct_fields, field::ParametricField, parametric_idx)
    type_param = Symbol("P", parametric_idx)
    push!(struct_fields.args, Expr(:(::), field.name, type_param))
    return parametric_idx + 1
end

function add_struct_field!(struct_fields, field::DescriptorField, param_idx)
    type_param = Symbol("T", param_idx)
    field_name = Symbol("description_of_", field.name)
    push!(struct_fields.args, Expr(:(::), field_name, type_param))
    return param_idx + 1
end

function add_struct_field!(struct_fields, field::ConstantField, _)
    push!(struct_fields.args, Expr(:(::), field.name, field.type_expr))
    return nothing  # unused index slot for ConstantField
end

# Helper: Generate struct fields in reordered format: parametric first, then parameters, then constants
function generate_struct_fields(ordered_fields)
    struct_fields = Expr(:block)

    # Track indices for type parameters
    param_idx = 1
    parametric_idx = 1

    # Parametric fields (declaration order)
    for field in ordered_fields
        field isa ParametricField &&
            (parametric_idx = add_struct_field!(struct_fields, field, parametric_idx))
    end

    # Descriptor fields (`::P`)
    for field in ordered_fields
        field isa DescriptorField &&
            (param_idx = add_struct_field!(struct_fields, field, param_idx))
    end

    # Typed constant fields
    for field in ordered_fields
        field isa ConstantField && add_struct_field!(struct_fields, field, nothing)
    end

    return struct_fields
end

# Helper: Generate struct definition
function generate_struct_definition(
    constructor_name,
    param_type_params,
    parametric_type_params,
    struct_fields,
)
    # Use fully qualified BuildConstructors.AbstractConstructor
    abstract_constructor_ref = Expr(:., :BuildConstructors, QuoteNode(:AbstractConstructor))
    # Combine all type parameters: P1, P2, ..., T1, T2, ... (parametric first, then parameters)
    all_type_params = vcat(parametric_type_params, param_type_params)
    struct_name_with_params = Expr(:curly, constructor_name, all_type_params...)
    return Expr(
        :struct,
        false,
        Expr(:<:, struct_name_with_params, abstract_constructor_ref),
        struct_fields,
    )
end

"""Keyword slot for generated `value(...; pars=...)`: shorthand when the binding is literally `pars`."""
function value_pars_kwarg(pars_sym::Symbol)
    if pars_sym === :pars
        return Expr(:parameters, :pars)
    end
    return Expr(:parameters, Expr(:kw, :pars, pars_sym))
end

# Multiple dispatch: Extract parameter value for DescriptorField (`::P`)
function extract_parameter!(
    param_extractions,
    field::DescriptorField,
    value_ref,
    pars_sym::Symbol,
)
    field_name = Symbol("description_of_", field.name)
    push!(
        param_extractions.args,
        Expr(
            :(=),
            field.name,
            Expr(
                :call,
                value_ref,
                value_pars_kwarg(pars_sym),
                Expr(:., :c, QuoteNode(field_name)),
            ),
        ),
    )
    return nothing
end

extract_parameter!(::Any, ::ParametricField, ::Any, ::Any) = nothing
extract_parameter!(::Any, ::ConstantField, ::Any, ::Any) = nothing

function add_slot_bindings!(bindings_block, field::Union{ParametricField, ConstantField})
    push!(bindings_block.args, Expr(:(=), field.name, Expr(:., :c, QuoteNode(field.name))))
    return nothing
end
add_slot_bindings!(::Any, ::DescriptorField) = nothing

# Multiple dispatch: Count fields by type
count_descriptor_fields(fields) = count(f -> f isa DescriptorField, fields)
count_parametric_fields(fields) = count(f -> f isa ParametricField, fields)

# Helper: Generate build_model function
function generate_build_model_function(constructor_name, ordered_fields, body, pars_sym::Symbol)
    value_ref = Expr(:., :BuildConstructors, QuoteNode(:value))

    # Descriptor locals: param = value(c.description_of_{param}; pars=pars_sym)
    build_model_body = Expr(:block)
    for field in ordered_fields
        add_slot_bindings!(build_model_body, field)
        extract_parameter!(build_model_body, field, value_ref, pars_sym)
    end

    # User body
    if body isa Expr && body.head == :block
        append!(build_model_body.args, body.args)
    else
        push!(build_model_body.args, body)
    end

    # Generate function definition
    build_model_ref = Expr(:., :BuildConstructors, QuoteNode(:build_model))
    return Expr(
        :function,
        Expr(:call, build_model_ref, Expr(:(::), :c, constructor_name), pars_sym),
        build_model_body,
    )
end

# Helper: Parse arguments sequentially - processes model name, fields, and body in order
function parse_macro_arguments(model_name_expr, params_expr...)
    model_name = nothing
    ordered_fields = Union{ParametricField,DescriptorField,ConstantField}[]
    body = nothing
    pars_sym = :pars

    # Normalize input: handle both @with_parameters(ModelName; ...) and @with_parameters ModelName; ...
    # Julia parses these differently, so we need to handle both cases
    args_to_process = Any[]

    if model_name_expr isa Expr && model_name_expr.head == :parameters
        # Syntax: @with_parameters(ModelName; fields...) - model name is in params_expr
        if !isempty(params_expr) && params_expr[1] isa Symbol
            model_name = params_expr[1]
            args_to_process = model_name_expr.args
        else
            error(
                "@with_parameters: model name missing. Expected `@with_parameters(ModelName; fields..., other_pars -> begin ... end)`.",
            )
        end
    elseif model_name_expr isa Symbol
        # Syntax: @with_parameters ModelName; fields... - model name is first
        model_name = model_name_expr
        args_to_process = params_expr
    else
        error("Model name must be a symbol, got: $model_name_expr")
    end

    # Process arguments sequentially
    for arg in args_to_process
        # Skip line number nodes
        arg isa LineNumberNode && continue

        # Model body: unary lambda `binder -> expr` (docs use `other_pars` as the typical binder name).
        if arg isa Expr && arg.head == :(->)
            pars_sym, body = parse_model_body_syntax(arg)
            break
        elseif looks_like_plain_body(arg)
            error(
                "@with_parameters: use a unary lambda for the model body, e.g. `other_pars -> begin ... end`, not a bare `begin ... end` block.",
            )
        end

        # Handle parameters expression (contains fields separated by semicolon)
        if arg isa Expr && arg.head == :parameters
            for field_expr in arg.args
                field_expr isa LineNumberNode && continue

                if field_expr isa Expr && field_expr.head == :(->)
                    pars_sym, body = parse_model_body_syntax(field_expr)
                    break
                elseif looks_like_plain_body(field_expr)
                    error(
                        "@with_parameters: use a unary lambda for the model body, e.g. `other_pars -> begin ... end`, not a bare `begin ... end` block.",
                    )
                else
                    field = parse_field(field_expr)
                    push!(ordered_fields, field)
                end
            end
            # If body was found in parameters expression, stop processing
            body !== nothing && break
            # Handle direct field declarations (no semicolon syntax)
        elseif arg isa Symbol || (arg isa Expr && arg.head == :(::))
            field = parse_field(arg)
            push!(ordered_fields, field)
        else
            error("Unexpected argument format in @with_parameters: $arg")
        end
    end

    # Validation
    if body === nothing
        error(
            "@with_parameters requires a model body unary lambda (`other_pars -> expr` or `other_pars -> begin ... end`), with a plain symbol before `->` (no type annotation).",
        )
    end
    if isempty(ordered_fields)
        error("@with_parameters requires at least one field")
    end

    return model_name, ordered_fields, body, pars_sym
end

"""
    @with_parameters ModelName; fields..., binder -> expr
    @with_parameters ModelName; fields..., binder -> begin
        ...
    end

Generate a `ConstructorOfModelName` subtype of `AbstractConstructor` and a
matching `build_model(::ConstructorOfModelName, binder)` method. Documentation
examples typically name `binder` **`other_pars`** so it reads as the runtime values
object threaded through `build_model`; you may choose any plain symbol.

The body must always be written as **one unary anonymous function**.
Use `other_pars -> begin ... end` in docs and examples for clarity.

The macro separates fields into three roles:

- `field::P`: parameter descriptor field. The generated struct stores it as
  `description_of_field`, constrained to `AbstractParameter`. Inside the lambda body,
  `field` is the resolved numeric value from `BuildConstructors.value`; the **`pars`** keyword
  receives the same binding as the second argument of `build_model`.
- `field::SomeType`: constant field. The generated struct stores it directly with
  the declared type. In the lambda body, use bare `field`.
- `field`: parametric field. The generated struct stores it directly with an
  inferred type parameter. This is useful for nested constructors or arbitrary
  user objects. In the lambda body, use bare `field`.

The generated constructor argument order is parametric fields first, parameter
descriptor fields second, and constant fields last. This keeps all generated
constructors predictable even when fields are declared in a mixed order.

Inside the lambda RHS, every field name from the header is a local binding: parameter
descriptors (`::P`) are resolved via `BuildConstructors.value`; parametric and
constant fields are read from `c`. Together with `binder`, those names obey normal
Julia scoping (`binder` itself must be a plain symbol before `->`, not `θ::SomeType`).
Tuple-destructuring for `binder` is not supported.

# Examples
```julia
@with_parameters Gaussian; μ::P, σ::P, support::Tuple{Float64,Float64}, other_pars -> begin
    truncated(Normal(μ, σ), support[1], support[2])
end

@with_parameters ScaleModel; D, scale::P, other_pars -> begin
    child = build_model(D, other_pars)
    x -> scale * child(x)
end

@with_parameters ScaleModel; D, scale::P, θ -> begin
    child = build_model(D, θ)
    x -> scale * child(x)
end
```
"""
macro with_parameters(model_name_expr, params_expr...)
    # Parse arguments sequentially: model name, fields, and body
    model_name, ordered_fields, body, pars_sym =
        parse_macro_arguments(model_name_expr, params_expr...)

    n_descriptor = count_descriptor_fields(ordered_fields)
    n_parametric = count_parametric_fields(ordered_fields)

    # Generate code
    constructor_name = Symbol("ConstructorOf", model_name)

    param_type_params, parametric_type_params =
        generate_type_parameters(n_descriptor, n_parametric)
    struct_fields = generate_struct_fields(ordered_fields)
    struct_def = generate_struct_definition(
        constructor_name,
        param_type_params,
        parametric_type_params,
        struct_fields,
    )
    build_model_def =
        generate_build_model_function(constructor_name, ordered_fields, body, pars_sym)

    return Expr(:block, esc(struct_def), esc(build_model_def), Expr(:line, __source__))
end
