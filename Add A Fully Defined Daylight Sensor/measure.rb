# Author: Julien Marrec
# email: julien.marrec@gmail.com

# start the measure
class AddAFullyDefinedDaylightSensor < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add Fully Defined Daylight Sensor to a zone"
  end

  # human readable description
  def description
    return "This measure adds a fully defined daylight sensor based on all input parameters (X,Y,Z, etc)."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Place the daylight sensor in sketchup as needed to get the required parameters. You'll need these values to use this measure.
This measure is only intended to make it possible to use in PAT for example and avoid needing to define an additional OSM just to add daylight as wanted."
  end

  def create_sensor(model, zone, is_primary, fraction_controlled, x_pos_si, y_pos_si, z_pos_si, phi, setpoint_si, control_type, min_power_fraction, min_light_fraction)
    #create a new sensor and put at the center of the space
    sensor = OpenStudio::Model::DaylightingControl.new(model)
    if is_primary
      sensor.setName("#{zone.name} Primary daylighting control")
    else
      sensor.setName("#{zone.name} Secondary daylighting control")
    end


    # Create a new Point3d to put sensor where needed (set in SI units)
    # new_point = OpenStudio::Point3d.new(x_pos_si, y_pos_si, z_pos_si)
    new_point = OpenStudio::Point3d.new(x_pos_si.value, y_pos_si.value, z_pos_si.value)
    sensor.setPosition(new_point)

    # Set the Phi rotation around Z-Axis
    sensor.setPhiRotationAroundZAxis(phi)

    # Assign the illuminance (has to be set in SI units)
    sensor.setIlluminanceSetpoint(setpoint_si.value)

    # Assign the rest
    sensor.setLightingControlType(control_type)
    sensor.setMinimumInputPowerFractionforContinuousDimmingControl(min_power_fraction)
    sensor.setMinimumLightOutputFractionforContinuousDimmingControl(min_light_fraction)

    # Right now I just dump it into the first space I find... This could be a problem if you do use multiple spaces into one thermal zone. (/!\Is it really needed? might only apply if radiance as engine)
    zone_space = zone.spaces[0]
    puts "zone_space in zone: #{zone_space.name}, handle: #{zone_space.handle}"
    sensor.setSpace(zone_space)

    zone.setPrimaryDaylightingControl(sensor)

    # Set fraction controlled
    zone.setFractionofZoneControlledbyPrimaryDaylightingControl(fraction_controlled)

    return sensor

  end


  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
   
    #make a choice argument for model objects
    zone_handles = OpenStudio::StringVector.new
    zone_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    zone_handles_args = model.getThermalZones
    zone_handles_args_hash = {}
    zone_handles_args.each do |zone_handles_arg|
      zone_handles_args_hash[zone_handles_arg.name.to_s] = zone_handles_arg
    end

    #looping through sorted hash of model objects
    zone_handles_args_hash.sort.map do |key,value|
      #only include if thermal zone is used in model( ???)
      if value.spaces.size > 0
        zone_handles << value.handle.to_s
        zone_display_names << key
      end
    end

    #make a choice argument for zone
    zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_handles, zone_display_names,true)
    zone.setDisplayName("Add Daylight Sensor to this Thermal Zone")
    args << zone



    #make an argument to determine if primary or secondary
    is_primary = OpenStudio::Ruleset::OSArgument::makeBoolArgument("is_primary",true)
    is_primary.setDisplayName("Is it the primary lighting control?")
    is_primary.setDefaultValue(true)
    is_primary.setDescription("If false, the secondaryLightingControl will be affected")
    args << is_primary

    #make an argument for fraction of lights controlled
    fraction_controlled = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fraction_controlled",true)
    fraction_controlled.setDisplayName("Fraction of Zone lighting controlled by this daylight control")
    fraction_controlled.setDefaultValue(1)
    args << fraction_controlled



    #make an argument for setpoint
    setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("setpoint",true)
    setpoint.setDisplayName("Daylighting Setpoint (fc)")
    setpoint.setDescription("1 fc = 10.76 lux. Default of 46.45 fc is 500 lux")
    setpoint.setDefaultValue(46.45)
    args << setpoint

    #make an argument for control_type
    chs = OpenStudio::StringVector.new
    chs << "None"
    chs << "Continuous"
    chs << "Stepped"
    chs << "Continuous/Off"
    control_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("control_type",chs)
    control_type.setDisplayName("Daylighting Control Type")
    control_type.setDefaultValue("Continuous/Off")
    args << control_type

    #make an argument for min_power_fraction
    min_power_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_power_fraction",true)
    min_power_fraction.setDisplayName("Daylighting Minimum Input Power Fraction(min = 0 max = 0.6)")
    min_power_fraction.setDefaultValue(0.3)
    args << min_power_fraction

    #make an argument for min_light_fraction
    min_light_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_light_fraction",true)
    min_light_fraction.setDisplayName("Daylighting Minimum Light Output Fraction (min = 0 max = 0.6)")
    min_light_fraction.setDefaultValue(0.2)
    args << min_light_fraction
    
    #make an argument for Position X-Coordinate
    x_pos = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("x_pos",true)
    x_pos.setDisplayName("Position X-Coordinate (ft)")
    args << x_pos
    
    #make an argument for Position X-Coordinate
    y_pos = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("y_pos",true)
    y_pos.setDisplayName("Position Y-Coordinate (ft)")
    args << y_pos
    
    #make an argument for height
    z_pos = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("z_pos",true)
    z_pos.setDisplayName("Position Z-Coordinate (ft)")
    z_pos.setDescription("Sensor Height from floor. Default value is 2.5 ft / 30 inches / 76.2 cm")
    z_pos.setDefaultValue(2.5)
    args << z_pos
    
    #make an argument for Phi Rotation around Z-Axis
    phi = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("phi",true)
    phi.setDisplayName("Phi Rotation around Z-axis")
    phi.setDescription("Sensor rotation around the Z-axis, defines the direction towards which the sensor is looking. We assume Psi and Theta rotation = 0")
    args << phi
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    zone = runner.getOptionalWorkspaceObjectChoiceValue("zone",user_arguments,model)
    is_primary = runner.getBoolArgumentValue("is_primary",user_arguments)
    fraction_controlled = runner.getDoubleArgumentValue("fraction_controlled",user_arguments)

    setpoint = runner.getDoubleArgumentValue("setpoint",user_arguments)
    control_type = runner.getStringArgumentValue("control_type",user_arguments)
    min_power_fraction = runner.getDoubleArgumentValue("min_power_fraction",user_arguments)
    min_light_fraction = runner.getDoubleArgumentValue("min_light_fraction",user_arguments)
    x_pos = runner.getDoubleArgumentValue("x_pos",user_arguments)
    y_pos = runner.getDoubleArgumentValue("y_pos",user_arguments)
    z_pos = runner.getDoubleArgumentValue("z_pos",user_arguments)
    phi = runner.getDoubleArgumentValue("phi",user_arguments)

    # check the zone for reasonableness
    if zone.empty?
      handle = runner.getStringArgumentValue("zone",user_arguments)
      if handle.empty?
        runner.registerError("No zone was selected.")
      else
        runner.registerError("The selected zone type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not zone.get.to_ThermalZone.empty?
        #If everything's alright, get the actual Thermal Zone object from the handle
        zone = zone.get.to_ThermalZone.get
        runner.registerInfo("Found the zone #{zone.name}")
        runner.registerInfo("Spaces linked to zone: #{zone.spaces.size}")
      else
        runner.registerError("Script Error - argument not showing up as ThermalZone type.")
      end
    end

    #check the fraction of lights controlled
    if fraction_controlled < 0.0 or fraction_controlled > 1.0
      runner.registerError("The requested Fraction of Zone Lights controlled of #{fraction_controlled} is outside the acceptable range of 0 to 1.")
      return false
    end
    
    #check the setpoint for reasonableness
    if setpoint < 0 or setpoint > 9999 #dfg need input on good value
      runner.registerError("A setpoint of #{setpoint} foot-candles is outside the measure limit.")
      return false
    elsif setpoint > 100
      # 100 fc is a 1000 lux, that's already too high for most applications.
      runner.registerWarning("A setpoint of #{setpoint} foot-candles is abnormally high.") 
    end

    #check the min_power_fraction for reasonableness
    if min_power_fraction < 0.0 or min_power_fraction > 0.6
      runner.registerError("The requested minimum input power fraction of #{min_power_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the min_light_fraction for reasonableness
    if min_light_fraction < 0.0 or min_light_fraction > 0.6
      runner.registerError("The requested minimum light output fraction of #{min_light_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the height for reasonableness
    if z_pos < -360 or z_pos > 360 # neg ok because space origin may not be floor
      runner.registerError("A setpoint of #{z_pos} inches is outside the measure limit.")
      return false
    elsif z_pos > 72
      runner.registerWarning("A setpoint of #{z_pos} inches is abnormally high.")
    elseif z_pos < 0
      runner.registerWarning("Typically the sensor height should be a positive number, however if your space origin is above the floor then a negative sensor height may be appropriate.")
    end
    
    #Would be nice to try to check whether the sensor is within the zone/space, but we assume the user has placed it using sketchup and therefore can't make any mistakes...

    #setup OpenStudio units that we will need
    unit_setpoint_ip = OpenStudio::createUnit("fc").get
    unit_setpoint_si = OpenStudio::createUnit("lux").get
    unit_length_ip = OpenStudio::createUnit("ft").get
    unit_length_si = OpenStudio::createUnit("m").get

    #define starting units
    setpoint_ip = OpenStudio::Quantity.new(setpoint, unit_setpoint_ip)
    x_pos_ip = OpenStudio::Quantity.new(x_pos, unit_length_ip)
    y_pos_ip = OpenStudio::Quantity.new(y_pos, unit_length_ip)
    z_pos_ip = OpenStudio::Quantity.new(z_pos, unit_length_ip)

    
    #unit conversion from IP units to SI units
    setpoint_si = OpenStudio::convert(setpoint_ip, unit_setpoint_si).get
    x_pos_si = OpenStudio::convert(x_pos_ip, unit_length_si).get
    y_pos_si = OpenStudio::convert(y_pos_ip, unit_length_si).get
    z_pos_si = OpenStudio::convert(z_pos_ip, unit_length_si).get
 
    
 
    #reporting initial condition of model
    runner.registerInitialCondition("Will try to add a daylight sensor to '#{zone.name}'.")

    if (is_primary and zone.primaryDaylightingControl.empty?) or (not is_primary and zone.secondaryDaylightingControl.empty?)

      #create a new sensor and put at the center of the space
      sensor = OpenStudio::Model::DaylightingControl.new(model)
      sensor.setName("#{zone.name} daylighting control")

      # Create a new Point3d to put sensor where needed (set in SI units)
      # new_point = OpenStudio::Point3d.new(x_pos_si, y_pos_si, z_pos_si)
      new_point = OpenStudio::Point3d.new(x_pos_si.value, y_pos_si.value, z_pos_si.value)
      sensor.setPosition(new_point)

      # Set the Phi rotation around Z-Axis
      sensor.setPhiRotationAroundZAxis(phi)

      # Assign the illuminance (has to be set in SI units)
      sensor.setIlluminanceSetpoint(setpoint_si.value)

      # Assign the rest
      sensor.setLightingControlType(control_type)
      sensor.setMinimumInputPowerFractionforContinuousDimmingControl(min_power_fraction)
      sensor.setMinimumLightOutputFractionforContinuousDimmingControl(min_light_fraction)

      # Right now I just dump it into the first space I find... This could be a problem if you do use multiple spaces into one thermal zone. (/!\Is it really needed? might only apply if radiance as engine)
      zone_space = zone.spaces[0]
      runner.registerInfo("zone_space in zone: #{zone_space.name}, handle: #{zone_space.handle}")
      sensor.setSpace(zone_space)

      if is_primary
        # Assign the sensor as a Primary Daylighting Control to the Thermal Zone
        zone.setPrimaryDaylightingControl(sensor)

        # Set fraction controlled
        zone.setFractionofZoneControlledbyPrimaryDaylightingControl(fraction_controlled)
      else

        primary_fraction = zone.fractionofZoneControlledbyPrimaryDaylightingControl
        total_fraction = fraction_controlled + primary_fraction
        if total_fraction > 1
          runner.registerError("The sum of Primary Fraction (#{primary_fraction}) and the desired Secondary Fraction (#{fraction_controlled}) of Zone lights controlled exceeds 1!")
          return false
        end

        # Assign the sensor as a Primary Daylighting Control to the Thermal Zone
        zone.setSecondaryDaylightingControl(sensor)

        # Set fraction controlled
        zone.setFractionofZoneControlledbySecondaryDaylightingControl(fraction_controlled)
      end

    else
        runner.registerWarning("Thermal zone '#{zone.name}' already had a daylighting sensor. No sensor was added.")
    end #end if


      

    # Report final condition of model
    runner.registerFinalCondition("Added a daylighting sensor to #{zone.name}. Here is the sensor definition \n\n #{sensor}")
    puts zone.to_s

    return true

  end #end run
  
end #end class

# register the measure to be used by the application
AddAFullyDefinedDaylightSensor.new.registerWithApplication
