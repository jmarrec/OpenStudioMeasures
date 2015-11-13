# Author: Julien Marrec
# email: julien.marrec@gmail.com

# Largely based on David Goldwasser's measure: Remove orphan objects and unused resources - https://bcl.nrel.gov/node/82267

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class PurgeUnusedDesignSpecificationOutsideAir < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Purge Unused Design Specification OutsideAir"
  end

  # human readable description
  def description
    return "This measure looks for all OS:DesignSpecification:OutdoorAir and remove those that aren't actually used by the model. Also has an optional filter to affect only those that contains the specified string"
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure fetches all the DesignSpecificationOutdoorAir objects.
If a filter is provided, it ignores all that have a name that does not include the specified string.
For each DSOA, it checks the instance.directUseCount and if not used, deletes the object."
  end

  # define the arguments that the user will input
  def arguments(model)

    args = OpenStudio::Ruleset::OSArgumentVector.new

    dsoa_filter = OpenStudio::Ruleset::OSArgument::makeStringArgument('dsoa_filter', false)
    dsoa_filter.setDisplayName("Only Apply to DesignSpecificationOutdoorAirs that contain the following string")
    dsoa_filter.setDescription("Case insensitive. For example, type 'dsoa' to apply to DSOAs that have the word 'DSOA' or 'dsoa' in their name. Leave blank to apply to all DSOAs")
    args << dsoa_filter

    return args

  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    dsoa_filter = runner.getOptionalStringArgumentValue('dsoa_filter', user_arguments)

    initial_number_dsoa = 0
    removed_number_dsoa = 0
    dsoas = model.getDesignSpecificationOutdoorAirs
    total_number_dsoa = dsoas.size

    # Find DSOAs
    # remove orphan design spec oa objects
    orphan_flag = false
    dsoas.sort.each do |instance|

      # Skip DSOA if name doesn't include dsoa_filter
      # Putting everything in Upper Case to make it case insensitive
      if !dsoa_filter.empty?
        next if not instance.name.to_s.upcase.include? dsoa_filter.to_s.upcase
      end

      initial_number_dsoa += 1

      if instance.directUseCount == 0
        runner.registerInfo("Removing orphan design specification outdoor air object named #{instance.name}")
        instance.remove
        removed_number_dsoa += 1
        orphan_flag = true
      end
    end
    if not orphan_flag
      runner.registerInfo("No orphan design specification outdoor air objects were found")
    end

    # echo the new space's name back to the user
    if not dsoa_filter.empty?
      filter_str = "\n Number of DSOAs that matched filter '#{dsoa_filter.to_s}': #{initial_number_dsoa}"
    end
    runner.registerInitialCondition("Total number of DSOAs: #{total_number_dsoa}" + filter_str)

    # report final condition of model
    runner.registerFinalCondition("Number of DSOAs that were removed: #{removed_number_dsoa}")

    return true

  end
  
end

# register the measure to be used by the application
PurgeUnusedDesignSpecificationOutsideAir.new.registerWithApplication
