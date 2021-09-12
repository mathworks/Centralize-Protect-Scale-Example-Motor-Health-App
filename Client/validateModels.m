function validateModels(dataFile,motorID,ax)
%validateModels Apply analytics to data from a single motor and visualize
%the results.
%
%    validateModels(dataFile, motorID, ax) sends the data in dataFile to
%    the remaining useful life and anomaly detection machine learning
%    analytics and graphs the results on axis ax.
%
% dataFile: Filesystem path to a MATLAB MAT-file containing a MATLAB 
%           timetable of motor sensor data.
% motorID : Unique numeric identifier of the motor that generated the data.
% ax      : MATLAB Axis object in which to graph results.
% 

    % Load the motor data and clean it up -- add a column for the key and
    % remove columns that we are not going to process.
    d = load(dataFile);
    motorData = d.dAll;
    motorData.Key = repmat(motorID,height(motorData),1);
    timestamp = motorData.motor_ts;
    motorData = removevars(motorData,{'motor_ts','SequenceNumber'});
    
    % Since we cannot send a timetable object across the write to MATLAB
    % Production Server, we need to convert the timetable into a structure.
    % The analytics function processMotorData will turn the structure back
    % into a timetable.
    %
    % Extract the names of the variables from the timetable
    data.variables = motorData.Properties.VariableNames;
    
    % Motor sensors sampled with millisecond precision in Posix integer
    % format. Convert to MATLAB datetime with default UTC timezone.
    ts = datetime(timestamp/1000, 'ConvertFrom', 'posixtime');
    
    % Prepare the axis for graphing the results. Set the max. number of RUL
    % hours as the Y-limit and use dateticks on the X-axis because this is
    % time series data.
    ylim(ax,[0, 4500]);
    xlim(ax,'manual');
    xlim(ax,[ts(1), ts(end)]);
    xt = linspace(datenum(ts(1)), datenum(ts(end)), 8);
    xticks(ax,'manual');
    xticks(ax,datetime(xt,'ConvertFrom','datenum'));
    datetick(ax,'x','HH mm/dd','keepticks');

    axis(ax,'manual');
    hold(ax,'on');
    
    % Divide the motor sensor data into 48 pieces -- we know the data is
    % sampled every minute for 48 hours, so each piece should contain 60
    % samples. Send the data in batches because that's what the machine
    % learning algorithms require.
    h = height(motorData);
    batchSize = 48;
    lgn = [];
    series = [];
    for k=1:(h/batchSize)
        
        % Offsets into the data representing the current batch.
        start = (k-1) * batchSize + 1;
        stop = start + batchSize - 1;
        
        % Extract data and time for the current batch into the structure
        % being sent to MATLAB Production Server.
        data.values = table2array(motorData(start:stop,:));
        data.timestamp = timestamp(start:stop,:);
        
        % Call the analytics function and wait for results.
        [rul, anomaly] = processMotorData(data,k==1);
        
        % processMotorData sent back a structure. Pull out the result data
        % and graph it.

        % Extract hours of remaining useful life from the structure.
        lifeHours = [rul.EstimatedRUL]';
        
        % For efficiency, timestamp sent between client and server in POSIX
        % numeric format. Convert to datetime for graphing.
        ts = datetime([rul.Time]', 'ConvertFrom','posixtime');
        rline = line(ax,ts,lifeHours, ...
            'DisplayName','Remaining Useful Life');
        
        % Use the series variable to encourage Legend to treat all the RUL
        % data as a single line, even though it is returned in segments.
        if isempty(series)
            series = rline;
        end
        % Animate results.
        drawnow;
        
        % If any anomalies occurred during this period, draw them on the
        % RUL line as red dots.
        a = find([anomaly.Anomaly] == 1);
        if ~isempty(a)
            
            aline = plot(ax,ts(a,:), lifeHours(a,:), ...
                'ro', 'MarkerFaceColor','red',...
                'MarkerEdgeColor','red', ...
                'DisplayName','Anomaly');
            
            % And have Legend treat the individual dots as part of the same
            % series.
            if numel(series) == 1
                series = [series aline];
            end
            % Animate
            drawnow;
        end
        
        % If the legend hasn't been rendered yet, or we've updated the
        % series, draw a legend in the lower left corner.
        if isempty(lgn) || numel(lgn.String) ~= numel(series)
            lgn = legend(ax, series, 'AutoUpdate','off', ...
                'Location', 'southwest');
            lgn.Box = 'off';
        end 
    end
end