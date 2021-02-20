% Reorders the contents of faces to have the correct CCW flow, ASSUMING
% THEY ARE PROPER
function faces = correctEdgeOrder(faces,points)
	
	numFaces = size(faces,1);
	for faceInd = 1:numFaces
		% Det being positive is proper
		if not(det(points(faces(faceInd,:),:)) > 0)
			% flip order of verts
			faces(faceInd,[2,3]) = faces(faceInd,[3,2]);
		end
	end
	
end