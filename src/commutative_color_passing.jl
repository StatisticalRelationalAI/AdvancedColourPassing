using Combinatorics, Multisets

@isdefined(FactorGraph) || include(string(@__DIR__, "/factor_graph.jl"))

"""
	commutative_color_passing!(fg::FactorGraph, factor_colors = Dict{Factor, Int}())::Tuple{Dict{RandVar, Int}, Dict{Factor, Int}, Dict{Factor, Vector{DiscreteRV}}, Dict{Factor, Dict{Set, Dict}}}

Apply commutative color passing to a given factor graph `fg`.
Return a tuple of four dictionaries, the first mapping each random variable
to a group of random variables, the second mapping each factor to a group
of factors, the third mapping each factor to a cache of commutative arguments,
and the fourth mapping each factor to a cache of histograms.

Corresponds to Algorithm 1 "Advanced Colour Passing" in the paper.

## Examples
```jldoctest
julia> fg = FactorGraph();
julia> nc, fc, com_cache, h_cache = commutative_color_passing!(fg)
```
"""
function commutative_color_passing!(
	fg::FactorGraph,
	factor_colors = Dict{Factor, Int}()
)::Tuple{Dict{RandVar, Int}, Dict{Factor, Int}, Dict{Factor, Vector{DiscreteRV}}, Dict{Factor, Dict{Set, Dict}}}
	node_colors = Dict{RandVar, Int}()
	hist_cache = Dict{Factor, Dict{Set, Dict}}() # Cache for histograms
	commutative_args_cache = Dict{Factor, Vector{DiscreteRV}}()

	initcolors_ccp!(node_colors, factor_colors, fg, hist_cache)

	while true
		changed = false
		f_signatures = Dict{Factor, Vector{Int}}()
		for f in factors(fg)
			f_signatures[f] = []
			for node in rvs(f)
				push!(f_signatures[f], node_colors[node])
			end
			push!(f_signatures[f], factor_colors[f])
		end

		changed |= assigncolors_ccp!(factor_colors, f_signatures, fg, hist_cache)

		rv_signatures = Dict{RandVar, Vector{Tuple{Int,Int}}}()
		for node in rvs(fg)
			rv_signatures[node] = []
			for f in edges(fg, node)
				if !haskey(commutative_args_cache, f)
					commutative_args_cache[f] = commutative_args(f, fg, hist_cache)
				end
				if node in commutative_args_cache[f]
					push!(rv_signatures[node], (factor_colors[f], 0))
				else
					push!(rv_signatures[node], (factor_colors[f], rvpos(f, node)))
				end
			end
			sort!(rv_signatures[node])
			push!(rv_signatures[node], (node_colors[node], 0))
		end

		changed |= assigncolors_ccp!(node_colors, rv_signatures, fg)

		!changed && break
	end

	return node_colors, factor_colors, commutative_args_cache, hist_cache
end

"""
	initcolors_ccp!(node_colors::Dict{RandVar, Int}, factor_colors::Dict{Factor, Int}, fg::FactorGraph, hist_cache::Dict{Factor, Dict{Set, Dict}})

Initialize the color dictionaries `node_colors` and `factor_colors` for the
factor graph `fg`.
"""
function initcolors_ccp!(
	node_colors::Dict{RandVar, Int},
	factor_colors::Dict{Factor, Int},
	fg::FactorGraph,
	hist_cache::Dict{Factor, Dict{Set, Dict}}
)
	assigncolors_ccp!(node_colors, Dict{RandVar, Vector{Tuple{Int, Int}}}(), fg)
	assigncolors_ccp!(factor_colors, Dict{Factor, Vector{Int}}(), fg, hist_cache)
end

"""
	assigncolors_ccp!(node_colors::Dict{RandVar, Int}, rv_signatures::Dict{RandVar, Vector{Tuple{Int, Int}}}, fg::FactorGraph)::Bool

Re-assign colors to the random variables in `fg` based on the signatures
`rv_signatures`.
"""
function assigncolors_ccp!(
	node_colors::Dict{RandVar, Int},
	rv_signatures::Dict{RandVar, Vector{Tuple{Int, Int}}},
	fg::FactorGraph
)::Bool
	colors = Dict()
	current_color = 0
	changed = false
	for rv in rvs(fg)
		key = isempty(rv_signatures) ? (range(rv), evidence(rv)) : rv_signatures[rv]
		if !haskey(colors, key)
			colors[key] = current_color
			current_color += 1
		end
		if haskey(node_colors, rv) && node_colors[rv] != colors[key]
			changed = true
		end
		node_colors[rv] = colors[key]
	end
	return changed
end

"""
	assigncolors_ccp!(factor_colors::Dict{Factor, Int}, f_signatures::Dict{Factor, Vector{Int}}, fg::FactorGraph, hist_cache::Dict{Factor, Dict{Set, Dict}})::Bool

Re-assign colors to the factors in `fg` based on the signatures `f_signatures`.
"""
function assigncolors_ccp!(
	factor_colors::Dict{Factor, Int},
	f_signatures::Dict{Factor, Vector{Int}},
	fg::FactorGraph,
	hist_cache::Dict{Factor, Dict{Set, Dict}}
)::Bool
	colors = Dict()
	current_color = numrvs(fg)
	current_groups = Dict()
	changed = false
	key = nothing
	for f in factors(fg)
		if isempty(f_signatures)
			found_match = false
			for f_group in values(current_groups)
				f2 = f_group[1] # Guaranteed to have at least one element
				has_same_arg_types(f, f2) || continue
				if !haskey(hist_cache, f)
					hist_cache[f] = Dict()
					hist_cache[f][Set(rvs(f))] = buildhistograms(f, rvs(f))
				end
				h1 = hist_cache[f][Set(rvs(f))]
				if !haskey(hist_cache, f2)
					hist_cache[f2] = Dict()
					hist_cache[f2][Set(rvs(f2))] = buildhistograms(f2, rvs(f2))
				end
				h2 = hist_cache[f2][Set(rvs(f2))]
				if h1 == h2
					if permute_args!(f, f2)
						key = potentials(f2)
						found_match = true
						break
					end
				end
			end
			# No match found
			!found_match && (key = potentials(f))
			if !haskey(current_groups, key)
				current_groups[key] = []
			end
			push!(current_groups[key], f)
		else
			key = f_signatures[f]
		end
		if !haskey(colors, key)
			colors[key] = current_color
			current_color += 1
		end
		if haskey(factor_colors, f) && factor_colors[f] != colors[key]
			changed = true
		end
		factor_colors[f] = colors[key]
	end
	return changed
end

"""
	has_same_arg_types(f1::Factor, f2::Factor)::Bool

Check whether the arguments of `f1` and `f2` have the same types, i.e.,
a bijection between the arguments of `f1` and `f2` exists that maps
each argument of `f1` to an argument of `f2` with the same range.
"""
function has_same_arg_types(f1::Factor, f2::Factor)::Bool
	length(rvs(f1)) == length(rvs(f2)) || return false
	rvsf2 = copy(rvs(f2))
	for rv1 in rvs(f1)
		for rv2 in rvsf2
			if range(rv1) == range(rv2)
				deleteat!(rvsf2, findfirst(x -> x == rv2, rvsf2))
				break
			end
		end
	end
	return isempty(rvsf2)
end

"""
	buildhistograms(f::Factor, args::Vector{DiscreteRV})::Dict

Build histograms for the factor `f` while considering only a subset `args`
of the arguments of `f`.

The histograms are used both for Section 3.1 and Section 3.2 in the paper.
"""
function buildhistograms(f::Factor, args::Vector{DiscreteRV})::Dict
	# Note: Currently only for Boolean RVs
	@assert all(x -> range(x) == [true, false], args)
	non_counted = setdiff(rvs(f), args)
	non_counted_pos = [findfirst(x -> x == rv, rvs(f)) for rv in non_counted]
	histograms = Dict()
	for c in sort([collect((Base.Iterators.product(map(x -> range(x), rvs(f))...)))...], rev=true)
		c = collect(c)
		p = potential(f, c)
		counts = [0, 0]
		non_counted_vals = []
		for pos in eachindex(c)
			if pos in non_counted_pos
				push!(non_counted_vals, c[pos])
			else
				# Note: Only for Boolean RVs
				if c[pos] == true
					counts[1] += 1
				else
					counts[2] += 1
				end
			end
		end
		key = isempty(non_counted_vals) ? (counts,) : (counts, non_counted_vals...)
		if !haskey(histograms, key)
			histograms[key] = Multiset()
		end
		push!(histograms[key], p)
	end

	return histograms
end

"""
	permute_args!(f1::Factor, f2::Factor)::Bool

Permute the arguments of `f1` such that its potentials are identical to
those of `f2`. Return `true` if a permutation was found and performed,
otherwise `false` (in this case, no changes are made).

Corresponds to Section 3.2 in the paper; is only called after the initial
histogram-check is successful.
"""
function permute_args!(f1::Factor, f2::Factor)::Bool
	@assert length(rvs(f1)) == length(rvs(f2))

	# Note: Currently only for Boolean RVs
	@assert all(x -> range(x) == [true, false], rvs(f1))
	@assert all(x -> range(x) == [true, false], rvs(f2))

	for perm in permutations(1:length(rvs(f1)))
		found_mismatch = false
		for c in sort([collect((Base.Iterators.product(map(x -> range(x), rvs(f1))...)))...], rev=true)
			conf = collect(c)
			conf_permutated = [conf[perm[i]] for i in eachindex(conf)]
			if potential(f2, conf) != potential(f1, conf_permutated)
				found_mismatch = true
				break
			end
		end
		if !found_mismatch
			rvs_new_order = Vector{DiscreteRV}(undef, length(rvs(f1)))
			for i in eachindex(perm)
				rvs_new_order[perm[i]] = f1.rvs[i]
			end
			f1.rvs = rvs_new_order
			f1.potentials = f2.potentials
			return true
		end
	end

	return false
end

"""
	commutative_args(
		f::Factor,
		fg::FactorGraph,
		hist_cache::Dict{Factor, Dict{Set, Dict}}
	)::Vector{DiscreteRV}

Compute the commutative arguments of `f` in the factor graph `fg`.

Corresponds so Section 3.1 in the paper.
"""
function commutative_args(
	f::Factor,
	fg::FactorGraph,
	hist_cache::Dict{Factor, Dict{Set, Dict}}
)::Vector{DiscreteRV}
	# Note: Currently only for Boolean RVs
	# Note: When generalized to non-Boolean RVs, ranges should be checked for equality first

	subset_size = length(rvs(f))
	while subset_size > 1
		for subset in powerset(rvs(f), subset_size, subset_size) # Consider subsets of a specific size only
			# Verify that all RVs have the same number of neighbors
			length(unique([length(edges(fg, rv)) for rv in subset])) == 1 || continue

			is_commutative = true
			if !haskey(hist_cache, f)
				hist_cache[f] = Dict()
			end
			if !haskey(hist_cache[f], Set(subset))
				hist_cache[f][Set(subset)] = buildhistograms(f, subset)
			end
			histograms = hist_cache[f][Set(subset)]
			for h in values(histograms)
				if length(unique(h)) > 1
					is_commutative = false
					break
				end
			end
			is_commutative && return collect(subset)
		end
		subset_size -= 1
	end

	return [] # No commutative arguments found
end