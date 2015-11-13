# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class CreateAWaterHeaterMixedAndAssignItsSourceAndUseSides < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Create a WaterHeaterMixed and assign its source and use sides to the specifed plant loop"
  end

  # human readable description
  def description
    return "Creates a WaterHeater:Mixed, and you can specify which plant loop is on its source side and which one is on its use side."
  end

  # human readable description of modeling approach
  def modeler_description
    return "See above"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new


    tank_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('tank_name', true)
    tank_name.setDisplayName("Name of WaterHeater:Mixed")
    args << tank_name

    # Create an argument for a plant loops in the model
    plant_loops = model.getPlantLoops
    plant_loops_handle = OpenStudio::StringVector.new
    plant_loops_displayName = OpenStudio::StringVector.new

    plant_loops.each do |plant_loop|
        plant_loops_handle << plant_loop.handle.to_s
        plant_loops_displayName << plant_loop.name.to_s
    end

    # Select SOURCE side
    source_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("source_loop", plant_loops_handle, plant_loops_displayName,true)
    source_loop.setDisplayName("Select SOURCE side plant loop (boiler loop)")
    args << source_loop

    # Select USE side
    use_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("use_loop", plant_loops_handle, plant_loops_displayName,true)
    use_loop.setDisplayName("Select USE side plant loop (secondary loop)")
    args << use_loop

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    tank_name = runner.getStringArgumentValue("tank_name",user_arguments)

    # Get source loop
    source_loop = runner.getOptionalWorkspaceObjectChoiceValue("source_loop",user_arguments,model)

    # Get use loop
    use_loop = runner.getOptionalWorkspaceObjectChoiceValue("use_loop",user_arguments,model)

    # Shouldn't happen, it's mandatory to provide it...
    if source_loop.empty?
      runner.registerError("You must select a SOURCE plant loop")
      return false
    else
      # Get it! (it's an optional) and convert it to plantloop
      source_loop = source_loop.get.to_PlantLoop.get
    end

    if use_loop.empty?
      runner.registerError("You must select a USE plant loop (secondary)")
      return false
    else
      use_loop = use_loop.get.to_PlantLoop.get
    end

    if source_loop == use_loop
      runner.registerError("You can't have the same loop for SOURCE and USE!")
      return false
    end
    runner.registerInitialCondition("The WaterHeader:Mixed named '#{tank_name}' will be placed on the Demand side of #{source_loop.name} and on the supply side of #{use_loop.name}")

    # Create a tank
    tank = OpenStudio::Model::WaterHeaterMixed.new(model)
    tank.setName(tank_name)


    # Put the tank on the demand side of the source loop
    source_loop.addDemandBranchForComponent(tank)

    # Put the tank on the supply side of the use loop
    use_loop.addSupplyBranchForComponent(tank)

    runner.registerFinalCondition("WaterHeader:Mixed named '#{tank_name} was created with success.\nClick on 'Advanced Output' to see the resulting WaterHeater:Mixed")

    puts tank


    return true

  end
  
end

# register the measure to be used by the application
CreateAWaterHeaterMixedAndAssignItsSourceAndUseSides.new.registerWithApplication
