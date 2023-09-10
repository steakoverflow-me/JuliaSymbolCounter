module JuliaSymbolCounter

import MacroTools
import DataStructures: OrderedDict
import TOML
import LibGit2

ENV["GIT_TERMINAL_PROMPT"] = 0

dict = OrderedDict{String, Int}()

dict_lock = ReentrantLock()

function walk(ex)
    try
        sym = ex.head
        if (sym in [:macrocall, :call, :ref, :.])
            sym = first(ex.args)
        end
        if sym isa Symbol || sym isa String
            key = string(sym)
            lock(dict_lock) do
                dict[key] = get(dict, key, 0) + 1
            end
        end
    catch
        ex
    end
end

const DIR = "../JuliaRegistries"

repos = []
for (root, _, fs) in walkdir(DIR)
    package_files = filter(f-> f == "Package.toml", fs)
    reps = map(joinpath.(root, package_files)) do f
        read(f, String) |> TOML.parse |> dict -> dict["repo"]
    end
    global repos = vcat(repos, reps) 
end

const REPOS_NUM = length(repos)
const REPOS_STR_LEN = length(string(REPOS_NUM))

excs = []
repo_num = 0

function parse_dir(dir, repo_num)
    files = []
    for (repo_root, _, fs) in walkdir(dir)
        jl_files = filter(f-> splitext(f)[2] == ".jl", fs)
        files = vcat(files, joinpath.(repo_root, jl_files))
    end

    files_num = length(files)
    str_len = length(string(files_num))

    num = 0
    num_lock = ReentrantLock()

    @Threads.threads for file in files
        lock(num_lock) do
            num = num + 1
            @info "[$(length(excs)) : $(lpad(repo_num, REPOS_STR_LEN, " "))/$REPOS_NUM) : $(lpad(num, str_len, " "))/$files_num]\tParsing $file"
        end

        content = read(file, String) |> strip
        parsed = try 
            Meta.parseall(content) |> MacroTools.rmlines
        catch exc
            push!(excs, exc)
        end
        MacroTools.postwalk(walk, parsed)
    end
end

for repo in repos
    global repo_num = repo_num + 1
    @info "Loading repository $repo"
    dir = "./code-$(replace(repo, "/" => "_"))"
    try
        LibGit2.clone(repo, dir)
        parse_dir(dir, repo_num)
    catch exc
        push!(excs, exc)
    finally
        rm(dir; force=true, recursive=true)
    end
end

@info "Parsing finished! Dictionary length is $(length(dict))"

for exc in excs
    error(exc)
    @warn exc
end

print("\n\n\n")
const MAX_VAL_LEN = length(string(maximum(collect(values(dict)))))
for pair in map(p-> lpad(p.second, MAX_VAL_LEN, " ") * "\t" * p.first, collect(dict)) |> sort
    println(pair)
end

end # module JuliaSymbolCounter
