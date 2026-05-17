clear; close all;
import org.opensim.modeling.*;

osim_file = '../Models/Sue_Inspired_Models/Sue_Leg_BranchCount_2/Output/Proposed/Sue_Leg2_no_forces.osim';

model = Model(osim_file);
state = model.initSystem();

coordSet = model.getCoordinateSet();

for i = 0:coordSet.getSize()-1
    coord = coordSet.get(i);
    name = char(coord.getName());

    coord.setDefaultSpeedValue(0);
    coord.setDefaultLocked(true);

    fprintf('Locked coordinate: %s\n', name);
end

model.setName('Sue_Leg2_no_forces_all_locked');
model.finalizeConnections();

model.print('../Models/Sue_Inspired_Models/Sue_Leg_BranchCount_2/Output/Proposed/Sue_Leg2_no_forces_all_locked.osim');