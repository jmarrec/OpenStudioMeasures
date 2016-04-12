# Author: Julien Marrec
# email: julien.marrec@gmail.com

# Start the measure
class EnableDCVAndReplaceFanWithVFD < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return 'Add DCV to each airloop and a VFD fan'
  end
  
  def description
    return 'Does what it says'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new


    loop_handles = OpenStudio::StringVector.new
    loop_display_names = OpenStudio::StringVector.new


    # Option to select all
    loop_handles << OpenStudio::toUUID("").to_s
    loop_display_names << "------ All airLoopHVACs -------"

    #putting model object and names into hash
    model.getAirLoopHVACs.each do |air_loop|
      loop_handles << air_loop.handle.to_s
      loop_display_names << air_loop.name.to_s
    end

    # make a choice argument for the loop
    loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("loop", loop_handles, loop_display_names, true)
    loop.setDisplayName("Select the Air Loop to affect, leave blank to affect all")
    loop.setDescription("Select '------ All airLoopHVACs -------' to affect all loops'")
    loop.setDefaultValue("------ All airLoopHVACs -------")
    args << loop


    has_DCV = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_DCV', false)
    has_DCV.setDisplayName('Demand Controlled Ventilation?')
    has_DCV.setDefaultValue(false)
    args << has_DCV
    
    has_VFD = OpenStudio::Ruleset::OSArgument::makeBoolArgument('has_VFD', false)
    has_VFD.setDisplayName('Include a Variable Volume Fan?')
    has_VFD.setDefaultValue(false)
    args << has_VFD
    
    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end


    has_DCV = runner.getBoolArgumentValue('has_DCV', user_arguments)
    has_VFD = runner.getBoolArgumentValue('has_VFD', user_arguments)

    air_loops = nil

    # get the Loop
    loop_object = runner.getOptionalWorkspaceObjectChoiceValue("loop", user_arguments, model)

    # check the zone for reasonableness
    if loop_object.empty?
      handle = runner.getStringArgumentValue("loop", user_arguments)
      if handle.empty?
        runner.registerError("No plantLoop or airLoop was selected.")
        return false
      elsif handle == OpenStudio::toUUID("").to_s
        runner.registerInfo("You choose to affect ALL AirLoopHVACs")
        # Puts all airLoopHVACs in the list
        air_loops = model.getAirLoopHVACs
      else
        runner.registerError("The selected loop type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not loop_object.get.to_AirLoopHVAC.empty?
        air_loop = loop_object.get.to_AirLoopHVAC.get
        runner.registerInfo("You chose to affect only #{air_loop}")
        # Make a list of one element only
        air_loops = [air_loop]
      else
        runner.registerError("Script Error - argument not showing up as air loop.")
        return false
      end
    end


    #info for initial condition
    initial_num_air_loops_demand_control = 0
    final_num_air_loops_demand_control = 0
    initial_num_fan_VFD = 0
    final_num_fan_VFD = 0
    
    
    
    #loop through air loops
    air_loops.each do |air_loop|

      supply_components = air_loop.supplyComponents

      #find AirLoopHVACOutdoorAirSystem on loop
      supply_components.each do |supply_component|
        oasys = supply_component.to_AirLoopHVACOutdoorAirSystem
        if not oasys.empty?
          oasys = oasys.get

          #get ControllerOutdoorAir
          controller_oa = oasys.getControllerOutdoorAir

          #get ControllerMechanicalVentilation
          controller_mv = controller_oa.controllerMechanicalVentilation

          #check if demand control is enabled, if not, then enable it
          if controller_mv.demandControlledVentilation == true
            initial_num_air_loops_demand_control += 1
          else
            controller_mv.setDemandControlledVentilation(true)
            puts controller_mv
            runner.registerInfo("Enabling demand control ventilation for #{air_loop.name}")
          end #End of if 
          final_num_air_loops_demand_control += 1
          
        end #End of HVACComponent.empty?
      
      end #end of supply component do loop          
      
      
      #Fan
      if has_VFD
      
        old_fan = air_loop.supplyComponents(OpenStudio::Model::FanConstantVolume::iddObjectType).first
        old_fan = old_fan.to_FanConstantVolume.get

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

        runner.registerInfo("Switching constant volume fan to VFD for #{air_loop.name}")
        
        final_num_fan_VFD += 1
        
      end #end of has_VFD loop
          
          
    end #End of do loop on each airloop
    
    #reporting initial condition of model
    runner.registerInitialCondition("Initially #{initial_num_air_loops_demand_control} air loops had demand controlled ventilation enabled, and #{initial_num_fan_VFD} airloops had vfds.")

    if final_num_air_loops_demand_control == 0
      runner.registerAsNotApplicable("The affected loop(s) do not have any outdoor air objects.")
      return true
    end

    #reporting final condition of model
    runner.registerFinalCondition("#{final_num_air_loops_demand_control} air loops now have demand controlled ventilation enabled. #{final_num_fan_VFD} fans have been switched from Constant to Variable Volume")

    return true
    
  end # end the run method

end # end the measure

# this allows the measure to be used by the application
EnableDCVAndReplaceFanWithVFD.new.registerWithApplication
