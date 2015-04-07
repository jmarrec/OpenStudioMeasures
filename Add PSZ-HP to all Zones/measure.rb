# Author: Julien Marrec
# email: julien.marrec@gmail.com


# start the measure
class AddPSZHPToEachZone < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return 'Add a PSZ-HP to each zone'
  end
  
  def description
    return 'This will add a Rooftop Packaged Single Zone Heat Pump (RTU with DX cooling and DX heating coils) to each zone of the model.'
  end

  def modeler_description
    return 'Add a System 4 - PSZ-HP - unit for each zone. This is a single zone system.
    Parameters:
    - Double: COP cooling and COP heating (Double)
    - Boolean: supplementary electric heating coil (Boolean)
    - Pressure rise (Optional Double)
    - Deletion of existing HVAC equipment (Boolean)
    - DCV enabled or not (Boolean)
    - Fan type: Variable Volume Fan (VFD) or not (Constant Volume) (Choice)
    - Filter for the zone name (String): only zones that contains the string you input in filter will receive this system.'
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    delete_existing = OpenStudio::Ruleset::OSArgument::makeBoolArgument('delete_existing', true)
    delete_existing.setDisplayName('Delete any existing HVAC equipment?')
    args << delete_existing
    
    cop_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cop_cooling', false)
    cop_cooling.setDisplayName('COP cooling (SI)')
    cop_cooling.setDefaultValue(3.0)
    args << cop_cooling

    cop_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cop_heating',  false)
    cop_heating.setDisplayName('COP cooling (SI)')
    cop_heating.setDefaultValue(3.0)
    args << cop_heating
	
    has_electric_coil = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_electric_coil', false)
    has_electric_coil.setDisplayName('Include supplementary electric heating coils?')
    has_electric_coil.setDefaultValue(true)
    args << has_electric_coil
    
    has_DCV = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_DCV', false)
    has_DCV.setDisplayName('Enable Demand Controlled Ventilation?')
    has_DCV.setDefaultValue(false)
    args << has_DCV
    
    chs = OpenStudio::StringVector.new
    chs << "Constant Volume (default)"
    chs << "Variable Volume (VFD)"
    fan_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('fan_type', chs, true)
    fan_type.setDisplayName("Select fan type:")
    args << fan_type
    
    # has_VFD = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_VFD', false)
    # has_VFD.setDisplayName('Include a Variable Volume Fan?')
    # has_VFD.setDefaultValue(false)
    # args << has_VFD
      
    fan_pressure_rise = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('fan_pressure_rise', false)
    fan_pressure_rise.setDisplayName('Fan Pressure Rise (Pa)')
    fan_pressure_rise.setDescription('Leave blank for default value')
    #fan_pressure_rise.setDefaultValue(0)
    args << fan_pressure_rise
    
    zone_filter = OpenStudio::Ruleset::OSArgument::makeStringArgument('zone_filter', false)
    zone_filter.setDisplayName("Only Apply to Zones that contain the following string")
    zone_filter.setDescription("Case insenstive. For example, type 'retail' to apply to zones that have the word 'retail' or 'REtaiL' in their name. Leave blank to apply to all zones")
    args << zone_filter
    
    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Retrieve arguments' values.
    delete_existing = runner.getBoolArgumentValue('delete_existing', user_arguments)
    cop_cooling = runner.getDoubleArgumentValue('cop_cooling', user_arguments)
    cop_heating = runner.getDoubleArgumentValue('cop_heating', user_arguments)
    has_electric_coil = runner.getBoolArgumentValue('has_electric_coil', user_arguments)
    has_DCV = runner.getBoolArgumentValue('has_DCV', user_arguments)
    #has_VFD = runner.getBoolArgumentValue('has_VFD', user_arguments)
    
    fan_pressure_rise = runner.getOptionalDoubleArgumentValue('fan_pressure_rise', user_arguments)
    if fan_pressure_rise.empty?
      fan_pressure_rise_double = 0
    else
      runner.registerInfo("Fan pressure rise: #{fan_pressure_rise.class}")
      fan_pressure_rise_double = OpenStudio::Double.new(fan_pressure_rise)
      runner.registerInfo("Fan pressure rise after: #{fan_pressure_rise_double.class}")
    end
    
    
    #fan_pressure_rise = runner.getDoubleArgumentValue('fan_pressure_rise', user_arguments)
    runner.registerInfo("Fan pressure rise: #{fan_pressure_rise}")
    
    # FanType
    fan_type = runner.getStringArgumentValue('fan_type', user_arguments)
    runner.registerInfo(fan_type)
    if fan_type == 'Variable Volume (VFD)'
      has_VFD = true
    else
      has_VFD = false
    end    
    
    
    # Zone filter
    zone_filter = runner.getOptionalStringArgumentValue('zone_filter', user_arguments)
    runner.registerInfo("zone filter : is empty: #{zone_filter.empty?} , value #{zone_filter}, class #{zone_filter.class}")
    new_string = zone_filter.to_s
    runner.registerInfo("zone filter new : is empty: #{new_string.empty?} , value #{new_string}, class #{new_string.class}")
    
    #info for initial condition
    initial_num_air_loops_demand_control = 0
    final_num_air_loops_demand_control = 0
    initial_num_fan_VFD = 0
    final_num_fan_VFD = 0
    delete_existing_loops = 0
    affected_loops = 0
    
    #If we need to delete existing AirLoops
    if delete_existing
      air_loops = model.getAirLoopHVACs
      air_loops.each do |air_loop|
        #Delete Air Loop
        runner.registerInfo("Air loop '#{air_loop.name}' was deleted.")
        air_loop.remove
        delete_existing_loops += 1
      end #end air_loops.each do
    end #end of delete_existing
  
    # Get all thermal zones
    zones = model.getThermalZones

    # For each thermal zones
    zones.each do |z|
    
      # Skip zone if name doesn't include zone_filter
      # Putting everything in Upper Case to make it case insensitive
      if !zone_filter.empty?
        next if not z.name.to_s.upcase.include? zone_filter.to_s.upcase
      end
      
      # Create a system 4 (PSZ-HP)
      air_handler = OpenStudio::Model::addSystemType4(model).to_AirLoopHVAC.get
      
      # Set name of Air Loop to be thermal_zone + 'Airloop'
      # Local variable name convention for a non-constant (dynamic) value is 'snake_case'
      base_name = z.name.to_s
      air_handler.setName(base_name + ' AirLoop')
      
      
      # Get existing fan, created with System 4, constant volume by default
      old_fan = air_handler.supplyComponents(OpenStudio::Model::FanConstantVolume::iddObjectType).first
      old_fan = old_fan.to_FanConstantVolume.get
      
      #If you want a VFD, we replace it with a Variable Volume one
      if has_VFD
        
        # Get the outlet node after the existing fan on the loop     
        next_node = old_fan.outletModelObject.get.to_Node.get
        
        #Create the new Variable speed fan
        fan = OpenStudio::Model::FanVariableVolume.new(model)
        
        #Add the new fan to the oulet node of the existing fan
        #before deleting the existing one
        fan.addToNode(next_node)
        
        # Remove the existing fan.  When this happens, either the pump's
        # inlet or outlet node will be deleted and the other will remain
        old_fan.remove
        
        # Rename the fan clearly 
        fan.setName(base_name + ' Variable Volume Fan')
        
        # If fan_pressure_rise has a non zero value, assign it
        if fan_pressure_rise_double > 0
          #fan.to_FanVariableVolume.get.setPressureRise(fan_pressure_rise)
          fan.setPressureRise(fan_pressure_rise_double)
        end
        
        final_num_fan_VFD += 1
        
      else
        # If VFD isn't wanted, we just rename the constant volume fan
        old_fan.setName(base_name + ' Constant Volume Fan')
        
        # If fan_pressure_rise has a non zero null value, assign it.
        if fan_pressure_rise_double > 0
          old_fan.setPressureRise(fan_pressure_rise_double)
        end

        
      end
      
      
      
      # The Cooling coil expects an OptionalDouble
      coil = air_handler.supplyComponents(OpenStudio::Model::CoilCoolingDXSingleSpeed::iddObjectType).first
      coil = coil.to_CoilCoolingDXSingleSpeed.get
      coil.setRatedCOP(OpenStudio::OptionalDouble.new(cop_cooling))
      coil.setName(base_name + " Coil Cooling DX Single Speed")
      
      
      # The Heating coil expects a Double
      coilheating = air_handler.supplyComponents(OpenStudio::Model::CoilHeatingDXSingleSpeed::iddObjectType).first
      coilheating = coilheating.to_CoilHeatingDXSingleSpeed.get
      coilheating.setRatedCOP(cop_heating)
      coilheating.setName(base_name + " Coil Heating DX Single Speed")
      
      # Delete the electric heating coil if unwanted
      if !has_electric_coil
        coilheatingelec = air_handler.supplyComponents(OpenStudio::Model::CoilHeatingElectric::iddObjectType).first
        coilheatingelec.remove
      end
      
      #Enable DCV (dunno if working)
      if has_DCV
      
        #get air_handler supply components
        supply_components = air_handler.supplyComponents

        #find AirLoopHVACOutdoorAirSystem on loop
        supply_components.each do |supply_component|
          hVACComponent = supply_component.to_AirLoopHVACOutdoorAirSystem
          if not hVACComponent.empty?
            hVACComponent = hVACComponent.get

            #get ControllerOutdoorAir
            controller_oa = hVACComponent.getControllerOutdoorAir
            controller_oa.setName(base_name + ' Controller Outdoor Air')

            #get ControllerMechanicalVentilation
            controller_mv = controller_oa.controllerMechanicalVentilation

            #check if demand control is enabled, if not, then enable it
            if controller_mv.demandControlledVentilation == true
              initial_num_air_loops_demand_control += 1
            else
              controller_mv.setDemandControlledVentilation(true)
              runner.registerInfo("Enabling demand control ventilation for #{air_handler.name}")
            end #End of if 
            final_num_air_loops_demand_control += 1
            
          end #End of HVACComponent.empty?
        
        end #end of supply component do loop
        
      end #End of has_DCV loop
      
      # Add a branch for the zone in question
      air_handler.addBranchForZone(z)
      
      #Counter
      affected_loops +=1 
      
    end #end of do loop on each thermal zone

    #Report Initial Condition
    if delete_existing
      runner.registerInitialCondition("#{delete_existing_loops} existing AirLoopHVACs have been deleted")
    else
      runner.registerInitialCondition("Initially #{initial_num_air_loops_demand_control} air loops had demand controlled ventilation enabled.")
    end #end of delete_existing
    
    
    
    # Report final condition
    base_str = "There are #{OpenStudio::toNeatString(affected_loops, 0, true)} zones for which a PSZ-HP system was created with a Cooling COP (SI) of #{OpenStudio::toNeatString(cop_cooling, 2, true)} and a Heating COP (SI) of #{OpenStudio::toNeatString(cop_heating, 2, true)}."
    
    if has_electric_coil
      elec_str = "Supplementary electric heating coils were added."
    else
      elec_str = "Supplementary electrical heating coils were NOT included."
    end # end of has_electric_coil
    
    if has_VFD
      fan_str = "Fan type was changed to be Variable Volume (VFD) for #{final_num_fan_VFD} fans."
    else
      fan_str = "Fan type was chosen to be Constant Volume."
    end # end of has_VFD
    
    if final_num_air_loops_demand_control == 0
      dcv_str = "Demand Controlled Ventilation wasn't enabled for the new air loops"
    else
      dcv_str = "#{final_num_air_loops_demand_control} air loops now have demand controlled ventilation enabled"
    end
    
    runner.registerFinalCondition(base_str + "\n" + elec_str + "\n" + fan_str + "\n" + dcv_str)
    
    return true
    
    
  end # end the run method

end # end the measure

# this allows the measure to be used by the application
AddPSZHPToEachZone.new.registerWithApplication
