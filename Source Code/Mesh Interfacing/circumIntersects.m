% Tests if two circumcircles intersect. c1, c2 are circum centers vectors,
% and e1, e2 are corresponding dotRadii.
function intersects = circumIntersects(c1,e1,c2,e2)
	
	% They trivially intersect if one circumcenter falls inside the
	% circumcircle of the other. Test both circumcircles simultaneously by
	% using the min of their dotRadii. (i.e. the max of their two angular
	% radii)
	e3 = dot(c1,c2);
	intersects = e3 >= min([e1,e2]);
	% This will also catch the case where one is entirely inside the other
	
	% If that didn't succeed, we don't know anything
	if ~intersects
		% In general, they intersect if the angles corresponding to their
		% radii (theta1,theta2) sum to greater than the angle between
		% circumcenters (theta3, from e3).
		% Depending on how large the angles are, we can make some
		% simplifications.
		root2over2 = 1/sqrt(2); % cosine of 45
		if e1 > root2over2 && e2 > root2over2 && e3 > 0 % can reliably work in cosine space
			% Convert condition to cosine space, apply cosine identity for
			% sum of angles. represent sin(theta) as sqrt(1-cos(theta)^2)
			intersects = e1*e2 - sqrt(1-e1^2)*sqrt(1-e2^2) <= e3;
		else % Cannot reliably work in cosine space, not monotonic in the whole region. work in angle space
			theta1 = acos(e1);
			theta2 = acos(e2);
			theta3 = acos(e3);
			intersects = theta1 + theta2 >= theta3;
		end
	end
end