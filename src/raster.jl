"""
    rasterize_points(points, dx::AbstractFloat)

Rasterize points in 2D by a cell size `dx`.
Returns a dictionary containing the indices points that are in a cell.
"""
immutable Raster <: Associative
    pixels::Dict{Tuple{Int,Int}, Vector{Int}}
    r_min::Array{Float64,2}
    r_max::Array{Float64,2}
    cellsize::Float64
end

"""
`rasterize_points{T <: AbstractVector}(points::Vector{T}, dx::AbstractFloat) -> Raster`

Returns `Raster` of  points `pos` with quadratic cellsize `dx`
"""
function rasterize_points{T <: AbstractVector}(points::Vector{T}, dx::AbstractFloat)
    min_xy = SVector{3, Float64}(minimum(map(x->x[1], points)), minimum(map(x->x[2], points)), 0) # TODO do this better!
    pixels = Dict{Tuple{Int, Int}, Vector{Int}}()
    inv_dx = 1.0/dx
    for i = 1:length(points)
        @inbounds p = points[i] - min_xy
        key = (floor(Int, p[1]*inv_dx), floor(Int, p[2]*inv_dx))
        if haskey(pixels, key)
            push!(pixels[key], i)
        else
            pixels[key] = Vector{Int}()
            push!(pixels[key], i)
        end
    end
    p_min = minimum(points, 2)
    p_max = maximum(points, 2)
    return Raster(pixels,p_min,p_max,dx)
end

function rasterize_points{T <: Number}(points::Matrix{T}, dx::AbstractFloat)
    ndim = size(points, 1)
    npoints = size(points, 2)
    if isbits(T)
        new_data = reinterpret(SVector{ndim, T}, points, (length(points) ÷ ndim, ))
    else
        new_data = SVector{ndim, T}[SVector{ndim, T}(points[:, i]) for i in 1:npoints]
    end
    rasterize_points(new_data, dx)
end

Base.keys(r::Raster) = keys(r.pixels)
Base.values(r::Raster) = values(r.pixels)
Base.getindex(r::Raster, ind) = r.pixels[ind]
