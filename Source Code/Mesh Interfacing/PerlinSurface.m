classdef PerlinSurface < SphereMesh
	
	properties 
		interpDefinition;
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
			numTP = this.sizes(end);
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
			interpolant1D = @(X) (1-cos(  pi*(  x - 0.038*sin(2*pi*x)  )  ))/2;
			
			for level = 1:this.maxLevel-1
				
				% Use the previous interpDefinition results as a shortcut
				% for this step. We don't need to check everything, just
				% the pieces which are related (pertinentSubTriangles) to
				% the previous level's result.
				if level == 1
					worthCheckingCell = repmat( this.pertinentSubTriangles(1), numTP,1); % No previous work to leverage
				else
					prevLevelFaces = this.interpDefinition(:,1,level-1); % Use face inds from previous level.
					worthCheckingCell = this.pertinentSubTriangles{level-1}(prevLevelFaces);
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
				
				
				% Save all the results in the interpDefinition matrix.
				this.interpDefinition(:,1,  level) = worthChecking(absoluteMatchInds);
				this.interpDefinition(:,2:4,level) = this.ref_faces{level}( worthChecking(absoluteMatchInds), :);
				this.interpDefinition(:,5:7,level) = weights ./ sum(weights,2); % Force weights sum to unity
				
			end
			
			% Remove the redundant face index info
			this.interpDefinition(:,1,:) = [];
			% Each row is [v1,v2,v3,w1,w2,w3] where v1,v2,v3 are the
			% indices of the enclosing vertices, and w1,w2,w3 are the
			% corresponding interpolant weights for those vertices.
			
		end
		
	end
	
end