function union = repeatedUnion(cellOfLists,cellIndices)
	isColVec = all(cellfun(@(list_) size(list_,2)==1,cellOfLists(cellIndices(1))));
	catDim = 2-isColVec;
	union = unique(cat(catDim,cellOfLists{cellIndices}));
end