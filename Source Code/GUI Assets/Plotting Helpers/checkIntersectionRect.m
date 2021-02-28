% Determines whether a point is inside the (standard matlab figure
% Position) rectangle.
% rect_LBWH = [distance from Left, distance from Bottom, Width, Height]
% Can check multiple rectangles simultaneously, each specified as a row.
function intersects = checkIntersectionRect(point_LB,rect_LBWH)
	intersects = ...
		rect_LBWH(:,1) <= point_LB(1) & point_LB(1) <= sum(rect_LBWH(:,[1,3]),2) &...
		rect_LBWH(:,2) <= point_LB(2) & point_LB(2) <= sum(rect_LBWH(:,[2,4]),2);
end