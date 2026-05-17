% This script is used to build introductory example models for users new to 
% the repository. The data for model construction is stored in the folder
% ../Models/Hello_ArborSim. Specifically, the data is located in 
% ../Models/Hello_ArborSim/Data/LocalData, using the "local" data format for 
% model construction. It is supposed to represent a simple 2D planar system
% with three links connected via a single degree of freedom rotational 
% joint, incorporating a muscle-tendon architecture where one muscle 
% bifurcates into two tendon branches. The muscle-tendon architecture is 
% modeled using the conventional branching method in 
% ../Models/Hello_ArborSim/Data/LocalData. To construct a model with the 
% proposed branching muscle-tendon architecture, set the explicit_branching
% flag to true in the "Set up the model construction parameters" section 
% below. This will use the proposed branching method, and the adjusted 
% local data will be stored in ../Models/Hello_ArborSim/Data/AdjustedLocalData.

%% Set up the environment
clear; close all;
addpath(genpath('Core'));

%% Set up the model construction parameters
% Define the root directory of the model
model_root_dir = '../Models/Sue_Inspired_Models/Sue_Leg_BranchCount_2';

% Define the name of the model
model_name = 'Sue_Leg2';

% Define the gravity vector of the model
model_gravity_vec = zeros(1,3);

% Define the length and mass units used in the data. Default units for angle 
% and force are degrees ('deg') and Newtons ('N'), respectively.
units_in_data.len = 'm';
units_in_data.mass = 'kg';

% Set the flag for explicit branching. If true, the model will be constructed 
% using the proposed branching muscle-tendon architecture method (detailed in 
% the accompanying paper). Otherwise, the conventional method is used.
explicit_branching = true;

% Parameters for the floating body, used only if explicit_branching is true.
float_body_props.radius = 0.01;
float_body_props.mass = 0.005;
float_body_props.geom_radius = 0.025;

% Define the sliding joint degree of freedom, used only if 
% explicit_branching is true.
sliding_joint_dof = {'ty'};

% Set preset values for tendon slack length and ligament rest length, used 
% only if explicit_branching is true.
preset_tendon_slk_len = 0.5;
preset_ligament_rest_len = 1;

%% Transform the "global" data to "local" data
% Because the data for the introductory example is stored in the "local" 
% data format, this step is commented out. However, PLEASE UNCOMMENT THE
% FOLLOWING LINES OF CODE IN THIS SECTION if one provides the data in the 
% "global" data format, and wants to build the model from the "global" data.

% % Create a transformer object
% transformer_obj = Transformer(model_root_dir, units_in_data);
% 
% % Get the transformation matrices for all bodies and transform the body
% % geometries
% transformer_obj = transformer_obj.get_trans_mats();
% transformer_obj.export_trans_mats()
% transformer_obj.batch_apply_trans_mat_to_geoms()
% 
% % Build the joint coordinate system table in a local data format
% transformer_obj = transformer_obj.build_jcs_tbl();
% transformer_obj.export_jcs_tbl();
% 
% % Build the MTU path table in a local data format
% transformer_obj = transformer_obj.build_mtu_path_tbl();
% transformer_obj.export_mtu_path_tbl();
% 
% % Build the body mass properties table in a local data format
% transformer_obj = transformer_obj.build_body_mass_props_tbl();
% transformer_obj.export_body_mass_props_tbl();
% 
% % Build the wrap surface table in a local data format
% transformer_obj = transformer_obj.build_wrap_surf_tbl();
% transformer_obj.export_wrap_surf_tbl();
% 
% % Copy the files in the "global" data folder to the "local" data folder 
% % directly as they do not need to be transformed
% transformer_obj = transformer_obj.mirror_mtu_params_tbl();
% transformer_obj = transformer_obj.mirror_joint_rom_tbl();
% transformer_obj = transformer_obj.mirror_branch_groups_tbl();
% transformer_obj = transformer_obj.mirror_mtu_wrap_surf_pair_tbl();

%% Adjust the local data if explicit branching flag is set to true
if explicit_branching
    % Create a brancher object
    brancher_obj = Brancher(model_root_dir, units_in_data, float_body_props);

    % Build direct graphs for MTUs in all branch groups
    brancher_obj = brancher_obj.mtu_path_tbl_to_struct();
    brancher_obj = brancher_obj.create_digraphs_for_all_branch_groups();

    % Identify the special nodes in the direct graphs
    brancher_obj = brancher_obj.identify_special_nodes();

    % Add the floating bodies and the respective sliding joints to the model
    brancher_obj = brancher_obj.augment_body_N_joints(sliding_joint_dof);
    
    % Adjust the MTU paths to account for the proposed branching muscle-tendon
    % architecture modeling method
    brancher_obj = brancher_obj.adjust_mtu_path_tbl();
    
    % Adjust the MTU parameters based on the adjusted MTU paths
    brancher_obj = brancher_obj.adjust_mtu_params_tbl(preset_tendon_slk_len, preset_ligament_rest_len);
    
    % Add the floating body visualization geometries to the model
    brancher_obj = brancher_obj.adjust_osim_geom_tbl();
    
    % Adjust the wrapping surface pairs
    brancher_obj = brancher_obj.adjust_wrap_surf_pair_tbl();

    % Export the adjusted local data to the respective directory
    brancher_obj.export_and_mirror_files();
end

%% Manually adjust the MTU and Ligament parameters. 
% Users should manually adjust some physiological parameters based on 
% experimental data, especially the tendon slack length and ligament
% resting length, as described in the accompanying paper.

% Here, we program several lines of code to mannually adjust the 
% ligament resting length. Other parameters do not need to be adjusted in 
% this example.

% In real applications, users are encouraged to adjust the physiological 
% parameters as needed based on their own experimental measurements.

% Define ligament names and rest lengths based on "experimental" measurements
ligament_names = {'trex_branch_group_ligament1', 'trex_branch_group_ligament2','trex_branch_group_ligament3','trex_branch_group_ligament4'};
rest_lens = {0.220227, 0.966228,0.284297,0.284297};

% Adjust the ligament parameters in the adjusted local data
ligament_params_file = [model_root_dir, '/Data/AdjustedLocalData/Ligament_Parameters.csv'];
ligament_params_tbl = readtable(ligament_params_file, 'Delimiter', ',');

for i = 1 : numel(ligament_names)
    [ligament_exists, ligament_idx] = ismember(ligament_names{i}, ligament_params_tbl.ligament_name);
    ligament_params_tbl.rest_len(ligament_idx) = rest_lens{i};
end

writetable(ligament_params_tbl, [model_root_dir, '/Data/AdjustedLocalData/Ligament_Parameters.csv'], ...
           'WriteMode', 'overwrite');

%% Assembly the model components from either the "local" or "adjusted local" data
% Create a builder object
builder_obj = Builder(model_root_dir, explicit_branching, units_in_data, model_gravity_vec);

% Add the bodies, joints, MTUs, and ligaments to the model
builder_obj = builder_obj.add_bodies();
builder_obj = builder_obj.add_joints();
builder_obj = builder_obj.add_mtus();

if explicit_branching
    builder_obj = builder_obj.add_ligaments();
end

% Add the wrap surfaces and link the surfaces to the MTUs and ligaments
builder_obj = builder_obj.add_wrap_surfs();
builder_obj = builder_obj.link_surfs_mtus_ligaments();

% Export the model
builder_obj.finalize_and_export_model(model_name);

