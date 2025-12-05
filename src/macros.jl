"""
    @with_parameters ModelName; field1, field2::P, field3::Type, ... begin
        # model-building logic
    end

Generate a constructor struct and build_model function for a model with the given fields.

Fields can be of three types:
1. `field` (no type) → parametric field (type parameter P1, P2, ...)
2. `field::P` → parameter field (becomes `description_of_field::T1<:AbstractParameter`)
3. `field::Type` → constant field (accessed via `_.field`)

The order of fields is preserved in the generated struct.

# Example
```julia
@with_parameters Gaussian; μ::P, σ::P, support::Tuple{Float64,Float64} begin
    truncated(Normal(μ, σ), _.support[1], _.support[2])
end

@with_parameters ScaleModel; D, scale::P begin
    build_model(_.D, pars) * scale
end
```
"""

# Helper: Check if expression is a body block
function is_body_block(expr)
    !(expr isa Expr) && return false
    return expr.head == :block || (expr.head == :call && expr.args[1] == :begin)
end

# Helper: Extract body block from expression
function extract_body_block(expr)
    if expr isa Expr
        if expr.head == :block
            return expr
        elseif expr.head == :call && expr.args[1] == :begin
            return Expr(:block, expr.args[2:end]...)
        end
    end
    return nothing
end

# Field type enum
struct ParametricField
    name::Symbol
end

struct ParameterField
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
            return ParameterField(field_name)
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

# Helper: Find all field usages (_.field_name) in expression tree and transform to c.field_name
# Also validates that fields are accessed via _.field pattern, not directly
function find_field_usages(expr, all_declared_fields, param_names)
    used_fields = Set{Symbol}()
    invalid_usages = Symbol[]  # Fields used directly without _.field pattern

    function traverse_and_transform(e)
        if e isa Expr
            # Check for _.field_name pattern and transform to c.field_name
            if e.head == :. && length(e.args) == 2
                if e.args[1] == :_ && e.args[2] isa QuoteNode
                    field_name = e.args[2].value
                    if field_name isa Symbol
                        push!(used_fields, field_name)
                        # Transform _.field to c.field
                        e.args[1] = :c
                    end
                end
            end
            # Recursively traverse all sub-expressions
            for arg in e.args
                traverse_and_transform(arg)
            end
        elseif e isa Symbol
            # Check if this symbol is a declared field being used directly (invalid)
            # But ignore if it's a parameter name (those are valid)
            if e in all_declared_fields && !(e in param_names)
                push!(invalid_usages, e)
            end
        end
    end

    traverse_and_transform(expr)

    # Report invalid usages
    if !isempty(invalid_usages)
        unique_invalid = unique(invalid_usages)
        field_list = join(["'$(f)'" for f in unique_invalid], ", ")
        error(
            "Field(s) $field_list are used directly but must be accessed via '_.field_name' pattern. " *
            "For example, use '_.$(unique_invalid[1])' instead of '$(unique_invalid[1])'",
        )
    end

    return used_fields
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

function add_struct_field!(struct_fields, field::ParameterField, param_idx)
    type_param = Symbol("T", param_idx)
    field_name = Symbol("description_of_", field.name)
    push!(struct_fields.args, Expr(:(::), field_name, type_param))
    return param_idx + 1
end

function add_struct_field!(struct_fields, field::ConstantField, _)
    push!(struct_fields.args, Expr(:(::), field.name, field.type_expr))
    return nothing  # No index to update
end

# Multiple dispatch: Check field type for filtering
field_type(::ParametricField) = :parametric
field_type(::ParameterField) = :parameter
field_type(::ConstantField) = :constant

# Helper: Generate struct fields in reordered format: parametric first, then parameters, then constants
function generate_struct_fields(ordered_fields, param_type_params, parametric_type_params)
    struct_fields = Expr(:block)

    # Track indices for type parameters
    param_idx = 1
    parametric_idx = 1

    # First pass: add parametric fields
    for field in ordered_fields
        field_type(field) == :parametric &&
            (parametric_idx = add_struct_field!(struct_fields, field, parametric_idx))
    end

    # Second pass: add parameter fields
    for field in ordered_fields
        field_type(field) == :parameter &&
            (param_idx = add_struct_field!(struct_fields, field, param_idx))
    end

    # Third pass: add constant fields
    for field in ordered_fields
        field_type(field) == :constant && add_struct_field!(struct_fields, field, nothing)
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

# Multiple dispatch: Extract parameter from field (only for ParameterField)
# Mutates param_extractions and param_names
function extract_parameter!(
    param_extractions,
    param_names,
    field::ParameterField,
    value_ref,
)
    field_name = Symbol("description_of_", field.name)
    push!(param_names, field.name)
    push!(
        param_extractions.args,
        Expr(
            :(=),
            field.name,
            Expr(
                :call,
                value_ref,
                Expr(:parameters, :pars),
                Expr(:., :c, QuoteNode(field_name)),
            ),
        ),
    )
    return nothing
end

extract_parameter!(::Any, ::Any, ::ParametricField, _) = nothing
extract_parameter!(::Any, ::Any, ::ConstantField, _) = nothing

# Multiple dispatch: Check if field is a parameter field
is_parameter_field(::ParameterField) = true
is_parameter_field(::ParametricField) = false
is_parameter_field(::ConstantField) = false

# Multiple dispatch: Get parameter name (only for ParameterField)
get_parameter_name(field::ParameterField) = field.name
get_parameter_name(::ParametricField) = nothing
get_parameter_name(::ConstantField) = nothing

# Multiple dispatch: Count fields by type using dispatch
count_field_type(::Type{ParameterField}, fields) =
    count(f -> field_type(f) == :parameter, fields)
count_field_type(::Type{ParametricField}, fields) =
    count(f -> field_type(f) == :parametric, fields)

# Helper: Generate build_model function
function generate_build_model_function(constructor_name, ordered_fields, body)
    value_ref = Expr(:., :BuildConstructors, QuoteNode(:value))

    # Extract parameters: param = value(c.description_of_{param}; pars)
    param_extractions = Expr(:block)
    param_names = Symbol[]

    for field in ordered_fields
        extract_parameter!(param_extractions, param_names, field, value_ref)
    end

    # Combine parameter extractions with user body
    build_model_body = Expr(:block)
    append!(build_model_body.args, param_extractions.args)

    # Add user body
    if body isa Expr && body.head == :block
        append!(build_model_body.args, body.args)
    else
        push!(build_model_body.args, body)
    end

    # Generate function definition
    build_model_ref = Expr(:., :BuildConstructors, QuoteNode(:build_model))
    return Expr(
        :function,
        Expr(:call, build_model_ref, Expr(:(::), :c, constructor_name), :pars),
        build_model_body,
    )
end

# Helper: Parse arguments sequentially - processes model name, fields, and body in order
function parse_macro_arguments(model_name_expr, params_expr...)
    model_name = nothing
    ordered_fields = Union{ParametricField,ParameterField,ConstantField}[]
    body = nothing

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
                "@with_parameters: model name missing. Expected: @with_parameters(ModelName; fields..., begin ... end)",
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

        # Check if this is a body block
        if is_body_block(arg)
            body = extract_body_block(arg)
            break  # Body block should be last
        end

        # Handle parameters expression (contains fields separated by semicolon)
        if arg isa Expr && arg.head == :parameters
            for field_expr in arg.args
                field_expr isa LineNumberNode && continue

                if is_body_block(field_expr)
                    body = extract_body_block(field_expr)
                    break
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
        error("@with_parameters requires a begin...end block with model-building logic")
    end
    if isempty(ordered_fields)
        error("@with_parameters requires at least one field")
    end

    return model_name, ordered_fields, body
end

macro with_parameters(model_name_expr, params_expr...)
    # Parse arguments sequentially: model name, fields, and body
    model_name, ordered_fields, body =
        parse_macro_arguments(model_name_expr, params_expr...)

    # Collect all declared field names and parameter names
    all_declared_fields = Set{Symbol}()
    param_names = Symbol[]

    for field in ordered_fields
        push!(all_declared_fields, field.name)
        param_name = get_parameter_name(field)
        param_name !== nothing && push!(param_names, param_name)
    end

    # Validate field usages in body
    param_names_set = Set(param_names)
    used_fields = find_field_usages(body, all_declared_fields, param_names_set)

    # Check that all used fields are declared
    for field in used_fields
        if !(field in all_declared_fields)
            error(
                "Field '$(field)' is used in the body but not declared. " *
                "Please declare it: $(field), $(field)::P, or $(field)::Type",
            )
        end
    end

    # Count fields by type
    n_params = count_field_type(ParameterField, ordered_fields)
    n_parametric = count_field_type(ParametricField, ordered_fields)

    # Generate code
    constructor_name = Symbol("ConstructorOf", model_name)

    param_type_params, parametric_type_params =
        generate_type_parameters(n_params, n_parametric)
    struct_fields =
        generate_struct_fields(ordered_fields, param_type_params, parametric_type_params)
    struct_def = generate_struct_definition(
        constructor_name,
        param_type_params,
        parametric_type_params,
        struct_fields,
    )
    build_model_def =
        generate_build_model_function(constructor_name, ordered_fields, body)

    return Expr(:block, esc(struct_def), esc(build_model_def), Expr(:line, __source__))
end
