#=##############################################################################
# DESCRIPTION
    Tools for formatting PSU-WOPWOP's inputs/outputs.

# AUTHORSHIP
  * Author    : Eduardo J. Alvarez and Tyler Critchfield
  * Email     : Edo.AlvarezR@gmail.com
  * Created   : Nov 2019
  * License   : MIT
=###############################################################################


"""
    `wopwop2vtk(grid, outputname, save_path; read_path="", paraview=false)`

Converts an output field from PSU-WOPWOP generated over a grid of observers to
vtk format. The user must make sure that the `grid` matches the exact grid that
WOPWOP used as an observer to generate the output fields.

# ARGUMENTS
* `grid::gt.AbstractGrid`        : Grid.
* `outputname::String`           : PSU-WOPWOP output file to read. For instance,
                                    `outputname=pressure` will look for the files
                                    pressure.nam and pressure.fn under path
                                    `read_path`.
* `save_path::String`           : Where to save vtk files.

# OPTIONAL ARGUMENTS
* `read_path::String`           : Path from where to read the inputs files.

"""
function wopwop2vtk(grid::gt.AbstractGrid, outputname::String, save_path::String;
                        read_path="", prompt=true,
                        verbose=true, v_lvl=0,
                        paraview=false)

    gt.create_path(save_path, prompt)

    if verbose
        println("\t"^v_lvl*"Reading output file...")
    end

    # Read header file
    f = open(joinpath(read_path, outputname*".nam"), "r")
    header = readlines(f)
    close(f)

    # Remove invalid characters from headers
    for str in [" ", "(", ")"]
        for i in 1:length(header)
            header[i] = replace(header[i], str, "")
        end
    end

    # Read function file
    f = open(joinpath(read_path, outputname*".fn"), "r")
    imax, jmax, tmax, fieldmax = [parse(elem) for elem in split(readline(f))]

        if verbose
        println("Found $(imax)x$(jmax) grid in WOPWOP output with"*
                    " $tmax time steps.")
    end

    # Read fields
    field = zeros(imax, jmax, tmax, fieldmax)
    for fieldi in 1:fieldmax # Iterate over fields

        if verbose
            println("\t"^(v_lvl+1)*"Reading field $(header[fieldi])...")
        end

        for t in 1:tmax # Iterate over time steps

            if verbose && (t-1)%ceil(Int, tmax/4)==0
                println("\t"^(v_lvl+2)*"Reading time t=$t out of $tmax")
            end

            for j in 1:jmax
                for i in 1:imax
                    # NOTE: Shouldn't I be iterating over in the inner loop?
                    field[i, j, t, fieldi] = parse(readline(f))
                end
            end
        end
    end

    close(f)

    # Add field to grid
    if verbose
        println("\t"^v_lvl*"Generating vtk files...")
    end

    for t in 1:tmax # Iterates over time steps

        if verbose && (t-1)%ceil(Int, tmax/10)==0
            println("\t"^(v_lvl+2)*"Saving vtk time t=$t out of $tmax")
        end

        for fieldi in 1:fieldmax # Iterates over fields

            field_name = header[fieldi]
            field_type = "scalar"
            entry_type = "node"
            field_data = reshape(field[:, :, t, fieldi], grid.nnodes)

            gt.add_field(grid, field_name, field_type, field_data,
                            entry_type; raise_warn=false)
        end

        # Save vtk of this time step
        gt.save(grid, outputname; path=save_path, num=t-1)

    end

    if paraview
        str = joinpath(save_path, outputname*"...vtk;")
        run(`paraview --data=$str`)
    end
end

"""
    `geomwopwop2vtk(filename; read_path="", save_path=nothing,
pref_save_fname::String="automatic", paraview=false, verbose=false, v_lvl=0)`

Converts an input patch file in PSU-WOPWOP format to VTK format.
"""
function geomwopwop2vtk(filename; read_path="", save_path=nothing,
                        pref_save_fname::String="automatic", paraview=false,
                        verbose=false, v_lvl=0)

    # String carrying vtk files
    if save_path!=nothing && paraview
        vtk_str = save_path*"/"
    end

    # Build output file name prefix
    if pref_save_fname=="automatic"
        doti = find(x->x=='.', filename)
        if length(doti)!=0
            # Get rid of extension
            preff = filename[1:doti[end]-1]
        else
            preff = filename
        end
    else
        preff = pref_save_fname
    end

    # Open PSU-WOPWOP file
    f = open(joinpath(read_path, filename), "r")

    # Read format header
    header = []
    push!(header, read(f, Int32, 1))                #1 Magic number
    push!(header, read(f, Int32, 2))                #2 Version
    chars = [Char(c) for c in read(f, Int8, 32)]    #3 Units
    str = ""; for c in chars; str *= c; end;
    push!(header, str)
    chars = [Char(c) for c in read(f, Int8, 1024)]  #4 Comments
    str = ""; for c in chars; str *= c; end;
    push!(header, str)
    push!(header, read(f, Int32, 1))                #5 Geometry file
    nz = read(f, Int32, 1)[1]                       #6 Number of zones
    push!(header, nz)
    push!(header, read(f, Int32, 1))                #7 1==structured, 2==unstructured
    push!(header, read(f, Int32, 1))                #8 1==Constant, 2==Periodic, 3==Aperiodic
    ncnt = read(f, Int32, 1)[1]                     #9 Normal centered 1==node, 2==face
    push!(header, ncnt)
    push!(header, read(f, Int32, 1))                #10 1==single, 2==double
    push!(header, read(f, Int32, 1))                #11 iblank
    push!(header, read(f, Int32, 1))                #12 something

    if verbose
        println("\t"^(v_lvl)*"$(header[1])\t # Magic number")
        println("\t"^(v_lvl)*"$(header[2])\t # Version")
        println("\t"^(v_lvl)*"$(header[3])\t # Units")
        println("\t"^(v_lvl)*"$(header[4])\t # Comment")
        println("\t"^(v_lvl)*"$(header[5])\t # Geometry file")
        println("\t"^(v_lvl)*"$(header[6])\t\t # Number of zones")
        println("\t"^(v_lvl)*"$(header[7])\t # 1==structured, 2==unstructured")
        println("\t"^(v_lvl)*"$(header[8])\t # 1==Constant, 2==Periodic, 3==Aperiodic")
        println("\t"^(v_lvl)*"$(header[9])\t\t # Normal centered 1==node, 2==face")
        println("\t"^(v_lvl)*"$(header[10])\t # 1==single, 2==double")
        println("\t"^(v_lvl)*"$(header[11])\t # iblank")
        println("\t"^(v_lvl)*"$(header[12])\t # something")
    end

    # Error cases: Current implementation only takes unstructured, constant,
    # face centered patches
    Int(header[2][1]) != 1 ? error("Only v1.0 is supported") :
    # Int(header[7][1]) != 2 ? error("Only unstructured patches are supported") :
    Int(header[8][1]) != 1 ? error("Only constant patches are supported") :
    # Int(header[9][1]) != 2 ? error("Only face-centered patches are supported") :
    Int(header[10][1]) != 1 ? error("Only single-precision floats are supported") :
    nothing;

    # Read patch headers
    points = []
    normals = []
    zones = []

    names = []
    nbnodes = []
    nbfaces = []
    imaxs = []
    jmaxs = []
    connectivity = []

    cells = []
    point_datas = []
    cell_datas = []
    celltypes = []

    for zonei in 1:nz
        # NOTE: Here I assume it is UNSTRUCTURED and constant

        chars = [Char(c) for c in read(f, Int8, 32)]
        str = ""; for c in chars; str *= c; end;

        push!(names, str)
        push!(connectivity, [])

        # Unstructured case
        if Int(header[7][1]) == 2
            push!(nbnodes, read(f, Int32))
            push!(nbfaces, read(f, Int32))
            if verbose
                println("\t"^(v_lvl)*"$(names[end])\t$(nbnodes[end]) $(nbfaces[end])\t# Name, nbNodes, nbFaces")
            end

            for facei in 1:nbfaces[end]       # Iterate over faces (cells)

                this_nbnodes = read(f, Int32) # Number of node indices to read
                push!(connectivity[end], [])

                for nodei in 1:this_nbnodes   # Collect node indices
                    push!(connectivity[end][end], read(f, Int32))
                end
            end

            push!(celltypes, -1)

        # Structured case
        else
            push!(imaxs, read(f, Int32))
            push!(jmaxs, read(f, Int32))
            push!(nbnodes, imaxs[end]*jmaxs[end])

            if verbose
                println("\t"^(v_lvl)*"$(names[end])\t$(imaxs[end]) $(jmaxs[end])\t# Name, iMax, jMax")
            end

            # Create connectivity: Quadrilateral-faces case
            if imaxs[end]!=1 && jmaxs[end]!=1
                push!(nbfaces, (imaxs[end]-1)*(jmaxs[end]-1))
                for ni in 1:imaxs[end]-1
                    for nj in 1:jmaxs[end]-1
                        # Subscripts of every node
                        subs = ( (ni, nj), (ni+1, nj), (ni+1, nj+1), (ni, nj+1) )
                        # Convert subscripts to linear index of every node
                        this_cell = [sub2ind((imaxs[end], jmaxs[end]), sub...) for sub in subs]
                        push!(connectivity[end], this_cell)
                    end
                end

                push!(celltypes, -1)

            # Create connectivity: Compact-patch (line) case
            else
                push!(nbfaces, imaxs[end]*jmaxs[end]-1)
                for ni in 1:(imaxs[end]*jmaxs[end]-1)
                    push!(connectivity[end], [ni, ni+1])
                end

                push!(celltypes, 4)
            end
        end

    end

    str = ""

    for zonei in 1:nz

        # Read points
        xyz = []
        for dim in 1:3
            vals = []
            for pi in 1:nbnodes[zonei]
                push!(vals, Float64(read(f, Float32)))
            end
            push!(xyz, vals)
        end

        this_points = [[xyz[1][i], xyz[2][i], xyz[3][i]] for i in 1:nbnodes[zonei]]
        zones = [zonei for p in this_points]


        # Read normals
        nxyz = []
        for dim in 1:3
            vals = []
            # Case of face-centered normals
            if Int(header[9][1]) == 2
                for pi in 1:nbfaces[zonei]
                    push!(vals, Float64(read(f, Float32)))
                end
            # Case of node-centered normals
            else
                for pi in 1:nbnodes[zonei]
                    push!(vals, Float64(read(f, Float32)))
                end
            end

            push!(nxyz, vals)
        end
        if Int(header[9][1]) == 2
            normals = [[nxyz[1][i], nxyz[2][i], nxyz[3][i]] for i in 1:nbfaces[zonei]]
        else
            normals = [[nxyz[1][i], nxyz[2][i], nxyz[3][i]] for i in 1:nbnodes[zonei]]
        end

        # Format cells: shifts to 0-indexing for VTK
        this_cells = [[index-1 for index in cell] for cell in connectivity[zonei]]

        # Data fields
        point_data = [Dict( "field_name" => "zone",
                            "field_type" => "scalar",
                            "field_data" => zones)]
        if Int(header[9][1]) == 2
            cell_data = [Dict( "field_name" => "normals",
                                "field_type" => "vector",
                                "field_data" => normals)]
        else
            cell_data = nothing
            push!(point_data, Dict( "field_name" => "normals",
                                    "field_type" => "vector",
                                    "field_data" => normals))
        end

        push!(points, this_points)
        push!(cells, this_cells)
        push!(point_datas, point_data)
        push!(cell_datas, cell_data)

        if save_path != nothing

            filename = preff*"_"*replace(names[zonei], " ", "")

            gt.generateVTK(filename, this_points; cells=this_cells,
                            point_data=point_data, cell_data=cell_data,
                            path=save_path,
                            override_cell_type=celltypes[zonei])

            str *= filename*".vtk;"
        end
    end

    close(f)

    if paraview && save_path != nothing
        vtk_str *= str
        run(`paraview --data=$(vtk_str)`)
    end

    return names, points, cells, point_datas, cell_datas, str
end


"""
    `read_wopwoploading(filename; read_path="", verbose=false, v_lvl=0)`

Read a PSU-WOPWOP functional file containing loading data (v1.0). Returns
`(hdr, names, timeinfo, dims, time, data)` where data[k][:, i, j] is the value at
the i-th node (or face) at the j-th time in the k-th zone
"""
function read_wopwoploading(filename; read_path="", verbose=false, v_lvl=0)

    # Open PSU-WOPWOP file
    f = open(joinpath(read_path, filename), "r")

    # Read format header
    header = []
    push!(header, read(f, Int32, 1))                #1 Magic number
    push!(header, read(f, Int32, 2))                #2 Version
    chars = [Char(c) for c in read(f, Int8, 1024)]  #3 Comments
    str = ""; for c in chars; str *= c; end;
    push!(header, str)
    push!(header, read(f, Int32, 1))                #4 Functional file
    nz = read(f, Int32, 1)[1]                       #5 Number of zones
    push!(header, nz)
    push!(header, read(f, Int32, 1))                #6 1==structured, 2==unstructured
    push!(header, read(f, Int32, 1))                #7 1==Constant, 2==Periodic, 3==Aperiodic
    ncnt = read(f, Int32, 1)[1]                     #8 1==node-centered, 2==face-centered
    push!(header, ncnt)
    push!(header, read(f, Int32, 1))                #9 1==pressure, 2==loading, 3==flow
    push!(header, read(f, Int32, 1))                #10 1==stationary ground fixed, 2==rotating ground fixed, 3==patch fixed
    push!(header, read(f, Int32, 1))                #11 1==single, 2==double
    push!(header, read(f, Int32, 1))                #12 something
    push!(header, read(f, Int32, 1))                #13 something else

    if verbose
        println("\t"^(v_lvl)*"$(header[1])\t # Magic number")
        println("\t"^(v_lvl)*"$(header[2])\t # Version")
        println("\t"^(v_lvl)*"$(header[3])\t # Comment")
        println("\t"^(v_lvl)*"$(header[4])\t # Functional file")
        println("\t"^(v_lvl)*"$(header[5])\t\t # Number of zones")
        println("\t"^(v_lvl)*"$(header[6])\t # 1==structured, 2==unstructured")
        println("\t"^(v_lvl)*"$(header[7])\t # 1==Constant, 2==Periodic, 3==Aperiodic")
        println("\t"^(v_lvl)*"$(header[8])\t\t # 1==node-centered, 2==face-centered")
        println("\t"^(v_lvl)*"$(header[9])\t # 1==pressure, 2==loading, 3==flow")
        println("\t"^(v_lvl)*"$(header[10])\t # 1==stationary ground, 2==rotating ground, 3==patch")
        println("\t"^(v_lvl)*"$(header[11])\t # 1==single, 2==double")
        println("\t"^(v_lvl)*"$(header[12])\t # something")
        println("\t"^(v_lvl)*"$(header[13])\t # something else")
    end

    # Error cases: Current implementation only takes unstructured, constant,
    # face centered patches
    Int(header[2][1]) != 1 ? error("Only v1.0 is supported") :
    Int(header[4][1]) != 2 ? error("File is not flagged as a functional file") :
    # Int(header[6][1]) != 2 ? error("Only unstructured patches are supported") :
    # Int(header[7][1]) != 1 ? error("Only constant patches are supported") :
    # Int(header[8][1]) != 2 ? error("Only face-centered patches are supported") :
    Int(header[9][1]) != 2 ? error("Only loading vectors are supported") :
    Int(header[11][1]) != 1 ? error("Only single-precision floats are supported") :
    nothing;

    # Zone specification
    zone_specs = zeros(Int, read(f, Int32))     # Read number of zones
    for i in 1:length(zone_specs)               # Read each zone number
        zone_specs[i] = Int(read(f, Int32))
    end

    if verbose
        println("\t"^(v_lvl+1)*"Zone specification: $zone_specs")
    end

    names = String[]
    timeinfo = []
    dims = []
    ndata = zeros(Int, length(zone_specs))
    nt = nothing

    # Data header
    for zi in 1:length(zone_specs)

        # Name
        chars = [Char(c) for c in read(f, Int8, 32)]
        str = ""; for c in chars; str *= c; end;
        push!(names, str)

        # Time information
        if Int(header[7][1])==2         # Periodic case
            push!(timeinfo, Any[read(f, Float32), read(f, Int32)])
            ntimes = timeinfo[end][2]

        elseif Int(header[7][1])==3     # Aperiodic case
            push!(timeinfo, read(f, Int32))
            ntimes = timeinfo[end]

        else                            # Constant case
            push!(timeinfo, 1)
            ntimes = 1
        end

        if nt != nothing && nt != ntimes
            error("Logic error: Got different times ($(nt)!=$(ntimes))")
        end
        nt = ntimes

        # Dimensions
        if Int(header[6][1])==1         # Structured case
            push!(dims, read(f, Int32, 2))
            ndata[zi] = dims[end][1]*dims[end][2]
        else
            push!(dims, read(f, Int32))
            ndata[zi] = dims[end]
        end

        if verbose
            println("\t"^(v_lvl+1)*"$(replace(names[end], " ", ""))"*
                    "\t$(timeinfo[end])\t$(dims[end]) # Name, Time info, dims")
        end
    end

    # Time of every data block of every zone
    time = [zeros(nt) for i in 1:length(zone_specs)]

    # Data of every zone, where data[k][:, i, j] is the value at the i-th node
    # (or face) at the j-th time in the k-th zone
    data = [zeros(3, nd, nt) for nd in ndata]

    for ti in 1:nt                          # Iterate over time entries
        for zi in 1:length(zone_specs)      # Iterate over zones

            if Int(header[7][1])!=1
                time[zi][ti] = Float64(read(f, Float32))
            end

            # NOTE: Here I assume is loading data (three-dimensional)
            for dim in 1:3                  # Iterate over spatial dimension
                for di in 1:ndata[zi]       # Iterate over nodes / faces

                    data[zi][dim, di, ti] = Float64(read(f, Float32))

                end
            end
        end
    end


    hdr = Dict(
                "version"   => header[2],
                "comment"   => header[3],
                "zones"     => Int(header[5][1]),
                "structured"=> Int(header[6][1])==1,
                "time"      => Int(header[7][1]),
                "ntimes"    => nt,
                "node-centered"=> Int(header[8][1])==1,
                "data-type" => Int(header[9][1]),
                "frame"     => Int(header[10][1])
              )

    return hdr, names, timeinfo, dims, time, data
end
