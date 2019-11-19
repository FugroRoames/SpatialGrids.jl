@testset "SparseVoxelGrid tests" begin
    # Create points for a uniformly spaced 4x4x4 grid
    x = collect(range(0.0, stop=3.0, length=3))
    cnt = 1
    points2d = zeros(2, 27)
    points3d = zeros(3, 27)
    for i in x, j in x, k in x
        points2d[1, cnt] = points3d[1, cnt] = i
        points2d[2, cnt] = points3d[2, cnt] = j
        points3d[3, cnt] = k
        cnt += 1
    end

    @testset "Rasterizer" begin
        # Test standard uniformly sized voxels
        d2d = rasterize_points(points2d, 1.0)

        [@test length(r) == 3 for r in values(d2d)]
        d3d = rasterize_points(points3d, 1.0)
        [@test length(r) == 3 for r in values(d3d)]

        @test length(keys(d2d)) == 9
        @test d2d[(0x00000000,0x00000000)] == UInt32[1, 2, 3]

        @test_throws DimensionMismatch rasterize_points([SVector{4, Float32}(rand(4)) for i= 1:4], 1.0)

        io = IOBuffer()
        show(io, d3d)
    end

    @testset "Voxelization" begin
        # Test standard uniformly sized voxels
        voxel_size = 1.0
        grid = SparseVoxelGrid(points3d, voxel_size)
        @test isempty(grid) == false
        @test haskey(grid, (0,0,0)) == true
        @test length(grid) == 27
        @test length(collect(grid)) == 27
    
        for voxel in grid
            @test length(collect(voxel_size)) == 1
        end

        @test voxel_center(grid, (1, 1, 1)) == SVector{3,Float64}(0.5, 0.5, 0.5)
        @test length(collect(SparseVoxelGrid(points3d, (2.0, 2.5, 4.0)))) == 4
        @test length(collect(SparseVoxelGrid(points3d, SVector(2.0, 2.5, 4.0)))) == 4

        vector_points = [SVector{3, Float64}(points3d[:,i]) for i = 1:size(points3d, 2)]
        grid = SparseVoxelGrid(vector_points, SVector(1, 1, 1))
        @test length(grid) == 27

        grid = SparseVoxelGrid(vector_points, 2.0)
        @test length(grid) == 8
    end

    @testset "Neighbouring voxel" begin
        radius = 1
        grid = SparseVoxelGrid(points3d, 2.0)
        for voxel in grid
            # Test using anonymous function method
            in_cuboid(grid, voxel, radius) do voxel
                @test haskey(grid, voxel.id)
            end
        end

        grid = SparseVoxelGrid(points3d, 1.5)
        voxel_list = [(1,1,1), (1,2,1), (2,2,2), (10,10,10)]

        @test length(collect(in_cuboid(grid, voxel_list[1], 2))) == 26
        @test length(collect(in_cuboid(grid, voxel_list[2], 2))) == 26
        @test length(collect(in_cuboid(grid, voxel_list[3], 2))) == 26
        @test length(collect(in_cuboid(grid, voxel_list[4], 2))) == 0
        @test length(collect(in_cuboid(grid, collect(grid)[1], 2))) == 26

        # Test show methods
        io = IOBuffer()
        voxel = collect(grid)[1]
        cuboid = in_cuboid(grid, (0,0,0), radius)
        @show(io, grid)
        @show(io, voxel)
        @show(io, cuboid)
    end
end
