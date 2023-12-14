using Dates, Random

@isdefined(FactorGraph)  || include(string(@__DIR__, "/factor_graph.jl"))
@isdefined(gen_randpots) || include(string(@__DIR__, "/helper.jl"))
@isdefined(Query)        || include(string(@__DIR__, "/queries.jl"))
@isdefined(save_to_file) || include(string(@__DIR__, "/helper.jl"))

"""
	run_generation(
		type::Symbol,
		output_dir=string(@__DIR__, "/../instances/input/"),
		seed=123
	)

Run the instance generation procedure to generate the instances as
described in 'Section 5: Experiments' in the paper.
"""
function run_generation(
	type::Symbol, # Either :inter or :intra
	output_dir=string(@__DIR__, "/../instances/input/"),
	seed=123
)
	Random.seed!(seed)

	if type == :inter
		dom_sizes = [2, 4, 8, 12, 16, 20, 32, 64, 128, 256, 512, 1024]
		p_permute = [0.03, 0.05, 0.1, 0.15]

		for d1 in dom_sizes
			d2 = round(Int, log2(d1))
			d1_str = lpad(d1, 2, "0")
			d2_str = lpad(d2, 2, "0")
			for p in p_permute
				p_str = lpad(floor(Int, p * 100), 2, "0")
				@info "Generating epid model with d1=$d1, d2=$d2, and p=$p..."
				fg, queries = gen_epid(d1, d2, seed)
				k = permute_factors!(fg, p)
				k_str = lpad(k, 2, "0")
				save_to_file(
					(fg, queries),
					string(output_dir, "epid-$k_str-d1=$d1_str-d2=$d2_str-p=$p_str.ser")
				)
			end
		end

		for d in dom_sizes
			d_str = lpad(d, 2, "0")
			for n in [4, 6]
				n_str = lpad(n, 2, "0")
				for p in p_permute
					p_str = lpad(floor(Int, p * 100), 2, "0")
					@info "Generating double_shared_pf model with d=$d, n=$n, and p=$p..."
					fg, queries = gen_double_shared_pf(n, d, seed)
					k = permute_factors!(fg, p)
					k_str = lpad(k, 2, "0")
					save_to_file(
						(fg, queries),
						string(output_dir, "ds-$k_str-d=$d_str-n=$n_str-p=$p_str.ser")
					)
				end
			end
		end
	elseif type == :intra
		dom_sizes = [2, 4, 8, 12, 16, 20]
		n_commutative = [1, 3, 7]

		for dom_size in dom_sizes
			d_str = lpad(dom_size, 2, "0")
			for k in n_commutative
				@info "Generating k-employee model with k=$k and d=$dom_size..."
				fg, queries = gen_employee_k(k, dom_size, seed)
				k_str = lpad(k, 2, "0")
				save_to_file(
					(fg, queries),
					string(output_dir, "employee-$k_str-d=$d_str.ser")
				)
			end
		end

		for d1 in dom_sizes
			d2 = round(Int, log2(d1))
			d1_str = lpad(d1, 2, "0")
			d2_str = lpad(d2, 2, "0")
			for k in n_commutative
				@info "Generating k-epid model with k=$k, d1=$d1_str, and d2=$d2_str..."
				fg, queries = gen_epid_k(d1, d2, k, seed)
				k_str = lpad(k, 2, "0")
				save_to_file(
					(fg, queries),
					string(output_dir, "epid-$k_str-d1=$d1_str-d2=$d2_str.ser")
				)
			end
		end
	else
		@error "Unsupported type '$type' in generation!"
	end
end

"""
	gen_employee(dom_size::Int, seed::Int=123)::Tuple{FactorGraph, Vector{Query}}

Generate the employee example with the given domain size for employees.
"""
function gen_employee(
	dom_size::Int,
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert dom_size > 0

	Random.seed!(seed)
	fg = FactorGraph()

	rev = DiscreteRV("Rev")
	add_rv!(fg, rev)

	r = [true, false] # All random variables are Boolean
	p1 = gen_randpots([r], 0)
	p2 = gen_randpots([r, r, r], 1)
	p3 = gen_commutative_randpots(fill(r, dom_size+1), [i for i in 1:dom_size], 2)
	coms = Vector{DiscreteRV}(undef, dom_size)
	for i in 1:dom_size
		com = DiscreteRV("Com.$i")
		coms[i] = com
		sal = DiscreteRV("Sal.$i")
		add_rv!(fg, com)
		add_rv!(fg, sal)

		f_com = DiscreteFactor("f_com$i", [com], p1)
		add_factor!(fg, f_com)
		add_edge!(fg, com, f_com)

		f_sal = DiscreteFactor("f_sal$i", [com, rev, sal], p2)
		add_factor!(fg, f_sal)
		add_edge!(fg, com, f_sal)
		add_edge!(fg, rev, f_sal)
		add_edge!(fg, sal, f_sal)
	end

	f_rev = DiscreteFactor("f_rev", [coms..., rev], p3)
	add_factor!(fg, f_rev)
	for com in coms
		add_edge!(fg, com, f_rev)
	end
	add_edge!(fg, rev, f_rev)

	queries = [Query("Rev"), Query("Sal.1", Dict("Rev" => true))]

	return fg, queries
end

"""
	gen_employee_k(k::Int, dom_size::Int, seed::Int=123)::Tuple{FactorGraph, Vector{Query}}

Generate a model with `k` commutative factors using the employee example as
a foundation.
The domain size of the employees is `dom_size`.
"""
function gen_employee_k(
	k::Int,
	dom_size::Int,
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert dom_size > 0 && k > 0

	k == 1 && return gen_employee(dom_size, seed)

	Random.seed!(seed)
	fg = FactorGraph()

	last_rev = DiscreteRV("Rev.1")
	add_rv!(fg, last_rev)

	r = [true, false] # All random variables are Boolean
	p1 = gen_randpots([r], 0)
	p2 = gen_commutative_randpots(fill(r, dom_size+1), [i for i in 1:dom_size], 1)
	p3 = gen_randpots([r, r], 2)
	coms = Vector{DiscreteRV}(undef, dom_size)
	for i in 1:dom_size
		com = DiscreteRV("Com.$i")
		coms[i] = com
		add_rv!(fg, com)

		f_com = DiscreteFactor("f_com$i", [com], p1)
		add_factor!(fg, f_com)
		add_edge!(fg, com, f_com)
	end

	f_rev = DiscreteFactor("f_rev1", [coms..., last_rev], p2)
	add_factor!(fg, f_rev)
	for com in coms
		add_edge!(fg, com, f_rev)
	end
	add_edge!(fg, last_rev, f_rev)

	for l in 2:k
		sals = Vector{DiscreteRV}(undef, dom_size)
		for i in 1:dom_size
			sal = DiscreteRV("Sal.$l-$i")
			sals[i] = sal
			add_rv!(fg, sal)

			f_sal = DiscreteFactor("f_sal$l-$i", [last_rev, sal], p3)
			add_factor!(fg, f_sal)
			add_edge!(fg, last_rev, f_sal)
			add_edge!(fg, sal, f_sal)
		end

		last_rev = DiscreteRV("Rev.$l")
		add_rv!(fg, last_rev)
		f_rev = DiscreteFactor("f_rev$l", [sals..., last_rev], p2)
		add_factor!(fg, f_rev)
		for sal in sals
			add_edge!(fg, sal, f_rev)
		end
		add_edge!(fg, last_rev, f_rev)
	end

	queries = [Query("Rev.1"), Query("Com.1", Dict("Rev.1" => true))]

	return fg, queries
end

"""
	gen_epid_k(d1::Int, d2::Int, k::Int, seed::Int=123)::Tuple{FactorGraph, Vector{Query}}

Generate the epid example with the given domain sizes for people (`d1`) and
medications (`d2`) and `k` extra commutative factors.
"""
function gen_epid_k(
	d1::Int,
	d2::Int,
	k::Int,
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert d1 > 0 && d2 > 0 && k > 0

	Random.seed!(seed)
	fg = FactorGraph()

	r = [true, false] # All random variables are Boolean
	p0 = gen_randpots([r], 0)
	p1 = gen_randpots([r, r, r], 1)
	p2 = gen_randpots([r, r, r], 2)
	p3 = gen_commutative_randpots(fill(r, d1 + 1), [i for i in 1:d1], 3)

	epid = DiscreteRV("Epid")
	f0 = DiscreteFactor("f0", [epid], p0)
	add_rv!(fg, epid)
	add_factor!(fg, f0)
	add_edge!(fg, epid, f0)

	com_rvs = Vector{DiscreteRV}(undef, d1)
	for i in 1:d1
		travel = DiscreteRV("Travel.$i")
		sick = DiscreteRV("Sick.$i")
		com_rvs[i] = sick
		add_rv!(fg, travel)
		add_rv!(fg, sick)
		f1 = DiscreteFactor("f1_$i", [travel, sick, epid], p1)
		add_factor!(fg, f1)
		add_edge!(fg, travel, f1)
		add_edge!(fg, sick, f1)
		add_edge!(fg, epid, f1)
		for j in 1:d2
			treat = DiscreteRV("Treat.$i-$j")
			add_rv!(fg, treat)
			f2 = DiscreteFactor("f2_$i-$j", [sick, epid, treat], p2)
			add_factor!(fg, f2)
			add_edge!(fg, sick, f2)
			add_edge!(fg, epid, f2)
			add_edge!(fg, treat, f2)
		end
	end

	last_com = DiscreteRV("R.1")
	for l in 1:k
		if l % 2 == 0
			com_rvs = [DiscreteRV("S$l.$i") for i in 1:d1]
			for rv in com_rvs
				add_rv!(fg, rv)
			end
		else
			last_com = DiscreteRV("R.$l")
			add_rv!(fg, last_com)
		end
		f = DiscreteFactor("f3_$l", [com_rvs..., last_com], p3)
		add_factor!(fg, f)
		for rv in com_rvs
			add_edge!(fg, rv, f)
		end
		add_edge!(fg, last_com, f)
	end

	queries = [Query("Travel.1"), Query("Treat.1-1")]

	return fg, queries
end

"""
	gen_epid(d1::Int, d2::Int, seed::Int=123)::Tuple{FactorGraph, Vector{Query}}

Generate the epid example with the given domain sizes for people (`d1`) and
medications (`d2`).
"""
function gen_epid(
	d1::Int,
	d2::Int,
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert d1 > 0 && d2 > 0

	Random.seed!(seed)
	fg = FactorGraph()

	r = [true, false] # All random variables are Boolean
	p0 = gen_randpots([r], 0)
	p1 = gen_randpots([r, r, r], 1)
	p2 = gen_randpots([r, r, r], 2)

	epid = DiscreteRV("Epid")
	f0 = DiscreteFactor("f0", [epid], p0)
	add_rv!(fg, epid)
	add_factor!(fg, f0)
	add_edge!(fg, epid, f0)

	for i in 1:d1
		travel = DiscreteRV("Travel.$i")
		sick = DiscreteRV("Sick.$i")
		add_rv!(fg, travel)
		add_rv!(fg, sick)
		f1 = DiscreteFactor("f1_$i", [travel, sick, epid], p1)
		add_factor!(fg, f1)
		add_edge!(fg, travel, f1)
		add_edge!(fg, sick, f1)
		add_edge!(fg, epid, f1)
		for j in 1:d2
			treat = DiscreteRV("Treat.$i-$j")
			add_rv!(fg, treat)
			f2 = DiscreteFactor("f2_$i-$j", [sick, epid, treat], p2)
			add_factor!(fg, f2)
			add_edge!(fg, sick, f2)
			add_edge!(fg, epid, f2)
			add_edge!(fg, treat, f2)
		end
	end

	queries = [Query("Travel.1"), Query("Treat.1-1")]

	return fg, queries
end

"""
	gen_single_distinct_pf(
		dom_sizes::Vector{Int},
		seed::Int=123
	)::Tuple{FactorGraph, Vector{Query}}

Generate a factor graph stemming from grounding a parfactor graph with a single
parfactor that has `|dom_sizes|` PRVs as arguments who do not share any logvar
(in particular, all PRVs have exactly one distinct logvar).
"""
function gen_single_distinct_pf(
	dom_sizes::Vector{Int},
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert !isempty(dom_sizes) && all(d -> d > 0, dom_sizes)

	Random.seed!(seed)
	fg = FactorGraph()

	r = [true, false] # All random variables are Boolean
	p = gen_randpots(fill(r, length(dom_sizes)), 0)

	rvs = Dict{String, DiscreteRV}()
	i = 1
	for conf in Base.Iterators.product([1:d for d in dom_sizes]...)
		rvs_conf = Vector{DiscreteRV}(undef, length(conf))
		for (index, value) in enumerate(conf)
			rv_name = "R$(index)_$value"
			if !haskey(rvs, rv_name)
				rv = DiscreteRV(rv_name)
				add_rv!(fg, rv)
				rvs[rv_name] = rv
			end
			rvs_conf[index] = rvs[rv_name]
		end
		f = DiscreteFactor("f_$i", rvs_conf, p)
		add_factor!(fg, f)
		for rv in rvs_conf
			add_edge!(fg, rv, f)
		end
		i += 1
	end

	queries = [Query("R1_1")]
	length(dom_sizes) > 1 && push!(queries, Query("R2_1"))

	return fg, queries
end

"""
	gen_double_shared_pf(
		num_prvs::Int,
		dom_size::Int,
		seed::Int=123
	)::Tuple{FactorGraph, Vector{Query}}

Generate a factor graph stemming from grounding a parfactor graph with two
parfactors, one connecting a parameterless PRV with a PRV R having a logvar X
with domain size `dom_size`, and the other parfactor connecting R as well as
`num_prvs` additional PRVs with the same logvar X.
"""
function gen_double_shared_pf(
	num_prvs::Int,
	dom_size::Int,
	seed::Int=123
)::Tuple{FactorGraph, Vector{Query}}
	@assert num_prvs > 0 && dom_size > 0

	Random.seed!(seed)
	fg = FactorGraph()

	r = [true, false] # All random variables are Boolean
	p0 = gen_asc_pots(fill(r, 2))
	p1 = gen_asc_pots(fill(r, num_prvs + 1))

	rv0 = DiscreteRV("R0")
	add_rv!(fg, rv0)
	for d in 1:dom_size
		rv1 = DiscreteRV("R1_$d")
		add_rv!(fg, rv1)
		f1 = DiscreteFactor("f1_$d", [rv0, rv1], p0)
		add_factor!(fg, f1)
		add_edge!(fg, rv0, f1)
		add_edge!(fg, rv1, f1)
		other_rvs = []
		for i in 1:num_prvs
			rv = DiscreteRV("R$(i+1)_$d")
			add_rv!(fg, rv)
			push!(other_rvs, rv)
		end
		f2 = DiscreteFactor("f2_$d", [rv1, other_rvs...], p1)
		add_factor!(fg, f2)
		add_edge!(fg, rv1, f2)
		for rv in other_rvs
			add_edge!(fg, rv, f2)
		end
	end

	queries = [Query("R0"), Query("R1_1")]

	return fg, queries
end


### Entry point ###
l = length(ARGS)
allowed = ["all", "inter", "intra"]
if l < 1 || (l == 1 && !(ARGS[1] in allowed)) ||
		(l > 1 && !all(a -> a in setdiff(allowed, ["all"]), ARGS))
	@error string(
		"Run this file via 'julia $PROGRAM_FILE <TYPE>' ",
		"with <TYPE> being 'all' or one or more (separated by spaces) of ",
		join(setdiff(allowed, ["all"]), ", "),
		"."
	)
	exit()
end

start = Dates.now()

types = ARGS[1] == "all" ? setdiff(allowed, ["all"]) : ARGS
for t in types
	if t == "inter"
		run_generation(:inter, string(@__DIR__, "/../instances/input/inter/"))
	elseif t == "intra"
		run_generation(:intra, string(@__DIR__, "/../instances/input/intra/"))
	else
		@error "Unsupported input type: $t"
	end
end

@info "=> Start:      $start"
@info "=> End:        $(Dates.now())"
@info "=> Total time: $(Dates.now() - start)"