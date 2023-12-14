@isdefined(FactorGraph)                || include(string(@__DIR__, "/factor_graph.jl"))
@isdefined(ParfactorGraph)             || include(string(@__DIR__, "/parfactor_graph.jl"))
@isdefined(color_passing)              || include(string(@__DIR__, "/color_passing.jl"))
@isdefined(commutative_color_passing!) || include(string(@__DIR__, "/commutative_color_passing.jl"))
@isdefined(groups_to_pfg)              || include(string(@__DIR__, "/fg_to_pfg.jl"))
@isdefined(model_to_blog)              || include(string(@__DIR__, "/blog_parser.jl"))

function run_simple_crv_example()
	a = DiscreteRV("A")
	b = DiscreteRV("B")

	p = [
		([true,  true],  1),
		([true,  false], 2),
		([false, true],  2),
		([false, false], 3)
	]
	f = DiscreteFactor("f", [a, b], p)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_factor!(fg, f)
	add_edge!(fg, a, f)
	add_edge!(fg, b, f)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running commutative_color_passing!..."
	node_cols, factor_cols, commutatives, hists = commutative_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_simple_permute_example()
	a = DiscreteRV("A")
	b = DiscreteRV("B")
	c = DiscreteRV("C")

	p1 = [
		([true,  true],  1),
		([true,  false], 2),
		([false, true],  3),
		([false, false], 4)
	]
	p2 = [
		([true,  true],  1),
		([true,  false], 3),
		([false, true],  2),
		([false, false], 4)
	]
	f1 = DiscreteFactor("f1", [a, b], p1)
	f2 = DiscreteFactor("f2", [b, c], p2)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_rv!(fg, c)
	add_factor!(fg, f1)
	add_factor!(fg, f2)
	add_edge!(fg, a, f1)
	add_edge!(fg, b, f1)
	add_edge!(fg, b, f2)
	add_edge!(fg, c, f2)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running commutative_color_passing!..."
	node_cols, factor_cols, commutatives, hists = commutative_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_simple_combined_example()
	a = DiscreteRV("A")
	b = DiscreteRV("B")
	c = DiscreteRV("C")
	d = DiscreteRV("D")

	p1 = [
		([true,  true],  1),
		([true,  false], 2),
		([false, true],  3),
		([false, false], 4)
	]
	p2 = [
		([true,  true],  5),
		([true,  false], 6),
		([false, true],  6),
		([false, false], 7)
	]
	p3 = [
		([true,  true],  1),
		([true,  false], 3),
		([false, true],  2),
		([false, false], 4)
	]
	f1 = DiscreteFactor("f1", [a, b], p1)
	f2 = DiscreteFactor("f2", [b, c], p2)
	f3 = DiscreteFactor("f3", [c, d], p3)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_rv!(fg, c)
	add_rv!(fg, d)
	add_factor!(fg, f1)
	add_factor!(fg, f2)
	add_factor!(fg, f3)
	add_edge!(fg, a, f1)
	add_edge!(fg, b, f1)
	add_edge!(fg, b, f2)
	add_edge!(fg, c, f2)
	add_edge!(fg, c, f3)
	add_edge!(fg, d, f3)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running commutative_color_passing!..."
	node_cols, factor_cols, commutatives, hists = commutative_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_employee_example()
	ca = DiscreteRV("ComA")
	cb = DiscreteRV("ComB")
	cc = DiscreteRV("ComC")
	r = DiscreteRV("Rev")
	sa = DiscreteRV("SalA")
	sb = DiscreteRV("SalB")
	sc = DiscreteRV("SalC")

	p1 = [
		([true],  9),
		([false], 10)
	]
	p2 = [
		([true,  true,  true,  true],  1),
		([true,  true,  true,  false], 2),
		([true,  true,  false, true],  3),
		([true,  true,  false, false], 4),
		([true,  false, true,  true],  3),
		([true,  false, true,  false], 4),
		([true,  false, false, true],  5),
		([true,  false, false, false], 6),
		([false, true,  true,  true],  3),
		([false, true,  true,  false], 4),
		([false, true,  false, true],  5),
		([false, true,  false, false], 6),
		([false, false, true,  true],  5),
		([false, false, true,  false], 6),
		([false, false, false, true],  7),
		([false, false, false, false], 8)
	]
	p3 = [
		([true,  true,  true],  11),
		([true,  true,  false], 12),
		([true,  false, true],  13),
		([true,  false, false], 14),
		([false, true,  true],  15),
		([false, true,  false], 16),
		([false, false, true],  17),
		([false, false, false], 18)
	]
	f1 = DiscreteFactor("f1", [ca], p1)
	f2 = DiscreteFactor("f2", [cb], p1)
	f3 = DiscreteFactor("f3", [cc], p1)
	f4 = DiscreteFactor("f4", [ca, cb, cc, r], p2)
	f5 = DiscreteFactor("f5", [ca, r, sa], p3)
	f6 = DiscreteFactor("f6", [cb, r, sb], p3)
	f7 = DiscreteFactor("f7", [cc, r, sc], p3)

	fg = FactorGraph()
	add_rv!(fg, ca)
	add_rv!(fg, cb)
	add_rv!(fg, cc)
	add_rv!(fg, r)
	add_rv!(fg, sa)
	add_rv!(fg, sb)
	add_rv!(fg, sc)
	add_factor!(fg, f1)
	add_factor!(fg, f2)
	add_factor!(fg, f3)
	add_factor!(fg, f4)
	add_factor!(fg, f5)
	add_factor!(fg, f6)
	add_factor!(fg, f7)
	add_edge!(fg, ca, f1)
	add_edge!(fg, cb, f2)
	add_edge!(fg, cc, f3)
	add_edge!(fg, ca, f4)
	add_edge!(fg, cb, f4)
	add_edge!(fg, cc, f4)
	add_edge!(fg, r, f4)
	add_edge!(fg, ca, f5)
	add_edge!(fg, r, f5)
	add_edge!(fg, sa, f5)
	add_edge!(fg, cb, f6)
	add_edge!(fg, r, f6)
	add_edge!(fg, sb, f6)
	add_edge!(fg, cc, f7)
	add_edge!(fg, r, f7)
	add_edge!(fg, sc, f7)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running commutative_color_passing!..."
	node_cols, factor_cols, commutatives, hists = commutative_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_epid_example()
	epid       = DiscreteRV("Epid")
	sick_a     = DiscreteRV("SickA")
	sick_b     = DiscreteRV("SickB")
	travel_a   = DiscreteRV("TravelA")
	travel_b   = DiscreteRV("TravelB")
	treat_a_m1 = DiscreteRV("TreatAM1")
	treat_a_m2 = DiscreteRV("TreatAM2")
	treat_b_m1 = DiscreteRV("TreatBM1")
	treat_b_m2 = DiscreteRV("TreatBM2")

	p0 = [
		([true],  1),
		([false], 2)
	]
	p1 = [
		([true,  true,  true],  3),
		([true,  true,  false], 4),
		([true,  false, true],  5),
		([true,  false, false], 6),
		([false, true,  true],  7),
		([false, true,  false], 8),
		([false, false, true],  9),
		([false, false, false], 10)
	]
	p2 = [
		([true,  true,  true],  11),
		([true,  true,  false], 12),
		([true,  false, true],  13),
		([true,  false, false], 14),
		([false, true,  true],  15),
		([false, true,  false], 16),
		([false, false, true],  17),
		([false, false, false], 18)
	]

	f0 = DiscreteFactor("f0", [epid], p0)
	f1_1 = DiscreteFactor("f1a", [epid, travel_a, sick_a], p1)
	f1_2 = DiscreteFactor("f1b", [epid, travel_b, sick_b], p1)
	f2_1 = DiscreteFactor("f2am1", [epid, sick_a, treat_a_m1], p2)
	f2_2 = DiscreteFactor("f2am2", [epid, sick_a, treat_a_m2], p2)
	f2_3 = DiscreteFactor("f2bm1", [epid, sick_b, treat_b_m1], p2)
	f2_4 = DiscreteFactor("f2bm2", [epid, sick_b, treat_b_m2], p2)

	fg = FactorGraph()
	add_rv!(fg, epid)
	add_rv!(fg, sick_a)
	add_rv!(fg, sick_b)
	add_rv!(fg, travel_a)
	add_rv!(fg, travel_b)
	add_rv!(fg, treat_a_m1)
	add_rv!(fg, treat_a_m2)
	add_rv!(fg, treat_b_m1)
	add_rv!(fg, treat_b_m2)
	add_factor!(fg, f0)
	add_factor!(fg, f1_1)
	add_factor!(fg, f1_2)
	add_factor!(fg, f2_1)
	add_factor!(fg, f2_2)
	add_factor!(fg, f2_3)
	add_factor!(fg, f2_4)
	add_edge!(fg, epid, f0)
	add_edge!(fg, epid, f1_1)
	add_edge!(fg, epid, f1_2)
	add_edge!(fg, epid, f2_1)
	add_edge!(fg, epid, f2_2)
	add_edge!(fg, epid, f2_3)
	add_edge!(fg, epid, f2_4)
	add_edge!(fg, sick_a, f1_1)
	add_edge!(fg, sick_a, f2_1)
	add_edge!(fg, sick_a, f2_2)
	add_edge!(fg, sick_b, f1_2)
	add_edge!(fg, sick_b, f2_3)
	add_edge!(fg, sick_b, f2_4)
	add_edge!(fg, travel_a, f1_1)
	add_edge!(fg, travel_b, f1_2)
	add_edge!(fg, treat_a_m1, f2_1)
	add_edge!(fg, treat_a_m2, f2_2)
	add_edge!(fg, treat_b_m1, f2_3)
	add_edge!(fg, treat_b_m2, f2_4)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running commutative_color_passing!..."
	node_cols, factor_cols, commutatives, hists = commutative_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

@info "==> Running simple CRV example..."
run_simple_crv_example()

@info "==> Running simple permutation example..."
run_simple_permute_example()

@info "==> Running simple combined (CRV+permutation) example..."
run_simple_combined_example()

@info "==> Running employee example..."
run_employee_example()

@info "==> Running epid example..."
run_epid_example()