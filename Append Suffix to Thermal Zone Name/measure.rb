# Author: Julien Marrec
# email: julien.marrec@gmail.com

# start the measure
class AppendSuffixToThermalZoneName < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Append suffix to Thermal Zone name"
  end

  # human readable description
  def description
    return "Append suffix to thermal zone names either include or don't included a search string"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Loop through all thermal zones, and append a user-specified suffix to thermal zone names that either include or don't include the user-provided search string"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new


    # Make an argument for the type of search: either include or don't include
    chs = OpenStudio::StringVector.new
    chs << "include"
    chs << "don't include"
    match_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('match_type', chs, true)
    match_type.setDisplayName("Affect only thermal zones that include/don't include the searched string")
    args << match_type

    # Make an argument for your searched string
    search_str = OpenStudio::Ruleset::OSArgument::makeStringArgument("search_str",true)
    search_str.setDisplayName("Type the searched string you want search for in thermal zone names")
    search_str.setDescription("Case insensitive. For example, type 'retail' to apply to thermal zones names that have the word 'retail' or 'RETAIL' in their name.")
    args << search_str

    # Make an argument for suffix to add to thermal zone name
    suffix_str = OpenStudio::Ruleset::OSArgument::makeStringArgument("suffix_str",true)
    suffix_str.setDisplayName("Type the suffix you want to add to the thermal zone names")
    args << suffix_str
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
    search_str = runner.getStringArgumentValue("search_str",user_arguments)
    suffix_str = runner.getStringArgumentValue("suffix_str",user_arguments)

    # FanType
    match_type = runner.getStringArgumentValue('match_type', user_arguments)
    runner.registerInfo("Match type: #{match_type}")


    #check the search_str for reasonableness
    puts search_str
    if search_str == ""
      runner.registerError("No search string was entered.")
      return false
    end

    #check the suffix_str for reasonableness
    puts suffix_str
    if suffix_str == ""
      runner.registerError("No suffix string was entered.")
      return false
    end

    # Get Thermal zones
    thermal_zones = model.getThermalZones

    #array for objects with names
    named_objects = []

    # Counter of zones that match/don't match the pattern
    number_match = 0

    #loop through all thermal zones
    thermal_zones.each do |z|

      # Check if thermal zone actually has a name
      if z.name.is_initialized

        # If match_type is include, we skip those that don't match
        if match_type == 'include'
          next if not z.name.to_s.upcase.include? search_str.to_s.upcase
        # else, we skip those that do match
        else
          next if z.name.to_s.upcase.include? search_str.to_s.upcase
        end

        # iterate the counter
        number_match += 1

        old_name = z.name.get
        requested_name = old_name + suffix_str
        new_name = z.setName(requested_name)
        if old_name != new_name
          named_objects << new_name
          runner.registerInfo("Change zone name from '#{old_name}' to '#{requested_name}'")
        elsif old_name != requested_name
          runner.registerWarning("Could not change name of '#{old_name}' to '#{requested_name}'")
        end
      end
    end


    #reporting initial condition of model
    if match_type == 'include'
      match_str = "But only #{number_match} thermal zones actually included the string '#{search_str}'"
    else
      match_str = "But only #{number_match} thermal zones DID NOT include the string '#{search_str}'"
    end
    runner.registerInitialCondition("The model has #{thermal_zones.size} thermal zones \n" + match_str)

    #reporting final condition of model
    runner.registerFinalCondition("#{named_objects.size} thermal zones were renamed")

    return true

  end
  
end

# register the measure to be used by the application
AppendSuffixToThermalZoneName.new.registerWithApplication
