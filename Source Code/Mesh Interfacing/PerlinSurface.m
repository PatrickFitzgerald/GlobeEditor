classdef PerlinSurface < SphereMesh
	
	properties 
		interpDefinition;
		
		seed;
		directions;
	end
	
	properties (Access = protected, Constant)
		debugInterpSetup = false;
	end
	
	methods (Access = public)
		
		% Constructor
		function this = PerlinSurface(numPoints)
			
			% Get/generate the final level of points
			[points,faces,circumCenters,dotRadii] = IrregularSpherePoints(numPoints);
			% Call the parent class constructor
			this = this@SphereMesh(points,faces,circumCenters,dotRadii);
			% This will perform the base class setup function
			
			% Let's invoke our specialized setup function
			this.precomputeInterpolation();
			
			
			this.prepVisuals();
			% Turn off all level patches and circles
			for tempLevel = 1:this.maxLevel
				this.debugMeshShow(tempLevel,[],false); % Base class function. Show none at the temp level
			end
			this.seed = 123323;
			rng(this.seed);
			this.directions = cell(this.maxLevel-1,1);
			for level = 1:this.maxLevel-1
				refPoints = this.ref_points{level};
				% Generate random vectors
				this.directions{level} = randn(size(refPoints,1),3);
				% Remove all radial components
				this.directions{level} = this.directions{level} - sum(this.directions{level}.*refPoints,2).*refPoints;
				% Normalize
				this.directions{level} = this.directions{level} ./ sqrt(sum(this.directions{level}.^2,2));
% Will need to normalize based on triangle length scale...
			end
			
			a = gobjects(0);
			
			tp = this.ref_points{end};
			funcVals = zeros(size(tp,1),1);
			scales = 4.^(1:this.maxLevel-1);
			for level = 1:this.maxLevel-1
				for vertexInd = 1:3
				funcVals = funcVals + ...
					scales(level) * ... % correct to desired scale
					sum(   this.directions{level}(  this.interpDefinition(:,vertexInd,level)  ).*tp,   2) .* ... % ramp along direction
					this.interpDefinition(:,3+vertexInd,level); % scale by weight
				end
			end
			
			funcVals = funcVals + randn(size(funcVals));
			funcVals = funcVals + tp(:,3)*100;
			
			a = [a,tricontour(this.ref_faces{end},this.ref_points{end},funcVals,[0,0],'Parent',this.ax)];
			
			
			
		end
		
	end
	
	methods (Access = private)
		
		% Prepare some data storage for the interpolation, to enable real
		% time updating.
		function precomputeInterpolation(this)
			
			% For each level, effectively perform a search() using the
			% lowest level's points as test points. Primarily, we're
			% interested in determining which lower-level face contains the
			% test points. Then we want to determine the interpolation
			% weights at the test point relative to the vertices that
			% enclose it.
			tp = this.ref_points{end};
			numTP = size(tp,1); % this.sizes is specifically for the number of faces, not points.
			% We don't need to record the final level, since the test
			% points are trivially related to themselves.
			this.interpDefinition = nan(numTP,7,this.maxLevel-1); % Will be trimmed later.
			% Each row is [f,v1,v2,v3,w1,w2,w3] where v1,v2,v3 are the
			% indices of the enclosing vertices which compose the face
			% indexed by f, and w1,w2,w3 are the corresponding interpolant
			% weights for those vertices. These weights will sum to 1, all
			% be nonnegative, and be larger when the test point is closer
			% to the corresponding vertex.
			% !!!! The inclusion of the 'f' column is temporary, and will
			% be removed after the next loop.
			
			% This will be used at the end of each loop for the interpolant
			% generation
			interpolant1D = @(x) (1-cos(  pi*(  x - 0.038*sin(2*pi*x)  )  ))/2;
			
			% Debug prep
			if this.debugInterpSetup
				this.prepVisuals(); % Base class function
				customPatch = patch('Parent',this.ax,'Vertices',tp,'Faces',this.ref_faces{end},'FaceColor','interp','EdgeColor','k','FaceVertexCData',ones(numTP,1));
				% Turn off all level patches and circles
				for tempLevel = 1:this.maxLevel
					this.debugMeshShow(tempLevel,[],false); % Base class function. Show none at the temp level
				end
			end
			
			for level = 1:this.maxLevel-1
				
				% Use the previous interpDefinition results as a shortcut
				% for this step. We don't need to check everything, just
				% the pieces which are related (pertinentSubTriangles) to
				% the previous level's result.
				if level == 1
					worthCheckingCell = repmat( this.pertinentSubTriangles{1}, numTP,1); % No previous work to leverage
				else
					prevLevelFaces = this.interpDefinition(:,1,level-1); % Use face inds from previous level.
					worthCheckingCell = this.pertinentSubTriangles{level}(prevLevelFaces);
				end
				% worthCheckingCell is a cell array of size numTP x 1. Each
				% entry is the set of faces at the current level that are
				% worth checking for that respective test point.
				
				% Downselect to the subset of worthChecking which contain
				% the test point in the face's circumcircle.
				worthCheckingCell = arrayfun(...
					@(tpInd) worthCheckingCell{tpInd}(    sum(this.ref_circumCenters{level}(worthCheckingCell{tpInd},:) .* tp(tpInd,:),2) >= this.ref_dotRadii{level}(worthCheckingCell{tpInd})    ),...
					(1:numTP)','UniformOutput',false);
				
				% Now lets calculate the uvw coordinates for all the faces
				% worth checking. To do this efficiently, we'll unwrap the
				% cell arrays into a single list.
				numToCheck = cellfun(@numel,worthCheckingCell);
				worthChecking = cell2mat(worthCheckingCell);
				% Stretch tp accordingly
				tp_ = [repelem(tp(:,1),numToCheck),repelem(tp(:,2),numToCheck),repelem(tp(:,3),numToCheck)]; % repelem only supports vectors in this approach
				p1_ = this.ref_points{level}( this.ref_faces{level}(worthChecking,1) ,:);
				p2_ = this.ref_points{level}( this.ref_faces{level}(worthChecking,2) ,:);
				p3_ = this.ref_points{level}( this.ref_faces{level}(worthChecking,3) ,:);
				uvwAll = [...
					this.getHalfAreaPoints(tp_,p2_,p3_),...
					this.getHalfAreaPoints(p1_,tp_,p3_),...
					this.getHalfAreaPoints(p1_,p2_,tp_)] ./ this.ref_halfAreas{level}(worthChecking);
				isInFace = all(uvwAll >= 0, 2);
				% Now briefly convert back to a cell array to perform a
				% find(...,1,'first') to handle when points are on edges. 
				localMatchInds = cellfun(@(boolList) find(boolList,1,'first'), mat2cell(isInFace,numToCheck), 'UniformOutput',true);
				% If something goes wrong, find will yield no answers, and
				% cellfun will error for me. localMatchInds is a list of
				% what face ind matched, and applies only to the reduced
				% scope of each worthCheckingCell sub-list. Make the
				% indices absolute/global.
				absoluteMatchInds = cumsum([0;numToCheck(1:end-1)]) + localMatchInds;
				
				
				% Next, calculate the interpolation weights
				U = uvwAll(absoluteMatchInds,1);
				V = uvwAll(absoluteMatchInds,2);
				W = uvwAll(absoluteMatchInds,3);
				p1 = p1_(absoluteMatchInds,:);
				p2 = p2_(absoluteMatchInds,:);
				p3 = p3_(absoluteMatchInds,:);
				% For simplicity, I will measure distance in a Euclidean
				% sense, not a spherical/angle sense.
				% These interpolation weights are of my own design. See
				% more about them at https://imgur.com/a/fBBoPwG
				normSqr12 = sum((p2-p1).^2,2);
				normSqr23 = sum((p3-p2).^2,2);
				normSqr31 = sum((p1-p3).^2,2);
				d_1 = sqrt(    sum((tp - p1).^2,2)   .*    (V.^2+W.^2)    ./    (normSqr12.*V.^2 + normSqr31.*W.^2)    );
				d_2 = sqrt(    sum((tp - p2).^2,2)   .*    (W.^2+U.^2)    ./    (normSqr23.*W.^2 + normSqr12.*U.^2)    );
				d_3 = sqrt(    sum((tp - p3).^2,2)   .*    (U.^2+V.^2)    ./    (normSqr31.*U.^2 + normSqr23.*V.^2)    );
				% Note that d23 = U, etc.
				d_1_23 = (1-d_1) .* (U.^2./(U.^2 + V.^2.*W.^2))  +  U .* (V.^2.*W.^2./(U.^2 + V.^2.*W.^2));
				d_2_31 = (1-d_2) .* (V.^2./(V.^2 + W.^2.*U.^2))  +  V .* (W.^2.*U.^2./(V.^2 + W.^2.*U.^2));
				d_3_12 = (1-d_3) .* (W.^2./(W.^2 + U.^2.*V.^2))  +  W .* (U.^2.*V.^2./(W.^2 + U.^2.*V.^2));
				% Now perform the 1D mapping
				weights = [interpolant1D(d_1_23),interpolant1D(d_2_31),interpolant1D(d_3_12)];
				% There are several ways the above calculation can result
				% in nan: For example: d_1 could be nan if both V and W are
				% zero; d_1_23 could be nan if both U was zero and V OR W
				% was zero; similarly for d_2,d_3 and d_2_31,d_3_12.
				% However, fixing it is easy, since in any of these cases,
				% the test point is perfectly coincident with the enclosing
				% vertices, so there's not really any interpolation
				% happening. As such, we may simply use the [U,V,W]
				% coordinates as the true weights (which are not nan).
				problem = any(isnan(weights),2);
				weights(problem,:) = uvwAll(absoluteMatchInds(problem),:);
				
				
				% Save all the results in the interpDefinition matrix.
				this.interpDefinition(:,1,  level) = worthChecking(absoluteMatchInds);
				this.interpDefinition(:,2:4,level) = this.ref_faces{level}( worthChecking(absoluteMatchInds), :);
				this.interpDefinition(:,5:7,level) = weights ./ sum(weights,2); % Force weights sum to unity
				
				
				if this.debugInterpSetup
					% Update the customPatch
					customPatch.FaceVertexCData = weights ./ sum(weights,2);
					drawnow
					pause(5);
				end
				
			end
			
			% Remove the redundant face index info
			this.interpDefinition(:,1,:) = [];
			% Each row is [v1,v2,v3,w1,w2,w3] where v1,v2,v3 are the
			% indices of the enclosing vertices, and w1,w2,w3 are the
			% corresponding interpolant weights for those vertices.
			
		end
		
	end
	
end