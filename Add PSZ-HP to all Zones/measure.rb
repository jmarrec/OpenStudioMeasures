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
    
    cop_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cop_cooling', true)
    cop_cooling.setDisplayName('COP cooling (SI)')
    cop_cooling.setDefaultValue(3.1)
    args << cop_cooling

    cop_heating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cop_heating',  true)
    cop_heating.setDisplayName('COP cooling (SI)')
    cop_heating.setDefaultValue(3.1)
    args << cop_heating
	
    has_electric_coil = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_electric_coil', false)
    has_electric_coil.setDisplayName('Include supplementary electric heating coils?')
    has_electric_coil.setDefaultValue(true)
    args << has_electric_coil
    
    has_dcv = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_dcv', false)
    has_dcv.setDisplayName('Enable Demand Controlled Ventilation?')
    has_dcv.setDefaultValue(false)
    args << has_dcv
    
    chs = OpenStudio::StringVector.new
    chs << "Constant Volume (default)"
    chs << "Variable Volume (VFD)"
    fan_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('fan_type', chs, true)
    fan_type.setDisplayName("Select fan type:")
    args << fan_type
      
    fan_pressure_rise = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('fan_pressure_rise', false)
    fan_pressure_rise.setDisplayName('Fan Pressure Rise (Pa)')
    fan_pressure_rise.setDescription('Leave blank for default value')
    #fan_pressure_rise.setDefaultValue(0)
    args << fan_pressure_rise
    
    zone_filter = OpenStudio::Ruleset::OSArgument::makeStringArgument('zone_filter', false)
    zone_filter.setDisplayName("Only Apply to Zones that contain the following string")
    zone_filter.setDescription("Case insensitive. For example, type 'retail' to apply to zones that have the word 'retail' or 'REtaiL' in their name. Leave blank to apply to all zones")
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

    # Retrieve arguments' values
    delete_existing = runner.getBoolArgumentValue('delete_existing', user_arguments)
    cop_cooling = runner.getDoubleArgumentValue('cop_cooling', user_arguments)
    cop_heating = runner.getDoubleArgumentValue('cop_heating', user_arguments)
    has_electric_coil = runner.getBoolArgumentValue('has_electric_coil', user_arguments)
    has_dcv = runner.getBoolArgumentValue('has_dcv', user_arguments)

    # Get fan_pressure_rise: this is an OptionalDouble - we'll use '.get' later
    fan_pressure_rise = runner.getOptionalDoubleArgumentValue('fan_pressure_rise', user_arguments)
    
    # FanType
    fan_type = runner.getStringArgumentValue('fan_type', user_arguments)
    runner.registerInfo("Fan type: #{fan_type}")

    if fan_type == 'Variable Volume (VFD)'
      has_vfd = true
    else
      has_vfd = false
    end    
    
    
    # Zone filter
    zone_filter = runner.getOptionalStringArgumentValue('zone_filter', user_arguments)
    new_string = zone_filter.to_s
    
    #info for initial condition
    initial_num_air_loops_demand_control = 0
    final_num_air_loops_demand_control = 0
    initial_num_fan_VFD = 0
    final_num_fan_VFD = 0
    delete_existing_air_loops = 0
    delete_existing_chiller_loops = 0
    delete_existing_condenser_loops = 0
    affected_loops = 0


    # If we need to delete existing HVAC loops, we'll store the PRE-EXISTING Loops in the following variables,
    # They will be used for clean up at the end
    if delete_existing
      air_loops = model.getAirLoopHVACs
      runner.registerInfo("Class of air_loops: #{air_loops.class}")
      plant_loops = model.getPlantLoops
      runner.registerInfo("Class of plant_loops: #{plant_loops.class}")
    end

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
      if has_vfd
        
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
        
        # If fan_pressure_rise has a non zero null value, assign it.
        if !fan_pressure_rise.empty?
          #We need the .get because this is an OptionalDouble. the .get will return a Double (float)
          fan.setPressureRise(fan_pressure_rise.get)
          runner.registerInfo("Fan '#{fan.name}' was assigned pressure rise of '#{fan_pressure_rise.get}' Pa")
        end
        
        final_num_fan_VFD += 1
        
      else
        # If VFD isn't wanted, we just rename the constant volume fan
        old_fan.setName(base_name + ' Constant Volume Fan')
        
        # If fan_pressure_rise has a non zero null value, assign it.
        if !fan_pressure_rise.empty?
          #We need the .get because this is an OptionalDouble. the .get will return a Double (float)
          old_fan.setPressureRise(fan_pressure_rise.get)
          runner.registerInfo("Fan '#{old_fan.name}' was assigned pressure rise of '#{fan_pressure_rise.get}' Pa")
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
      if has_dcv
      
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
        
      end #End of has_dcv loop
      
      # Add a branch for the zone in question
      air_handler.addBranchForZone(z)
      
      #Counter
      affected_loops +=1 
      
    end #end of do loop on each thermal zone


    #CLEAN-UP SECTION
    # Idea: loop on PRE-EXISTING AirLoops, delete all that don't have any zones anymore
    # Then loop on chiller loop, delete all that don't have a coil connected to an air loop
    # then loop on condenser water, delette all that don't have a chiller anymore

    #If we need to delete existing HVAC loops, we'll loop on the PRE-EXISTING Loops we stored earlier
    if delete_existing

      chiller_plant_loops = []
      boiler_plant_loops = []

      # Loop on the pre-existing air loops (not the ones that were created above)
      air_loops.each do |air_loop|

        # Check if it's got a thermal zone attached left or not..
        # We assume we'll delete it unless...
        delete_flag = true

        air_loop.demandComponents.each do |comp|
          # If there is at least a single zone left, we can't delete it
          if comp.to_ThermalZone.is_initialized
            delete_flag = false
          end #end of if
        end #end of do loop on comp

        # If deletion is warranted
        if delete_flag
          #before deletion, let's get the potential associated plant loop.
          if air_loop.supplyComponents(OpenStudio::Model::CoilCoolingWater::iddObjectType).empty?
            runner.registerInfo("Air loop '#{air_loop.name}' DOES NOT HAVE a CoilHeatingWater")
          else
            cooling_coil = air_loop.supplyComponents(OpenStudio::Model::CoilCoolingWater::iddObjectType).first.to_CoilCoolingWater.get
            chiller_plant_loop = cooling_coil.plantLoop.get
            # Store handle in array
            chiller_plant_loops << chiller_plant_loop
            runner.registerInfo("Air loop '#{air_loop.name}' has a CoilCoolingWater, connected to CHILLER plant loop '#{chiller_plant_loop.name }'")
          end
          if air_loop.supplyComponents(OpenStudio::Model::CoilHeatingWater::iddObjectType).empty?
            runner.registerInfo("Air loop '#{air_loop.name}' DOES NOT HAVE a CoilHeatingWater")
          else
            heating_coil = air_loop.supplyComponents(OpenStudio::Model::CoilCoolingWater::iddObjectType).first.to_CoilCoolingWater.get
            boiler_plant_loop = heating_coil.plantLoop.get
            # Store handle in array
            boiler_plant_loops << boiler_plant_loop
            runner.registerInfo("Air loop '#{air_loop.name}' has a CoilHeatinggWater, connected to BOILER plant loop '#{boiler_plant_loop.name }'")
          end

          # Now we can delete and report.
          air_loop.remove
          runner.registerInfo("DELETED: Air loop '#{air_loop.name}' doesn't have Thermal zones attached and was removed")
          delete_existing_air_loops += 1
        else
          runner.registerInfo("This air loop '#{air_loop.name}' has thermal zones and was not deleted")
        end #end if delete_flag
      end #end air_loops.each do


      runner.registerInfo("FINISHED AIR LOOPS, MOVING TO PLANT LOOPS")

      #First pass on plant loops: chilled water loops.
      chiller_plant_loops.each do |chiller_plant_loop|

        runner.registerInfo("Chiller plant loop name: #{chiller_plant_loop.name}")

        # Check if the chiller plant loop has remaining demand components

        # Delete flag: first assumption is that yes... unless!
        delete_flag = true

        if chiller_plant_loop.demandComponents(OpenStudio::Model::CoilCoolingWater::iddObjectType).empty?
          runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' DOES NOT HAVE a CoilCoolingWater")
        else
          runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' has a CoilCoolingWater")
          cooling_coil = chiller_plant_loop.demandComponents(OpenStudio::Model::CoilCoolingWater::iddObjectType).first.to_CoilCoolingWater.get
          if cooling_coil.airLoopHVAC.empty?
            runner.registerInfo("But Cooling coil '#{cooling_coil.name}' is not connected to any airloopHVAC")
          else
            runner.registerInfo("And Cooling coil '#{cooling_coil.name}' is connected to airloopHVAC '#{cooling_coil.airLoopHVAC.get.name}' and therefore can't be deleted")
            # In this case, we can't delete the chiller plant loop
            delete_flag = false
          end #end cooling_coil.airLoopHVAC.empty?

        end #end of chiller_plant_loop.demandComponents CoilCoolingWater

        # We know it's a chiller plant so this is likely unnecessary, but better safe than sorry
        if chiller_plant_loop.demandComponents(OpenStudio::Model::WaterUseConnections::iddObjectType).empty?
          runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' DOES NOT HAVE WaterUseConnections")
        else
          runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' has WaterUseConnections and therefore can't be deleted")
          delete_flag = false
        end


        # If deletion is warranted
        if delete_flag
          # Now we can delete and report.
          chiller_plant_loop.remove
          runner.registerInfo("DELETED: Chiller PlantLoop '#{chiller_plant_loop.name}' wasn't connected to any AirLoopHVAC nor WaterUseConnections and therefore was removed")
          delete_existing_chiller_loops += 1
          #This section below is actually optional (and not working) but could be nice to only delete affected ones
=begin
          #before deletion, let's get the potential associated condenser water plant loop.
          if chiller_plant_loop.supplyComponents(OpenStudio::Model::ChillerElectricEIR::iddObjectType).empty?
            runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' DOES NOT HAVE an electric chiller")
          else
            chiller = chiller_plant_loop.supplyComponents(OpenStudio::Model::ChillerElectricEIR::iddObjectType).first.to_ChillerElectricEIR.get
            runner.registerInfo("Chiller Plant loop '#{chiller_plant_loop.name}' has an electric chiller '#{chiller.name}' with condenser type '#{chiller.condenserType}'")
            if chiller.condenserType == 'WaterCooled'
              # Chiller is WaterCooled therefore should be connected to a condenser water loop
            end
          end
=end
        end #end of delete_flag

      end #end of chiller_plant_loops.each do

      #Second pass on plant loops: condenser water loops.
      # TO WRITE

      #Third pass on plant loops: boiler water loops.
      # TO WRITE


    end #end of if delete_existing

    #Report Initial Condition
    if delete_existing
      air_loop_str = "#{delete_existing_air_loops} existing AirLoopHVACs have been deleted"
      chiller_plant_loop_str = "#{delete_existing_chiller_loops} existing Chiller PlantLoops have been deleted"
      condenser_plant_loop_str = "#{delete_existing_condenser_loops} existing Condenser PlantLoops have been deleted"
      runner.registerInitialCondition(air_loop_str + "\n" + chiller_plant_loop_str + "\n" + condenser_plant_loop_str)
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
    
    if has_vfd
      fan_str = "Fan type was changed to be Variable Volume (VFD) for #{final_num_fan_VFD} fans."
    else
      fan_str = "Fan type was chosen to be Constant Volume."
    end # end of has_vfd
    
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
