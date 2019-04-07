push!(LOAD_PATH, "../src/")
using Documenter, Healpix

makedocs(
    modules = [Healpix],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    sitename = "Healpix.jl",
    pages = [
        "Introduction"  => "index.md",
        "Working with resolutions" => "resolutions.md",
        "Pixel functions" => "pixelfunc.md",
        "Map functions" => "mapfunc.md",
        "Spherical harmonics" => "alm.md",
        "Visualization" => "visualization.md",
        "Miscellanea" => "misc.md",
    ])

deploydocs(
    repo = "github.com/ziotom78/Healpix.jl.git",
)
