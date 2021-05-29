### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ b624cf52-0089-404e-af5b-c14a93ad79e8
begin
	using PlutoUI
	using CSV
	using DataFrames
	using StatsPlots
	plotly()
end

# ╔═╡ e2e2e3e6-bf45-11eb-0990-ef4c69f166d2
available_files = [file for file in readdir() if endswith(file, ".csv")]

# ╔═╡ 52a7dbb3-149a-4cad-a6da-229c027317fa
@bind files MultiCheckBox(available_files, orientation = :column)

# ╔═╡ 3909b6c0-efb3-40b9-891f-4067498c3df4
function loadbenchmark(file)
	name = basename(file)
    if endswith(name, ".csv")
        name = name[1:end-4]
    end
    df = CSV.File(file, types = [String, Float64, Bool, Int, Int]) |> DataFrame
    df[!, :name] .= name
    name => df
end

# ╔═╡ 01387cbc-a371-40ed-a08b-c984cebd085a
begin
	names = String[]
	dfs = DataFrame[]
	for file in files
		name, df = loadbenchmark(file)
		push!(names, name)
		push!(dfs, df)
	end
	N = length(dfs)
end

# ╔═╡ 56e5b83d-0331-4789-9d7f-f57e31d23fa8
if !isempty(dfs)
	let df = combine(groupby(vcat(dfs...), :name), :elapsed => sum => :elapsed)
		@df df bar(:name, :elapsed,
			       title = "Total Time",
			       legend = :false,
		           formatter = :plain)
	end
end

# ╔═╡ d2b0bfb4-de0a-4c1a-afa7-603e32527017
begin
	scatters = []
	for i = 1:lastindex(dfs)-1
		let df1 = dfs[i],
			name1 = names[i]
			for j = i+1:lastindex(dfs)
				let df2 = dfs[j],
					name2 = names[j],
					df = innerjoin(select(df1, :cohort, :elapsed => :x),
						           select(df2, :cohort, :elapsed => :y),
						           on = :cohort),
					p = @df df scatter(:x, :y,
						               xlabel = name1,
						               ylabel = name2,
						               legend = false,
						               hover = :cohort,
					                   aspect_ratio = :equal,
					                   smooth = true)
					push!(scatters,
						  md"""
						  #### $name1 / $name2
						  $p
						  """)
				end
			end
		end
	end
	md"$(scatters...)"
end

# ╔═╡ 5fd2e131-7b5a-430b-ada0-c857b0781f54
if !isempty(dfs)
	let df = vcat(dfs...)
		@df df heatmap(:name, :cohort, :elapsed, hover = :cohort)
	end
end

# ╔═╡ Cell order:
# ╠═e2e2e3e6-bf45-11eb-0990-ef4c69f166d2
# ╠═52a7dbb3-149a-4cad-a6da-229c027317fa
# ╠═01387cbc-a371-40ed-a08b-c984cebd085a
# ╠═56e5b83d-0331-4789-9d7f-f57e31d23fa8
# ╠═d2b0bfb4-de0a-4c1a-afa7-603e32527017
# ╠═5fd2e131-7b5a-430b-ada0-c857b0781f54
# ╠═b624cf52-0089-404e-af5b-c14a93ad79e8
# ╠═3909b6c0-efb3-40b9-891f-4067498c3df4
