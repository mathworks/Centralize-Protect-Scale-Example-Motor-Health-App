function stateData = initMotorRULData()
%initMotorRULData Load the pre-trained RUL model.

% Copyright 2021 The MathWorks, Inc.

    m = load('rulModelForStreaming_initial','mdlLin');
    stateData.rulModel = m.mdlLin;
end
