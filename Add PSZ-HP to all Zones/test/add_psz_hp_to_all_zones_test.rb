require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddPSZHPToEachZoneTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = AddPSZHPToEachZone.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)


    # Assert arguments size
    assert_equal(11, arguments.size)

    # Check argnames
    argnames = ['delete_existing', 'cop_cooling', 'cop_heating', 'has_electric_coil', 'has_dcv', 'fan_type', 'fan_pressure_rise', 'filter_type', 'space_type', 'standards_space_type', 'zone_filter']

    argnames.each_with_index do |argname, i|
      assert_equal(argname, arguments[i].name)
    end

  end

  def test_bad_argument_values
    # create an instance of the measure
    measure = AddPSZHPToEachZone.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["space_name"] = ""

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
  end

  def test_good_argument_values_delete_existing


    # Note: in 1.8.5, deleting existing equipment would make it hang (run indefinitely) that's why I added it
    # create an instance of the measure
    measure = AddPSZHPToEachZone.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # store the number of spaces in the seed model
    num_spaces_seed = model.getSpaces.size

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}

    argnames = ['delete_existing', 'cop_cooling', 'cop_heating', 'has_electric_coil', 'has_dcv', 'fan_type', 'fan_pressure_rise', 'filter_type', 'space_type', 'standards_space_type', 'zone_filter']
    argvalues = [true,3.11,3.2,false,false,]

    args_hash["delete_existing"] = true
    args_hash["cop_cooling"] = 3.11
    args_hash["cop_heating"] = 3.2
    args_hash["has_electric_coil"] = false
    args_hash["has_dcv"] = false
    args_hash["fan_type"] = 'Variable Volume (VFD)'
    args_hash["fan_pressure_rise"] = 1178
    args_hash["filter_type"] = "By Space Type's 'Standards Space Type'"
    args_hash["standards_space_type"] = 'OpenOffice'

            # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      # Check if exists
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    #assert(result.info.size == 1)
    #assert(result.warnings.size == 0)

    # check that there is now 1 space
    #assert_equal(1, model.getSpaces.size - num_spaces_seed)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path,true)
  end

  def test_good_argument_values_dont_delete_existing


    # Note: in 1.8.5, deleting existing equipment would make it hang (run indefinitely) that's why I added it
    # create an instance of the measure
    measure = AddPSZHPToEachZone.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # store the number of spaces in the seed model
    num_spaces_seed = model.getSpaces.size

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}

    argnames = ['delete_existing', 'cop_cooling', 'cop_heating', 'has_electric_coil', 'has_dcv', 'fan_type', 'fan_pressure_rise', 'filter_type', 'space_type', 'standards_space_type', 'zone_filter']
    argvalues = [true,3.11,3.2,false,false,]

    args_hash["delete_existing"] = false
    args_hash["cop_cooling"] = 3.11
    args_hash["cop_heating"] = 3.2
    args_hash["has_electric_coil"] = false
    args_hash["has_dcv"] = false
    args_hash["fan_type"] = 'Variable Volume (VFD)'
    args_hash["fan_pressure_rise"] = 1178
    args_hash["filter_type"] = "By Space Type's 'Standards Space Type'"
    args_hash["standards_space_type"] = 'OpenOffice'

    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      # Check if exists
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    #assert(result.info.size == 1)
    #assert(result.warnings.size == 0)

    # check that there is now 1 space
    #assert_equal(1, model.getSpaces.size - num_spaces_seed)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path,true)
  end

end
