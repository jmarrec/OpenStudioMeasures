# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class SetCOPAndCurvesForChiller < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Set COP and Curves for Chiller"
  end

  # human readable description
  def description
    return "Set COP and Curves for Chiller"
  end

  # human readable description of modeling approach
  def modeler_description
    return "So far it will only look for chillers of type Chiller:Electric:EIR.
Also, it will only accept for EIRFPLR a quadratic or cubic curve, and for EIRFT and CAPFT a biquadratic or bicubic, but modifying it is easy"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for model objects
    chillers_handles = OpenStudio::StringVector.new
    chillers_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    chillers_args = model.getChillerElectricEIRs
    chillers_args_hash = {}
    chillers_args.each do |chiller_arg|
      chillers_args_hash[chiller_arg.name.to_s] = chiller_arg
    end

    #looping through sorted hash of model objects
    chillers_args_hash.sort.map do |key,value|
      chillers_handles << value.handle.to_s
      chillers_display_names << key
    end
    chillers_handles << 'All'
    chillers_display_names << 'All of them'

    #make a choice argument for space type
    chiller = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("chiller", chillers_handles, chillers_display_names, true)
    chiller.setDisplayName("Select the Chiller you want to affect")
    args << chiller

    cop_cooling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cop_cooling', false)
    cop_cooling.setDisplayName('COP Cooling (SI)')
    cop_cooling.setDefaultValue(5.5)
    args << cop_cooling


    ##################################################
    #              Get Curves into hashes
    ##################################################
    #putting quadratic and cubic curves and names into hash
    eirfplr_args_hash = {}
    eirfplr_args = model.getCurveQuadratics
    eirfplr_args.each do |curve_arg|
      eirfplr_args_hash[curve_arg.name.to_s] = curve_arg
    end
    eirfplr_args = model.getCurveCubics
    eirfplr_args.each do |curve_arg|
      eirfplr_args_hash[curve_arg.name.to_s] = curve_arg
    end


    #putting biquadratic and bicubic curves and names into hassh
    bi_curves_args_hash = {}
    bi_curves_args = model.getCurveBiquadratics
    bi_curves_args.each do |curve_arg|
      bi_curves_args_hash[curve_arg.name.to_s] = curve_arg
    end
    bi_curves_args = model.getCurveBicubics
    bi_curves_args.each do |curve_arg|
      bi_curves_args_hash[curve_arg.name.to_s] = curve_arg
    end


    ################################################################################
    #                 Make choice arguments and load the hashed values
    ################################################################################

    ########################        EIR-FPLR         ###############################
    #make a choice argument for model objects for the EIRFPLR curve
    eirfplr_curves_handles = OpenStudio::StringVector.new
    eirfplr_curves_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of model objects to load into choice argument
    eirfplr_args_hash.sort.map do |key,value|
      eirfplr_curves_handles << value.handle.to_s
      eirfplr_curves_display_names << key
    end


    ########################        EIR-FT           ###############################
    #make a choice argument for model objects for the EIRFT curve
    eirft_curves_handles = OpenStudio::StringVector.new
    eirft_curves_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of model objects
    bi_curves_args_hash.sort.map do |key,value|
      eirft_curves_handles << value.handle.to_s
      eirft_curves_display_names << key
    end


    ########################        CAP-FT           ###############################
    #make a choice argument for model objects for the CAPFT curve
    capft_curves_handles = OpenStudio::StringVector.new
    capft_curves_display_names = OpenStudio::StringVector.new
    #looping through sorted hash of model objects
    bi_curves_args_hash.sort.map do |key,value|
      capft_curves_handles << value.handle.to_s
      capft_curves_display_names << key
    end

    ##################################################
    #                 FINAL DISPLAY
    ##################################################
    #make a choice argument for EIRFPLR
    eirfplr_curve = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("eirfplr_curve", eirfplr_curves_handles, eirfplr_curves_display_names,false)
    eirfplr_curve.setDisplayName("Select the quadratic curve you want to use for EIRFPLR")
    args << eirfplr_curve




    #make a choice argument for space type
    eirft_curve = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("eirft_curve", eirft_curves_handles, eirft_curves_display_names,false)
    eirft_curve.setDisplayName("Select the quadratic curve you want to use for EIRFT")
    args << eirft_curve




    #make a choice argument for space type
    capft_curve = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("capft_curve", capft_curves_handles, capft_curves_display_names,false)
    capft_curve.setDisplayName("Select the quadratic curve you want to use for CAPFT")
    args << capft_curve




    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    chiller = runner.getOptionalWorkspaceObjectChoiceValue("chiller",user_arguments, model)
    cop_cooling = runner.getOptionalDoubleArgumentValue("cop_cooling", user_arguments)
    eirfplr_curve = runner.getOptionalWorkspaceObjectChoiceValue("eirfplr_curve",user_arguments, model)
    eirft_curve = runner.getOptionalWorkspaceObjectChoiceValue("eirft_curve",user_arguments, model)
    capft_curve = runner.getOptionalWorkspaceObjectChoiceValue("capft_curve",user_arguments, model)

    # Create an array to store the chiller objects
    chillers = Array.new

    # report initial condition of model
    if chiller.empty?
      handle = runner.getStringArgumentValue("chiller",user_arguments)
      if handle.empty?
        runner.registerError("No chiller was selected.")
        return false
      else
        runner.registerInitialCondition("You chose to affect all chillers")
        chillers = model.getChillerElectricEIRs
      end
    else
      if not chiller.get.to_ChillerElectricEIR.empty?
        #If everything's alright, get the actual Thermal Zone object from the handle
        mychiller = chiller.get.to_ChillerElectricEIR.get
        runner.registerInitialCondition("You chose to affect the Chiller '#{mychiller.name}'")
        chillers << mychiller
      end
    end


    eirfplr = false
    if not eirfplr_curve.empty?
      eirfplr_curve = eirfplr_curve.get
      runner.registerInfo("#{eirfplr_curve.name.to_s} is of class #{eirfplr_curve.class}}")
      if not eirfplr_curve.to_CurveQuadratic.empty?
        eirfplr_curve = eirfplr_curve.to_CurveQuadratic.get
        runner.registerInfo("#{eirfplr_curve.name.to_s} is quadratic")
      elsif not eirfplr_curve.to_CurveCubic.empty?
        eirfplr_curve = eirfplr_curve.to_CurveCubic.get
        runner.registerInfo("#{eirfplr_curve.name.to_s} is cubic")
      end
      eirfplr = true
    end

    eirft = false
    if not eirft_curve.empty?
      eirft_curve = eirft_curve.get
      runner.registerInfo("#{eirft_curve.name.to_s} is of class #{eirft_curve.class}}")
      if not eirft_curve.to_CurveBiquadratic.empty?
        eirft_curve = eirft_curve.to_CurveBiquadratic.get
        runner.registerInfo("#{eirft_curve.name.to_s} is biquadratic")
      elsif eirft_curve.to_CurveBicubic.empty?
        eirft_curve = eirft_curve.to_CurveBicubic.get
        runner.registerInfo("#{eirft_curve.name.to_s} is bicubic")
      end
      eirft = true
    end



    capft = false
    if not capft_curve.empty?
      capft_curve = capft_curve.get
      runner.registerInfo("#{capft_curve.name.to_s} is of class #{capft_curve.class}}")
      if not capft_curve.to_CurveBiquadratic.empty?
        capft_curve = capft_curve.to_CurveBiquadratic.get
        runner.registerInfo("#{capft_curve.name.to_s} is biquadratic")
      elsif capft_curve.to_CurveBicubic.empty?
        capft_curve = capft_curve.to_CurveBicubic.get
        runner.registerInfo("#{capft_curve.name.to_s} is bicubic")
      end
      capft = true
    end


    runner.registerInfo("EIR-FPLR=#{eirfplr}")
    runner.registerInfo("EIR-FT=#{eirft}")
    runner.registerInfo("CAP-FT=#{capft}")

    n = 0
    chillers.each do |chiller|

      runner.registerInfo("#{chiller.name.to_s} of class #{chiller.class}")

      if not cop_cooling.empty?
        previous_cop = chiller.referenceCOP
        chiller.setReferenceCOP(cop_cooling.get)
        runner.registerInfo("Changed COP from #{previous_cop} to #{cop_cooling}")
      end

      if eirfplr
        previous_eirfplr = chiller.electricInputToCoolingOutputRatioFunctionOfPLR.name.to_s
        chiller.setElectricInputToCoolingOutputRatioFunctionOfPLR(eirfplr_curve)
        runner.registerInfo("Changed curve from #{previous_eirfplr} to #{eirfplr_curve.name.to_s}")
      end

      if eirft
        previous_eirft = chiller.electricInputToCoolingOutputRatioFunctionOfTemperature.name.to_s
        chiller.setElectricInputToCoolingOutputRatioFunctionOfTemperature(eirft_curve)
        runner.registerInfo("Changed curve from #{previous_eirft} to #{eirft_curve.name.to_s}")
      end

      if capft
        previous_capft = chiller.coolingCapacityFunctionOfTemperature.name.to_s
        chiller.setCoolingCapacityFunctionOfTemperature(capft_curve)
        runner.registerInfo("Changed curve from #{previous_capft} to #{capft_curve.name.to_s}")
      end

      n += 1

    end

    runner.registerFinalCondition("Successfully modified #{n} chillers")

    return true

  end
  
end

# register the measure to be used by the application
SetCOPAndCurvesForChiller.new.registerWithApplication
