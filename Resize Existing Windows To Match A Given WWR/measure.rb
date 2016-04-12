# Author: Julien Marrec
# email: julien.marrec@gmail.com

# start the measure
class ResizeExistingWindowsToMatchAGivenWWR < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Resize existing windows to match a given WWR"
  end

  # human readable description
  def description
    return "This measure aims to resize all of the existing windows in order to produce a specified, user-input, window to wall ratio.
The windows will be resized around their centroid.
It should be noted that this measure should work in all cases when DOWNSIZING the windows (which is often the need given the 40% WWR imposed as baseline by ASHRAE Appendix G).
If you aim to increase the area, please note that this could result in subsurfaces being larger than their parent surface"
  end

  # human readable description of modeling approach
  def modeler_description
    return "The measure works in several steps:

1. Find the current Window to Wall Ratio (WWR).
This will compute the WWR by taking into account all of the surfaces that have all of the following characteristics:
- They are walls
- They have the outside boundary condition as 'Outdoors' (aims to not take into account the adiabatic surfaces)
- They are SunExposed (could be removed...)

2. Resize all of the existing windows by re-setting the vertices: scaled centered on centroid.

"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make double argument for wwr
    wwr = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("wwr",true)
    wwr.setDisplayName("Window to Wall Ratio (fraction).")
    wwr.setDefaultValue(0.4)
    args << wwr


    check_wall = OpenStudio::Ruleset::OSArgument::makeBoolArgument('check_wall', false)
    check_wall.setDisplayName('Only affect surfaces that are "walls"?')
    check_wall.setDefaultValue(true)
    args << check_wall

    check_outdoors = OpenStudio::Ruleset::OSArgument::makeBoolArgument('check_outdoors', false)
    check_outdoors.setDisplayName('Only affect surfaces that have boundary condition = "Outdoor"?')
    check_outdoors.setDefaultValue(true)
    args << check_outdoors

    check_sunexposed = OpenStudio::Ruleset::OSArgument::makeBoolArgument('check_sunexposed', false)
    check_sunexposed.setDisplayName('Only affect surfaces that are "SunExposed"?')
    check_sunexposed.setDefaultValue(true)
    args << check_sunexposed


    return args
  end


  def getExteriorWindowToWallRatio(spaceArray)

    # counters
    total_gross_ext_wall_area = 0
    total_ext_window_area = 0

    spaceArray.each do |space|

      #get surface area adjusting for zone multiplier
      zone = space.thermalZone
      if not zone.empty?
        zone_multiplier = zone.get.multiplier
        if zone_multiplier > 1
        end
      else
        zone_multiplier = 1 #space is not in a thermal zone
      end

      # puts "\n" + space.name.get

      space.surfaces.each do |s|
        next if not s.surfaceType == "Wall"
        next if not s.outsideBoundaryCondition == "Outdoors"
        # Surface has to be Sun Exposed!
        next if not s.sunExposure == "SunExposed"

        # puts s.name.get + ": " + s.surfaceType + ', ' + s.outsideBoundaryCondition + ', ' + s.sunExposure

        surface_gross_area = s.grossArea * zone_multiplier

        #loop through sub surfaces and add area including multiplier
        ext_window_area = 0
        s.subSurfaces.each do |subSurface|
          ext_window_area = ext_window_area + subSurface.grossArea * subSurface.multiplier * zone_multiplier
        end

        total_gross_ext_wall_area += surface_gross_area
        total_ext_window_area += ext_window_area
      end #end of surfaces.each do
    end # end of space.each do


    result = total_ext_window_area/total_gross_ext_wall_area
    return result

  end


  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    wwr_after = runner.getDoubleArgumentValue("wwr",user_arguments)

    #check reasonableness of fraction
    if wwr_after <= 0 or wwr_after >= 1
      runner.registerError("Window to Wall Ratio must be greater than 0 and less than 1.")
      return false
    end

    check_wall = runner.getBoolArgumentValue('check_wall', user_arguments)
    check_outdoors = runner.getBoolArgumentValue('check_outdoors', user_arguments)
    check_sunexposed = runner.getBoolArgumentValue('check_sunexposed', user_arguments)

    wwr_before = getExteriorWindowToWallRatio(model.getSpaces)

    # report initial condition of model
    runner.registerInitialCondition("The initial WWR was #{OpenStudio::toNeatString(wwr_before*100,2,true)}%.")

    area_scale_factor = wwr_after / wwr_before
    scale_factor = area_scale_factor**0.5


    # Loop on surfaces
    surfaces = model.getSurfaces

    counter = 0

    runner.registerInfo("Click on 'Advanced' for a CSV of each surface WWR before and after")
    puts "\n=====================================================\n"
    puts "RESIZING INFORMATION (CSV)"
    puts "Surface Name, WWR_before, WWR_after"

    surfaces.each do |surface|
      next if (not surface.surfaceType == "Wall") & check_wall
      next if (not surface.outsideBoundaryCondition == "Outdoors") & check_outdoors
      # Surface has to be Sun Exposed!
      next if (not surface.sunExposure == "SunExposed") & check_sunexposed
      next if surface.subSurfaces.empty?

      counter += 1
      # Write before
      print surface.name.to_s + "," + surface.windowToWallRatio.to_s

      # Loop on each subSurfaces
      surface.subSurfaces.each do |subsurface|


        # Get the centroid

        g = subsurface.centroid

        # Create an array to collect the new vertices (subsurface.vertices is a frozen array)
        vertices = []

        # Loop on vertices
        subsurface.vertices.each do |vertex|
          # A vertex is a Point3d.
          # A diff a 2 Point3d creates a Vector3d

          # Vector from centroid to vertex (GA, GB, GC, etc)
          centroid_vector = vertex-g

          # Resize the vector (done in place) according to scale_factor
          centroid_vector.setLength(centroid_vector.length*scale_factor)

          # Change the vertex
          vertex = g + centroid_vector

          vertices << vertex


        end # end of loop on vertices

        # Assign the new vertices to the subsurface
        subsurface.setVertices(vertices)

      end # End of loop on subsurfaces

      # Append the new windowToWallRatio
      print "," + surface.windowToWallRatio.to_s + "\n"

    end # end of surfaces.each do |surface|


    # report final condition of model
    check_wwr_after = getExteriorWindowToWallRatio(model.getSpaces)
    runner.registerFinalCondition("Checking final WWR #{OpenStudio::toNeatString(check_wwr_after*100,2,true)}%. #{counter} surfaces were resized")

    return true

  end
  
end

# register the measure to be used by the application
ResizeExistingWindowsToMatchAGivenWWR.new.registerWithApplication
