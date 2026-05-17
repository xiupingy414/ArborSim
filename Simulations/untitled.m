clear; close all;
import org.opensim.modeling.*;

osim_file = '../Models/Sue_Inspired_Models/Sue_Leg_BranchCount_2/Output/Proposed/Sue_Leg2.osim';

model = Model(osim_file);
state = model.initSystem();

forceSet = model.getForceSet();

for i = 0:forceSet.getSize()-1
    force = forceSet.get(i);
    force_name = char(force.getName());

    if contains(force_name, 'ligament')
        lig = Ligament.safeDownCast(force);

        len = lig.getLength(state);
        rest_len = lig.getRestingLength();

        fprintf('%s:\n', force_name);
        fprintf('  current length = %.6f\n', len);
        fprintf('  resting length = %.6f\n', rest_len);
        fprintf('  length/resting = %.4f\n\n', len/rest_len);
    end
end