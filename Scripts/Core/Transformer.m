classdef Transformer
    % This class implements the Transformer, reponsible for transforming the model from the global format to the local format.
    % 
    % For any questions, feedback, issues, please contact author:
    % xunfu@umich.edu (Xun Fu)
    
    properties
        model_root_dir;             % The base directory for the model (string)
        bodies;                     % A cell array containing the names of the bodies in the model
        trans_mats;                 % A cell array containing the transformation matrices for the bodies
        jcs_tbl;                    % A table containing the joint coordinate systems
        mtu_path_tbl;               % A table containing the muscle-tendon unit (MTU) paths
        body_mass_props_tbl;        % A table containing the mass properties of the bodies
        mtu_params_tbl;             % A table containing the MTU parameters
        joint_rom_tbl;              % A table containing the range of motion (ROM) of the joints
        branch_group_tbl;           % A table containing the branch groups
        wrap_surf_tbl;              % A table containing the wrapping surfaces
        mtu_wrap_surf_pair_tbl;     % A table containing the MTU wrapping surface pairs

        len_unit_in_data;           % The length unit used in the data (string)
        mass_unit_in_data;          % The mass unit used in the data (string)
        force_unit_in_data;         % The force unit used in the data (string)
        angle_unit_in_data;         % The angle unit used in the data (string)

    end

    methods
        function obj = Transformer(model_root_dir, unit_struct)
            % Constructor for the class.
            %
            % Inputs:
            %   - model_root_dir: The base directory for the model (string of 1xN characters, 
            %     where N is the length of the input string)
            %   - unit_struct: A struct containing the length and mass units used in the data 
            %     (struct with fields 'len' and 'mass')
            %
            % Outputs:
            %   - obj: An instance of the Transformer class (Transformer object)
            %
            % Example usage:
            %   obj = Transformer('../Model', struct('len', 'mm', 'mass', 'g'));
            
            % Set the base directory for the model
            obj.model_root_dir = model_root_dir;
            
            % Initialize the properties with empty values
            obj.bodies = {};
            obj.trans_mats = {};
            obj.jcs_tbl = [];
            obj.mtu_path_tbl = [];
            obj.body_mass_props_tbl = [];
            obj.mtu_params_tbl = [];
            obj.joint_rom_tbl = [];
            obj.branch_group_tbl = [];
            obj.wrap_surf_tbl = [];
            obj.mtu_wrap_surf_pair_tbl = [];
            
            % Set the units used in the data
            % If the length unit and mass unit are provided, use the provided units
            if nargin > 1
                obj.len_unit_in_data = unit_struct.len;
                obj.mass_unit_in_data = unit_struct.mass;
            % Otherwise, use the default units
            else
                obj.len_unit_in_data = 'mm';
                obj.mass_unit_in_data = 'g';
            end
            
            % Set the force and angle units to the default units (Newtons (N) and degrees (deg) respectively)
            % Note: The current tool configuration does not support other options for force and angle units
            obj.force_unit_in_data = 'N';
            obj.angle_unit_in_data = 'deg';
            
        end
        
        function obj = get_trans_mats(obj)
            % This method calculates and sets the transformation matrices for all bodies in the model.
            % It reads the body frame landmarks from the 'Body_Frame_Landmarks.csv' file and then
            % calculates the transformation matrices using the landmark points and sets them for each body.
            %
            % Inputs: None
            % 
            % Outputs:
            %   - obj: An instance of the Transformer class (Transformer object)
            %
            % Example usage:
            %   obj = Transformer('../Model', struct('len', 'mm', 'mass', 'g'));

            % Read the body frame landmarks from the body frame landmarks file
            bf_landmarkfile = [obj.model_root_dir, '/Data/GlobalData/Body_Frame_Landmarks.csv'];
            bf_landmarks = readtable(bf_landmarkfile, 'Delimiter', ',');

            % Check if there are non-unique body elements in the body_name column
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(bf_landmarks.body_name(:));
            
            % If there are non-unique body elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the body_name column']);
            end
            
            % Set the bodies property and initialize the transformation matrices property
            obj.bodies = bf_landmarks.body_name(:);
            obj.trans_mats = cell(size(obj.bodies));
            
            % Loop over all body frame landmarks
            for i = 1 : size(bf_landmarks, 1)
                % Get the x, y, and z coordinates of the landmark point for the origin of the coordinate system
                org_pt = [bf_landmarks.org_pt_x(i), ...
                          bf_landmarks.org_pt_y(i), ...
                          bf_landmarks.org_pt_z(i)];
                
                % Get the x, y, and z coordinates of the landmark point to denote the positive x-axis of the coordinate system
                pos_xaxis_pt = [bf_landmarks.pos_xaxis_pt_x(i), ...
                                bf_landmarks.pos_xaxis_pt_y(i), ...
                                bf_landmarks.pos_xaxis_pt_z(i)];

                % Get the x, y, and z coordinates of the landmark point to denote the positive y-axis of the coordinate system
                pos_yaxis_pt = [bf_landmarks.pos_yaxis_pt_x(i), ...
                                bf_landmarks.pos_yaxis_pt_y(i), ...
                                bf_landmarks.pos_yaxis_pt_z(i)];

                % Get the normalized and corrected for perpendicularity vectors for the positive 
                % x, y, and z axes of the coordinate system
                [pos_xaxis_vec_normd, pos_yaxis_vec_normd, pos_zaxis_vec_normd] = ... 
                    obj.get_cs_normd_vecs(org_pt, pos_xaxis_pt, pos_yaxis_pt);
                
                % Compute the rotation matrix and the transformation matrix
                rot_mat = inv([pos_xaxis_vec_normd', pos_yaxis_vec_normd', pos_zaxis_vec_normd']);
                trans_mat = [rot_mat, -rot_mat*(org_pt'); 0, 0, 0, 1];
                
                % Set the transformation matrix for the current body
                obj.trans_mats{i} = trans_mat;
            
            end

        end


        function [normd_pos_xaxis_vec, normd_pos_yaxis_vec, normd_pos_zaxis_vec] = ...
                    get_cs_normd_vecs(obj, org_pt, pos_xaxis_pt, pos_yaxis_pt)
            % This method calculates normalized and perpendicular vectors for the positive 
            % x, y, and z axes of the coordinate system
            % 
            % Inputs:
            %   - org_pt: The coordinates of the landmark point for the origin of the coordinate system 
            %     (1x3 array of doubles)
            %   - pos_xaxis_pt: The coordinates of the landmark point to denote the positive x-axis of 
            %     the coordinate system (1x3 array of doubles)
            %   - pos_yaxis_pt: The coordinates of the landmark point to denote the positive y-axis of 
            %     the coordinate system (1x3 array of doubles)
            %
            % Outputs:
            %   - normd_pos_xaxis_vec: The normalized vector for the positive x-axis (1x3 array of doubles)
            %   - normd_pos_yaxis_vec: The normalized vector for the positive y-axis (1x3 array of doubles)
            %   - normd_pos_zaxis_vec: The normalized vector for the positive z-axis (1x3 array of doubles)
            %
            % Example usage:
            %   [normd_pos_xaxis_vec, normd_pos_yaxis_vec, normd_pos_zaxis_vec] = ...
            %           obj.get_cs_normd_vecs(org_pt, pos_xaxis_pt, pos_yaxis_pt);

            % Calculate the vectors denoting the positive x and y axes of the coordinate system
            pos_xaxis_vec = pos_xaxis_pt - org_pt;
            pos_yaxis_vec = pos_yaxis_pt - org_pt;
            
            % Calculate the vector denoting the positive z axis using the cross product of the x and y axis vectors
            pos_zaxis_vec = cross(pos_xaxis_vec, pos_yaxis_vec);
            % Recalculate the y axis vector to ensure that it is perpendicular to the x and z axis vectors
            pos_yaxis_vec = cross(pos_zaxis_vec, pos_xaxis_vec);

            % Normalize the x, y, and z axis vectors
            normd_pos_xaxis_vec = pos_xaxis_vec ./ norm(pos_xaxis_vec);
            normd_pos_yaxis_vec = pos_yaxis_vec ./ norm(pos_yaxis_vec);
            normd_pos_zaxis_vec = pos_zaxis_vec ./ norm(pos_zaxis_vec);

        end

        function export_trans_mats(obj)            
            % This method exports the transformation matrices to text files in the 'transformation_matrices' directory
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_trans_mats();

            % Define the directory where the transformation matrices will be exported
            export_dir = [obj.model_root_dir, '/Data/GlobalData/transformation_matrices'];

            % If the export directory does not exist, create it
            if ~isfolder(export_dir)
                mkdir(export_dir);
            end
            
            % Loop over all the bodies
            for i = 1 : size(obj.bodies, 1)
                % Write the transformation matrix for the current body to a text file
                % The file name is 'trans_mat_' followed by the name of the body
                writematrix(obj.trans_mats{i}, [export_dir, filesep, 'trans_mat_', obj.bodies{i}, '.txt'], ...
                            'Delimiter', 'space')
            
            end
        
        end

        function apply_trans_mat_to_geom(obj, body, geom_src_file, geom_save_file)
            % This method applies a transformation matrix to the geometry of a single body.
            % It reads the original geometry from an STL file, applies the transformation, and then 
            % writes the transformed geometry to a new STL file.
            %
            % Inputs:
            %   - body: Body name (string)
            %   - geom_src_file: The path to the source STL file for the body's geometry (string)
            %   - geom_save_file: The path where the transformed STL file will be saved (string)
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.apply_trans_mat_to_geom('femur_r', ...
            %                               '../Model/Data/GlobalData/Geometry/femur_r.stl', ...
            %                               '../Model/Data/LocalData/Geometry/femur_r.stl');

            % Get the transformation matrix for the body according to the body's name
            [trans_mat, ~] = obj.query_trans_mat(body);

            % Read the STL file for the body's geometry
            TR = stlread(geom_src_file);

            % Extract the vertices and faces from the STL data
            vertices = TR.Points;
            faces = TR.ConnectivityList;
            
            % Convert the vertices to homogeneous coordinates
            vertices_homo = [vertices, ones(size(vertices, 1), 1)];
            % Apply the transformation matrix to the vertices
            transd_vertices_homo = vertices_homo * trans_mat';
            
            % Convert the transformed vertices back to non-homogeneous coordinates
            transd_vertices = transd_vertices_homo(:, 1:3);
            % Create a new triangulation with the transformed vertices and the original faces
            transd_TR = triangulation(faces, transd_vertices);

            % Write the transformed geometry to an STL file
            stlwrite(transd_TR, geom_save_file);

        end

        function  batch_apply_trans_mat_to_geoms(obj)            
            % This method applies the transformation matrices to the geometries of all bodies 
            % in the model (excluding the groud if exists) and writes the transformed geometries
            % to STL files in the 'Geometry' directory under 'LocalData'
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.batch_apply_trans_mat_to_geoms();
            
            % Get the list of bodies in the model
            bodies = obj.bodies;

            % Define the source and destination directoreis for the geometries
            geom_src_dir = [obj.model_root_dir, '/Data/GlobalData/Geometry'];
            geom_save_dir = [obj.model_root_dir, '/Data/LocalData/Geometry'];
            
            % If the destination directory does not exist, create it
            if ~isfolder(geom_save_dir)
                mkdir(geom_save_dir);
            end

            % Loop over all bodies
            for i = 1 : length(bodies)
                body  = bodies{i};
                
                % Skip the ground body
                if strcmp(body, 'ground')
                    continue;
                end

                % Define the source and destination files for the body's geometry
                geom_src_file = [geom_src_dir, filesep, body, '.stl'];
                geom_save_file = [geom_save_dir, filesep, body, '.stl'];

                % Apply the transformation matrix to the body's geometry and save the transformed geometry
                obj.apply_trans_mat_to_geom(body, geom_src_file, geom_save_file);

            end        
        
        end

        function obj = build_jcs_tbl(obj)
            % This method reads the JCS landmarks from a CSV file, and then constructs a table with the joint names, 
            % parent and child bodies, and the location and orientation of the joint in both parent and child bodies.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Transformer class (Transformer object) with an 
            %     updated 'jcs_tbl' property.
            %
            % Example usage:
            %   obj = obj.build_jcs_tbl();
            %

            % Read the JCS landmarks from the JCS landmarks file
            jcs_landmarkfile = [obj.model_root_dir, '/Data/GlobalData/JCS_Landmarks.csv'];
            jcs_landmarks = readtable(jcs_landmarkfile, 'Delimiter', ',');

            % Check if there are non-unique joint name elements in the joint_name column
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(jcs_landmarks.joint_name(:));
            
            % If there are non-unique joint name elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the joint_name column']);
            end
            
            % Define the variable names and types for the JCS table
            variable_names = {'joint_name', 'par_body', 'chd_body', ...
                              'loc_in_par_x', 'loc_in_par_y', 'loc_in_par_z', ...
                              'ori_in_par_x', 'ori_in_par_y', 'ori_in_par_z', ...
                              'loc_in_chd_x', 'loc_in_chd_y', 'loc_in_chd_z', ...
                              'ori_in_chd_x', 'ori_in_chd_y', 'ori_in_chd_z',};
            
            variable_types = [repmat({'string'}, 1, 3), repmat({'double'}, 1, 12)];

            % Initialize the JCS table
            jcs_tbl = table('Size', [0, length(variable_names)], 'VariableTypes', variable_types, 'VariableNames', variable_names);

            % Loop over all JCS landmarks
            for i = 1 : size(jcs_landmarks, 1)
                % Get the joint name, parent and child bodies, and the landmark points for the joint in both parent and child bodies
                joint_name = jcs_landmarks.joint_name{i};
                par_body = jcs_landmarks.par_body{i};
                chd_body = jcs_landmarks.chd_body{i};

                % Extract the landmark points for the joint frames in both parent and child bodies
                par_joint_frm_org_pt = [jcs_landmarks.par_joint_frm_org_pt_x(i), ...
                                        jcs_landmarks.par_joint_frm_org_pt_y(i), ...
                                        jcs_landmarks.par_joint_frm_org_pt_z(i)];

                par_joint_frm_pos_xaxis_pt = [jcs_landmarks.par_joint_frm_pos_xaxis_pt_x(i), ...
                                              jcs_landmarks.par_joint_frm_pos_xaxis_pt_y(i), ...
                                              jcs_landmarks.par_joint_frm_pos_xaxis_pt_z(i)];

                par_joint_frm_pos_yaxis_pt = [jcs_landmarks.par_joint_frm_pos_yaxis_pt_x(i), ...
                                              jcs_landmarks.par_joint_frm_pos_yaxis_pt_y(i), ...
                                              jcs_landmarks.par_joint_frm_pos_yaxis_pt_z(i)];

                chd_joint_frm_org_pt = [jcs_landmarks.chd_joint_frm_org_pt_x(i), ...
                                        jcs_landmarks.chd_joint_frm_org_pt_y(i), ...
                                        jcs_landmarks.chd_joint_frm_org_pt_z(i)];

                chd_joint_frm_pos_xaxis_pt = [jcs_landmarks.chd_joint_frm_pos_xaxis_pt_x(i), ...
                                              jcs_landmarks.chd_joint_frm_pos_xaxis_pt_y(i), ...
                                              jcs_landmarks.chd_joint_frm_pos_xaxis_pt_z(i)];

                chd_joint_frm_pos_yaxis_pt = [jcs_landmarks.chd_joint_frm_pos_yaxis_pt_x(i), ...
                                              jcs_landmarks.chd_joint_frm_pos_yaxis_pt_y(i), ...
                                              jcs_landmarks.chd_joint_frm_pos_yaxis_pt_z(i)];
                
                % Compute the location of the joint in both parent and child bodies                              
                loc_in_par = obj.get_loc_in_body(par_body, par_joint_frm_org_pt);
                loc_in_chd = obj.get_loc_in_body(chd_body, chd_joint_frm_org_pt);
                
                % Compute the normalized and corrected for perpendicularity vectors for the positive x, y, and z axes of 
                % the joint frames in both parent and child bodies
                [normd_par_joint_frm_pos_xaxis_vec, normd_par_joint_frm_pos_yaxis_vec, normd_par_joint_frm_pos_zaxis_vec] = ... 
                    obj.get_cs_normd_vecs(par_joint_frm_org_pt, par_joint_frm_pos_xaxis_pt, par_joint_frm_pos_yaxis_pt);
                
                [normd_chd_joint_frm_pos_xaxis_vec, normd_chd_joint_frm_pos_yaxis_vec, normd_chd_joint_frm_pos_zaxis_vec] = ... 
                    obj.get_cs_normd_vecs(chd_joint_frm_org_pt, chd_joint_frm_pos_xaxis_pt, chd_joint_frm_pos_yaxis_pt);

                % Compute the orientation of the joint in both parent and child bodies
                ori_in_par = obj.get_ori_in_body(par_body, ...
                    normd_par_joint_frm_pos_xaxis_vec, normd_par_joint_frm_pos_yaxis_vec, normd_par_joint_frm_pos_zaxis_vec);

                ori_in_chd = obj.get_ori_in_body(chd_body, ...
                    normd_chd_joint_frm_pos_xaxis_vec, normd_chd_joint_frm_pos_yaxis_vec, normd_chd_joint_frm_pos_zaxis_vec);
                
                % Construct the row to add to the JCS table
                row_to_add = {joint_name, par_body, chd_body, ...
                              loc_in_par(1), loc_in_par(2), loc_in_par(3), ...
                              ori_in_par(1), ori_in_par(2), ori_in_par(3), ...
                              loc_in_chd(1), loc_in_chd(2), loc_in_chd(3), ...
                              ori_in_chd(1), ori_in_chd(2), ori_in_chd(3)};

                % Add the row to the JCS table
                jcs_tbl = [jcs_tbl; row_to_add];
            end
            
            % Update the jcs_tbl property
            obj.jcs_tbl = jcs_tbl;

        end

        function [trans_mat, idx] = query_trans_mat(obj, body)
            % This method takes the name of a body as input and returns the corresponding transformation matrix
            % and the index of the body in the 'bodies' property of the object.
            %
            % Inputs:
            %   - body: A string representing the name of the body for which the transformation matrix is to be retrieved.
            %
            % Outputs:
            %   - trans_mat: The transformation matrix for the body (4x4 array of doubles)
            %   - idx: The index of the body in the 'bodies' property of the object (integer)
            %
            % Example usage:
            %   [trans_mat, idx] = obj.query_trans_mat('femur_r');

            % Find the index of the body in the 'bodies' property of the object
            idx = find(strcmp(obj.bodies, body));
            
            % If the body is not found, throw an error
            if isempty(idx)
                error(['Cound not find the body named ', body]);
            end
            
            % Retrieve the transformation matrix for the body
            trans_mat = obj.trans_mats{idx};

        end

        function loc = get_loc_in_body(obj, body, pt)
            % This method takes the name of a body and a point in the global coordinate system as inputs, 
            % and returns the location of the point in the local coordinate system of the body.
            %
            % Inputs:
            %   - body: A string representing the name of the body.
            %   - pt: The coordinates of the point in the global coordinate system (1x3 array of doubles).
            %
            % Outputs:
            %   - loc: The coordinates of the point in the local coordinate system of the body (1x3 array of doubles).
            % 
            % Example usage:
            %   loc = obj.get_loc_in_body('femur_r', [1, 2, 3]);  
            
            % Query the transformation matrix for the body
            trans_mat = obj.query_trans_mat(body);
            
            % Compute the location of the point in the local coordinate system of the body
            loc = trans_mat*([pt, 1]');
            loc = loc(1:3)';
        
        end

        function ori = get_ori_in_body(obj, body, pos_xaxis_vec, pos_yaxis_vec, pos_zaxis_vec)
            % This method takes the name of a body and the vectors of the positive  x, y, and z axes of
            % a frame in the global coordinate system as inputs and returns the orientation of the frame 
            % in the local coordinate system of the body.
            % 
            % Inputs:
            %   - body: A string representing the name of the body.
            %   - pos_xaxis_vec: The vector denoting the positive x-axis of the frame in the 
            %     global coordinate system (1x3 array of doubles).
            %   - pos_yaxis_vec: The vector denoting the positive y-axis of the frame in the 
            %     global coordinate system (1x3 array of doubles).
            %   - pos_zaxis_vec: The vector denoting the positive z-axis of the frame in the 
            %     global coordinate system (1x3 array of doubles).
            %
            % Outputs:
            %   - ori: The orientation of the frame in the local coordinate system of the body (1x3 array of doubles).
            %
            % Example usage:
            %   ori = obj.get_ori_in_body('femur_r', [1, 2, 3], [4, 5, 6], [7, 8, 9]);

            % Query the transformation matrix for the body
            trans_mat = obj.query_trans_mat(body);

            % Compute the transformed vectors of the positive x, y, and z axes of the frame
            transd_pos_xaxis_vec = pos_xaxis_vec*trans_mat(1:3, 1:3)';
            transd_pos_yaxis_vec = pos_yaxis_vec*trans_mat(1:3, 1:3)';
            transd_pos_zaxis_vec = pos_zaxis_vec*trans_mat(1:3, 1:3)';
            
            % Compute the rotation matrix and the orientation of the frame in the local coordinate system of the body
            rot_mat = [transd_pos_xaxis_vec', transd_pos_yaxis_vec', transd_pos_zaxis_vec'];

            % Compute the orientation of the frame in the local coordinate system of the body
            ori = rad2deg(rotm2eul(rot_mat, 'XYZ'));
        
        end

        function [is_unique, nonunique_elements] = find_nonunique_elements(obj, cell_arr)
            % This method takes a cell array as input and returns a boolean indicating whether 
            % all elements in the array are unique, and a cell array of the non-unique elements. 
            %
            % Inputs:
            %   - cell_arr: A cell array of strings.
            % 
            % Outputs:
            %   - is_unique: A boolean indicating whether all elements in the array are unique.
            %   - nonunique_elements: A cell array of the non-unique elements.
            %
            % Example usage:
            %   [is_unique, nonunique_elements] = obj.find_nonunique_elements({'a', 'b', 'a'});

            % Find the unique elements in the array
            [unique_elements, ~, idx] = unique(cell_arr);

            % Count the number of occurences of each unique element
            occurences = histcounts(idx, 1:numel(unique_elements)+1);
            
            % Identify the non-unique elements
            nonunique_elements = unique_elements(occurences > 1);

            % Determine whether all elements in the array are unique
            is_unique = isempty(nonunique_elements);
        
        end

        function export_jcs_tbl(obj)
            % This method writes the 'jcs_tbl' property of the object to a CSV file named 'JCS.csv' 
            % in the 'LocalData' directory under the model root directory. If a file with the same name
            % already exists, it is overwritten.
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_jcs_tbl();

            % Define the directory where the file will be saved
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            
            % Write the 'jcs_tbl' property of the object to a CSV file
            writetable(obj.jcs_tbl, [export_dir, filesep, 'JCS.csv'], 'WriteMode', 'overwrite');
        
        end

        function obj = build_mtu_path_tbl(obj)
            % This method reads the MTU path landmarks from a CSV file, computes the location of each 
            % landmark in the local coordinate system of the body it is attached to, and stores the
            % results in the 'mtu_path_tbl' property of the object.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an 
            %     updated 'mtu_path_tbl' property.
            %
            % Example usage:
            %   obj = obj.build_mtu_path_tbl();

            % Read the MTU path landmarks from the MTU path landmarks file
            mtu_path_landmarkfile = [obj.model_root_dir, '/Data/GlobalData/MTU_Path_Landmarks.csv'];
            mtu_path_landmarks = readtable(mtu_path_landmarkfile, 'Delimiter', ',');
            
            % Define the variable names and types for the MTU path table
            variable_names = {'mtu_name', 'pt_idx', 'pt_type', 'attached_body', ...
                              'loc_in_body_x', 'loc_in_body_y', 'loc_in_body_z'};
            variable_types = [{'string'}, {'uint8'}, repmat({'string'}, 1, 2), repmat({'double'}, 1, 3)];

            % Initialize the MTU path table
            mtu_path_tbl = table('Size', [0, length(variable_names)], 'VariableTypes', variable_types, 'VariableNames', variable_names);

            % Iterate over all MTU path landmarks
            for i = 1 : size(mtu_path_landmarks, 1)
                % Extract the MTU name, point index, point type, attached body, and the landmark point
                mtu_name = mtu_path_landmarks.mtu_name{i};
                pt_idx = mtu_path_landmarks.pt_idx(i);
                pt_type = mtu_path_landmarks.pt_type{i};
                attached_body = mtu_path_landmarks.attached_body{i};

                % Extract the coordinates of the landmark point
                pt = [mtu_path_landmarks.pt_x(i), ...
                      mtu_path_landmarks.pt_y(i), ...
                      mtu_path_landmarks.pt_z(i)];
                
                % Compute the location of the landmark point in the local coordinate system of the attached body
                loc_in_body = obj.get_loc_in_body(attached_body, pt);
                
                % Construct the row to add to the MTU path table
                row_to_add = {mtu_name, pt_idx, pt_type, attached_body, ...
                              loc_in_body(1), loc_in_body(2), loc_in_body(3)};

                % Add the row to the MTU path table
                mtu_path_tbl = [mtu_path_tbl; row_to_add];
            end
            
            % Set the 'mtu_path_tbl' property of the object to the MTU path table
            obj.mtu_path_tbl = mtu_path_tbl;
        end
        
        function export_mtu_path_tbl(obj)
            % This method writes the 'mtu_path_tbl' property of the object to a CSV file named 'MTU_Path.csv' 
            % in the 'LocalData' directory under the model root directory. If a file with the same name 
            % already exists, it is overwritten.
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_mtu_path_tbl();

            % Define the directory where the file will be saved
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            
            % Write the 'mtu_path_tbl' property of the object to a CSV file
            writetable(obj.mtu_path_tbl, [export_dir, filesep, 'MTU_Path.csv'], 'WriteMode', 'overwrite');
        
        end

        function [transd_com, transd_inertia] = apply_trans_mat_to_bmp(obj, body, com, inertia)
            % This method takes the name of a body, its COM, and its inertia as inputs, and returns the transformed COM and inertia.
            %
            % Inputs:
            %   - body: A string representing the name of the body.
            %   - com: The coordinates of the COM in the global coordinate system (1x3 array of doubles).
            %   - inertia: The inertia of the body in the global coordinate system (1x6 array of doubles).
            %
            % Outputs:
            %   - transd_com: The coordinates of the transformed COM in the local coordinate system of the body (1x3 array of doubles).
            %   - transd_inertia: The transformed inertia of the body in the local coordinate system of the body (1x6 array of doubles).
            %
            % Example usage:
            %   [transd_com, transd_inertia] = obj.apply_trans_mat_to_bmp('body1', com, inertia);

            % Query the transformation matrix for the body
            [trans_mat, ~] = obj.query_trans_mat(body);

            % Transform the COM
            com_homo = [com, 1];
            transd_com = trans_mat * (com_homo');
            transd_com = transd_com(1:3)';
            
            % Transform the inertia
            inertia_tensor = [inertia(1), inertia(4), inertia(5);...
                              inertia(4), inertia(2), inertia(6); ...
                              inertia(5), inertia(6), inertia(3)];
            
            transd_inertia_tensor = trans_mat(1:3, 1:3) * inertia_tensor * trans_mat(1:3, 1:3)';

            transd_inertia = [transd_inertia_tensor(1, 1), ...
                              transd_inertia_tensor(2, 2), ...
                              transd_inertia_tensor(3, 3), ...
                              transd_inertia_tensor(1, 2), ...
                              transd_inertia_tensor(1, 3), ...
                              transd_inertia_tensor(2, 3)];

        end

        function obj = build_body_mass_props_tbl(obj)
            % This method reads the body mass properties from a CSV file, applies the transformation matrix to 
            % the COM and inertia of each body, and stores the results in the 'body_mass_props_tbl' property of the object.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'body_mass_props_tbl' property.
            %
            % Example usage:
            %   obj = obj.build_body_mass_props_tbl();

            % Read the body mass properties from the body mass properties file
            body_mass_props_file = [obj.model_root_dir, '/Data/GlobalData/Body_Mass_Properties.csv'];
            body_mass_props = readtable(body_mass_props_file, 'Delimiter', ',');

            % Check if there are non-unique body elements in the body_name column
            [is_unique, nonunique_elements] = obj.find_nonunique_elements(body_mass_props.body_name(:));
            
            % If there are non-unique body elements, throw an error
            if ~is_unique
                error([strjoin(nonunique_elements, ' and '), ' occur(s) multiple times in the body_name column']);
            end
            
            % Define the variable names and types for the body mass properties table
            variable_names = {'body_name', 'mass', ...
                              'com_x', 'com_y', 'com_z', ...
                              'inertia_xx', 'inertia_yy', 'inertia_zz', ...
                              'inertia_xy', 'inertia_xz', 'inertia_yz'};
            variable_types = [repmat({'string'}, 1, 1), repmat({'double'}, 1, 10)];
            
            % Initialize the body mass properties table
            body_mass_props_tbl = table('Size', [0, length(variable_names)], 'VariableTypes', variable_types, 'VariableNames', variable_names);

            % Iterate over all body mass properties
            for i = 1 : size(body_mass_props, 1)
                body_name = body_mass_props.body_name{i};
                mass = body_mass_props.mass(i);
                com = [body_mass_props.com_x(i), body_mass_props.com_y(i), body_mass_props.com_z(i)];
                inertia = [body_mass_props.inertia_xx(i), ...
                           body_mass_props.inertia_yy(i), ...
                           body_mass_props.inertia_zz(i), ...
                           body_mass_props.inertia_xy(i), ...
                           body_mass_props.inertia_xz(i), ...
                           body_mass_props.inertia_yz(i)];
                
                % Apply the transformation matrix to the COM and inertia of the body
                [transd_com, transd_inertia] = obj.apply_trans_mat_to_bmp(body_name, com, inertia);

                % Construct the row to add to the body mass properties table
                row_to_add = {body_name, mass, ...
                              transd_com(1), transd_com(2), transd_com(3), ...
                              transd_inertia(1), transd_inertia(2), transd_inertia(3), ...
                              transd_inertia(4), transd_inertia(5), transd_inertia(6)};

                % Add the row to the body mass properties table
                body_mass_props_tbl = [body_mass_props_tbl; row_to_add];
            end
            
            % Set the 'body_mass_props_tbl' property of the object to the body mass properties table
            obj.body_mass_props_tbl = body_mass_props_tbl;
        
        end

        function obj = build_wrap_surf_tbl(obj)
            % This method reads the wrapping surface properties from a CSV file and stores the results 
            % in the 'wrap_surf_tbl' property of the object.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'wrap_surf_tbl' property.
            %
            % Example usage:
            %   obj = obj.build_wrap_surf_tbl();

            % Read the wrapping surface properties from the wrapping surface properties file
            wrap_surf_landmarkfile = [obj.model_root_dir, '/Data/GlobalData/Wrapping_Surface_Landmarks.csv'];
            wrap_surf_imp_opts = detectImportOptions(wrap_surf_landmarkfile);
            wrap_surf_imp_opts = setvartype(wrap_surf_imp_opts, 'geom_params', 'string');
            wrap_surf_imp_opts.Delimiter = ',';
            wrap_surf_landmarks = readtable(wrap_surf_landmarkfile, wrap_surf_imp_opts);
            
            % Define the variable names and types for the wrapping surface table
            variable_names = {'wrap_surf_name', 'attached_body', ... 
                              'loc_in_body_x', 'loc_in_body_y', 'loc_in_body_z', ...
                              'ori_in_body_x', 'ori_in_body_y', 'ori_in_body_z', ...
                              'type', 'geom_params', 'quadrant'};
            variable_types = [repmat({'string'}, 1, 2), repmat({'double'}, 1, 6), repmat({'string'}, 1, 3)];

            % Initialize the wrapping surface table
            wrap_surf_tbl = table('Size', [0, length(variable_names)], 'VariableTypes', variable_types, 'VariableNames', variable_names);

            % Iterate over all wrapping surface landmarks
            for i = 1 : size(wrap_surf_landmarks, 1)
                % Extract the wrapping surface name, attached body, landmark point, and the vectors of 
                % the positive x and y axes of the wrapping surface frame
                warp_surf_name = wrap_surf_landmarks.wrap_surf_name{i};
                attached_body = wrap_surf_landmarks.attached_body{i};

                wrap_surf_frm_org_pt = [wrap_surf_landmarks.org_pt_x(i), ...
                                        wrap_surf_landmarks.org_pt_y(i), ...
                                        wrap_surf_landmarks.org_pt_z(i)];

                wrap_surf_frm_pos_xaxis_pt = [wrap_surf_landmarks.pos_xaxis_pt_x(i), ...
                                              wrap_surf_landmarks.pos_xaxis_pt_y(i), ...
                                              wrap_surf_landmarks.pos_xaxis_pt_z(i)];

                wrap_surf_frm_pos_yaxis_pt = [wrap_surf_landmarks.pos_yaxis_pt_x(i), ...
                                              wrap_surf_landmarks.pos_yaxis_pt_y(i), ...
                                              wrap_surf_landmarks.pos_yaxis_pt_z(i)];
                
                % Extract the type, geometric parameters, and quadrant of the wrapping surface
                type = wrap_surf_landmarks.type{i};
                geom_params = wrap_surf_landmarks.geom_params(i);
                quadrant = wrap_surf_landmarks.quadrant{i};
                
                % Compute the location of the wrapping surface in the local coordinate system of the attached body
                loc_in_body = obj.get_loc_in_body(attached_body, wrap_surf_frm_org_pt);
                
                % Compute the normalized and corrected for perpendicularity vectors for the positive 
                % x, y, and z axes of the wrapping surface frame
                [normd_warp_surf_frm_pos_xaxis_vec, normd_warp_surf_frm_pos_yaxis_vec, normd_warp_surf_frm_pos_zaxis_vec] = ... 
                    obj.get_cs_normd_vecs(wrap_surf_frm_org_pt, wrap_surf_frm_pos_xaxis_pt, wrap_surf_frm_pos_yaxis_pt);
                
                % Compute the orientation of the wrapping surface in the local coordinate system of the attached body
                ori_in_body = obj.get_ori_in_body(attached_body, ...
                    normd_warp_surf_frm_pos_xaxis_vec, normd_warp_surf_frm_pos_yaxis_vec, normd_warp_surf_frm_pos_zaxis_vec);

                % Construct the row to add to the wrapping surface table
                row_to_add = {warp_surf_name, attached_body, ...
                              loc_in_body(1), loc_in_body(2), loc_in_body(3), ...
                              ori_in_body(1), ori_in_body(2), ori_in_body(3), ...
                              type, geom_params, quadrant};

                % Add the row to the wrapping surface table
                wrap_surf_tbl = [wrap_surf_tbl; row_to_add];
            end
            
            % Set the 'wrap_surf_tbl' property of the object to the wrapping surface table
            obj.wrap_surf_tbl = wrap_surf_tbl;
        
        end

        function export_wrap_surf_tbl(obj)
            % This method writes the 'wrap_surf_tbl' property of the object to a CSV file named 'Wrapping_Surfaces.csv'
            % in the 'LocalData' directory under the model root directory. If a file with the same name already exists,
            % it is overwritten.
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_wrap_surf_tbl();

            % Define the directory where the file will be saved
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            
            % Write the 'wrap_surf_tbl' property of the object to a CSV file
            writetable(obj.wrap_surf_tbl, [export_dir, filesep, 'Wrapping_Surfaces.csv'], 'WriteMode', 'overwrite');

        end


        function export_body_mass_props_tbl(obj)
            % This method writes the 'body_mass_props_tbl' property of the object to a CSV file named 
            % 'Body_Mass_Properties.csv' in the 'LocalData' directory under the model root directory.
            % If a file with the same name already exists, it is overwritten.
            %
            % Inputs: None
            %
            % Outputs: None
            %
            % Example usage:
            %   obj.export_body_mass_props_tbl();

            % Define the directory where the file will be saved
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            
            % Write the 'body_mass_props_tbl' property of the object to a CSV file
            writetable(obj.body_mass_props_tbl, [export_dir, filesep, 'Body_Mass_Properties.csv'], 'WriteMode', 'overwrite');
        
        end

        function obj = mirror_mtu_params_tbl(obj)
            % This method reads the MTU parameters from MTU_Parameters.csv and stores the results in the 
            % 'mtu_params_tbl' property of the object. It also writes the 'mtu_params_tbl' property of the 
            % object to a CSV file named 'MTU_Parameters.csv' in the 'LocalData' directory under the model root directory.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'mtu_params_tbl' property.
            %
            % Example usage:
            %   obj.mirror_mtu_params_tbl();

            % Read the MTU parameters from the MTU parameters file and store it in the 'mtu_params_tbl' property
            mtu_params_file = [obj.model_root_dir, '/Data/GlobalData/MTU_Parameters.csv'];
            obj.mtu_params_tbl = readtable(mtu_params_file, 'Delimiter', ',');
            
            % Write the 'mtu_params_tbl' property of the object to a CSV file named 'MTU_Parameters.csv' in 
            % the 'LocalData' directory under the model root directory.
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            writetable(obj.mtu_params_tbl, [export_dir, filesep, 'MTU_Parameters.csv'], 'WriteMode', 'overwrite');
        
        end

        function obj = mirror_joint_rom_tbl(obj)
            % This method reads the joint ROM from Joint_ROM.csv and stores the results in the 
            % 'joint_rom_tbl' property of the object. It also writes the 'joint_rom_tbl' property 
            % of the object to a CSV file named 'Joint_ROM.csv' in the 'LocalData' directory under the model root directory.
            %
            % Inputs: None
            %
            % Outputs:
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'joint_rom_tbl' property.
            %            
            % Example usage:
            %   obj.mirror_joint_rom_tbl();

            % Read the joint ROM from the joint ROM file and store it in the 'joint_rom_tbl' property
            joint_rom_file = [obj.model_root_dir, '/Data/GlobalData/Joint_ROM.csv'];
            joint_rom_imp_opts = detectImportOptions(joint_rom_file);
            joint_rom_imp_opts = setvartype(joint_rom_imp_opts, 'dof', 'string');
            
            numeric_columns = {'min_rx', 'max_rx', 'min_ry', 'max_ry', 'min_rz', 'max_rz', ...
                              'min_tx', 'max_tx', 'min_ty', 'max_ty', 'min_tz', 'max_tz'};

            joint_rom_imp_opts = setvartype(joint_rom_imp_opts, numeric_columns, 'double');
            joint_rom_imp_opts = setvaropts(joint_rom_imp_opts, numeric_columns, 'TreatAsMissing', '');
            joint_rom_imp_opts.Delimiter = ',';

            obj.joint_rom_tbl = readtable(joint_rom_file, joint_rom_imp_opts);
            
            % Write the 'joint_rom_tbl' property of the object to a CSV file named 'Joint_ROM.csv' 
            % in the 'LocalData' directory under the model root directory.
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            writetable(obj.joint_rom_tbl, [export_dir, filesep, 'Joint_ROM.csv'], 'WriteMode', 'overwrite');
        
        end
        
        function obj = mirror_branch_groups_tbl(obj)
            % This method reads the branch groups from Branch_Groups.csv and stores the results 
            % in the 'branch_group_tbl' property of the object. It also writes the 'branch_group_tbl' property
            % of the object to a CSV file named 'Branch_Groups.csv' in the 'LocalData' directory under the model root directory.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'branch_group_tbl' property.
            %
            % Example usage:
            %  obj.mirror_branch_groups_tbl();

            % Read the branch groups from the branch groups file and store it in the 'branch_group_tbl' property
            branch_groups_file = [obj.model_root_dir, '/Data/GlobalData/Branch_Groups.csv'];
            obj.branch_group_tbl = readtable(branch_groups_file, 'Delimiter', ',');
            
            % Write the 'branch_group_tbl' property of the object to a CSV file named 'Branch_Groups.csv' 
            % in the 'LocalData' directory under the model root directory.
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            writetable(obj.branch_group_tbl, [export_dir, filesep, 'Branch_Groups.csv'], 'WriteMode', 'overwrite');
        
        end

        function obj = mirror_mtu_wrap_surf_pair_tbl(obj)
            % This method reads the wrapping surface-MTU pairings from Wrapping_Surface_MTU_Ligament_Pairings.csv 
            % and stores the results in the 'mtu_wrap_surf_pair_tbl' property of the object. It also writes the 
            % 'mtu_wrap_surf_pair_tbl' property of the object to a CSV file named 'Wrapping_Surface_MTU_Ligament_Pairings.csv'
            % in the 'LocalData' directory under the model root directory.
            %
            % Inputs: None
            %
            % Outputs: 
            %   - obj: An instance of the Transformer class (Transformer object) with an
            %     updated 'mtu_wrap_surf_pair_tbl' property.
            %
            % Example usage:
            %   obj.mirror_mtu_wrap_surf_pair_tbl();

            % Read the wrapping surface-MTU pairings from the wrapping surface-MTU pairings file and store it in 
            % the 'mtu_wrap_surf_pair_tbl' property
            mtu_wrap_surf_pair_file = [obj.model_root_dir, '/Data/GlobalData/Wrapping_Surface_MTU_Ligament_Pairings.csv'];
            obj.mtu_wrap_surf_pair_tbl = readtable(mtu_wrap_surf_pair_file, 'Delimiter', ',');

            % Write the 'mtu_wrap_surf_pair_tbl' property of the object to a CSV file named 'Wrapping_Surface_MTU_Ligament_Pairings.csv' 
            % in the 'LocalData' directory under the model root directory.
            export_dir = [obj.model_root_dir, '/Data/LocalData'];
            writetable(obj.mtu_wrap_surf_pair_tbl, [export_dir, filesep, 'Wrapping_Surface_MTU_Ligament_Pairings.csv'], 'WriteMode', 'overwrite');
            
        end

    end

end
