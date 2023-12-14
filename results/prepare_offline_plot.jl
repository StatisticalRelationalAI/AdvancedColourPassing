using Statistics

@isdefined(nanos_to_millis) || include(string(@__DIR__, "/../src/helper.jl"))

"""
	prepare_times(file::String, type::Symbol)

Parse the times of the BLOG inference output, build the average number of
queries needed to amortise the additional offline overhead and write the
results into a new `.csv` file.
The parameter `type` is either `:inter` or `:intra` and specifies the type of
the instances.
"""
function prepare_times(file::String, type::Symbol)
	@assert type in [:inter, :intra] "Unsupported type '$type' in evaluation!"

	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-offline-prepared.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	timeouts = filter_timeouts(file)
	file_cleaned = file
	if !isempty(timeouts)
		new_lines = []
		open(file, "r") do io
			for line in readlines(io)
				line_split = split(line, ",")
				if line_split[2] in timeouts
					@assert length(line_split) == 28
					new_line = join(vcat(line_split[1:7], fill(-1, 14)), ",")
					push!(new_lines, string(new_line, "\n"))
					push!(new_lines, string(join(line_split[8:end], ","), "\n"))
				else
					push!(new_lines, string(line, "\n"))
				end
			end
		end

		file_cleaned = replace(file, ".csv" => "_cleaned.csv")
		open(file_cleaned, "w") do io
			for line in new_lines
				write(io, line)
			end
		end
	end

	is_inter = type == :inter
	averages = Dict()
	open(file_cleaned, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			engine = cols[1]
			name = cols[2]
			parse(Float64, cols[12]) > 0 || continue # Skip timeouts
			algo = endswith(name, "-ccp") ? "ccp" : "cp"
			engine = string(engine, "-", algo)
			occursin("ve.VarElimEngine", engine) && continue # Skip VE
			time = nanos_to_millis(parse(Float64, cols[12]))
			d = match(r"d1?=(\d+)-", name)[1]
			if is_inter
				p = match(r"p=(\d+)-", name)[1]
			else
				p = split(name, "-")[2]
			end
			haskey(averages, p) || (averages[p] = Dict())
			haskey(averages[p], d) || (averages[p][d] = Dict())
			haskey(averages[p][d], engine) || (averages[p][d][engine] = [])
			push!(averages[p][d][engine], time)
		end
	end

	offline_times = Dict()
	open(replace(file, "_stats" => ""), "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			name = cols[1]
			if is_inter
				p = match(r"p=(\d+)-", name)[1]
			else
				p = split(name, "-")[2]
			end
			d = match(r"d1?=(\d+)-", name)[1]
			cp_algo = cols[3] == "color_passing" ? "cp" : "ccp"
			engine = string(cols[4], "-", cp_algo)
			occursin("ve.VarElimEngine", engine) && continue # Skip VE
			time = parse(Float64, cols[17])

			haskey(offline_times, p) || (offline_times[p] = Dict())
			haskey(offline_times[p], d) || (offline_times[p][d] = Dict())
			haskey(offline_times[p][d], engine) || (offline_times[p][d][engine] = [])
			push!(offline_times[p][d][engine], time)
		end
	end

	open(new_file, "a") do io
		pk = is_inter ? "p" : "k"
		write(io, "d,$pk,min_alpha,max_alpha,mean_alpha,median_alpha,std\n")
		for (p, ds) in averages
			for (d, _) in ds
				gain = averages[p][d]["fove.LiftedVarElim-cp"] .-
					averages[p][d]["fove.LiftedVarElim-ccp"]
				overhead = offline_times[p][d]["fove.LiftedVarElim-ccp"] .-
					offline_times[p][d]["fove.LiftedVarElim-cp"]
				alphas = round.(overhead ./ gain, digits=2)
				s = string(
					parse(Int, d), ",",
					parse(Int, p), ",",
					minimum(alphas), ",",
					maximum(alphas), ",",
					mean(alphas), ",",
					median(alphas), ",",
					std(alphas), "\n"
				)
				write(io, s)
			end
		end
	end
end

"""
	filter_timeouts(file::String)::Vector{String}

Return all file names for which a timeout occurred.
"""
function filter_timeouts(file::String)::Vector{String}
	res_file = replace(file, "_stats" => "")
	timeouts = []

	open(res_file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			name = cols[1]
			is_timeout = cols[17] == "timeout"
			is_timeout && push!(timeouts, name)
		end
	end

	return timeouts
end


prepare_times(string(@__DIR__, "/results-inter_stats.csv"), :inter)
prepare_times(string(@__DIR__, "/results-intra_stats.csv"), :intra)