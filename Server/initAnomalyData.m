function stateData = initAnomalyData()
%initAnomalyData Create the OneClassSVM incremental learning model.

% Copyright 2021 The MathWorks, Inc.

    nu = 0.5; % nu (typical default)
    rho = 0.2263;  % from some previous analysis
    lambda = rho*nu;
    F = 1000; 
    sigma = 5;
    learnRate = 0.5;

    stateData.svm = OneClassSVM(lambda,F,sigma,learnRate,'OutlierPvalue',0.001);
    stateData.rngState = rng(1);
end
