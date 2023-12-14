using Statistics

@isdefined(nanos_to_millis) || include(string(@__DIR__, "/../src/helper.jl"))

"""
	prepare_times(file::String, type::Symbol)

Parse the times of the BLOG inference output, build averages and
write the results into a new `.csv` file.
The parameter `type` is either `:inter` or `:intra` and specifies the type of
the instances.
"""
function prepare_times(file::String, type::Symbol)
	@assert type in [:inter, :intra] "Unsupported type '$type' in evaluation!"

	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared.csv")
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
			time = nanos_to_millis(parse(Float64, cols[12]))
			d = match(r"d1?=(\d+)-", name)[1]
			if is_inter
				p = match(r"p=(\d+)-", name)[1]
			else
				p = split(name, "-")[2]
			end
			haskey(averages, p) || (averages[p] = Dict())
			haskey(averages[p], engine) || (averages[p][engine] = Dict())
			haskey(averages[p][engine], d) || (averages[p][engine][d] = [])
			push!(averages[p][engine][d], time)
		end
	end

	if !is_inter
		k_avgs = Dict()
		open(replace(file, "_stats" => ""), "r") do io
			readline(io) # Remove header
			for line in readlines(io)
				cols = split(line, ",")
				name = cols[1]
				k = split(name, "-")[2]
				perc = parse(Float64, cols[9])
				d1 = match(r"-d1?=(\d+)", name)[1]
				d2 = match(r"-d2=(\d+)", name)
				d = isnothing(d2) ? d1 : string(d1, "-", d2[1])
				haskey(k_avgs, k) || (k_avgs[k] = Dict())
				haskey(k_avgs[k], d) || (k_avgs[k][d] = perc)
			end
		end
		k_avgs_arr = Dict()
		for (k, ds) in k_avgs
			k_avgs_arr[k] = []
			for (_, perc) in ds
				push!(k_avgs_arr[k], perc)
			end
		end
	end

	open(new_file, "a") do io
		pk = is_inter ? "p" : "k"
		perc = is_inter ? "" : ",k_perc"
		write(io, "engine,d,$pk$perc,min_time,max_time,mean_time,median_time,std\n")
		for (p, engines) in averages
			for (engine, d) in engines
				for (d, times) in d
					s = string(
						engine, ",",
						parse(Int, d), ",",
						parse(Int, p), ",",
						!is_inter ? string(mean(k_avgs_arr[p]), ",") : "",
						minimum(times), ",",
						maximum(times), ",",
						mean(times), ",",
						median(times), ",",
						std(times), "\n"
					)
					write(io, s)
				end
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