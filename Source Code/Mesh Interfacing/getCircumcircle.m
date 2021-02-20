% Determines the circumcenter and the dot-radius of the circle
% I'm abusing the spherical geometry to use the dot product as a measure of
% distance. The circle is defined as all points p such that
%    circ dot p >= dotRadius
% circ is the circumcenter, and dotRadius is the 'radius' in this funky
% representation.
% The order of point indices in each row of faces is important.
function [circumCenters,dotRadii] = getCircumcircle(faces,points)
	
	% Preallocate the output storage
	numFaces = size(faces,1);
	circumCenters = nan(numFaces,3);
	dotRadii      = nan(numFaces,1);
	
	% Loop over each face
	for faceInd = 1:numFaces
		
		% Extract a matrix with rows as each point's coordinates
		abc = points(faces(faceInd,:),:);
		% Solve for a direction vector which has equal dot product with all
		% three points
		circumcenter = abc \ [1;1;1]; % column vector right now
		circumcenter = circumcenter / sqrt(sum(circumcenter.^2)); % normalize. still a column vector right now
		dotRadius = abc(1,:) * circumcenter;
		
		% Double check it's direction. The sign of det(abc) should match
		% that of dotRadius.
		changeSign = sign(dotRadius) * sign(det(abc)); % this is non-unity only when they currently differ
		circumCenters(faceInd,:) = changeSign * circumcenter';
		dotRadii(faceInd)        = changeSign * dotRadius;
		
	end
	
end