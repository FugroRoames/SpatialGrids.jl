# SpatialGrids.jl

[![Build Status](https://travis-ci.org/FugroRoames/SpatialGrids.jl.svg?branch=master)](https://travis-ci.org/FugroRoames/SpatialGrids.jl)
[![codecov](https://codecov.io/gh/FugroRoames/SpatialGrids.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/FugroRoames/SpatialGrids.jl)

**SpatialGrids** provides 2D and 3D grid structures for working with point cloud data.

The current grids available are a 2D raster and a sparse voxel grid for working with 3D point cloud.

# Raster Grid

To create a 2D raster grid:

```julia
using SpatialGrids
points = rand(3, 100000) * 20.0
raster = rasterize_points(points, 0.1)
```

# Sparse Voxel Grid

To create a sparse voxel grid with voxel side length of 10 metres for arbitrary points:

```julia
using SpatialGrids
points = rand(3, 100000) * 20.0
grid = SparseVoxelGrid(points, 10.0)
```

The created grid is an iteratable object that returns a `Voxel` at each index.
Each voxel can be accessed directly with a `for` loop or all voxels can be `collect`ed into an array.
Likewise, the returned `Voxel` is an iterable object that returns the point indices.

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