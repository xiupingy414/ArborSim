classdef Brancher
    % This class implements the Brancher. It takes the modeling data where complex muscle-tendon
    % architectures are represented as distinct, separate, and independent muscle-tendon compartments 
    % as input, which is a common practice in musculoskeletal modeling. The class then modifies the data
    % so that branched muscle-tendon architectures are no longer depicted as multiple muscle-tendon compartments.
    % Instead, it models them as a collection of individual muscular and tendinous elements interconnected
    % through extra floating bodies, which explicitly considers the physical interactions between
    % the muscles and tendons within the branched muscle-tendon architectures.
    %
    % For any questions, feedback, issues, please contact author:
    % xunfu@umich.edu (Xun Fu)

    properties
        model_root_dir;                 % The base directory for the model (string)

        branch_group_tbl;               % A table containing the mtu branching groups
        
        mtu_path_struct;                % A structure containing the original muscle-tendon unit paths
        dir_graph_struct;               % A structure containing the directed graphs for the branch groups
        float_body_struct;              % A structure containing the float bodies information
        
        float_sphere_radius;            % The radius of the float sphere (double)
        float_sphere_mass;              % The mass of the float sphere (double)
        float_sphere_geom_radius        % The radius of the float sphere for visualization (double)

        adj_body_mass_props_tbl;        % A table containing the adjusted body mass properties
        adj_jcs_tbl;                    % A table containing the adjusted joint coordinate systems
        adj_joint_rom_tbl;              % A table containing the adjusted joint range of motion
        adj_mtu_path_tbl;               % A table containing the adjusted muscle-tendon unit paths
        adj_mtu_params_tbl;             % A table containing the adjusted muscle-tendon unit parameters
        adj_osim_geom_tbl;              % A table containing the adjusted OpenSim artifical geometries
        adj_wrap_surf_pair_tbl;         % A table containing the adjusted wrapping surface pairs

        ligament_path_tbl;              % A table containing the ligament paths
        ligament_params_tbl;            % A table containing the ligament parameters

        len_unit_in_data;               % The length unit used in the data (string)
        mass_unit_in_data;              % The mass unit used in the data (string)
        force_unit_in_data;             % The force unit used in the data (string)
        angle_unit_in_data;             % The angle unit used in the data (string)

    end

    methods
        function obj = Brancher(model_root_dir, unit_struct, float_sphere_props)
            % Constructor for the Brancher class
            %
            % Inputs:
            %   - model_root_dir: The root directory of the model (string). 
            %   - unit_struct: A structure containing the units of the model (struct).
            %   - float_sphere_props: A structure containing the properties of the float sphere (struct).
            %     This includes the radius, mass, and radius for visualization of the float sphere.
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object)
            %
            % Example usage:
            %   obj = Brancher(model_root_dir, unit_struct, float_sphere_props)

            % Set the model root directory
            obj.model_root_dir = model_root_dir;
            
            % Initialize the properties with empty values
            obj.branch_group_tbl = [];

            obj.mtu_path_struct = [];
            obj.dir_graph_struct = [];
            obj.float_body_struct = [];

            obj.float_sphere_radius = 0;
            obj.float_sphere_mass = 0;
            obj.float_sphere_geom_radius = 0;
            
            obj.adj_body_mass_props_tbl = [];
            obj.adj_jcs_tbl = [];
            obj.adj_joint_rom_tbl = [];
            obj.adj_mtu_path_tbl = [];
            obj.adj_osim_geom_tbl = [];
            obj.adj_wrap_surf_pair_tbl = [];

            obj.ligament_path_tbl = [];
            obj.ligament_params_tbl = [];
            
            % Define the default values for the units and float sphere properties
            def_len_unit_in_data = 'mm';
            def_mass_unit_in_data = 'g';
            def_float_sphere_radius = 1;
            def_float_sphere_mass = 0.001;
            def_float_sphere_geom_radius = 0.1;

            % If unit_struct is provided, use it to set the units. Otherwise, use the default units.
            if nargin > 1
                if ~isempty(unit_struct)
                    obj.len_unit_in_data = unit_struct.len;
                    obj.mass_unit_in_data = unit_struct.mass;
                else
                    obj.len_unit_in_data = def_len_unit_in_data;
                    obj.mass_unit_in_data = def_mass_unit_in_data;
                end

                % If float_sphere_props is provided, use it to set the float sphere properties. 
                % Otherwise, use the default properties.
                if nargin > 2
                    if ~isempty(float_sphere_props)
                        obj.float_sphere_radius = float_sphere_props.radius;
                        obj.float_sphere_mass = float_sphere_props.mass;
                        obj.float_sphere_geom_radius = float_sphere_props.geom_radius;
                    else
                        obj.float_sphere_radius = def_float_sphere_radius;
                        obj.float_sphere_mass = def_float_sphere_mass;
                        obj.float_sphere_geom_radius = def_float_sphere_geom_radius;
                    end
                else
                    obj.float_sphere_radius = def_float_sphere_radius;
                    obj.float_sphere_mass = def_float_sphere_mass;
                    obj.float_sphere_geom_radius = def_float_sphere_geom_radius;
                end
            else
                obj.len_unit_in_data = def_len_unit_in_data;
                obj.mass_unit_in_data = def_mass_unit_in_data;

                obj.float_sphere_radius = def_float_sphere_radius;
                obj.float_sphere_mass = def_float_sphere_mass;
                obj.float_sphere_geom_radius = def_float_sphere_geom_radius;
            end
            
            % Set the force and angle units to the default units (Newtons (N) and degrees (deg) respectively)
            % Note: The current tool configuration does not support other options for force and angle units
            obj.force_unit_in_data = 'N';
            obj.angle_unit_in_data = 'deg';

        end

        function obj = load_branch_groups_tbl(obj)
            % This method loads the branch group table from the Branch_Groups.csv file
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     branch_group_tbl property.
            %
            % Example usage:
            %   obj = obj.load_branch_groups_tbl()

            % Read and store the branch group table from the Branch_Groups.csv file
            branch_groups_file = [obj.model_root_dir, '/Data/LocalData/Branch_Groups.csv'];
            obj.branch_group_tbl = readtable(branch_groups_file, 'Delimiter', ',');
        
        end

        function obj = create_digraphs_for_all_branch_groups(obj)
            % This method creates directed graphs for all branch groups. One for each branch group.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     dir_graph_struct property.
            %
            % Example usage:
            %   obj = obj.create_digraphs_for_all_branch_groups()

            % Load the branch groups table
            obj = obj.load_branch_groups_tbl();
            
            % Initialize the dir_graph_struct property
            dir_graph_struct = struct;

            % Loop over all branch groups
            for i = 1 : size(obj.branch_group_tbl, 1)
                % Get the group name and MTUs in the group from the current row
                group_name = obj.branch_group_tbl.group_name{i};
                mtu_in_group = obj.branch_group_tbl.mtu_in_group{i};

                % Split the MTUs in the group into a cell array
                mtu_in_group = strtrim(strsplit(mtu_in_group, ','));

                % Create a directed graph for the current branch group
                [G, metadata] = obj.create_digraph_for_one_branch_group(mtu_in_group);

                % Store the directed graph and metadata in the dir_graph_struct property
                dir_graph_struct(i).group_name = group_name;
                
                % Add a new field to the edges of the graph. This will be used to store the 
                % MTU or ligament name associated with each edge.
                G.Edges.corr_mtu_ligament = repmat({'TBD'}, numedges(G), 1);
                
                % Store the directed graph and metadata in the dir_graph_struct property
                dir_graph_struct(i).G = G;
                dir_graph_struct(i).metadata = metadata;

            end

            % Set the dir_graph_struct property
            obj.dir_graph_struct = dir_graph_struct;

        end

        function [G, metadata] = create_digraph_for_one_branch_group(obj, mtu_in_group)
            % This method creates a directed graph for a single branch group.
            %
            % Inputs: None
            %
            % Outputs:
            %   - G: A directed graph representing the branch group (digraph object).
            %   - metadata: A structure containing metadata for the branch group (struct).
            %
            % Example usage:
            %   [G, metadata] = obj.create_digraph_for_one_branch_group(mtu_in_group)

            % Initialize the directed graph and metadata
            G = digraph();
            metadata = struct;

            % Initialize the node index
            node_idx = 1;
            % Loop over all MTUs in the branch group
            for i = 1 : numel(mtu_in_group)
                % Get the current MTU name and path
                mtu = mtu_in_group{i};
                mtu_path = obj.mtu_path_struct.(mtu);
                
                % Get the points in the current MTU path
                pts = fieldnames(mtu_path);

                % Initialize the previous node name with an empty value
                prev_node_name = [];

                % Loop over all points in the current MTU path
                for j = 1 : numel(pts)
                    % Get the attached body, location in body, and point type for the current point
                    pt_attached_body = mtu_path.(pts{j}).attached_body;
                    pt_loc_in_body = mtu_path.(pts{j}).loc_in_body;
                    pt_type = mtu_path.(pts{j}).pt_type;
                    
                    % Check if the current point is already in the graph
                    [node_exists, found_node_name] = obj.is_node_in_graph(G, pt_attached_body, pt_loc_in_body, pt_type);

                    % If the current point is already in the graph
                    if node_exists
                        % If the current point is not an MTU's origin point
                        if j ~= 1
                            % Check if the edge between the previous node and the current node already exists
                            if ~findedge(G, prev_node_name, found_node_name)
                                % If the edge does not exist, add an edge between the previous node and the current node
                                G = addedge(G, prev_node_name, found_node_name);
                            end
                        end
                        % Update the previous node name
                        prev_node_name = found_node_name;

                        % Update the metadata for the current node
                        metadata.(found_node_name).asso_org_mtu_info.(mtu).pt_idx = j;
                        metadata.(found_node_name).asso_org_mtu_info.(mtu).pt_type = pt_type;
                    
                    % If the current point is not already in the graph
                    else
                        % Create a new node for the current point
                        new_node_name = ['Node', num2str(node_idx)];
                        new_node = table({new_node_name}, {pt_attached_body}, pt_loc_in_body, {pt_type}, ...
                                        'VariableNames', {'Name', 'attached_body', 'loc_in_body', 'pt_type'});
                        
                        % Add the new node to the graph
                        G = addnode(G, new_node);
                        
                        % If the current point is not an MTU's origin point, add an edge between the 
                        % previous node and the current node
                        if j ~= 1
                            G = addedge(G, prev_node_name, new_node_name);
                        end

                        % Update the metadata for the current node
                        metadata.(new_node_name).attached_body = pt_attached_body;
                        metadata.(new_node_name).loc_in_body = pt_loc_in_body;
                        
                        metadata.(new_node_name).asso_org_mtu_info.(mtu).pt_idx = j;
                        metadata.(new_node_name).asso_org_mtu_info.(mtu).pt_type = pt_type;

                        % Update the node index and previous node name
                        node_idx = node_idx + 1;
                        prev_node_name = new_node_name;

                    end
                end
            end
        end

        function [node_exists, node_name] = is_node_in_graph(obj, G, attached_body, loc, pt_type)
            % This method checks if a node is already in a graph.
            %
            % Inputs:
            %   - G: A directed graph (digraph object).
            %   - attached_body: The name of the attached body for the node (string).
            %   - loc: The location of the node in the attached body (1x3 double).
            %   - pt_type: The type of the node (string).
            %
            % Outputs:
            %   - node_exists: A boolean indicating whether the node is already in the graph (boolean).
            %   - node_name: The name of the node if it is already in the graph. NaN otherwise (string or NaN).
            %
            % Example usage:
            %   [node_exists, node_name] = obj.is_node_in_graph(G, attached_body, loc, pt_type)

            % Get the node table from the graph
            node_table = G.Nodes;

            % Check if the node table is empty
            if isempty(node_table)
                % If the node table is empty, set the node exists flag to false and the node name to NaN and return
                node_exists = false;
                node_name = NaN;
                return;
            end
            
            % Define a boolean array indicating whether the attached body of each node in the graph 
            % matches the attached body of the node to check
            attached_body_exists = strcmp(node_table.('attached_body'), attached_body);            
            
            % Compute the difference between the location of each node in the graph and the 
            % location of the node to check
            loc_diff = node_table.('loc_in_body') - loc;
            
            % Define a boolean array indicating whether the location of each node in the graph 
            % matches the location of the node to check
            loc_exists = all(loc_diff == 0, 2);
            
            % Define a boolean array indicating whether the type of each node in the graph matches 
            % the type of the node to check
            type_exists = strcmp(node_table.('pt_type'), pt_type);

            % Define a boolean array indicating whether the node to check is already in the graph 
            % by checking if the attached body, location, and type of the node match any node in 
            % the graph simultaneously
            node_exists = attached_body_exists & loc_exists & type_exists;
            
            % find non-zero elements in the node_exists array
            row_idx = find(node_exists);

            % If the node does not exist, set the node exists flag to false and the node name to NaN
            if isempty(row_idx)
                node_exists = false;
                node_name = NaN;
            % If more than one node exists, throw an error
            elseif numel(row_idx) > 1
                error('More than one node(vertex) represents the same point.')
            % If only one node exists, set the node exists flag to true and the node name to the name of the node
            else
                node_exists = true;
                node_name = node_table.('Name'){row_idx};
            end

        end

        function obj = identify_special_nodes(obj)
            % This method identifies the special nodes in each directed graph. The special nodes are 
            % the origin nodes, branch nodes, and insertion nodes.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     dir_graph_struct property.
            %
            % Example usage:
            %   obj = obj.identify_special_nodes()

            % Loop over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Get the directed graph
                G = obj.dir_graph_struct(i).G;

                % Compute the in-degree and out-degree of each node in the graph
                in_deg = indegree(G);
                out_deg = outdegree(G);

                % Identify the origin nodes, branch nodes, and insertion nodes           
                is_origin_node = (in_deg == 0) & (out_deg > 0);
                is_branch_node = (in_deg + out_deg >= 3) & (in_deg > 0) & (out_deg > 0);
                is_insertion_node = (out_deg == 0) & (in_deg > 0);

                % Get the names of the origin nodes, branch nodes, and insertion nodes
                origin_node_names = G.Nodes.Name(is_origin_node);
                branch_node_names = G.Nodes.Name(is_branch_node);
                insertion_node_names = G.Nodes.Name(is_insertion_node);

                % Store the special nodes in the dir_graph_struct property
                obj.dir_graph_struct(i).special_nodes.origin_nodes = origin_node_names;
                obj.dir_graph_struct(i).special_nodes.branch_nodes = branch_node_names;
                obj.dir_graph_struct(i).special_nodes.insertion_nodes = insertion_node_names;

            end
        
        end

        function obj = augment_body_N_joints(obj, slide_joint_dof)
            % This method augments the body, joint, and joint ROM tables to include the float bodies and joints.
            %
            % Inputs:
            %   - slide_joint_dof: The degrees of freedom for the slide joints (cell array of strings).
            %     This should be a subset of {'tx', 'ty', 'tz', 'rx', 'ry', 'rz'}. 
            %     The default value is {'tx', 'ty', 'tz'}.
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with updated body, joint, and joint ROM tables.
            %
            % Example usage:
            %   obj = obj.augment_body_N_joints(slide_joint_dof)

            % If the slide joint degrees of freedom are not provided, use the default values
            if nargin == 1
                slide_joint_dof = {'tx', 'ty', 'tz'};
            end

            % Create a structure containing the float bodies
            obj = obj.create_float_body_struct();
            
            % Adjust the body, joint, and joint ROM tables to include the float bodies and joints
            obj = obj.adjust_body_mass_props_tbl();
            obj = obj.adjust_jcs_tbl();
            obj = obj.adjust_joint_rom_tbl(slide_joint_dof);

        end

        function obj = adjust_body_mass_props_tbl(obj)
            % This method adjusts the body mass properties table to include the float bodies.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     adj_body_mass_props_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_body_mass_props_tbl()

            % Read the body mass properties table from the Body_Mass_Properties.csv file
            body_mass_props_file = [obj.model_root_dir, '/Data/LocalData/Body_Mass_Properties.csv'];
            body_mass_props_tbl = readtable(body_mass_props_file, 'Delimiter', ',');
            
            % Check if the body name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(body_mass_props_tbl.body_name(:));
            
            % If the body name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the body_name column']);
            end
            
            % Loop over all float bodies
            for i = 1 : numel(obj.float_body_struct)
                % Get the float body name from the float_body_struct's body_name field
                float_body_name = obj.float_body_struct(i).body_name;
                
                % Set the mass to be predefined float sphere mass
                mass = obj.float_sphere_mass;
                
                % Set the center of mass with respect to the float body frame to be the origin
                com = zeros(1, 3);

                % Set the inertia with respect to the float body frame to be the inertia of a sphere
                inertia = [(2 * obj.float_sphere_mass * (obj.float_sphere_radius)^2 / 5) * ones(1, 3), zeros(1, 3)];
                
                % Define a row to add to the body mass properties table
                row_to_add = {float_body_name, mass, ...
                              com(1), com(2), com(3), ...
                              inertia(1), inertia(2), inertia(3), ...
                              inertia(4), inertia(5), inertia(6)};
                
                % Add the row to the body mass properties table
                body_mass_props_tbl = [body_mass_props_tbl; row_to_add];

            end
            
            % Update the adj_body_mass_props_tbl property
            obj.adj_body_mass_props_tbl = body_mass_props_tbl;

        end
        
        function obj = adjust_jcs_tbl(obj)
            % This method adjusts the joint coordinate system table to include the float joints.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated adj_jcs_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_jcs_tbl()

            % Read the joint coordinate system table from the JCS.csv file
            jcs_file = [obj.model_root_dir, '/Data/LocalData/JCS.csv'];
            jcs_tbl = readtable(jcs_file, 'Delimiter', ',');

            % Check if the joint name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(jcs_tbl.joint_name(:));
            
            % If the joint name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the joint_name column']);
            end
            
            % Loop over all float bodies
            for i = 1 : numel(obj.float_body_struct)
                % Get the float body name and attached body name from the float_body_struct's body_name 
                % and attached_body fields
                float_body = obj.float_body_struct(i).body_name;
                attached_body = obj.float_body_struct(i).attached_body;

                % Set the parent body to be the body the float body is attached to
                par_body = attached_body;
                
                % Set the child body to be the float body
                chd_body = float_body;

                % Set the joint name to be the parent body name followed by the child body name
                joint_name = [par_body, '_', chd_body];
                
                % Set the location of the joint in the parent body frame to be the location of the float body 
                % in the parent body frame
                loc_in_par = obj.float_body_struct(i).loc_in_body;
                
                % Set the orientation of the joint in the parent body frame to be zero
                ori_in_par = zeros(1, 3);
                
                % Set the location and orientation of the joint in the child body to be zero
                loc_in_chd = zeros(1, 3);
                ori_in_chd = zeros(1, 3);
                
                % Define a row to add to the joint coordinate system table
                row_to_add = {joint_name, par_body, chd_body, ...
                              loc_in_par(1), loc_in_par(2), loc_in_par(3), ...
                              ori_in_par(1), ori_in_par(2), ori_in_par(3), ...
                              loc_in_chd(1), loc_in_chd(2), loc_in_chd(3), ...
                              ori_in_chd(1), ori_in_chd(2), ori_in_chd(3)};
                
                % Add the row to the joint coordinate system table
                jcs_tbl = [jcs_tbl; row_to_add];

            end
            
            % Update the adj_jcs_tbl property
            obj.adj_jcs_tbl = jcs_tbl;

        end
        
        function obj = adjust_joint_rom_tbl(obj, dof)
            % This method adjusts the joint range of motion table to include the float joints.
            %
            % Inputs: None
            %   - dof: The degrees of freedom for the float joints (cell array of strings).
            %     This should be a subset of {'rx', 'ry', 'rz', 'tx', 'ty', 'tz'}.
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated adj_joint_rom_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_joint_rom_tbl(dof)

            % Read the joint range of motion table from the Joint_ROM.csv file
            joint_rom_file = [obj.model_root_dir, '/Data/LocalData/Joint_ROM.csv'];
            joint_rom_tbl = readtable(joint_rom_file, 'Delimiter', ',');

            % Check if the joint name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(joint_rom_tbl.joint_name(:));
            
            % If the joint name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the joint_name column']);
            end
            
            % Join the dof strings into a single string with commas as delimiters
            dof = strjoin(strtrim(dof), ',');
            
            % Loop over all float bodies
            for i = 1 : numel(obj.float_body_struct)
                % Get the float body name and attached body name from the float_body_struct's body_name 
                % and attached_body fields
                float_body = obj.float_body_struct(i).body_name;
                attached_body = obj.float_body_struct(i).attached_body;

                % Set the parent body to be the body the float body is attached to
                par_body = attached_body;
                
                % Set the child body to be the float body
                chd_body = float_body;

                % Set the joint name to be the parent body name followed by the child body name
                joint_name = [par_body, '_', chd_body];
                
                % Set the minimum and maximum values for each degree of freedom to be NaN
                min_rx = NaN; max_rx = NaN;
                min_ry = NaN; max_ry = NaN; 
                min_rz = NaN; max_rz = NaN;
                
                min_tx = NaN; max_tx = NaN;
                min_ty = NaN; max_ty = NaN;
                min_tz = NaN; max_tz = NaN;
                
                % Define a row to add to the joint range of motion table
                row_to_add = {joint_name, dof, ...
                              min_rx, max_rx, min_ry, max_ry, min_rz, max_rz, ...
                              min_tx, max_tx, min_ty, max_ty, min_tz, max_tz};
                
                % Add the row to the joint range of motion table
                joint_rom_tbl = [joint_rom_tbl; row_to_add];
            end
            
            % Update the adj_joint_rom_tbl property
            obj.adj_joint_rom_tbl = joint_rom_tbl;

        end

        function obj = create_float_body_struct(obj)
            % This method creates a structure containing the float bodies. The structure contains the 
            % name of the float body, the name of the body the float body is attached to, and the 
            % location of the float body in the attached body frame. This method also creates a new 
            % field in the dir_graph_struct property to map the branch nodes to the float bodies.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     float_body_struct property and an 
            %     updated dir_graph_struct property.
            % 
            % Example usage:
            %   obj = obj.create_float_body_struct()  
            
            % Initialize the float body structure
            float_body_struct = struct;
            
            % Initialize the float body index
            float_body_idx = 1;

            % Loop over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Get the directed graph and branch nodes
                G = obj.dir_graph_struct(i).G;
                branch_nodes = obj.dir_graph_struct(i).special_nodes.branch_nodes;
                
                % Loop over all branch nodes
                for j = 1 : numel(branch_nodes)
                    % Set the name of the float body to be 'float' followed by the float body index
                    float_body_name = ['float', num2str(float_body_idx)];
                    
                    % Get the name of the branch node
                    node_name = branch_nodes{j};
                    
                    % Get the index of the branch node in the graph
                    node_idx = findnode(G, node_name);

                    % Get the attached body and location of the branch node
                    attached_body = G.Nodes.attached_body{node_idx};
                    loc_in_body = G.Nodes.loc_in_body(node_idx, :);

                    % Store the float body name, attached body, and location in the float body structure
                    float_body_struct(float_body_idx).body_name = float_body_name;
                    float_body_struct(float_body_idx).attached_body = attached_body;
                    float_body_struct(float_body_idx).loc_in_body = loc_in_body;
                    
                    % Store the mapping between the branch node and the float body in the dir_graph_struct property
                    obj.dir_graph_struct(i).bnode_to_fb.(node_name) = float_body_name;
                    
                    % Increment the float body index
                    float_body_idx = float_body_idx + 1;
                end
            
            end
            
            % Update the float_body_struct property
            obj.float_body_struct = float_body_struct;
        
        end

        function obj = adjust_mtu_path_tbl(obj)
            % This method adjusts the muscle-tendon unit path to model the mtus within the 
            % branch groups as individual mtus and ligaments.
            % 
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated 
            %     adj_mtu_path_tbl property and an updated ligament_path_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_mtu_path_tbl()

            % Extract the ungrouped mtu path structure from the mtu_path_struct property
            ungrouped_mtu_path_struct = obj.extract_ungrouped_mtu_path_struct();
            
            % Build the branched mtu path structure
            [grouped_mtu_path_struct, obj] = obj.build_branched_mtu_path_struct();
            
            % Build the ligament path structure
            [ligament_path_struct, obj] = obj.build_ligament_path_struct();
            
            % Define the mtu path table variable names and types
            mtu_path_tbl_variable_names = {'mtu_name', 'pt_idx', 'pt_type', 'attached_body', ...
                                           'loc_in_body_x', 'loc_in_body_y', 'loc_in_body_z'};
            mtu_path_tbl_variable_types = [{'string'}, {'uint8'}, repmat({'string'}, 1, 2), repmat({'double'}, 1, 3)];

            % Initialize the muscle-tendon unit path table
            adj_mtu_path_tbl = table('Size', [0, length(mtu_path_tbl_variable_names)], 'VariableTypes', ...
                                     mtu_path_tbl_variable_types, 'VariableNames', mtu_path_tbl_variable_names);
            
            % Combine the ungrouped and grouped mtu path structures into a single mtu path structure
            adj_mtu_path_tbl = obj.transfer_path_struct_to_path_tbl(adj_mtu_path_tbl, ungrouped_mtu_path_struct);
            adj_mtu_path_tbl = obj.transfer_path_struct_to_path_tbl(adj_mtu_path_tbl, grouped_mtu_path_struct);

            % Define the ligament path table variable names and types
            ligament_path_tbl_variable_names = {'ligament_name', 'pt_idx', 'pt_type', 'attached_body', ...
                                                'loc_in_body_x', 'loc_in_body_y', 'loc_in_body_z'};
            ligament_path_tbl_variable_types = [{'string'}, {'uint8'}, repmat({'string'}, 1, 2), repmat({'double'}, 1, 3)];
            
            % Initialize the ligament path table
            ligament_path_tbl = table('Size', [0, length(ligament_path_tbl_variable_names)], 'VariableTypes', ...
                                     ligament_path_tbl_variable_types, 'VariableNames', ligament_path_tbl_variable_names);
            
            % Transfer the ligament path structure to the ligament path table
            ligament_path_tbl = obj.transfer_path_struct_to_path_tbl(ligament_path_tbl, ligament_path_struct);

            % Update the adj_mtu_path_tbl and ligament_path_tbl properties
            obj.adj_mtu_path_tbl = adj_mtu_path_tbl;
            obj.ligament_path_tbl = ligament_path_tbl;

        end

        function obj = adjust_mtu_params_tbl(obj, preset_tendon_slk_len, preset_ligament_rest_len)
            % This method adjusts the muscle-tendon unit parameters and introduces ligament parameters after the original muscle-tendon
            % units are adjusted to explicitly model the muscle-tendon units within the branch groups as individual muscle-tendon units and ligaments.            
            %
            % Inputs:
            %   - preset_tendon_slk_len: The preset tendon slack length for the muscle-tendon units (double).
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated adj_mtu_params_tbl property and an updated
            %     ligament_params_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_mtu_params_tbl(1, 10)

            % If the preset tendon slack length and/or the preset ligament rest length are not provided, use NaN as the default values.
            % Otherwise, use the provided values.
            if nargin > 1
                preset_tendon_slk_len = preset_tendon_slk_len;
                if nargin > 2
                    preset_ligament_rest_len = preset_ligament_rest_len;
                else
                    preset_ligament_rest_len = NaN;
                end
            else
                preset_tendon_slk_len = NaN;
                preset_ligament_rest_len = NaN;
            end

            % Extract the ungrouped muscle-tendon unit parameters table and the original muscle-tendon unit parameters table from the
            [ungrouped_mtu_params_tbl, org_mtu_params_tbl] = obj.extract_ungrouped_mtu_params_tbl();

            % Define the muscle-tendon unit parameters table variable names and types
            mtu_params_variable_names = {'mtu_name', 'max_iso_frc', ...
                                         'opt_fib_len', 'tendon_slk_len', 'penn_ang', 'def_fib_len'};

            mtu_params_variable_types = [repmat({'string'}, 1, 1), repmat({'double'}, 1, 5)];

            % Initialize the muscle-tendon unit parameters table
            adj_mtu_params_tbl = table('Size', [0, length(mtu_params_variable_names)], 'VariableTypes', ...
                                       mtu_params_variable_types, 'VariableNames', mtu_params_variable_names);

            % Add the ungrouped muscle-tendon unit parameters to the muscle-tendon unit parameters table                           
            adj_mtu_params_tbl = [adj_mtu_params_tbl; ungrouped_mtu_params_tbl];
            
            % Get the muscle-tendon unit names that are not in the ungrouped muscle-tendon unit parameters table
            adj_mtu_names = setdiff(unique(obj.adj_mtu_path_tbl.mtu_name), ungrouped_mtu_params_tbl.mtu_name);

            % Loop over all muscle-tendon units that are not in the ungrouped muscle-tendon unit parameters table
            for i = 1 : numel(adj_mtu_names)
                % Get the current muscle-tendon unit name
                adj_mtu_name = adj_mtu_names(i);

                % Get the original muscle-tendon units that are associated with the current muscle-tendon unit
                org_mtus = obj.fetch_value_from_mtu_ligament_map(adj_mtu_name);
                
                % Calculate the adjusted muscle-tendon unit parameters
                adj_mtu_params = obj.cal_adj_mtu_params(org_mtus, org_mtu_params_tbl, preset_tendon_slk_len);

                % Extract the adjusted muscle-tendon unit parameters
                max_iso_frc =  adj_mtu_params.max_iso_frc;
                opt_fib_len = adj_mtu_params.opt_fib_len;
                tendon_slk_len = adj_mtu_params.tendon_slk_len;
                penn_ang = adj_mtu_params.penn_ang;
                def_fib_len = adj_mtu_params.def_fib_len;
                
                % Define a row to add to the muscle-tendon unit parameters table
                row_to_add = {adj_mtu_name, max_iso_frc, ...
                              opt_fib_len, tendon_slk_len, penn_ang, def_fib_len};

                % Add the row to the muscle-tendon unit parameters table
                adj_mtu_params_tbl = [adj_mtu_params_tbl; row_to_add];
            end
            
            % Define the ligament parameters table variable names and types
            ligament_params_variable_names = {'ligament_name', 'frc_scale', 'rest_len'};
            ligament_params_variable_types = [repmat({'string'}, 1, 1), repmat({'double'}, 1, 2)];

            ligament_params_tbl = table('Size', [0, length(ligament_params_variable_names)], 'VariableTypes', ...
                                        ligament_params_variable_types, 'VariableNames', ligament_params_variable_names);
            
            % Get the ligament names
            ligament_names = unique(obj.ligament_path_tbl.ligament_name);
            
            % Loop over all ligament names
            for i = 1 : numel(ligament_names)
                % Get the current ligament name
                ligament_name = ligament_names(i);

                % Get the original muscle-tendon units that are associated with the current ligament
                org_mtus = obj.fetch_value_from_mtu_ligament_map(ligament_name);
                
                % Calculate the ligament parameters
                ligament_params = obj.cal_ligament_params(org_mtus, org_mtu_params_tbl, preset_ligament_rest_len);

                % Extract the ligament parameters
                frc_scale = ligament_params.frc_scale;
                rest_len =  ligament_params.rest_len;

                % Define a row to add to the ligament parameters table
                row_to_add = {ligament_name, frc_scale, rest_len};
                ligament_params_tbl = [ligament_params_tbl; row_to_add];
            end

            % Update the adj_mtu_params_tbl and ligament_params_tbl properties
            obj.adj_mtu_params_tbl = adj_mtu_params_tbl;
            obj.ligament_params_tbl = ligament_params_tbl;

        end
        
        function adj_mtu_params = cal_adj_mtu_params(obj, mtus, mtu_params_tbl, preset_tendon_slk_len)
            % This method calculates the adjusted parameters of a muscle-tendon unit after the original muscle-tendon units that include
            % the muscle-tendon unit are adjusted.
            %
            % Inputs:
            %   - mtus: The original muscle-tendon units that include the adjusted muscle-tendon unit (cell array of strings).
            %   - mtu_params_tbl: The original muscle-tendon unit parameters table (table).
            %   - preset_tendon_slk_len: The preset tendon slack length for the muscle-tendon units (double).
            %
            % Outputs:
            %   - adj_mtu_params: The adjusted muscle-tendon unit parameters (structure).
            %
            % Example usage:
            %   adj_mtu_params = obj.cal_adj_mtu_params(mtus, mtu_params_tbl, preset_tendon_slk_len)

            % Initialize the adjusted muscle-tendon unit parameters
            max_iso_frc =  NaN(1, numel(mtus));
            opt_fib_len = NaN(1, numel(mtus));
            penn_ang = NaN(1, numel(mtus));
            def_fib_len = NaN(1, numel(mtus));

            % Loop over all original muscle-tendon units that include the adjusted muscle-tendon unit
            for i = 1 : numel(mtus)
                % Get the index of the original muscle-tendon unit in the original muscle-tendon unit parameters table
                [~, idx] = ismember(mtus{i}, mtu_params_tbl.mtu_name);
                
                % Extract the original muscle-tendon unit parameters
                max_iso_frc(i) = mtu_params_tbl.max_iso_frc(idx);
                opt_fib_len(i) = mtu_params_tbl.opt_fib_len(idx);
                penn_ang(i) = mtu_params_tbl.penn_ang(idx);
                def_fib_len(i) = mtu_params_tbl.def_fib_len(idx);

            end
            
            % Check if the original muscle-tendon units share the same optimal fiber length, pennation angle, and default fiber length
            uni_opt_fib_len = unique(opt_fib_len);
            uni_pen_ang = unique(penn_ang);
            uni_def_fib_len = unique(def_fib_len);
            
            % If the original muscle-tendon units do not share the same optimal fiber length, pennation angle, and default fiber length,
            % issue a warning and use the first optimal fiber length, pennation angle, and default fiber length
            if numel(uni_opt_fib_len) > 1
                warning([strjoin(mtus, ' and '), ' do not share the optimal fiber length in the original MTU parameters... ', ...
                         'Using ', mtus{1}, '''s optimal fiber length.']);
            end
            
            if numel(uni_pen_ang) > 1
                warning([strjoin(mtus, ' and '), ' do not share the pennation angle in the original MTU parameters... ', ...
                         'Using ', mtus{1}, '''s pennation angle']);
            end

            if numel(uni_def_fib_len) > 1
                warning([strjoin(mtus, ' and '), ' do not share the default fiber length in the original MTU parameters... ', ...
                        'Using ', mtus{1}, '''s default fiber length']);
            end
            
            % Store the adjusted muscle-tendon unit parameters
            adj_mtu_params.max_iso_frc = sum(max_iso_frc);
            adj_mtu_params.opt_fib_len = uni_opt_fib_len(1);
            adj_mtu_params.penn_ang = uni_pen_ang(1);
            adj_mtu_params.def_fib_len = uni_def_fib_len(1);
            
            % Assign the preset tendon slack length to the tendon slack length of the adjusted muscle-tendon unit.
            % NOTE THAT THIS IS NOT THE FINAL TENDON SLACK LENGTH OF THE ADJUSTED MUSCLE-TENDON UNIT. USERS ARE EXPECTED TO MANUALLY
            % ADJUST THE TENDON SLACK LENGTH OF THE ADJUSTED MUSCLE-TENDON UNIT POST-HOC ACCORDING TO THEIR DATA RESOURCES.
            adj_mtu_params.tendon_slk_len = preset_tendon_slk_len;

        end

        function ligament_params = cal_ligament_params(obj, mtus, mtu_params_tbl, preset_ligament_rest_len)
            % This method calculates the ligament parameters after the original muscle-tendon units that include the ligament are adjusted.
            %
            % Inputs:
            %   - mtus: The original muscle-tendon units that include the ligament (cell array of strings).
            %   - mtu_params_tbl: The original muscle-tendon unit parameters table (table).
            %   - preset_ligament_rest_len: The preset ligament rest length for the ligament (double).
            %
            % Outputs:
            %   - ligament_params: The ligament parameters (structure).
            %
            % Example usage:
            %   ligament_params = obj.cal_ligament_params(mtus, mtu_params_tbl, preset_ligament_rest_len)

            % Initialize the ligament parameters
            max_iso_frc =  NaN(1, numel(mtus));

            % Loop over all original muscle-tendon units that include the ligament
            for i = 1 : numel(mtus)
                % Get the index of the original muscle-tendon unit in the original muscle-tendon unit parameters table
                [~, idx] = ismember(mtus{i}, mtu_params_tbl.mtu_name);
                
                % Extract the maximal isometric force of the original muscle-tendon unit
                max_iso_frc(i) = mtu_params_tbl.max_iso_frc(idx);

            end
            
            % Set the force scale of the ligament to be the sum of the maximal isometric forces of the original muscle-tendon units
            ligament_params.frc_scale = sum(max_iso_frc);
            
            % Set the rest length of the ligament to be the preset ligament rest length.
            % NOTE THAT USERS ARE EXPECTED TO MANUALLY ADJUST THE REST LENGTH OF THE LIGAMENT POST-HOC ACCORDING TO THEIR DATA RESOURCES.
            ligament_params.rest_len = preset_ligament_rest_len;
        
        end
        
        function value = fetch_value_from_mtu_ligament_map(obj, key)
            % This method returns the original muscle-tendon units that the adjusted muscle-tendon unit is associated with.
            % 
            % Inputs:
            %   - key: The adjusted muscle-tendon unit name (string).
            %
            % Outputs:
            %   - value: The original muscle-tendon units that the adjusted muscle-tendon unit is associated with (cell array of strings).
            %
            % Example usage:
            %   value = obj.fetch_value_from_mtu_ligament_map(key)

            % Get the field names of the mtu_ligament_map property. This map is used to map the adjusted muscle-tendon units to the original
            % muscle-tendon units.
            map_fieldnames = fieldnames(obj.dir_graph_struct(1).mtu_ligament_map(1));
            
            % Get the key field name and the value field name of the mtu_ligament_map
            key_fieldname = map_fieldnames{1};
            value_fieldname = map_fieldnames{2};

            % Initialize the count
            count = 0;

            % Loop over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Loop over all elements in the mtu_ligament_map
                for j = 1 : numel(obj.dir_graph_struct(i).mtu_ligament_map)
                    % Get the current key
                    curr_key = obj.dir_graph_struct(i).mtu_ligament_map(j).(key_fieldname);

                    % If the current key is the same as the input key, get the value. Otherwise, continue to the next element in the map.
                    if strcmp(curr_key, key)
                        value = obj.dir_graph_struct(i).mtu_ligament_map(j).(value_fieldname);
                        
                        % Increment the count
                        count = count + 1;
                    end
                    
                end
            end

            % If the count is zero, throw an error. If the count is greater than one, throw an error.
            if count == 0
                error(['Requested mtu/ligament: "', key, '" not found as a "key" in the mtu_ligament_map',])
            elseif count > 1
                error(['Requested mtu/ligament: "', key, '" occurs multiple times as a "key" in the mtu_ligament_map',])
            end

        end

        function obj = adjust_wrap_surf_pair_tbl(obj)
            % This method adjusts the wrapping surface pairings to accomodate the adjusted muscle-tendon units and ligaments.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated adj_wrap_surf_pair_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_wrap_surf_pair_tbl()

            % Read the wrapping surfaces table from the Wrapping_Surfaces.csv file
            wrap_surfs_file = [obj.model_root_dir, '/Data/LocalData/Wrapping_Surfaces.csv'];
            wrap_surf_imp_opts = detectImportOptions(wrap_surfs_file);
            wrap_surf_imp_opts = setvartype(wrap_surf_imp_opts, 'geom_params', 'string');
            wrap_surf_imp_opts.Delimiter = ',';
            wrap_surfs_tbl = readtable(wrap_surfs_file, wrap_surf_imp_opts);

            % Check if the wrapping surface name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(wrap_surfs_tbl.wrap_surf_name(:));
            
            % If the wrapping surface name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the wrap_surf_name column']);
            end

            % Read the wrapping surface pairings table from the Wrapping_Surface_MTU_Ligament_Pairings.csv file
            wrap_pair_file = [obj.model_root_dir, '/Data/LocalData/Wrapping_Surface_MTU_Ligament_Pairings.csv'];
            wrap_pair_tbl = readtable(wrap_pair_file, 'Delimiter', ',');
            
            % Check if the wrapping surface name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(wrap_pair_tbl.wrap_surf_name(:));
            
            % If the wrapping surface name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the wrap_surf_name column']);
            end

            % Define the wrapping surface pairings table variable names and types
            adj_wrap_pair_tbl_variable_names = {'wrap_surf_name', 'paired_mtu_ligament', 'active'};
            adj_wrap_pair_tbl_variable_types = [repmat({'string'}, 1, 2), 'double'];

            % Initialize the adjusted wrapping surface pairings table
            adj_wrap_surf_pair_tbl = table('Size', [0, length(adj_wrap_pair_tbl_variable_names)], 'VariableTypes', ...
                                        adj_wrap_pair_tbl_variable_types, 'VariableNames', adj_wrap_pair_tbl_variable_names);
            
            % Loop over all wrapping surface pairings
            for i = 1 : size(wrap_pair_tbl, 1)
                % Get the wrapping surface name, paired muscle-tendon units, and active status from the wrapping surface pairings table
                wrap_surf_name = wrap_pair_tbl.wrap_surf_name{i};
                paired_mtus = strtrim(strsplit(wrap_pair_tbl.paired_mtu_ligament{i}, ','));
                active = boolean(wrap_pair_tbl.active(i));
                
                % Get the new paired muscle-tendon units
                new_paired_mtu_ligament = obj.refresh_wrap_surf_pairings(wrap_surf_name, paired_mtus, wrap_surfs_tbl);
                
                % Join the new paired muscle-tendon units into a single string with commas as delimiters
                new_paired_mtu_ligament = strjoin(new_paired_mtu_ligament, ',');
                
                % Define a row to add to the adjusted wrapping surface pairings table
                row_to_add = {wrap_surf_name, new_paired_mtu_ligament, active};
                adj_wrap_surf_pair_tbl = [adj_wrap_surf_pair_tbl; row_to_add];
            end
            
            % Update the adj_wrap_surf_pair_tbl property
            obj.adj_wrap_surf_pair_tbl = adj_wrap_surf_pair_tbl;
            
        end

        function new_paired_mtu_ligament = refresh_wrap_surf_pairings(obj, wrap_surf_name, org_paired_mtus, wrap_surfs_tbl)
            % This method generates the new paired muscle-tendon units and ligaments for a wrapping surface after the original 
            % muscle-tendon units are adjusted.
            %
            % Inputs:
            %   - wrap_surf_name: The wrapping surface name (string).
            %   - org_paired_mtus: The original paired muscle-tendon units and ligaments (cell array of strings).
            %   - wrap_surfs_tbl: The wrapping surfaces table (table).
            %
            % Outputs:
            %   - new_paired_mtu_ligament: The new paired muscle-tendon units and ligaments (cell array of strings).
            %
            % Example usage:
            %   new_paired_mtu_ligament = obj.refresh_wrap_surf_pairings(wrap_surf_name, org_paired_mtus, wrap_surfs_tbl)

            % Initialize the new paired muscle-tendon units and ligaments
            new_paired_mtu_ligament = {};

            % Get the attached body of the wrapping surface
            [~, wrap_surf_idx] = ismember(wrap_surf_name, wrap_surfs_tbl.wrap_surf_name);
            attached_body = wrap_surfs_tbl.attached_body{wrap_surf_idx};

            % Get the muscle-tendon unit names that are in the ungrouped muscle-tendon unit parameters table
            ungrouped_mtu_names = obj.separate_grouped_ungrouped_mtus();

            % Loop over all the original paired muscle-tendon units and ligaments
            for i = 1 : numel(org_paired_mtus)
                % Get the original muscle-tendon unit name
                org_mtu_name = org_paired_mtus{i};

                % If the original muscle-tendon unit is in the ungrouped muscle-tendon unit parameters table, add it to the new paired
                if ismember(org_mtu_name, ungrouped_mtu_names)
                    new_paired_mtu_ligament = [new_paired_mtu_ligament, org_mtu_name];
                    continue;
                end
                
                % Get the muscle-tendon units and ligaments that are associated with the original muscle-tendon unit
                mtu_ligament_names = obj.fetch_key_from_mtu_ligament_map(org_mtu_name);
                
                % Loop over all the muscle-tendon units and ligaments that are associated with the original muscle-tendon unit
                for j = 1 : numel(mtu_ligament_names)
                    % Get the current muscle-tendon unit or ligament name
                    mtu_ligament_name = mtu_ligament_names{j};
                    
                    % If the current muscle-tendon unit or ligament name is in the adjusted muscle-tendon unit path table
                    if ismember(mtu_ligament_name, obj.adj_mtu_path_tbl.mtu_name)
                        % Get the indices of the current muscle-tendon unit in the adjusted muscle-tendon unit path table
                        mtu_indices = find(strcmp(mtu_ligament_name, obj.adj_mtu_path_tbl.mtu_name));

                        % Get the attached bodies of the current muscle-tendon unit in the adjusted muscle-tendon unit path table
                        mtu_asso_bodies = obj.adj_mtu_path_tbl.attached_body(mtu_indices);

                        % If the attached body of the wrapping surface is in the attached bodies of the current muscle-tendon unit, 
                        % add the current muscle-tendon unit to the new paired
                        if ismember(attached_body, mtu_asso_bodies)
                            new_paired_mtu_ligament = [new_paired_mtu_ligament, mtu_ligament_name];
                        end
                    
                    % If the current muscle-tendon unit or ligament name is in the ligament path table
                    elseif ismember(mtu_ligament_name, obj.ligament_path_tbl.ligament_name)
                        % Get the indices of the current ligament in the ligament path table
                        ligament_indices = find(strcmp(mtu_ligament_name, obj.ligament_path_tbl.ligament_name));

                        % Get the attached bodies of the current ligament in the ligament path table
                        ligament_asso_bodies = obj.ligament_path_tbl.attached_body(ligament_indices);

                        % If the attached body of the wrapping surface is in the attached bodies of the current ligament, 
                        % add the current ligament to the new paired
                        if ismember(attached_body, ligament_asso_bodies)
                            new_paired_mtu_ligament = [new_paired_mtu_ligament, mtu_ligament_name];
                        end
                    
                    % If the current muscle-tendon unit or ligament name is not in the adjusted muscle-tendon unit path table or 
                    % the ligament path table, throw an error
                    else
                        error(['Could not find ', mtu_ligament_name, ' in adjusted MTU or ligament paths.'])
                    end

                end
            
            end

            % Remove duplicate muscle-tendon units and ligaments from the new pairs.
            new_paired_mtu_ligament = unique(new_paired_mtu_ligament);

        end

        function key = fetch_key_from_mtu_ligament_map(obj, value)
            % This method returns the adjusted muscle-tendon unit that the original muscle-tendon unit is associated with.
            %
            % Inputs:
            %   - value: The original muscle-tendon unit name (string).
            %
            % Outputs:
            %   - key: The adjusted muscle-tendon unit that the original muscle-tendon unit is associated with (cell array of strings).
            %
            % Example usage:
            %   key = obj.fetch_key_from_mtu_ligament_map(value)

            % Get the field names of the mtu_ligament_map property.
            map_fieldnames = fieldnames(obj.dir_graph_struct(1).mtu_ligament_map(1));
            key_fieldname = map_fieldnames{1};
            value_fieldname = map_fieldnames{2};
            
            % Initialize the key cell array
            key = {};

            % Loop over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Loop over all the muscle-tendon unit and ligament maps in the current directed graph structure
                for j = 1 : numel(obj.dir_graph_struct(i).mtu_ligament_map)
                    % If the given value is in the current muscle-tendon unit and ligament map
                    if ismember(value, obj.dir_graph_struct(i).mtu_ligament_map(j).(value_fieldname))
                        % Add the key associated with the given value in the current mtu_ligament_map to the key cell array
                        key = [key; obj.dir_graph_struct(i).mtu_ligament_map(j).(key_fieldname)];
                    end
                end
            end
            
        end
        
        function [ungrouped_mtu_params_tbl, mtu_params_tbl] = extract_ungrouped_mtu_params_tbl(obj)
            % This method extracts the ungrouped muscle-tendon unit parameters table from the original muscle-tendon unit parameters table.
            %
            % Inputs: None
            %
            % Outputs:
            %   - ungrouped_mtu_params_tbl: The ungrouped muscle-tendon unit parameters table (table).
            %   - mtu_params_tbl: The original muscle-tendon unit parameters table (table).

            % Read the muscle-tendon unit parameters table from the MTU_Parameters.csv file
            mtu_params_file = [obj.model_root_dir, '/Data/LocalData/MTU_Parameters.csv'];
            mtu_params_tbl = readtable(mtu_params_file, 'Delimiter', ',');

            % Check if the muscle-tendon unit name column contains non-unique elements
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(mtu_params_tbl.mtu_name(:));
            
            % If the muscle-tendon unit name column contains non-unique elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the mtu_name column']);
            end

            % Get all muscle-tendon unit names from the mtu_path_struct field of the object
            all_mtu_names = fieldnames(obj.mtu_path_struct);

            % Find where each name in 'all_mtu_names' is located inside the table
            [found, row_indices] = ismember(all_mtu_names, mtu_params_tbl.mtu_name);
            
            % Validate that every name in the struct actually exists in the CSV
            if ~all(found)
                missing_names = all_mtu_names(~found);
                error('The following names in mtu_path_struct are missing from the CSV: %s', strjoin(missing_names, ', '));
            end
            
            % Re-order the table rows. Now, Row 1 corresponds to all_mtu_names{1}, etc.
            mtu_params_tbl = mtu_params_tbl(row_indices, :); 

            % Get the muscle-tendon unit names that are in the ungrouped muscle-tendon unit parameters table
            ungrouped_mtu_names = obj.separate_grouped_ungrouped_mtus();

            % Get the ungrouped muscle-tendon unit parameters table
            ungrouped_mtu_params_tbl = mtu_params_tbl(ismember(all_mtu_names, ungrouped_mtu_names), :);
        
        end

        function path_tbl = transfer_path_struct_to_path_tbl(obj, path_tbl, path_struct)
            % This method transfers the muscle-tendon unit path structure or the ligament path structure to 
            % a muscle-tendon unit path table
            %
            % Inputs:
            %   - path_tbl: The muscle-tendon unit path table or the ligament path table (table).
            %   - path_struct: The muscle-tendon unit path structure or the ligament path structure (structure).
            % 
            % Outputs:
            %   - path_tbl: The muscle-tendon unit path table or the ligament path table (table).  

            % Get the field names of the path structure
            names = fieldnames(path_struct);
            
            % Iterate over each field name (muscle-tendon unit name or ligament name)
            for i = 1 : numel(names)
                % Get the current field name
                name = names{i};
                
                % Get the point names of the current muscle-tendon unit or ligament
                pts = fieldnames(path_struct.(name));

                % Iterate over each point name
                for j = 1 : numel(pts)
                    % Get the current point index
                    pt_idx = j;

                    % Get the current point
                    pt = pts{j};

                    % Get the point type, attached body, and location in body of the current point
                    pt_type = path_struct.(name).(pt).pt_type;
                    attached_body = path_struct.(name).(pt).attached_body;
                    loc_in_body = path_struct.(name).(pt).loc_in_body;

                    % Define a row to add to the muscle-tendon unit path table or the ligament path table
                    row_to_add = {name, pt_idx, pt_type, attached_body, ...
                                  loc_in_body(1), loc_in_body(2), loc_in_body(3)};
                    
                    % Add the row to the path table
                    path_tbl = [path_tbl; row_to_add];
                end

            end            
        
        end        

        function ungrouped_mtu_path_struct = extract_ungrouped_mtu_path_struct(obj)
            % This method extracts the ungrouped muscle-tendon unit path structure from the muscle-tendon unit path structure.
            %
            % Inputs: None
            %
            % Outputs:
            %   - ungrouped_mtu_path_struct: The ungrouped muscle-tendon unit path structure (structure).
            %
            % Example usage:
            %   ungrouped_mtu_path_struct = obj.extract_ungrouped_mtu_path_struct()

            % Initialize the ungrouped muscle-tendon unit path structure
            ungrouped_mtu_path_struct = struct;

            % Get the ungrouped muscle-tendon unit names
            ungrouped_mtu_names = obj.separate_grouped_ungrouped_mtus();

            % Loop over all ungrouped muscle-tendon unit names
            for i = 1 : numel(ungrouped_mtu_names)
                % For each ungrouped muscle-tendon unit, copy its path information from the mtu_path_struct field of the object
                % to the ungrouped_mtu_path_struct
                ungrouped_mtu_path_struct.(ungrouped_mtu_names{i}) = obj.mtu_path_struct.(ungrouped_mtu_names{i}); 
            end

        end

        function [ungrouped_mtu_names, grouped_mtu_names] = separate_grouped_ungrouped_mtus(obj)
            % This method separates the ungrouped and grouped muscle-tendon unit names.
            %
            % Inputs: None
            %
            % Outputs:
            %   - ungrouped_mtu_names: The ungrouped muscle-tendon unit names (cell array of strings).
            %   - grouped_mtu_names: The grouped muscle-tendon unit names (cell array of strings).
            %
            % Example usage:
            %   [ungrouped_mtu_names, grouped_mtu_names] = obj.separate_grouped_ungrouped_mtus()
            
            % Initialize the grouped muscle-tendon unit names
            grouped_mtu_names = {};

            % Iterate over each branching group
            for i = 1 : size(obj.branch_group_tbl, 1)
                % Get the muscle-tendon unit names in the current branching group
                mtu_in_group = obj.branch_group_tbl.mtu_in_group{i};
                
                % Split the muscle-tendon unit names in the current branching group into a cell array of strings
                mtu_in_group = strtrim(strsplit(mtu_in_group, ','));
                
                % Append the muscle-tendon unit names in the current branching group to the grouped muscle-tendon unit names
                grouped_mtu_names = [grouped_mtu_names, mtu_in_group];

            end

            % Get all muscle-tendon unit names from the mtu_path_struct field of the object
            all_mtu_names = fieldnames(obj.mtu_path_struct);

            % Get the ungrouped muscle-tendon unit names by differencing the grouped muscle-tendon unit names from all muscle-tendon unit names
            ungrouped_mtu_names = setdiff(all_mtu_names, grouped_mtu_names);

        end

        function [branch_mtu_path_struct, obj] = build_branched_mtu_path_struct(obj)
            % This method constructs a structure that contains the path informatin for each branched muscle-tendon unit group.
            %
            % Inputs: None
            %
            % Outputs:
            %   - branch_mtu_path_struct: The branched muscle-tendon unit path structure (structure).
            %   - obj: An instance of the Brancher class (Brancher object) with an updated dir_graph_struct property.
            %
            % Example usage:
            %   [branch_mtu_path_struct, obj] = obj.build_branched_mtu_path_struct()
            
            % Initialize the branched muscle-tendon unit path structure
            branch_mtu_path_struct = struct;
            
            % Iterate over each branching group
            for i = 1 : numel(obj.dir_graph_struct)
                % Get the current directed graph structure
                curr_graph_struct = obj.dir_graph_struct(i);
                
                % Extract the current directed graph structure's graph, group name, and special nodes
                G = curr_graph_struct.G;
                group_name = curr_graph_struct.group_name;
                origin_nodes = curr_graph_struct.special_nodes.origin_nodes;
                branch_nodes = curr_graph_struct.special_nodes.branch_nodes;
                insertion_nodes = curr_graph_struct.special_nodes.insertion_nodes;
                
                % Initialize the branched muscle-tendon unit index. This index is used to name the branched muscle-tendon units.
                branched_mtu_idx = 1;

                % Loop over all origin nodes
                for j = 1 : numel(origin_nodes)
                    % Define the branched muscle-tendon unit name prefix. This prefix is used to name the branched muscle-tendon units.
                    branched_mtu_name_prefix = [group_name, '_MTU'];

                    % Get the current origin node
                    origin_node = origin_nodes{j};

                    % Check if the mtus of this origin node branch or not
                    [is_branched, org_mtu] = branched_check(obj, origin_node, curr_graph_struct);
                    
                    % If the mtus of this origin node do not branch, issue a warning and add the path information of the mtus to the
                    % branched muscle-tendon unit path structure
                    if ~is_branched
                        warning([strjoin(org_mtu, ', '), ' do(es) not branch. You may want to remove them(it) from the branching group.'])
                        
                        % Iterate over each insertion node
                        for k = 1 : numel(insertion_nodes)
                            % Get the current insertion node
                            insertion_node = insertion_nodes{k};

                            % Get the nodes from the origin node to the insertion node
                            path_nodes = allpaths(G, origin_node, insertion_node);
                            
                            % If the path nodes are not empty, meaning that there is a path from the origin node to the insertion node,
                            if numel(path_nodes) ~= 0
                                % Convert the path nodes to a structure that contains the path information
                                branch_mtu_path_struct = obj.path_nodes_to_path(branch_mtu_path_struct, branched_mtu_name_prefix, branched_mtu_idx, ...
                                                                                path_nodes, curr_graph_struct);
                                
                                % Create a map that maps the branched muscle-tendon unit to the original muscle-tendon units
                                mtu_ligament_map = obj.create_mtu_ligament_map(branched_mtu_name_prefix, branched_mtu_idx, ...
                                                                                             path_nodes, curr_graph_struct);
                                
                                % Update the mtu_ligament_map property with the mtu_ligament_map
                                obj = obj.update_mtu_ligament_map(i, mtu_ligament_map);

                                % Associate the branched muscle-tendon unit with the edges in the directed graph. This will be used for
                                % visualization purposes.
                                obj = obj.asso_mtu_ligament_with_edge(i, branched_mtu_name_prefix, branched_mtu_idx, path_nodes);
                                
                                % Increment the branched muscle-tendon unit index
                                branched_mtu_idx = branched_mtu_idx + numel(path_nodes);
                            end
                        end
                    
                    % If the mtus of this origin node branch
                    else
                        % Iterate over each branch node
                        for k = 1 : numel(branch_nodes)
                            % Get the current branch node
                            branch_node = branch_nodes{k};
                            
                            % Get the nodes from the origin node to the branch node
                            path_nodes = allpaths(G, origin_node, branch_node);

                            % Only keep the paths that do not contain a third branch node.
                            path_nodes = obj.path_filter(path_nodes, setdiff(branch_nodes, branch_node));
                            
                            % If the path nodes are not empty, meaning that there is a valid path from the origin node to the current branch node,
                            if numel(path_nodes) ~= 0
                                % Convert the path nodes to a structure that contains the path information
                                branch_mtu_path_struct = obj.path_nodes_to_path(branch_mtu_path_struct, branched_mtu_name_prefix, branched_mtu_idx, ...
                                                                                path_nodes, curr_graph_struct);
                                
                                % Create a map that maps the branched muscle-tendon unit to the original muscle-tendon units
                                mtu_ligament_map = obj.create_mtu_ligament_map(branched_mtu_name_prefix, branched_mtu_idx, ...
                                                                                             path_nodes, curr_graph_struct);
                                
                                % Update the mtu_ligament_map property with the mtu_ligament_map
                                obj = obj.update_mtu_ligament_map(i, mtu_ligament_map);

                                % Associate the branched muscle-tendon unit with the edges in the directed graph. This will be used for
                                % visualization purposes.
                                obj = obj.asso_mtu_ligament_with_edge(i, branched_mtu_name_prefix, branched_mtu_idx, path_nodes);
                                
                                % Increment the branched muscle-tendon unit index
                                branched_mtu_idx = branched_mtu_idx + numel(path_nodes);
                            end
                        end
                    end
                                    
                end
            
            end

        end
        
        function obj = asso_mtu_ligament_with_edge(obj, dir_graph_idx, mtu_ligament_name_prefix, mtu_ligament_idx, path_nodes)
            % This method associates a muscle-tendon unit (MTU) or ligament with the edges in the directed graph.
            %
            % Inputs:
            %   - dir_graph_idx: The index of the directed graph in the dir_graph_struct property (double).
            %   - mtu_ligament_name_prefix: The prefix of the muscle-tendon unit or ligament name (string).
            %   - mtu_ligament_idx: The index of the muscle-tendon unit or ligament (integer).
            %   - path_nodes: The nodes in the directed graph that are associated with the muscle-tendon unit or ligament (cell array of strings).
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated dir_graph_struct property.
            %
            % Example usage:
            %   obj = obj.asso_mtu_ligament_with_edge(dir_graph_idx, mtu_ligament_name_prefix, mtu_ligament_idx, path_nodes)

            % Get the directed graph from the dir_graph_struct property
            G = obj.dir_graph_struct(dir_graph_idx).G;

            % Loop over all path nodes
            for i = 1 : numel(path_nodes)
                % Get the current path node
                v = path_nodes{i};
                
                % Get the name of the muscle-tendon unit or ligament
                mtu_ligament_name = [mtu_ligament_name_prefix, num2str(mtu_ligament_idx)];

                % Loop over all edges in the path
                for j = 1 : numel(v) - 1
                    % Get the current edge index
                    edge_idx = findedge(G, v{j}, v{j+1});

                    % Associate the muscle-tendon unit or ligament with the corresponding edge
                    obj.dir_graph_struct(dir_graph_idx).G.Edges.corr_mtu_ligament{edge_idx} = mtu_ligament_name;

                end

            end
        end
        
        function visualize_direct_graph(obj)
            % This method visualizes the directed graph. For each branching group, a figure is generated to visualize the nodes and edges. 
            % The nodes are named according to the original muscle-tendon unit names and the point index in the original muscle-tendon unit. 
            % The color of each edge is determined by the associated adjusted muscle-tendon unit or ligament, with each having a unique color. 
            % This visualization is useful for users to check the branching structure. It can also serve as 
            % a reference when manually inputting the physiological parameters of the adjusted muscle-tendon units and ligaments.
            % 
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.visualize_direct_graph()

            % Add the External folder to the MATLAB path. This is for calling the distinguishable_colors function.
            addpath(genpath('External/'));

            % Loop over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Get the branching group name of the current directed graph
                group_name = obj.dir_graph_struct(i).group_name;
                
                % Rename the nodes in the directed graph for visualization purposes
                G = obj.rename_nodes_for_visualization(obj.dir_graph_struct(i).G, obj.dir_graph_struct(i).metadata);

                % Get the associated adjusted muscle-tendon unit or ligament names for each edge
                mtu_ligament_names = G.Edges.corr_mtu_ligament;
                
                % Initialize the colors for each edge
                colors = NaN(numel(mtu_ligament_names), 3);
                
                % Get the unique adjusted muscle-tendon unit or ligament names
                unique_mtu_ligament_names = unique(mtu_ligament_names);
                
                % Get unique colors for each adjusted muscle-tendon unit or ligament
                unique_colors = distinguishable_colors(numel(unique_mtu_ligament_names));

                % Assign colors to each edge
                for j = 1 : numel(mtu_ligament_names)
                    unique_color_idx = strcmp(mtu_ligament_names{j}, unique_mtu_ligament_names);
                    colors(j, :) = unique_colors(unique_color_idx, :);
                end
                
                figure;
                hold on;
                
                pl = [];
                % Create a legend for the adjusted muscle-tendon units or ligaments
                for k = 1 : numel(unique_mtu_ligament_names)
                    pl(k) = plot(NaN, NaN, 'LineWidth', 5, 'Color', unique_colors(k, :));
                end
                
                lgd = legend(pl, unique_mtu_ligament_names);
                lgd.Interpreter = 'none';
                lgd.AutoUpdate = 'off';
                lgd.Location = 'best'; 

                % Plot the directed graph
                p = plot(G, 'Layout', 'layered');
                p.EdgeColor = colors;
                p.EdgeAlpha = 1;
                p.LineWidth = 2;
                p.NodeColor = [0, 0, 0];
                p.MarkerSize = 5;
                p.ArrowSize = 8;
                p.Interpreter = 'none';
                p.NodeFontSize = 10;
                
                % Set the axis and figure properties
                ax = gca;
                ax.XTick = [];
                ax.YTick = [];
                ax.Title.String = group_name;
                ax.Title.FontSize = 20;
                ax.Title.Interpreter = 'none';

                fig = gcf;
                fig.Position = [269, 1, 900, 800];

                hold off;
            end
        end

        function G_with_renamed_nodes = rename_nodes_for_visualization(obj, G, metadata)
            % This method renames the nodes in the directed graph for visualization purposes.
            %
            % Inputs:
            %   - G: The directed graph (digraph object).
            %   - metadata: The metadata of the directed graph (structure).
            %
            % Outputs:
            %   - G_with_renamed_nodes: The directed graph with renamed nodes (digraph object).
            %
            % Example usage:
            %   G_with_renamed_nodes = obj.rename_nodes_for_visualization(G, metadata)

            % Initialize the directed graph with renamed nodes
            G_with_renamed_nodes = G;
            
            % Loop over all nodes in the directed graph
            for i = 1 : numel(G_with_renamed_nodes.Nodes.Name)
                % Get the original node name
                org_node_name = G_with_renamed_nodes.Nodes.Name{i};

                % Get the associated adjusted muscle-tendon unit or ligament names for the current node
                asso_org_mtu_info = metadata.(org_node_name).asso_org_mtu_info;
                asso_org_mtu_names = fieldnames(asso_org_mtu_info);
                
                % Initialize the cell array that contains the adjusted muscle-tendon unit or ligament names with point indices
                asso_org_mtu_with_pt_idx_names = {};

                % Loop over all associated adjusted muscle-tendon unit or ligament names
                for j = 1 : numel(asso_org_mtu_names)
                    % Get the current associated adjusted muscle-tendon unit or ligament name
                    asso_org_mtu_name = asso_org_mtu_names{j};
                    
                    % Get the point index in the original muscle-tendon unit
                    pt_idx_in_asso_org_mtu = asso_org_mtu_info.(asso_org_mtu_name).pt_idx;

                    % Append the adjusted muscle-tendon unit or ligament name with the point index to the cell array
                    asso_org_mtu_with_pt_idx_names{1, j} = [asso_org_mtu_name, '_pt', num2str(pt_idx_in_asso_org_mtu)];

                end

                % Join the adjusted muscle-tendon unit or ligament names with point indices into a single string
                new_node_name = strjoin(asso_org_mtu_with_pt_idx_names, ' & ');
                
                % Set the new node name
                G_with_renamed_nodes.Nodes.Name{i} = new_node_name;

            end
        
        end

        function [is_branched, org_mtu]= branched_check(obj, origin_node, curr_graph_struct)
            % This method checks if the muscle-tendon units of the origin node branch or not.
            %
            % Inputs:
            %   - origin_node: The origin node (string).
            %   - curr_graph_struct: The directed graph structure (structure).
            %
            % Outputs:
            %   - is_branched: A boolean indicating if the muscle-tendon units of the origin node branch or not (logical).
            %   - org_mtu: The original muscle-tendon unit names (cell array of strings).
            %
            % Example usage:
            %   [is_branched, org_mtu] = obj.branched_check(origin_node, curr_graph_struct)

            % Get the directed graph, branch nodes, and metadata from the directed graph structure
            G = curr_graph_struct.G;
            branch_nodes = curr_graph_struct.special_nodes.branch_nodes;
            metadata = curr_graph_struct.metadata;

            % Perform a depth-first search from the origin node
            v = dfsearch(G, origin_node);
            
            % If the discovered nodes contain any branch nodes, the muscle-tendon units of the origin node branch
            if any(ismember(branch_nodes, v))
                is_branched = true;
            % Otherwise, the muscle-tendon units of the origin node do not branch
            else
                is_branched = false;
            end

            % Get the original muscle-tendon unit names
            org_mtu = fieldnames(metadata.(origin_node).asso_org_mtu_info);
            
            % Reshape the original muscle-tendon unit names into a row vector
            if size(org_mtu, 1) > size(org_mtu, 2)
                org_mtu = org_mtu';
            end
        
        end

        function filtered_path_nodes = path_filter(obj, path_nodes, flags)
            % This method filters a set of path nodes based on a specific criteria.
            % The criteria for filtering is defined by the 'flags' input.
            % If a node in a path is found in 'flags', the path is excluded from the filtered paths.
            %
            % Inputs:
            %   - path_nodes: The path nodes (cell array of cell arrays of strings).
            %   - flags: The flags that define the criteria for filtering (cell array of strings).
            %
            % Outputs:
            %   - filtered_path_nodes: The filtered path nodes (cell array of cell arrays of strings).
            %
            % Example usage:
            %   filtered_path_nodes = obj.path_filter(path_nodes, flags)

            % Initialize the filtered path nodes
            filtered_path_nodes = {};

            % Iterate over all paths
            for i = 1 : numel(path_nodes)
                % Get the current set of path nodes
                v = path_nodes{i};
                
                % If the current set of path nodes does not contain any node in 'flags', add it to the filtered path nodes
                if ~any(ismember(flags, v))
                    filtered_path_nodes = [filtered_path_nodes; {v}];
                end

            end
        
        end

        function path_struct = path_nodes_to_path(obj, path_struct, name_prefix, idx, path_nodes, graph_struct)
            % This method converts a set of path nodes to a structure that contains the path information.
            %
            % Inputs:
            %   - path_struct: The path structure (structure).
            %   - name_prefix: The prefix of the muscle-tendon unit or ligament name (string).
            %   - idx: The index of the muscle-tendon unit or ligament (integer).
            %   - path_nodes: The path nodes (cell array of cell arrays of strings).
            %   - graph_struct: The directed graph structure (structure).
            %
            % Outputs:
            %   - path_struct: The updated path structure (structure).
            %
            % Example usage:
            %   path_struct = obj.path_nodes_to_path(path_struct, name_prefix, idx, path_nodes, graph_struct)
            
            % Iterate over all paths
            for i = 1 : numel(path_nodes)
                % Get the current set of path nodes
                v = path_nodes{i};

                % Get the adjusted muscle-tendon unit or ligament name
                name = [name_prefix, num2str(idx)];

                % Iterate over all nodes in the current set of path nodes
                for j = 1 : numel(v)
                    % Get the current node name
                    node_name = v{j};
                    
                    % Get the point name
                    pt_name = ['pt', num2str(j)];
                    
                    % Determine the point type
                    if j == 1
                        pt_type = 'origin';
                    elseif j == numel(v)
                        pt_type = 'insertion';
                    else
                        pt_type = 'viapoint';
                    end
                    
                    % Determine the attached body and location in body of the current point
                    if isfield(graph_struct.bnode_to_fb, node_name)
                        attached_body = graph_struct.bnode_to_fb.(node_name);
                        loc_in_body = zeros(1, 3);
                    else
                        attached_body = graph_struct.metadata.(node_name).attached_body;
                        loc_in_body = graph_struct.metadata.(node_name).loc_in_body;
                    
                    end
                    
                    % Add the path information to the path structure
                    path_struct.(name).(pt_name).pt_type = pt_type;
                    path_struct.(name).(pt_name).attached_body = attached_body;
                    path_struct.(name).(pt_name).loc_in_body = loc_in_body;
    
                    path_struct.(name).(pt_name).org_pt_info = graph_struct.metadata.(node_name);

                end
                
                % Increment the muscle-tendon unit or ligament index
                idx = idx + 1;

            end
        
        end

        function map = create_mtu_ligament_map(obj, name_prefix, idx, path_nodes, graph_struct)
            % This method creates a map bewteen the adjusted muscle-tendon unit or ligament to the original muscle-tendon units.
            %
            % Inputs:
            %   - name_prefix: The prefix of the adjusted muscle-tendon unit or ligament name (string).
            %   - idx: The index of the muscle-tendon unit or ligament (integer).
            %   - path_nodes: The path nodes (cell array of cell arrays of strings).
            %   - graph_struct: The directed graph structure (structure).
            %
            % Outputs:
            %   - map: The map between the adjusted muscle-tendon unit or ligament to the original muscle-tendon units (structure).
            %
            % Example usage:
            %   map = obj.create_mtu_ligament_map(name_prefix, idx, path_nodes, graph_struct)

            % Initialize the map
            map = struct;

            % Iterate over all paths
            for i = 1 : numel(path_nodes)
                % Get the current set of path nodes
                v = path_nodes{i};

                % Get the adjusted muscle-tendon unit or ligament name
                name = [name_prefix, num2str(idx)];
                
                % Initialize the cell array that contains the original muscle-tendon unit names
                respective_mtus = {};

                % Iterate over all nodes in the current set of path nodes
                for j = 1 : numel(v)
                    % Get the current node name
                    node_name = v{j};

                    % Get the original muscle-tendon unit names
                    asso_org_mtu_names = fieldnames(graph_struct.metadata.(node_name).asso_org_mtu_info);
                    
                    % Keep the muscle-tendon unit names that are common to all nodes in the current set of path nodes. 
                    if j == 1
                        respective_mtus = asso_org_mtu_names;
                    else
                        respective_mtus = intersect(respective_mtus, asso_org_mtu_names);
                    end
                end
                
                % If the cell array that contains the original muscle-tendon unit names is empty, throw an error
                if isempty(respective_mtus)
                    error('Could not find an original mtu that contains the segment.')
                end

                % Add the map to the map structure
                map(i).proposed = name;
                map(i).conventional = respective_mtus;

                % Increment the muscle-tendon unit or ligament index
                idx = idx + 1;

            end
        
        end

        function obj = update_mtu_ligament_map(obj, dir_graph_idx, map_to_add)
            % This method updates the mtu_ligament_map property in the dir_graph_struct with the given map.
            %
            % Inputs:
            %   - dir_graph_idx: The index of the directed graph in the dir_graph_struct property (integer).
            %   - map_to_add: The map to add to the mtu_ligament_map property (structure).
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated dir_graph_struct property.
            %
            % Example usage:
            %   obj = obj.update_mtu_ligament_map(dir_graph_idx, map_to_add)

            % If the mtu_ligament_map property does not exist in the dir_graph_struct, create it
            if ~isfield(obj.dir_graph_struct(dir_graph_idx), 'mtu_ligament_map')
               obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map = [];
            end
            
            % If the mtu_ligament_map property is empty, set the exist_map_num to 0
            if isempty(obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map) ...
                    || (isstruct(obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map) & ... 
                        isempty(fieldnames(obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map)))
                exist_map_num = 0;
            % Otherwise, set the exist_map_num to the number of maps in the mtu_ligament_map property    
            else
                exist_map_num = numel(obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map);
            end
            
            % Get the field names of the map to add
            map_fields = fieldnames(map_to_add);

            % Iterate over all maps in the map to add
            for i = 1 : numel(map_to_add)
                % Add the map to the mtu_ligament_map property
                for j = 1 : numel(map_fields)
                    obj.dir_graph_struct(dir_graph_idx).mtu_ligament_map(exist_map_num + i).(map_fields{j}) = map_to_add(i).(map_fields{j});
                end
            end

        end

        function [ligament_path_struct, obj] = build_ligament_path_struct(obj)
            % This method constructs a structure that contains the path informatin for each ligament.
            %
            % Inputs: None
            %
            % Outputs:
            %   - ligament_path_struct: The ligament path structure (structure).
            %   - obj: An instance of the Brancher class (Brancher object) with an updated dir_graph_struct property.
            %
            % Example usage:
            %   [ligament_path_struct, obj] = obj.build_ligament_path_struct()

            % Initialize the ligament path structure
            ligament_path_struct = struct;
            
            % Iterate over all directed graphs
            for i = 1 : numel(obj.dir_graph_struct)
                % Get the current directed graph structure
                curr_graph_struct = obj.dir_graph_struct(i);
                
                % Extract the current directed graph structure's graph, group name, branch nodes, and insertion nodes
                G = curr_graph_struct.G;
                group_name = curr_graph_struct.group_name;
                branch_nodes = curr_graph_struct.special_nodes.branch_nodes;
                insertion_nodes = curr_graph_struct.special_nodes.insertion_nodes;
                
                % Get the union of the branch nodes and insertion nodes
                branch_or_insertion_nodes = union(branch_nodes, insertion_nodes);

                % Initialize the ligament index. This index is used to name the ligaments.
                ligament_idx = 1;

                % Loop over all branch nodes
                for j = 1 : numel(branch_nodes)
                    % Define the ligament name prefix. This prefix is used to name the ligaments.
                    ligament_name_prefix = [group_name, '_ligament'];

                    % Get the current branch node
                    branch_node = branch_nodes{j};

                    % Define the ending nodes. These nodes are the branch nodes and insertion nodes excluding the current branch node.
                    end_nodes = setdiff(branch_or_insertion_nodes, branch_node);

                    % Iterate over all ending nodes
                    for k = 1 : numel(end_nodes)
                        % Get the current ending node
                        end_node = end_nodes{k};

                        % Find all paths from the current branch node to the current ending node
                        path_nodes = allpaths(G, branch_node, end_node);

                        % Only keep the paths that do not contain a third ending node.
                        path_nodes = obj.path_filter(path_nodes, setdiff(end_nodes, end_node));
                        
                        % If the path nodes are not empty, meaning that there is a valid path from the current branch node to the current ending node,
                        if numel(path_nodes) ~= 0
                            % Convert the path nodes to a structure that contains the path information
                            ligament_path_struct = obj.path_nodes_to_path(ligament_path_struct, ligament_name_prefix, ligament_idx, ...
                                                                          path_nodes, curr_graph_struct);
                            
                            % Create a map that maps the ligament to the original muscle-tendon units
                            mtu_ligament_map = obj.create_mtu_ligament_map(ligament_name_prefix, ligament_idx, ...
                                                                                path_nodes, curr_graph_struct);
                            
                            % Update the mtu_ligament_map property with the mtu_ligament_map
                            obj = obj.update_mtu_ligament_map(i, mtu_ligament_map);

                            % Associate the ligament with the edges in the directed graph. This will be used for visualization purposes.
                            obj = obj.asso_mtu_ligament_with_edge(i, ligament_name_prefix, ligament_idx, path_nodes);
                            
                            % Increment the ligament index
                            ligament_idx = ligament_idx + numel(path_nodes);
                        end
                    end
                                    
                end
            
            end
        
        end

        function obj = mtu_path_tbl_to_struct(obj)
            % This method converts the muscle-tendon unit path table to a structure.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated mtu_path_struct property.
            %
            % Example usage:
            %   obj = obj.mtu_path_tbl_to_struct()

            % Read the muscle-tendon unit parameters table
            mtu_params_file = [obj.model_root_dir, '/Data/LocalData/MTU_Parameters.csv'];
            mtu_params_tbl = readtable(mtu_params_file, 'Delimiter', ',');

            % Check if the muscle-tendon unit names in the muscle-tendon unit parameters table are unique
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(mtu_params_tbl.mtu_name(:));

            % If the muscle-tendon unit names in the muscle-tendon unit parameters table are not unique, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the mtu_name column']);
            end

            % Read the muscle-tendon unit path table
            mtu_path_file = [obj.model_root_dir, '/Data/LocalData/MTU_Path.csv'];
            mtu_path_tbl = readtable(mtu_path_file, 'Delimiter', ',');

            % If the muscle-tendon unit names in the muscle-tendon unit parameters table and the muscle-tendon unit path table do not match, throw an error
            if ~isequal(sort(mtu_params_tbl.mtu_name(:)), sort(unique(mtu_path_tbl.mtu_name(:))))
                error('MTUs in MTU_Parameters.csv and MTU_Path.csv do not match');
            end
            
            % Initialize the muscle-tendon unit path structure
            mtu_path_struct = struct;

            % Iterate over all rows in the muscle-tendon unit path table
            for i = 1 : size(mtu_path_tbl, 1)
                % Get the muscle-tendon unit name, point index, point type, attached body, and location in body
                mtu_name = mtu_path_tbl.mtu_name{i};
                pt_idx = mtu_path_tbl.pt_idx(i);
                pt_type = mtu_path_tbl.pt_type{i};
                attached_body = mtu_path_tbl.attached_body{i};
                loc_in_body_x = mtu_path_tbl.loc_in_body_x(i);
                loc_in_body_y = mtu_path_tbl.loc_in_body_y(i);
                loc_in_body_z = mtu_path_tbl.loc_in_body_z(i);
                
                % Define the point name
                pt_name = ['pt', num2str(pt_idx)];

                % If multiple points with the same index exist for the same muscle-tendon unit in the path table, throw an error
                if isfield(mtu_path_struct, mtu_name) && isfield(mtu_path_struct.(mtu_name), pt_name)
                    error([mtu_name, ' has more than one points with index ', num2str(pt_idx)], '.');
                end

                % Store the path information in the muscle-tendon unit path structure
                mtu_path_struct.(mtu_name).(pt_name).pt_type = pt_type;
                mtu_path_struct.(mtu_name).(pt_name).attached_body = attached_body;
                mtu_path_struct.(mtu_name).(pt_name).loc_in_body = [loc_in_body_x, loc_in_body_y, loc_in_body_z];
            end
            
            % Get all muscle-tendon unit names in the muscle-tendon unit path structure
            all_mtu_fields = fieldnames(mtu_path_struct);

            % Iterate over all muscle-tendon units
            for i = 1 : numel(all_mtu_fields)
                % Get all point names in the current muscle-tendon unit
                all_pt_fields = fieldnames(mtu_path_struct.(all_mtu_fields{i}));

                % Define the benchmark point names that start from 'pt1' and end with 'ptN', where N is the number of points in the current muscle-tendon unit
                pt_fields_benchmark = arrayfun(@(k) ['pt' num2str(k)], 1 : numel(all_pt_fields), 'UniformOutput', false);
        
                % If the point names in the current muscle-tendon unit do not match the benchmark point names, throw an error
                if ~isequal(sort(all_pt_fields(:)), sort(pt_fields_benchmark(:)))
                    error(['Incomplete index sequence detected for ', all_mtu_fields{i}, '. ' ...
                           'The indices do not form a complete, consecutive sequence from 1 to the number of points.']);
                end

                % Reorder the point names in the current muscle-tendon unit to match the benchmark point names
                mtu_path_struct.(all_mtu_fields{i}) = orderfields(mtu_path_struct.(all_mtu_fields{i}), pt_fields_benchmark);

            end
            
            % Update the mtu_path_struct property with the muscle-tendon unit path structure
            obj.mtu_path_struct = mtu_path_struct;
        
        end
        
        function [is_unique, nonunique_elements] = find_nonunique_elements(obj, cell_arr)
            % This method checks if the elements in a cell array are unique or not.
            %
            % Inputs:
            %   - cell_arr: The cell array to check (cell array).
            %
            % Outputs:
            %   - is_unique: A boolean indicating if the elements in the cell array are unique or not (logical).
            %   - nonunique_elements: The nonunique elements in the cell array (cell array).
            %
            % Example usage:
            %   [is_unique, nonunique_elements] = obj.find_nonunique_elements(cell_arr)

            % Get the unique elements in the cell array, and the indices of the unique elements in the cell array
            [unique_elements, ~, idx] = unique(cell_arr);

            % Get the number of occurences of each unique element in the cell array
            occurences = histcounts(idx, 1:numel(unique_elements)+1);
            
            % Get the nonunique elements in the cell array
            nonunique_elements = unique_elements(occurences > 1);

            % If the nonunique elements are empty, the elements in the cell array are unique
            is_unique = isempty(nonunique_elements);
        
        end

        function obj = adjust_osim_geom_tbl(obj)
            % This method append the float body geometries to the OpenSim artificial geometry table.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Brancher class (Brancher object) with an updated adj_osim_geom_tbl property.
            %
            % Example usage:
            %   obj = obj.adjust_osim_geom_tbl()
            
            % Read the OpenSim artificial geometry table
            osim_geom_file = [obj.model_root_dir, '/Data/LocalData/Artificial_OpenSim_Geometries.csv'];
            osim_geom_imp_opts = detectImportOptions(osim_geom_file);
            osim_geom_imp_opts = setvartype(osim_geom_imp_opts, 'params', 'string');
            osim_geom_imp_opts.Delimiter = ',';
            osim_geom_tbl = readtable(osim_geom_file, osim_geom_imp_opts);
            
            % Define the radius of the float body geometries
            variable_names = {'body_name', 'osim_geom_type', 'params'};
            variable_types = [repmat({'string'}, 1, 3)];

            % Initialize the adjusted OpenSim artificial geometry table
            adj_osim_geom_tbl = table('Size', [0, length(variable_names)], 'VariableTypes', variable_types, 'VariableNames', variable_names);
            
            % Append the float body geometries to the adjusted OpenSim artificial geometry table
            adj_osim_geom_tbl = [adj_osim_geom_tbl; osim_geom_tbl];
            
            % Loop over all float body structures
            for i = 1 : numel(obj.float_body_struct)
                % Get the body name, OpenSim geometry type, and radius of the current float body
                body_name = obj.float_body_struct(i).body_name;
                osim_geom_type = 'Sphere';
                radius = num2str(obj.float_sphere_geom_radius);

                % Define the row to add to the adjusted OpenSim artificial geometry table
                row_to_add = {body_name, osim_geom_type, radius};

                % Append the row to the adjusted OpenSim artificial geometry table
                adj_osim_geom_tbl = [adj_osim_geom_tbl; row_to_add];
            end

            % Set the adj_osim_geom_tbl property to the adjusted OpenSim artificial geometry table
            obj.adj_osim_geom_tbl = adj_osim_geom_tbl;

        end

        function export_and_mirror_files(obj)
            % This method exports the adjusted local data to the 'AdjustedLocalData' directory under the model root directory.
            % It also mirrors the 'Geometry' and 'Wrapping_Surfaces.csv' files from the 'LocalData' directory to the 'AdjustedLocalData' directory.
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_and_mirror_files()

            % Define the export directory
            export_dir = [obj.model_root_dir, '/Data/AdjustedLocalData'];

            % Export the adjusted local data
            writetable(obj.adj_body_mass_props_tbl, [export_dir, filesep, 'Body_Mass_Properties.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_jcs_tbl, [export_dir, filesep, 'JCS.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_joint_rom_tbl, [export_dir, filesep, 'Joint_ROM.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_mtu_params_tbl, [export_dir, filesep, 'MTU_Parameters.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_mtu_path_tbl, [export_dir, filesep, 'MTU_Path.csv'], 'WriteMode', 'overwrite');
            writetable(obj.ligament_params_tbl, [export_dir, filesep, 'Ligament_Parameters.csv'], 'WriteMode', 'overwrite');
            writetable(obj.ligament_path_tbl, [export_dir, filesep, 'Ligament_Path.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_osim_geom_tbl, [export_dir, filesep, 'Artificial_OpenSim_Geometries.csv'], 'WriteMode', 'overwrite');
            writetable(obj.adj_wrap_surf_pair_tbl, [export_dir, filesep, 'Wrapping_Surface_MTU_Ligament_Pairings.csv'], 'WriteMode', 'overwrite');

            % Mirror the 'Geometry' and 'Wrapping_Surfaces.csv' files from the 'LocalData' directory to the 'AdjustedLocalData' directory
            copyfile([obj.model_root_dir, '/Data/LocalData/Geometry'], [export_dir, filesep, 'Geometry']);
            copyfile([obj.model_root_dir, '/Data/LocalData/Wrapping_Surfaces.csv'], [export_dir, filesep, 'Wrapping_Surfaces.csv']);

        end

    end

end

