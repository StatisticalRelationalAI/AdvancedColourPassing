using Random, Serialization, StatsBase

@isdefined(FactorGraph)      || include(string(@__DIR__, "/factor_graph.jl"))
@isdefined(color_passing)    || include(string(@__DIR__, "/color_passing.jl"))
@isdefined(colors_to_groups) || include(string(@__DIR__, "/fg_to_pfg.jl"))

"""
	load_from_file(path::String)

Load a serialized object from the given file.
"""
function load_from_file(path::String)
	io = open(path, "r")
	obj = deserialize(io)
	close(io)
	return obj
end

"""
	save_to_file(obj, path::String)

Serialize an object to a given file.
"""
function save_to_file(obj, path::String)
	open(path, "w") do io
		serialize(io, obj)
	end
end

"""
	permute_factors!(fg::FactorGraph, p::AbstractFloat, seed::Int=123)::Int

Permute the factors in a factor graph `fg` with probability `p` (i.e., change
the order of their arguments without changing their semantics).
Return the number of factors that have been permuted.
"""
function permute_factors!(fg::FactorGraph, p::AbstractFloat, seed::Int=123)::Int
	Random.seed!(seed)
	num_perm = 0
	for f in factors(fg)
		length(rvs(f)) > 1 || continue
		if rand() < p
			permute_factor!(f, seed + num_perm)
			num_perm += 1
		end
	end
	return num_perm
end

"""
	permute_factor!(f::Factor, seed::Int=123)

Permute the arguments of the given factor `f` (without changing its semantics).
"""
function permute_factor!(f::Factor, seed::Int=123)
	Random.seed!(seed)

	permutation = shuffle(1:length(rvs(f)))
	new_potentials = Dict()
	for c in collect(Base.Iterators.product(map(x -> range(x), f.rvs)...))
		new_c = collect(c)
		new_c = [new_c[i] for i in permutation]
		new_potentials[join(new_c, ",")] = potential(f, collect(c))
	end
	f.potentials = new_potentials
	f.rvs = [f.rvs[i] for i in permutation]
end

"""
	gen_randpots(ds::Array, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random potentials for a given array of ranges.
"""
function gen_randpots(rs::Array, seed::Int=123)::Vector{Tuple{Vector, Float64}}
	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], rand(0.1:0.1:2.0)))
	end

	return potentials
end

"""
	gen_asc_pots(ds::Array)::Vector{Tuple{Vector, Float64}}

Generate ascending potentials for a given array of ranges (especially useful
for debugging purposes).
"""
function gen_asc_pots(rs::Array)::Vector{Tuple{Vector, Float64}}
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	i = 1
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], i))
		i += 1
	end

	return potentials
end

"""
	gen_commutative_randpots(rs::Array, comm_indices::Vector{Int}, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random commutative potentials for a given array of ranges.
The second parameter `comm_indices` specifies the indices of the ranges
that should be commutative.
"""
function gen_commutative_randpots(
	rs::Array,
	comm_indices::Vector{Int},
	seed::Int=123
)::Vector{Tuple{Vector, Float64}}
	@assert !isempty(comm_indices)
	@assert all(idx -> 1 <= idx <= length(rs), comm_indices)
	@assert all(idx -> rs[idx] == rs[comm_indices[1]], comm_indices)

	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	com_range = rs[comm_indices[1]]
	vals = Dict()
	potentials = []
	for conf in Iterators.product(rs...)
		key_parts = Vector{Int}(undef, length(com_range))
		for (idx, range_val) in enumerate(com_range)
			com_vals = [val for (idx, val) in enumerate(conf) if idx in comm_indices]
			key_parts[idx] = count(x -> x == range_val, com_vals)
		end
		key = join(key_parts, "-")
		!haskey(vals, key) && (vals[key] = rand(0.1:0.1:2.0))
		push!(potentials, ([conf...], vals[key]))
	end

	return potentials
end

"""
	add_noise!(potentials::Dict, epsilon::Float64)

Add noise to the given potentials.
"""
function add_noise!(potentials::Dict, epsilon::Float64)
	for (key, _) in potentials
		potentials[key] += epsilon
	end
end

"""
	nanos_to_millis(t::AbstractFloat)::Float64

Convert nanoseconds to milliseconds.
"""
function nanos_to_millis(t::AbstractFloat)::Float64
    # Nano /1000 -> Micro /1000 -> Milli /1000 -> Second
    return t / 1000 / 1000
end