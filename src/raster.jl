using StaticArrays

"""
    rasterize_points(points, dx::AbstractFloat)

Rasterize points in 2D by a cell size `dx`.
Returns a dictionary containing the indices points that are in a cell.
"""
immutable Raster{T<:SVector,U<:Integer} <: Associative{T,U}
    pixels::Dict{Tuple{U,U}, Vector{U}}
    r_min::T
    r_max::T
    cellsize::Float64
end

# from: https://github.com/andyferris/HeightOrderedGrid.jl/blob/master/src/HeightOrderedGrid.jl
# as opposed to: SVector{N, Float64}(minimum(map(x->x[1], points)), minimum(map(x->x[2], points)), 0)
function bounds{T}(points::Vector{T})
    xmin = typemax(eltype(eltype(T)))
    xmax = typemin(eltype(eltype(T)))
    ymin = typemax(eltype(eltype(T)))
    ymax = typemin(eltype(eltype(T)))

    for p ∈ points
        @inbounds x = p[1]
        if x < xmin
            xmin = x
        end
        if x > xmax
            xmax = x
        end

        @inbounds y = p[2]
        if y < ymin
            ymin = y
        end
        if y > ymax
            ymax = y
        end
    end

    return (xmin, xmax, ymin, ymax)
end


"""
`rasterize_points{T <: AbstractVector}(points::Vector{T}, dx::AbstractFloat) -> Raster`

Returns `Raster` of  points `pos` with quadratic cellsize `dx`
"""
function rasterize_points{T <: AbstractVector}(points::Vector{T}, dx::AbstractFloat)
    (xmin, xmax, ymin, ymax) = bounds(points)

    if size(eltype(points))[1] == 2
        min_xy = eltype(points)(xmin, ymin)
        max_xy = eltype(points)(xmax, ymax)
    elseif size(eltype(points))[1] == 3
        min_xy = eltype(points)(xmin, ymin, 0)
        max_xy = eltype(points)(xmax, ymax, 0)
    else
        throw("Unsupported input point dimensions")
    end

    pixels = Dict{Tuple{UInt32, UInt32}, Vector{UInt32}}()
    inv_dx = 1.0/dx
    for i = 1:length(points)
        @inbounds p = points[i] - min_xy
        key = (floor(UInt32, p[1]*inv_dx), floor(UInt32, p[2]*inv_dx))
        if haskey(pixels, key)
            push!(pixels[key], i)
        else
            pixels[key] = Vector{UInt32}()
            push!(pixels[key], i)
        end
    end
    return Raster(pixels,min_xy,max_xy,dx)
end

function rasterize_points{T <: Number}(points::Matrix{T}, dx::AbstractFloat)
    ndim = size(points, 1)
    npoints = size(points, 2)
    if isbits(T)
        new_data = reinterpret(SVector{ndim, T}, points, (npoints,))
    else
        new_data = SVector{ndim, T}[SVector{ndim, T}(points[:, i]) for i in 1:npoints]
    end
    rasterize_points(new_data, dx)
end

Base.keys(r::Raster) = keys(r.pixels)
Base.values(r::Raster) = values(r.pixels)
Base.getindex(r::Raster, ind) = r.pixels[ind]
