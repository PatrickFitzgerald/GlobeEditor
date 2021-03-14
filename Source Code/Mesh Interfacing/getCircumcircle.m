% Determines the circumcenter and the dot-radius of the circle
% I'm abusing the spherical geometry to use the dot product as a measure of
% distance. The circle is defined as all points p such that
%    circ dot p >= dotRadius
% circ is the circumcenter, and dotRadius is the 'radius' in this funky
% representation.
% The order of point indices in each row of faces is important.
function [circumCenters,dotRadii] = getCircumcircle(faces,points)
	
	% OLD, LOOP WAY
	
% 	% Preallocate the output storage
% 	numFaces = size(faces,1);
% 	circumCenters = nan(numFaces,3);
% 	dotRadii      = nan(numFaces,1);
% 	
% 	% Loop over each face
% 	for faceInd = 1:numFaces
% 		
% 		% Extract a matrix with rows as each point's coordinates
% 		abc = points(faces(faceInd,:),:);
% 		% Solve for a direction vector which has equal dot product with all
% 		% three points
% 		circumcenter = abc \ [1;1;1]; % column vector right now
% 		circumcenter = circumcenter / sqrt(sum(circumcenter.^2)); % normalize. still a column vector right now
% 		dotRadius = abc(1,:) * circumcenter;
% 		
% 		% Double check it's direction. The sign of det(abc) should match
% 		% that of dotRadius.
% 		changeSign = sign(dotRadius) * sign(det(abc)); % this is non-unity only when they currently differ
% 		circumCenters(faceInd,:) = changeSign * circumcenter';
% 		dotRadii(faceInd)        = changeSign * dotRadius;
% 		
% 	end
	
	% FAST, VECTORIZED WAY
	
	a1 = points(faces(:,1),1);
	a2 = points(faces(:,1),2);
	a3 = points(faces(:,1),3);
	b1 = points(faces(:,2),1);
	b2 = points(faces(:,2),2);
	b3 = points(faces(:,2),3);
	c1 = points(faces(:,3),1);
	c2 = points(faces(:,3),2);
	c3 = points(faces(:,3),3);
	
	% Perform the inverse manually, avoiding the determinant part.
	%    circumcenter = abc \ [1;1;1];
	circumCenters = [...
		a2.*(b3-c3)+b2.*(c3-a3)+c2.*(a3-b3),...
		a3.*(b1-c1)+b3.*(c1-a1)+c3.*(a1-b1),...
		a1.*(b2-c2)+b1.*(c2-a2)+c1.*(a2-b2)...
	];
	% Normalize
	circumCenters = circumCenters ./ sqrt(sum(circumCenters.^2,2));
	
	% Determine the dot radius
	%    dotRadius = abc(1,:) * circumcenter;
	dotRadii = sum( [a1,a2,a3].*circumCenters, 2);
	
	% In the above sign correction, since the inverse Im already doing
	% has a factor of 1/det(abc), and my manual version does not have it,
	% and the application of the sign doesn't matter if it's in the
	% denominator or not, we don't need to worry about it. I'll just scale
	% by sign(dotRadii)
	circumCenters = circumCenters .* sign(dotRadii);
	dotRadii      = abs(dotRadii); % Not sure why abs() makes sense here, but its equivalent...
	
end