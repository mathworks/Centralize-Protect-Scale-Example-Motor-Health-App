classdef OneClassSVM

% Copyright 2021 The MathWorks, Inc.
    
    properties(SetAccess=protected)
        % Properties that must be set by the user
        Lambda % Vector of regularization parameters (inverse of box constraint)
        NumExpansionDimensions % Dimensionality of the high-dimensional space
        KernelScale % Kernel scale for the Gaussian kernel
        LearnRate % Initial learning rate
        
        % Properties that have sensible defaults
        OutlierPvalue % Test level for outlier detection
        BatchSize
        Stream % RNG stream
        WarmUpPeriod
        
        
        % Properties that are obtained from the first data batch
        NumVariables % Dimensionality of data
        FeatureMapper % Object to map into high-dimensional space
        IsXDouble % Is X double or single
        EpsilonX % Accuracy on X
        
        % Properties that are fitted
        Beta
        Bias
        BatchIndex
        ScoreMean
        ScoreVariance
        NumProcessedObservations
        StandarizationMu
        StandarizationSigma
        
        
    end
    
    
    properties(SetAccess=protected,GetAccess=protected)
        Initialized = false; % Object initialized for training
        UseVariables
        OutlierSigma
        NumProcessedGoodObservations
    end
    
    
    properties(Constant)
        NumProcessedObservationsThresholdForScore            = 100
        NumProcessedObservationsThresholdForOutlierDetection = 200
    end
    
    
    methods
        function obj = OneClassSVM(lambda,numexpdim,kernelscale,learnrate,varargin)
            obj.Lambda = lambda;
            obj.NumExpansionDimensions = numexpdim;
            obj.KernelScale = kernelscale;
            obj.LearnRate = learnrate;
            
            obj.UseVariables = true(obj.NumExpansionDimensions,1);
            
            args = {'stream' 'batchsize' 'outlierpvalue'};
            defs = {      []          10            0.01};
            [stream,batchsize,pval] = internal.stats.parseArgs(args,defs,varargin{:});
            if isempty(stream)
                obj.Stream = RandStream.getGlobalStream;
            end
            obj.BatchSize = batchsize;
            obj.OutlierPvalue = pval;
            obj.OutlierSigma = -icdf('norm',pval,0,1);
            obj.StandarizationMu = [];
            obj.StandarizationSigma = [];
        end
        
        
        function obj = increment(obj,X)
        % Pass X with observations in columns
            
            if istable(X) || istimetable(X)
                X = X{:,:};
            end
            
            if isempty(X)
                return
            end
            
            [X,obj.StandarizationMu,obj.StandarizationSigma] = zscore(X);
            obj.StandarizationSigma(obj.StandarizationSigma==0) = 1;
            X = X';
                        
            [D,N] = size(X);
            L = numel(obj.Lambda);
            
            if ~obj.Initialized
                obj = initialize(obj,X);
            else
                if D~=obj.NumVariables
                    error('Number of variables in input data %i does not match expected number %i.',D,obj.NumVariables)
                end
            end

            % Map into high-D space
            Xm = map(obj.FeatureMapper,X',obj.KernelScale)';

            if obj.NumProcessedObservations > obj.NumProcessedObservationsThresholdForScore
                S = scoreMapped(obj,Xm);
                isOutlier = isoutlierScore(obj,S);
                obj = updateScoreStats(obj,S,isOutlier);
            else
                isOutlier = false(N,L);
            end

            % Update the model
            for j=1:L
                good = ~isOutlier(:,j);
                ngood = sum(good);
                
                if ngood==0
                    continue
                end
                
               localBatchIndex = 0; % so there is no learning rate schedule
                
                [obj.Beta(:,j),obj.Bias(j),~,~,~,~,~,~,~,...
                    localBatchIndex,~,~,~,~,~,~,~,~,~,~,~] = ...
                    classreg.learning.linearutils.solve(...
                    obj.Beta(:,j),obj.Bias(j),Xm(:,good),ones(ngood,1),ones(ngood,1)/ngood,...
                    'hinge',true,obj.Lambda(j),obj.LearnRate,1,0,obj.BatchSize,{'sgd'},...
                    0,0,NaN,false,obj.EpsilonX,0,[],[],[],localBatchIndex,NaN,...
                    ngood,1,obj.IsXDouble,false,NaN,obj.UseVariables,0,[],false,NaN,false,0,obj.Stream,0);
            end                        
            
            obj.NumProcessedObservations = obj.NumProcessedObservations + N;
            obj.BatchIndex = obj.BatchIndex + 1;
        end
        
        
        function A = isAnomaly(obj,X)
            A = score(obj,X)<=0.2;
        end
        
        function S = score(obj,X)
        % Pass X with observations in columns
            
            if any(obj.BatchIndex <= 1) || isempty(obj.BatchIndex)
                S = NaN(size(X,1),1);
                return
            end
            if istable(X) || istimetable(X)
                X = X{:,:};
            end
        
            [X,obj.StandarizationMu,obj.StandarizationSigma] = zscore(X);
            obj.StandarizationSigma(obj.StandarizationSigma==0) = 1;
            X = X';
            
            D = size(X,1);
            if D~=obj.NumVariables
                error('Number of variables in input data %i does not match expected number %i.',D,obj.NumVariables)
            end
            
            Xm = map(obj.FeatureMapper,X',obj.KernelScale);
            S = Xm*obj.Beta + obj.Bias;
        end
        
        
        function isOutlier = isoutlier(obj,X)
        % Pass X with observations in columns

            S = score(obj,X);
            isOutlier = isoutlierScore(obj,S);
        end
    end
    
    
    
    methods(Access=protected)
        function obj = initialize(obj,X)            
            D = size(X,1);
            
            obj.NumVariables = D;
            obj.FeatureMapper = ClassificationKernel.resolveEmptyFeatureMapper([],D,obj.NumExpansionDimensions,'kitchensinks',obj.Stream);

            clsname = class(X);
            obj.IsXDouble = isa(X,'double');
            obj.EpsilonX = 100*eps(clsname);
            
            L = numel(obj.Lambda);
            
            obj.Beta = zeros(obj.NumExpansionDimensions,L,clsname);
            obj.Bias = zeros(1,L,clsname);
            
            obj.BatchIndex                   = zeros(1,L);
            obj.NumProcessedGoodObservations = zeros(1,L);
            
            obj.NumProcessedObservations = 0;
            
            obj.ScoreMean     = zeros(1,L,clsname);
            obj.ScoreVariance = zeros(1,L,clsname);
            
            obj.Initialized = true;            
        end
        
        function obj = updateScoreStats(obj,S,isOutlier)
        % Chan's algorithm
            
            L = numel(obj.Lambda);
        
            chunkWeight = sum(~isOutlier,1);
            
            chunkScoreMean = zeros(1,L,'like',S);
            for j=1:L
                chunkScoreMean(j) = mean(S(~isOutlier(:,j),j));
            end
            
            chunkScoreVariance = zeros(1,L,'like',S);
            for j=1:L
                chunkScoreVariance(j) = var(S(~isOutlier(:,j),j),1);
            end
            
            oldWeight = obj.NumProcessedGoodObservations;
            oldScoreMean = obj.ScoreMean;
            oldScoreVariance = obj.ScoreVariance;
            
            delta = chunkScoreMean - oldScoreMean;
            
            newWeight = oldWeight + chunkWeight;
            newScoreMean = oldScoreMean + (chunkWeight./newWeight).*(chunkScoreMean-oldScoreMean);
            newScoreVariance = ( oldWeight.*oldScoreVariance + chunkWeight.*chunkScoreVariance ...
                + delta.*delta./(1./oldWeight + 1./chunkWeight) )./newWeight;
            
            obj.NumProcessedGoodObservations = newWeight;
            obj.ScoreMean                    = newScoreMean;
            obj.ScoreVariance                = newScoreVariance;
        end
        
        function S = scoreMapped(obj,Xm)
            S = (obj.Beta'*Xm)' + obj.Bias;
        end
        
        function isOutlier = isoutlierScore(obj,S)
            if obj.NumProcessedObservations <= obj.NumProcessedObservationsThresholdForOutlierDetection
                isOutlier = false(size(S));
                return
            end
            
            isOutlier = (S < obj.ScoreMean - sqrt(obj.ScoreVariance)*obj.OutlierSigma);
        end
    end
    
end

