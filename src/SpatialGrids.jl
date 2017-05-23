__precompile__()

module SpatialGrids

using StaticArrays

export Raster, rasterize_points
export SparseVoxelGrid, in_cuboid, voxel_center, make_voxel_id

include("raster.jl")
include("sparse_voxels.jl")

end # module
