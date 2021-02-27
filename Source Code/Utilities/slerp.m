% Creates a dense version of points [Nx3] which form great args
% between consecutive points. There are no trivially repeated
% points. sharedPoints is the list of indices which make up the
% boundaries between each segment. Always includes the reference
% points in the interpolated result.
function [points_,sharedInds] = slerp(points,maxAngleSep_rad)
	% Consecutive dot products to find consecutive angle spacings
	angleSeps_rad = acos(clamp(  sum(points(2:end-0,:) .* points(1:end-1,:),2),  -1,1));
	% Determine the number of steps necessary
	numSteps = max(1, ceil(angleSeps_rad / maxAngleSep_rad)); % ensures at least one step per point
	
	% Now loop over consecutive pairs and interpolate them
	% sufficiently.
	points_ = nan(1+sum(numSteps),3); % +1 for starting point
	points_(1,:) = points(1,:);
	sharedInds = 1+cumsum([0;numSteps]);
	for segmentInd = 1:numel(angleSeps_rad)
		gamma = (1/numSteps(segmentInd) : 1/numSteps(segmentInd) : 1 )'; % Omit 0
		points_(sharedInds(segmentInd)+(1:numSteps(segmentInd)),:) = ...
			(...
			sin((1-gamma)*angleSeps_rad(segmentInd)) .* points(segmentInd+0,:) +...
			sin(   gamma *angleSeps_rad(segmentInd)) .* points(segmentInd+1,:) ...
			) / sin(angleSeps_rad(segmentInd));
	end
end