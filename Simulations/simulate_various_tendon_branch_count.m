   % This script simulates models categorized by fiber length to MTU length 
% ratio as described in the accompanying paper. It applies both the 
% conventional branching modeling method and proposed branching modeling 
% method, storing results in the 'Results' folder.
% 
% IMPORTANT: Run 'create_arborsim_paper_toy_models.m' under the folder: 
% ../Scripts first to generate models.
% 
% CAUTION: Running this script multiple times consecutively without 
% regenerating models may alter the models with each execution.

%% Set up the environment
clear; close all;
import org.opensim.modeling.*;

%% Set up the parameters for the simulation
% Define the master directory for the models, the category of the models, 
% the model name, and the result directory
model_master_dir = '../Models/ArborSim_Paper_Toy_Models/';
category = 'Tendon_Branch_Count_Category';
model_name_prefix = 'Tendon_Branch_Count';
model_name_suffix_arr = 1:6;
result_master_dir = 'Results/';

% Get individual model root directories, names, and result directories
individual_model_dirs = {};
individual_model_names = {};
individual_result_dirs = {};

for i = 1 : numel(model_name_suffix_arr)
    model_name = [model_name_prefix, '_', num2str(model_name_suffix_arr(i))];
    
    individual_model_dirs{end+1, 1} = fullfile(model_master_dir, category, model_name);
    individual_model_names{end+1, 1} = model_name;

    individual_result_dirs{end+1, 1} = fullfile(result_master_dir, category, model_name);
end

% Set the flag for explicit branching.
explicit_branching = {false, true};

% Set the coordinate limit force parameters
rot_coordlimitfrc_transition = 9;
rot_coordlimitfrc_stiffness_ub = 0.2;
rot_coordlimitfrc_damping = 0.4;

% Set the prescribed controller parameters
prescribed_controller_params.exc_starttime = 0.1;
prescribed_controller_params.exc_endtime = 1.1;
prescribed_controller_params.exc_startvalue = 0.2;
prescribed_controller_params.exc_endvalue = 1;

% Set the MTU fiber damping
mtu_fiber_damping = 0.2;

% Set the reporter parameters, including the time step, the simulation
% duration, and the simulation accuracy
reporter_dt = 0.001;
T_sim = 3;
sim_accuracy = 5e-6;

%% Run the simulation
% Loop through the individual model root directories
for i = 1 : numel(individual_model_dirs)
    % For each individual model root directory, loop through the explicit branching flag
    for j = 1 : numel(explicit_branching)
        % Set the osim file and the rigid tendon flag
        if ~explicit_branching{j}
            osim_file = [individual_model_dirs{i}, '/Output/Conventional/', individual_model_names{i}, '.osim'];
            rigid_tendon = false;
        else
            osim_file = [individual_model_dirs{i}, '/Output/Proposed/', individual_model_names{i}, '.osim'];
            rigid_tendon = true;
        end
    
        % Load the model
        osim_model = Model(osim_file);
    
        % Add the prescribed controller to the model
        osim_model = add_controller(osim_model, 'StepFunction', prescribed_controller_params);
        
        % Add the coordinate limit force to the model
        osim_model = add_coordlimitfrc(osim_model, rot_coordlimitfrc_transition, ...
                                       rot_coordlimitfrc_stiffness_ub, rot_coordlimitfrc_damping);
                                       
        % Edit the MTU properties
        osim_model = edit_mtu_properties(osim_model, mtu_fiber_damping, rigid_tendon);
    
        % Add the coordinate reporter to the model
        [osim_model, coord_reporter] = add_coordreporter(osim_model, reporter_dt);
        
        % Finalize the model
        osim_model.initSystem();
        osim_model.finalizeConnections();
        
        % Print the finalized model
        osim_model.print(osim_file);
        
        % Start the simulation
        disp(['Running the simulation for the model: ', individual_model_names{i}, '. Explicit branching: ', char(string(explicit_branching{j})), '.']);
        initstate = osim_model.initSystem();
        sim_manager = Manager(osim_model);
        sim_manager.setIntegratorAccuracy(sim_accuracy);
        sim_manager.initialize(initstate);
    
        sim_manager.integrate(T_sim);
    
        % Save the results
        coord_report = osimTableToStruct(coord_reporter.getTable());
        sto = STOFileAdapter();
    
        if ~explicit_branching{j}
            result_save_dir = [individual_result_dirs{i}, '/Conventional/'];
        else
            result_save_dir = [individual_result_dirs{i}, '/Proposed/'];
        end
    
        if ~isfolder(result_save_dir)
            mkdir(result_save_dir);
        end
    
        sto.write(coord_reporter.getTable(), [result_save_dir, individual_model_names{i}, '_SimMotion.sto']);
        save([result_save_dir, individual_model_names{i},  '_SimData.mat']);
    
    end
end

