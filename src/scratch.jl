# This file is a part of Julia. License is MIT: https://julialang.org/license

using Test
const CC = Core.Compiler

include("irutils.jl")
include("newinterp.jl")


# OverlayMethodTable
# ==================

using Base.Experimental: @MethodTable, @overlay

# @overlay method with return type annotation
@MethodTable RT_METHOD_DEF
@overlay RT_METHOD_DEF Base.sin(x::Float64)::Float64 = cos(x)
@overlay RT_METHOD_DEF function Base.sin(x::T)::T where T<:AbstractFloat
    cos(x)
end

@newinterp MTOverlayInterp
@MethodTable OverlayedMT
CC.method_table(interp::MTOverlayInterp) = CC.OverlayMethodTable(CC.get_world_counter(interp), OverlayedMT)

functio" ⋯ 16494 bytes ⋯ "i, CONST_INVOKE_INTERP_WORLD, CONST_INVOKE_INTERP_WORLD)
    @test target_ci.rettype == Tuple{Float64,Nothing} # constprop'ed source
    # display(@ccall jl_uncompress_ir(target_ci.def.def::Any, C_NULL::Ptr{Cvoid}, target_ci.inferred::Any)::Any)

    raw = false
    lookup = @cfunction(custom_lookup, Any, (Any,Csize_t,Csize_t))
    params = CodegenParams(;
        debug_info_kind=Cint(0),
        safepoint_on_entry=raw,
        gcstack_arg=raw,
        lookup)
    io = IOBuffer()
    code_llvm(io, custom_lookup_target, (Bool,Int,); params)
    @test  occursin("j_sin_", String(take!(io)))
    @test !occursin("j_cos_", String(take!(io)))
end