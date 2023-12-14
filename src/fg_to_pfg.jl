using Combinatorics

@isdefined(FactorGraph)    || include(string(@__DIR__, "/factor_graph.jl"))
@isdefined(ParfactorGraph) || include(string(@__DIR__, "/parfactor_graph.jl"))

"""
	groups_to_pfg(
		fg::FactorGraph,
		node_colors::Dict{RandVar, Int},
		factor_colors::Dict{Factor, Int},
		commutative_args_cache::Dict = Dict(),
		hist_cache::Dict = Dict()
	)::Tuple{ParfactorGraph, Dict{RandVar, String}}

Convert the groups in a factor graph `fg` to a parfactor graph.
Return a tuple consisting of the parfactor graph and a dictionary which
contains a mapping from each random variable to an individual object.

Corresponds to the steps from Section 4, mainly Definition 6, in the paper
to transform the obtained groups into a valid PFG.
"""
function groups_to_pfg(
	fg::FactorGraph,
	node_colors::Dict{RandVar, Int},
	factor_colors::Dict{Factor, Int},
	commutative_args_cache::Dict = Dict(),
	hist_cache::Dict = Dict()
)::Tuple{ParfactorGraph, Dict{RandVar, String}}
	pfg = ParfactorGraph()
	rv_groups, factor_groups = colors_to_groups(node_colors, factor_colors)
	rv_group_to_prv = Dict()
	prv_to_rv_group = Dict()
	f_group_to_pf = Dict()

	### Create placeholder parfactor graph (to have the edges in advance)
	for (rv_group_id, rv_group) in rv_groups
		r = range(rv_group[1]) # All rvs in group have the same range
		if length(rv_group) > 1
			lvs = [LogVar(string("L", rv_group_id), length(rv_group))]
		else
			lvs = []
		end
		prv = PRV(string("R", rv_group_id), r, lvs, nothing, [])
		rv_group_to_prv[rv_group_id] = prv
		prv_to_rv_group[prv] = rv_group
		add_prv!(pfg, prv)
	end
	for (f_group_id, f_group) in factor_groups
		pf = Parfactor(string("pf", f_group_id), Vector{PRV}(), [])
		f_group_to_pf[f_group_id] = pf
		add_parfactor!(pfg, pf)
		for f in f_group, rv in rvs(f)
			prv = rv_group_to_prv[node_colors[rv]]
			!has_edge(pfg, prv, pf) && push!(pf.prvs, prv) # Only add once
			add_edge!(pfg, prv, pf)
		end
	end

	### Add real logvars and potentials
	shared_logvars = Dict{PRV, Set{PRV}}()
	for (f_group_id, f_group) in factor_groups
		pf = f_group_to_pf[f_group_id]
		# Take any fg in the group as all have the same number of neighbors
		num_rvs      = length(rvs(f_group[1]))
		num_prvs     = length(prvs(pf))
		prvs_pf      = filter(prv -> !isempty(logvars(prv)), prvs(pf))
		f_group_size = length(f_group)

		# Set logvars
		@debug "Set logvars in pf $pf with |gr($pf)| = $f_group_size"
		if !isempty(prvs_pf) &&
				all(prv -> length(prv_to_rv_group[prv]) == f_group_size, prvs_pf)
			# All PRVs share the same (single) logvar with a domain
			# size equal to `f_group_size`
			@debug "All PRVs share the same (single) logvar."
			for prv in prvs_pf
				!haskey(shared_logvars, prv) && (shared_logvars[prv] = Set{PRV}())
				other_prvs = filter(x -> x != prv, prvs_pf)
				!isempty(other_prvs) && push!(shared_logvars[prv], other_prvs...)
			end
		elseif !isempty(prvs_pf) &&
				all(prv -> length(prv_to_rv_group[prv]) != f_group_size, prvs_pf)
			# All PRVs have exactly one logvar. Two PRVs share the same logvar
			# if and only if their group sizes are equal and their groundings
			# can be mapped to each other such that they occur in `k` factors
			# together with `k` being their group size.
			@debug "All PRVs have exactly one logvar but not all share the same."
			set_identical_lvs!(
				shared_logvars,
				fg,
				prv_to_rv_group,
				prvs_pf,
				f_group
			)
		elseif any(prv -> length(prv_to_rv_group[prv]) == f_group_size, prvs_pf)
			# PRVs with a group size equal to `f_group_size` have to logvars.
			# Conditions for two PRVs to share the same logvar is identical to
			# the previous case.
			@debug "There are PRVs with two logvars."
			for prv in prvs_pf
				# Add second logvar if necessary.
				length(prv_to_rv_group[prv]) == f_group_size || continue
				lv1 = logvars(prv)[1]
				push!(logvars(prv), LogVar(
					string(name(lv1), "_2"),
					length(prv_to_rv_group[prv]) ÷ domain_size(lv1)
				))
				lv1.name = string(name(lv1), "_1")
			end
			set_identical_lvs!(
				shared_logvars,
				fg,
				prv_to_rv_group,
				prvs_pf,
				f_group
			)
		end

		# Set potentials
		if num_rvs == num_prvs # Number of neighbors unchanged: No CRV
			pf.potentials = f_group[1].potentials
		else # Number of neighbors has changed: CRV needed
			@assert haskey(commutative_args_cache, f_group[1])
			# Commutative args are the same for all factors in group
			commutative_rvs = commutative_args_cache[f_group[1]]
			# Color is not necessarily identical for all rvs in group
			set_size = length(commutative_rvs)
			while set_size > 0
				done = false
				for subset in powerset(commutative_rvs, set_size, set_size)
					# Verify that all RVs have the same color
					if length(unique([node_colors[rv] for rv in subset])) == 1
						commutative_rvs = subset
						done = true
						break
					end
				end
				done && break
				set_size -= 1
			end
			# Color is now identical for all rvs in group
			prv = rv_group_to_prv[node_colors[commutative_rvs[1]]]
			@assert length(logvars(prv)) == 1
			prv.counted_over = logvars(prv)[1]
			push!(prv.counted_in, pf)
			# Move CRV to first position to match potentials
			pf.prvs = [prv; setdiff(prvs(pf), [prv])]
			counted_ps = hist_cache[f_group[1]][Set(commutative_rvs)]
			new_potentials = Dict{String, AbstractFloat}()
			for (config, pot) in counted_ps
				# pot is a multi-set containing exactly one value
				hist = replace(string(config[1]), "," => ";")
				rest = length(config) > 1 ? string(config[2:end]) : ""
				rest = replace(rest, "(" => "", ",)" => "")
				key = string(hist, isempty(rest) ? "" : ", ", rest)
				new_potentials[key] = collect(pot)[1]
			end
			pf.potentials = new_potentials
		end
	end

	# Set logvars for all PRVs in the whole parfactor graph
	@debug "Update logvars of PRVs to match shared logvars found before."
	assign_logvars!(shared_logvars)

	rv_to_i = Dict() # Maps names from fg to pfg for queries
	lvdom_indices = Dict() # Assumes that each PRV has at most two logvars
	for rv in rvs(fg)
		prv = rv_group_to_prv[node_colors[rv]]
		!haskey(lvdom_indices, prv) && (lvdom_indices[prv] = [1, 1])
		if isempty(logvars(prv))
			rv_to_i[rv] = name(prv)
		elseif length(logvars(prv)) == 1
			lv = logvars(prv)[1]
			individual = domain(lv)[lvdom_indices[prv][1]]
			rv_to_i[rv] = string(name(prv), "(", individual, ")")
			lvdom_indices[prv][1] += 1
		else # length(logvars(prv)) == 2
			individuals = [
				domain(logvars(prv)[1])[lvdom_indices[prv][1]],
				domain(logvars(prv)[2])[lvdom_indices[prv][2]]
			]
			rv_to_i[rv] = string(name(prv), "(", join(individuals, ", "), ")")
			if lvdom_indices[prv][2] < length(domain(logvars(prv)[2]))
				lvdom_indices[prv][2] += 1
			else
				lvdom_indices[prv][1] += 1
				lvdom_indices[prv][2] = 1
			end
		end
	end

	return pfg, rv_to_i
end

"""
	colors_to_groups(
		node_colors::Dict{RandVar, Int},
		factor_colors::Dict{Factor, Int}
	)::Tuple{Dict, Dict}

Convert colors returned by a color passing algorithm to groups of random
variables and factors, respectively.
"""
function colors_to_groups(
	node_colors::Dict{RandVar, Int},
	factor_colors::Dict{Factor, Int}
)::Tuple{Dict, Dict}
	rv_groups, factor_groups = Dict(), Dict()
	for (rv, color) in node_colors
		if !haskey(rv_groups, color)
			rv_groups[color] = []
		end
		push!(rv_groups[color], rv)
	end
	for (f, color) in factor_colors
		if !haskey(factor_groups, color)
			factor_groups[color] = []
		end
		push!(factor_groups[color], f)
	end
	return rv_groups, factor_groups
end

"""
	set_identical_lvs!(
		shared_logvars::Dict,
		fg::FactorGraph,
		prv_to_rv_group::Dict,
		prvs_pf::Vector,
		f_group::Vector
	)

Find all pairs of PRVs that share the same logvar and store them in
`shared_logvars`.
"""
function set_identical_lvs!(
	shared_logvars::Dict,
	fg::FactorGraph,
	prv_to_rv_group::Dict,
	prvs_pf::Vector,
	f_group::Vector
)
	for i in eachindex(prvs_pf)
		prv1 = prvs_pf[i]
		for j in i+1:length(prvs_pf)
			prv2 = prvs_pf[j]
			isshared = has_identical_logvar(
				fg,
				prv_to_rv_group[prv1],
				prv_to_rv_group[prv2],
				f_group
			)
			@debug "Check if $prv1 and $prv2 share the same logvar: $isshared"
			if isshared
				!haskey(shared_logvars, prv1) && (shared_logvars[prv1] = Set{PRV}())
				!haskey(shared_logvars, prv2) && (shared_logvars[prv2] = Set{PRV}())
				push!(shared_logvars[prv1], prv2)
				push!(shared_logvars[prv2], prv1)
			end
		end
	end
end

"""
	has_identical_logvar(
		fg::FactorGraph,
		rv_group1::Vector,
		rv_group2::Vector,
		f_group::Vector
	)::Bool

Check whether two groups of random variables represented by two PRVs should
share the same logvar.
"""
function has_identical_logvar(
	fg::FactorGraph,
	rv_group1::Vector,
	rv_group2::Vector,
	f_group::Vector
)::Bool
	# If one group is represented by a PRV with two logvars (i.e., the size of
	# the group is equal to the number of ground factors `f_group_size`), then
	# its PRV shares the same logvar with all other PRVs (because in 2-logvar
	# models, there are at most two logvars in a parfactor).
	f_group_size = length(f_group)
	if length(rv_group1) == f_group_size || length(rv_group2) == f_group_size
		return true
	elseif length(rv_group1) != length(rv_group2)
		return false
	end

	rv_group2_cpy = copy(rv_group2)
	for rv1 in rv_group1
		found = false
		for rv2 in rv_group2_cpy
			f_rv1 = filter(f -> f in f_group, edges(fg, rv1))
			f_rv2 = filter(f -> f in f_group, edges(fg, rv2))
			if f_rv1 == f_rv2
				deleteat!(rv_group2_cpy, findfirst(x -> x == rv2, rv_group2_cpy))
				found = true
				break
			end
		end
		found || return false
	end

	return isempty(rv_group2_cpy)
end

"""
	assign_logvars!(shared_logvars::Dict)

Assign identical logvars to PRVs that share the same logvar.
"""
function assign_logvars!(shared_logvars::Dict)
	visited = Set{PRV}()
	for (prv, _) in shared_logvars
		if !(prv in visited)
			assign_logvars_rec!(prv, shared_logvars, visited)
		end
	end
end

"""
	assign_logvars_rec!(prv::PRV, shared_logvars::Dict, visited::Set)

Helper function to recursively assign identical logvars to PRVs that share the
same logvar.
"""
function assign_logvars_rec!(prv::PRV, shared_logvars::Dict, visited::Set)
	push!(visited, prv)

	for prv2 in shared_logvars[prv]
		if length(logvars(prv)) == length(logvars(prv2))
			# Domain sizes are already set in this case.
			prv2.logvars = prv.logvars
			# Update counted logvar after replacement.
			!isnothing(counted_over(prv2)) && (prv2.counted_over = logvars(prv2)[1])
		elseif length(logvars(prv2)) == 2
			# Guaranteed to have exactly one logvar due to the if-condition.
			lv_prv = logvars(prv)[1]
			# If the shared logvar is not already incorporated in prv2, take
			# any unmodified logvar (i.e., '_' is still in the name) and
			# replace it by the shared logvar.
			if all(lv -> lv != lv_prv, logvars(prv2))
				group_size = prod([domain_size(lv) for lv in logvars(prv2)])
				cand = filter(lv -> occursin("_", name(lv)), logvars(prv2))
				# If the shared logvar is not already incorporated (i.e., the
				# if-condition is satisfied), then there must be at least one
				# unmodified logvar.
				@assert !isempty(cand)
				# Replace any placeholder logvar by the shared logvar and then
				# update the domain size of the other logvar if necessary.
				prv2.logvars = replace(logvars(prv2), cand[1] => lv_prv)
				# If the other logvar is still a placeholder, its domain size
				# has to be updated (in case it does not get replaced later).
				old_lvs = filter(lv -> occursin("_", name(lv)), logvars(prv2))
				@assert length(old_lvs) <= 1
				if !isempty(old_lvs)
					old_lvs[1].domain = [string(lowercase(name(old_lvs[1])), "_", i)
						for i in 1:(group_size ÷ domain_size(lv_prv))]
				end
			end
		end
		# else: prv has two logvars and prv2 has one logvar. This case is
		# handled in the recursive call with prv and prv2 being swapped.
		!(prv2 in visited) && assign_logvars_rec!(prv2, shared_logvars, visited)
	end
end