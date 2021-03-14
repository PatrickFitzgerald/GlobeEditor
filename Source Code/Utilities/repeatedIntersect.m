function intersection = repeatedIntersect(cellOfLists,cellIndices)
	intersection = cellOfLists{cellIndices(1)};
	for listInd = 2:numel(cellIndices)
		intersection = intersect(intersection,cellOfLists{cellIndices(listInd)});
	end
end