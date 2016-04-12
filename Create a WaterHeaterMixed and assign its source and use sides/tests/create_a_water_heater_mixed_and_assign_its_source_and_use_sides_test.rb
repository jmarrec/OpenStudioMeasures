require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CreateAWaterHeaterMixedAndAssignItsSourceAndUseSidesTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = CreateAWaterHeaterMixedAndAssignItsSourceAndUseSides.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
    assert_equal("tank_name", arguments[0].name)
    assert_equal("source_loop", arguments[1].name)
    assert_equal("use_loop", arguments[2].name)
  end

  def test_bad_argument_values_same_loop
    # create an instance of the measure
    measure = CreateAWaterHeaterMixedAndAssignItsSourceAndUseSides.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # Create a boiler loop
    source_loop = OpenStudio::Model::PlantLoop.new(model)
    source_loop.setName("Boiler Plant Loop")

    # Create a DHW loop
    use_loop = OpenStudio::Model::PlantLoop.new(model)
    use_loop.setName("DHW Plant Loop")

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["tank_name"] = "Storage tank"
    args_hash["source_loop"] = source_loop.handle.to_s
    args_hash["use_loop"] = source_loop.handle.to_s


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
    assert_equal("Fail", result.value.valueName)
  end

  def test_good_argument_values
    # create an instance of the measure
    measure = CreateAWaterHeaterMixedAndAssignItsSourceAndUseSides.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # Create a boiler loop
    source_loop = OpenStudio::Model::PlantLoop.new(model)
    source_loop.setName("Boiler Plant Loop")

    # Create a DHW loop
    use_loop = OpenStudio::Model::PlantLoop.new(model)
    use_loop.setName("DHW Plant Loop")

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["tank_name"] = "Storage tank"
    args_hash["source_loop"] = source_loop.handle.to_s
    args_hash["use_loop"] = use_loop.handle.to_s


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
    assert(result.info.size == 0)
    assert(result.warnings.size == 0)

    # check that the tank has a plantLoop and a secondaryPlantLoop
    tank = model.getWaterHeaterMixedByName("Storage tank").get
    assert_equal(false, tank.plantLoop.empty?)

    assert_equal(false, tank.secondaryPlantLoop.empty?)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path,true)
  end

end
