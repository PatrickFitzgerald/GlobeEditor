[points,faces,circumCenters,dotRadii] = IrregularSpherePoints(400);

%%

numFaces = size(faces,1);
refScales = [10,50,250,1000,5000,10000,20000];

% The largest scale will just use the actual points
maxScale = find(refScales < numFaces / 2,1,'last') + 1; % +1 to save room for actual points
ref_points        = cell(maxScale,1); 
ref_faces         = cell(maxScale,1);
ref_circumCenters = cell(maxScale,1);
ref_dotRadii      = cell(maxScale,1);
for scale = 1:maxScale-1 % omit the last one
	[ref_points{scale},ref_faces{scale},ref_circumCenters{scale},ref_dotRadii{scale}] = IrregularSpherePoints(refScales(scale));
end
% Fill in the actual points as the final scale.
ref_points{end}        = points;
ref_faces{end}         = faces;
ref_circumCenters{end} = circumCenters;
ref_dotRadii{end}      = dotRadii;

%%

sizes = cellfun(@(ref_faces_) size(ref_faces_,1), ref_faces);

% Test whether the circumcircles intersect
figure;
daspect([1,1,1]);
axis vis3d;

% Keep track of what intersects each member of this scale. Keep results
% resolved by what scale we're testing at
memberIndices = cell(sizes(1),maxScale+1);
for scale = 1:maxScale
	
	% Find where all the higher scales fit into the current scale
	for circInd = 1:sizes(scale)
		pause(5)
		clf
		daspect([1,1,1]);
		axis vis3d;
		c1 = ref_circumCenters{scale}(circInd,:);
		e1 = ref_dotRadii{scale}(circInd);
		for testScale = scale+1:maxScale
			tempTestScaleIntersects = false(sizes(testScale),1);
			for testCircInd = 1:sizes(testScale)
				tempTestScaleIntersects(testCircInd) = circumIntersects(...
					c1,...
					e1,...
					ref_circumCenters{testScale}(testCircInd,:),...
					ref_dotRadii{testScale}(testCircInd));
			end
			memberIndices{circInd,testScale-scale} = find(tempTestScaleIntersects);
			
			patch('faces',ref_faces{testScale}(tempTestScaleIntersects,:),'Vertices',testScale * ref_points{testScale},'FaceColor',rand(1,3),'FaceAlpha',0.3);
			drawnow
			pause(0.5)
		end
	end
	
end
