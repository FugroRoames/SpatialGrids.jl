const VoxelId = NTuple{3, Int}

"""
    SparseVoxelGrid(points, voxel_size)
    SparseVoxelGrid(points, voxel_size::NTuple{3, AbstractFloat})

Creates a sparse spatial grid by organising 3D points into voxels. `points` can either
be a 3xN matrix or a `PointCloud`. `voxel_size` will either create uniformly sized voxels in each
axis or if it is a 3D tuple the size of each axis can be specified.

### Example

To create a spatial grid with voxel side length of 10 metres for arbitrary points:
```julia
using PointClouds
points = rand(3, 100000) * 20.0
grid = SparseVoxelGrid(points, 10.0)
```

The created grid is an iteratable object which returns a `Voxel` in each iteration.
Each voxel can be accessed directly with a `for` loop or all voxels can be `collect`ed into an array.
Likewise, the returned `Voxel` is an iterable object that returns the point indices:
```julia
# Iterate through each voxel in grid
for voxel in grid
    # Get each point index in voxel
    for idx in voxel
        # Do stuff with points[:,idx]
    end
    # Or, you may want all point indices in a voxel
    all_point_indices = collect(voxel)
end
```
"""
struct SparseVoxelGrid{T <: Real}
    voxel_size::SVector{3, T}
    voxel_info::Dict{VoxelId, UnitRange{Int}}
    point_indices::Vector{Int}
end

function SparseVoxelGrid(points::AbstractVector{T1}, voxel_size::SVector{3, T2}) where {T1 <: AbstractVector, T2 <: Real}
    npoints = length(points)

    # In order to avoid allocating a vector for each voxel, we construct the data structure in a backward-looking order.

    # Assign each point to a voxel id
    voxel_ids = Vector{VoxelId}(undef, npoints)
    for j = 1:npoints
        @inbounds voxel_ids[j] = make_voxel_id(points[j], voxel_size)
    end

    # Count the number of points in each voxel
    group_counts = Dict{VoxelId, Int}()
    for id in voxel_ids
        group_counts[id] = get(group_counts, id, 0) + 1
    end

    # Allocate ranges for the indices of points in each voxel based on the counts
    voxel_info = Dict{VoxelId, UnitRange{Int}}()
    current_index = 1
    # TODO: Using keys(group_counts) is a workaround for inference in julia-0.5 - let's just iterate over the dictionary in the future
    for group_id in keys(group_counts)
        group_size = group_counts[group_id]
        voxel_info[group_id] = UnitRange(current_index, current_index+group_size-1)
        current_index += group_size
    end

    # Place indices for points into the appropriate index range for the associated voxel
    point_indices = Vector{Int}(undef, npoints)
    for j = 1:npoints
        id = voxel_ids[j]
        index_in_group = group_counts[id]
        group_counts[id] = index_in_group - 1
        point_indices[first(voxel_info[id]) + index_in_group-1] = j
    end
    return SparseVoxelGrid(voxel_size, voxel_info, point_indices)
end

function SparseVoxelGrid(points::Matrix{T1}, voxel_size) where T1 <: Real
    ndims, npoints = size(points)
    @assert ndims == 3
    new_data = reshape(reinterpret(SVector{3, T1}, vec(points)), (length(points) ÷ 3, ))
    SparseVoxelGrid(new_data[1:end], get_voxel_size(voxel_size))
end

function SparseVoxelGrid(points::AbstractVector{T1}, voxel_size) where T1 <: AbstractVector
    SparseVoxelGrid(points, get_voxel_size(voxel_size))
end

get_voxel_size(voxel_size::NTuple{3, T}) where T <: Real  = SVector{3, T}(voxel_size)
get_voxel_size(voxel_size::T) where T <: Real             = SVector{3, T}(voxel_size, voxel_size, voxel_size)
get_voxel_size(voxel_size::SVector{3, T}) where T <: Real = voxel_size

Base.length(grid::SparseVoxelGrid) = length(grid.voxel_info)
Base.isempty(grid::SparseVoxelGrid) = isempty(grid.voxel_info)
Base.haskey(grid::SparseVoxelGrid, k) = haskey(grid.voxel_info, k)

function Base.show(io::IO, grid::SparseVoxelGrid)
    println(io, typeof(grid))
    println(io, "  Number of voxels: ", length(grid))
    println(io, "  Number of points in grid: ", length(grid.point_indices))
    print(io, "  Side length per dimension: ", collect(grid.voxel_size))
end

"""
    make_voxel_id(point::AbstractVector, voxel_size::SVector{3,AbstractFloat})

Create the voxel id for a given point and voxel size.
"""
@inline function make_voxel_id(point::AbstractVector, voxel_size::SVector{3, T}) where T <: Real
    (floor(Int, point[1] / voxel_size[1]), floor(Int, point[2] / voxel_size[2]),
     floor(Int, point[3] / voxel_size[3]))
end

"An iterator type to return point indices in a voxel. See SparseVoxelGrid() for usage."
struct Voxel
    id::VoxelId
    point_index_range::UnitRange{Int}
    all_point_indices::Vector{Int}
end

function Base.iterate(v::SparseVoxelGrid, state=(v.voxel_info, 1))
    state = iterate(v.voxel_info, state[2])
    state == nothing && return nothing
    id = state[1][1]
    point_index_range = state[1][2]
    return Voxel(id, point_index_range, v.point_indices), state
end

Base.eltype(::SparseVoxelGrid) = Voxel

function Base.getindex(grid::SparseVoxelGrid, id::VoxelId)
    Voxel(id, grid.voxel_info[id], grid.point_indices)
end


function Base.iterate(v::Voxel, state=1)
    if state > length(v.point_index_range)
        return nothing
    end
    return v.all_point_indices[v.point_index_range[state]], state + 1
end


Base.eltype(::Voxel) = Int
Base.length(v::Voxel) = length(v.point_index_range)

function Base.show(io::IO, v::Voxel)
    print(io, typeof(v), " ", v.id, " with ", length(v.point_index_range), " points")
end

"Voxel iterator that returns the `Voxel`s. See `in_cuboid()` for usage."
struct VoxelCuboid
    grid::SparseVoxelGrid
    voxel_id::VoxelId
    range::CartesianIndices{3,Tuple{UnitRange{Int64},UnitRange{Int64},UnitRange{Int64}}}

end

# TODO the `do` syntax for in_cuboid is faster than the iterator - can the iterator be improved?

"""
    in_cuboid(grid::SparseVoxelGrid, voxel::Voxel, radius::Int)
    in_cuboid(grid::SparseVoxelGrid, voxel_id::NTuple{3,Int}, radius::Int)

Search for neighbouring voxels within a `radius` around the reference `voxel` or `voxel_id`.
Returns a `Voxel` in each iteration.

### Example
The `in_cuboid` function can be implemented using the `do` block syntax:

```julia
radius = 1
query_voxel = (1,1,1)
in_cuboid(grid, query_voxel, radius) do voxel
    for index in voxel
        # Do stuff with point[:, index]
    end
    # Or, collect all indices into an array
    indices = collect(voxel)
end
```

Alternatively, you may use a `for` loop which returns a voxel in each iteratation:
```julia
for voxel in in_cuboid(grid, query_voxel, radius)
    # do stuff with the `Voxel` (i.e. collect(voxel) or for index in voxel etc.)
end
```
"""
in_cuboid(grid::SparseVoxelGrid, voxel::Voxel, radius::Int) = in_cuboid(grid, voxel.id, radius)

function in_cuboid(grid::SparseVoxelGrid, voxel::VoxelId, radius::Int)
    index_start = (-radius+voxel[1], -radius+voxel[2], -radius+voxel[3])
    index_stop = (radius+voxel[1], radius+voxel[2], radius+voxel[3])
    indices = CartesianIndices((index_start[1]:index_stop[1], index_start[2]:index_stop[2], index_start[3]:index_stop[3]))
    VoxelCuboid(grid, voxel, indices)
end

in_cuboid(f::Function, grid::SparseVoxelGrid, voxel::Voxel, radius::Int) = in_cuboid(f, grid, voxel.id, radius)

function in_cuboid(f::Function, grid::SparseVoxelGrid, voxel::VoxelId, radius::Int)
    for i=-radius+voxel[1]:radius+voxel[1], j=-radius+voxel[2]:radius+voxel[2], k=-radius+voxel[3]:radius+voxel[3]
        id = (i, j, k)
        if haskey(grid, id) && id != voxel
           f(grid[id])
        end
    end
end

function Base.getindex(c::VoxelCuboid, id::CartesianIndex{3})
    Voxel(id.I, c.grid.voxel_info[id.I], c.grid.point_indices)
end


#find the next viable Voxel
function next_voxel(c::VoxelCuboid, state::Tuple{CartesianIndex{3}, Int})
    next_state = state
    next_state[1] == nothing && return nothing , 0
    voxel = c[next_state[1]]
    while next_state != nothing
        next_state = iterate(c.range, next_state[1])
        next_state == nothing && return voxel, (next_state, 0)
        id = next_state[1]

        if haskey(c.grid.voxel_info, next_state[1].I) && c.voxel_id != next_state[1].I
            # return current voxel and the state for the next voxel
            return voxel, (next_state[1], 1)
        end
    end
    # Next voxel does not exist exists
    return voxel, (next_state, 0)
end

function Base.iterate(c::VoxelCuboid, state=(c.range[1], 1))

    if state[1] == c.range[1]
        if !haskey(c.grid, state[1].I) # first voxel id is not in grids
            # find the next voxel in grid
            while state != nothing
                state = iterate(c.range, state[1])
                state == nothing && return nothing
                id = state[1]
                if haskey(c.grid, id.I) && c.voxel_id != id.I
                    state =  id, 1
                    @show state
                    return next_voxel(c, state)
                end
            end
            # no voxel id was found set value to quit iterations
            return nothing
        end
        # return the starting voxel
        return next_voxel(c, state)

    else
        state[1] == nothing && return nothing
        return next_voxel(c, state)
    end
    
end

Base.eltype(::VoxelCuboid) = Voxel

if VERSION >= v"0.5.0-dev+3305"
    # See https://github.com/JuliaLang/julia/issues/15977
    # Possibly could implement length() instead, but it's nontrivial work to compute.
    Base.IteratorSize(::Type{VoxelCuboid}) = Base.SizeUnknown()
end

function Base.show(io::IO, c::VoxelCuboid)
    len = length(c.range)
    print(io, typeof(c), " ID iteration range: ", c.range[1].I, " -> ", c.range[len].I)
end

"""
    voxel_center(grid::SparseVoxelGrid, voxel_id::NTuple{3,Int})

Calculate the centre point for the `voxel_id` in the spatial grid.
"""
@inline function voxel_center(grid::SparseVoxelGrid, voxel_id::VoxelId)
    center = SVector{3, Float64}(voxel_id) .* grid.voxel_size - grid.voxel_size * 0.5
end
