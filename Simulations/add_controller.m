function model = add_controller(model, prescribed_controller_type, prescribed_controller_params)
    % This function adds a 'StepFunction' type controller to each muscle in
    % the given model.
    % 
    % NOTE: This functionality is intended for extending the toy models in 
    % the accompanying paper for simulation purposes and is not a core
    % component of the current tool's model generation capabilities. 
    % Therefore, there might be some hard-coding involved in this script.
    % Future versions may integrate this feature more comprehensively into 
    % the core scripts, if required.

    % Import OpenSim libraries
    import org.opensim.modeling.*;

    % The controllers are prescribed by a StepFunction in OpenSim.
    if strcmp(prescribed_controller_type, 'StepFunction')
        
        % Get the number of muscles in the model.
        mtu_num = model.getForceSet().getMuscles().getSize();
        
        % Add a controller for each muscle.
        for i = 1 : mtu_num
            % Get the muscle.
            mtu = Millard2012EquilibriumMuscle.safeDownCast(model.getForceSet().getMuscles().get(i-1));
            mtu_name = char(mtu.getName());

            % If selected MTU names are provided, only stimulate those MTUs.
            if isfield(prescribed_controller_params, 'mtu_names')
                if ~ismember(mtu_name, prescribed_controller_params.mtu_names)
                    continue;
                end
            end
            
            % Create a controller for the muscle.
            controller_to_add = PrescribedController();
            controller_to_add.addActuator(mtu);

            % Get the parameters for the controller.
            exc_starttime = prescribed_controller_params.exc_starttime;
            exc_endtime = prescribed_controller_params.exc_endtime;
            exc_startvalue = prescribed_controller_params.exc_startvalue;
            exc_endvalue = prescribed_controller_params.exc_endvalue;

            % Configure the controller.
            controller_to_add.prescribeControlForActuator(mtu.getName(), StepFunction(exc_starttime, exc_endtime, exc_startvalue, exc_endvalue));
            
            % Add the controller to the model.
            model.addController(controller_to_add);
        end
    
    % Other controller types are not supported for now.
    else
        error('Does not support controller types other than "StepFunction" for now.')
    end

end
