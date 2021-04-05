% The faces are Mx3 describing the point indices which compose each
% triangle. The points are NxD, D being the dimension of the space
% containing the mesh. The vals is Nx1, capturing the function values at
% each of the points. The levels is a vector describing which contour
% levels should be traced out, corresponding to the content of vals.
function C = tricontour_core(faces,points,vals,levels)
% This code was influenced by
%    https://www.mathworks.com/matlabcentral/fileexchange/38858-contour-plot-for-scattered-data
%    D.C. Hanselman, University of Maine, Orono, ME 04469
%    MasteringMatlab@yahoo.com
% but I adapted it for arbitrary dimensionality, and the implementation
% diverged rather significantly.
	
	% Check inputs
	if ~isnumeric(points) || ~ismatrix(points) || any(isnan(points(:))) || any(isinf(points(:))) || any(imag(points(:))~=0) || ~isfloat(points)
		error('''points'' must be real floating point numbers (non-nan, non-inf)');
	end
	numPoints = size(points,1);
	numDims   = size(points,2);
	if numDims < 2
		error('The CLabel data storage format is not compatible with fewer than 2 dimensions.');
	end
	if ~isnumeric(faces) || ~ismatrix(faces) || any(isnan(faces(:))) || any(isinf(faces(:))) || any(imag(faces(:))~=0) || ~all(round(faces(:))==faces(:)) || size(faces,2)~=3
		error('''faces'' must be an Mx3 matrix of row-indices of ''points''');
	end
	if max(faces(:)) > numPoints || min(faces(:)) < 1
		error('''faces'' must only contain indices in the range 1 < %u (%u = size(points,1))',numPoints,numPoints);
	end
	numFaces = size(faces,1);
	if ~isnumeric(levels) || ~isvector(levels) || any(isinf(levels(:))) || any(imag(levels(:)~=0)) || ~isfloat(levels)
		error('''levels'' must be a vector of real fininte floating point numbers');
	end
	levels = levels(:);
	levels(isnan(levels)) = []; % Omit nans
	levels = sort(levels);
	
	valsF = vals(faces);
	minVals = min(valsF(:)); % Find min and max of the vals represented in the faces.
	maxVals = max(valsF(:)); % Don't use worry about vals which aren't in a face.
	levels(levels>=maxVals | levels<=minVals) = []; % Eliminate contours outside data limits
	numLevels = numel(levels);
	if numLevels == 0
		error('No levels remain which are consistent for this data');
	end
	% Reorder vals and faces so within each face [p1,p2,p3],
	%     vals(p1) <= vals(p2) <= vals(p3)
	[valsF,order] = sort(valsF,2);
	faces = faces((1:numFaces)' + (order-1)*numFaces); % Reorder faces to match, using linear indices
	% Prepare storage for the output contour/clabel style contour paths
	C = nan(numDims,0);
	% Main Loop -----------------------------------------------------------
	for levelInd = 1:numLevels       % One contour level at a time
		level = levels(levelInd);    % Chosen level
		above = valsF >= level;
		numAbove = sum(above,2);     % Number of triangle vertices above contour, 0, 1, 2, or 3. Only 1 or 2 have an intersection
		tri1 = faces(numAbove==1,:); % Triangles with one vertex above contour
		tri2 = faces(numAbove==2,:); % Triangles with two vertices above contour
		n1 = size(tri1,1);           % Number with one vertex above
		n2 = size(tri2,1);           % Number with two vertices above
		edges = [...
			tri1(:,[1 3]);           % First  column is indices below contour level
			tri1(:,[2 3]);           % Second column is indices above contour level
			tri2(:,[1 2]);           % This leverages the vertex reordering above
			tri2(:,[1 3]);
		];
		% This next variable offers a map from edge index to triangle index
		edgeToTriMap = [1:n1,1:n1,n1+(1:n2),n1+(1:n2)]'; % Indices local to [tri1;tri2]
		% The definition of edges provides a definite ordering of edge
		% vertices. Thus, any repeats are from edges shared between faces.
		% Remove that redundancy, but keep track of it so we can account
		% for which edges are neighboring each other in the traced contour
		% (saying edges are adjacent if they belong to a common face)
		[edges,~,origToUniqMap] = unique(edges,'rows');
		
		% Assign edges to triangle number. These are local indices, namely
		% they index [tri1;tri2] rows.
		triByEdge = accumarray(origToUniqMap,edgeToTriMap,[],@(x){sort(x)}); % Local triangle indices
		numFaceNeighbors = cellfun(@numel,triByEdge);
		
		% Now we need to work out all the EDGE neighbors of each edge.
		% Start by creating all pairs of edges which belong to a common
		% face. There are necessarily 
		edgeByTri = accumarray(cat(1,triByEdge{:}),repelem((1:size(edges,1))',numFaceNeighbors),[],@(x){sort(x)'}); % triangle indices are still local
		% The order of these pairs doesn't matter, so expand these out into
		% an array (non-cell) to capture everything
		edgePairs = cat(1,edgeByTri{:});
		edgePairs = [edgePairs;fliplr(edgePairs)]; %#ok<AGROW> This warning is incorrect due to previous line...
		% Now group these relations so we can index using one edge and see
		% a list of all its edge neighbors
		edgeNeighbors = accumarray(edgePairs(:,1),edgePairs(:,2),[],@(x){sort(x)});
				
		% With each unique edge which transitions from below to above the
		% contour level, find the edge-point which represents that
		% crossover, using interpolation.
		valsE = vals(edges);
		pointsELo = points(edges(:,1),:);
		pointsEHi = points(edges(:,2),:);
		alpha = (level-valsE(:,1))./(valsE(:,2)-valsE(:,1));
		% Since the contour matrix is largely horizontal, transpose this
		% now for convenience
		interpE = transpose(alpha .* (pointsEHi-pointsELo) + pointsELo);
		
		% Now, trace out all the paths at this level.
		while ~all(numFaceNeighbors == 0)
			% Find the earliest edge location with an odd number of
			% neighbors. Either it has 1 neighbor, meaning it's a terminal
			% edge node, or it has 3, 5, 7 etc and will be the terminal
			% edge for a path, while having other paths pass through it.
			node = find(mod(numFaceNeighbors,2)==1,1,'first');
			% If no odd-neighbored edges are present, then there are only
			% closed loops left. We have to pick somewhere to start and
			% stop them...
			if isempty(node)
				node = find(numFaceNeighbors~=0,1,'first'); % Necessarily nonempty because of the while loop condition
			end
			
			% Prepare node/edge index storage, which is at worst as large
			% as the total number of times we need to hit each edge. It
			% will only use all of these if all the points belong to one
			% connected contour path.
			nodeInds = nan(1,sum(numFaceNeighbors));
			nodeInds(1) = node;
			
			sequenceLength = 1;
			prevNode = nan;
			% Perform steps in the sequence. Since edgeByTri contains two
			% edges each, we need to count down each node once for
			% travelling to it, and once for leaving it. This accounting
			% will ensure we trace out all paths sufficiently.
			while numFaceNeighbors(node)>0
				% Decrement the current node by one
				numFaceNeighbors(node) = numFaceNeighbors(node) - 1;
				% Determine the next node. Disallow going backwards, but
				% don't prevent passing through the same node multiple
				% times in a single path. Thus, prevent repeating the
				% previous node.
				nextNode = edgeNeighbors{node};
				nextNode = nextNode( find( numFaceNeighbors(nextNode)~=0 & nextNode~=prevNode, 1,'first') );
				
				% Decrement the next node by one
				numFaceNeighbors(nextNode) = numFaceNeighbors(nextNode) - 1;
				
				sequenceLength = sequenceLength + 1;
				nodeInds(sequenceLength) = nextNode;
				prevNode = node;
				node = nextNode;
			end
			
			% Combine the results onto the final results
			C = [
				C,...
				[[level;sequenceLength;nan(numDims-2,1)],interpE(:,nodeInds(1:sequenceLength))] % Arbitrary dimension contour matrix
			]; %#ok<AGROW>
		end
	end
end