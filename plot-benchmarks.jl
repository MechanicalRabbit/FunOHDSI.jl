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
files = [file for file in readdir() if endswith(file, ".csv")]

# ╔═╡ 52a7dbb3-149a-4cad-a6da-229c027317fa
@bind file1 Select(files)

# ╔═╡ c8ae0708-459e-4606-a9de-08347eacf257
@bind file2 Select(files)

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
name1, df1 = loadbenchmark(file1)

# ╔═╡ d2b0bfb4-de0a-4c1a-afa7-603e32527017
name2, df2 = loadbenchmark(file2)

# ╔═╡ 45924ea7-7ff1-4b9c-af4b-dfab44908f74
begin
	scatter_df = innerjoin(select(df1, :cohort, :elapsed => :x),
		                   select(df2, :cohort, :elapsed => :y),
		                   on = :cohort)
	@df scatter_df scatter(:x, :y, xlabel = name1, ylabel = name2, legend = false, hover = :cohort)
end

# ╔═╡ f0fe3600-c25b-4f40-b775-b46023454dbb
begin
	diff_df = scatter_df[:, :]
	diff_df.d = (diff_df.x .- diff_df.y) ./ diff_df.x
	sort!(diff_df, [:d])
	@df diff_df plot(:d)
end

# ╔═╡ Cell order:
# ╠═e2e2e3e6-bf45-11eb-0990-ef4c69f166d2
# ╠═52a7dbb3-149a-4cad-a6da-229c027317fa
# ╠═c8ae0708-459e-4606-a9de-08347eacf257
# ╠═01387cbc-a371-40ed-a08b-c984cebd085a
# ╠═d2b0bfb4-de0a-4c1a-afa7-603e32527017
# ╠═45924ea7-7ff1-4b9c-af4b-dfab44908f74
# ╠═f0fe3600-c25b-4f40-b775-b46023454dbb
# ╠═b624cf52-0089-404e-af5b-c14a93ad79e8
# ╠═3909b6c0-efb3-40b9-891f-4067498c3df4
