function [model, coord_reporter] = add_coordreporter(model, reporter_dt)
    % This function adds a coordinate reporter to the given model.
    %
    % Modified for models that may contain joints with no coordinates.
    % Instead of looping through joints, this version loops through the
    % model's CoordinateSet directly.

    % Import OpenSim libraries
    import org.opensim.modeling.*;
    
    % Create a coordinate reporter
    coord_reporter = TableReporter();
    coord_reporter.set_report_time_interval(reporter_dt);
    
    % Add coordinates to the reporter
    coord_set = model.getCoordinateSet();
    coord_num = coord_set.getSize();

    for i = 1 : coord_num
        coord = coord_set.get(i-1);
        coord_name = char(coord.getName());

        coord_reporter.addToReport(coord.getOutput('value'), coord_name);
    end
    
    % Add the reporter to the model
    model.addComponent(coord_reporter);
    
end