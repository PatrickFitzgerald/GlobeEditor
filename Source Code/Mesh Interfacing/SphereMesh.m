classdef SphereMesh < handle
	
	properties (GetAccess = public, SetAccess = private)
		points;
		faces;
	end
	properties (Access = private)
		refLevelSizes = [10,50,250,1000,5000,20000,100000,500000];
		
		maxLevel;
		sizes;
		
		ref_points;
		ref_faces;
		ref_circumCenters;
		ref_dotRadii;
		
		pertinentSubTriangles;
	end
	properties (Access = private, Constant)
		debugSequencing = false;
		debugSearching  = true;
	end
	properties (Access = private) % PLOTTING DEBUG
		fig;
		globe;
		ax;
		patches;
		circles1;
		circles2;
	end
	
	methods (Access = public)
		
		% Constructor
		function this = SphereMesh(points,faces,circumCenters,dotRadii)
			
			% Store the actual points
			this.points = points;
			this.faces  = faces;
			
			% Prepare the reference data
			numPoints = size(points,1);
			% The largest level will just use the actual points
			this.maxLevel = find(this.refLevelSizes < numPoints / 2,1,'last') + 1; % +1 to save room for actual points
			this.ref_points        = cell(this.maxLevel,1);
			this.ref_faces         = cell(this.maxLevel,1);
			this.ref_circumCenters = cell(this.maxLevel,1);
			this.ref_dotRadii      = cell(this.maxLevel,1);
			for level = 1:this.maxLevel-1 % omit the last one
				[this.ref_points{level},this.ref_faces{level},this.ref_circumCenters{level},this.ref_dotRadii{level}] = IrregularSpherePoints(this.refLevelSizes(level));
			end
			% Fill in the actual points as the final level.
			this.ref_points{end}        = points;
			this.ref_faces{end}         = faces;
			this.ref_circumCenters{end} = circumCenters;
			this.ref_dotRadii{end}      = dotRadii;
			
			% Get the number of triangles/circles in each level
			this.sizes = cellfun(@(ref_faces_) size(ref_faces_,1), this.ref_faces);
			
			% Perform a quick check to ensure the sequencing can work
			% Double check what we've done is reliable
minRadius = cellfun(@(e)acos(max(e)),this.ref_dotRadii);
maxRadius = cellfun(@(e)acos(min(e)),this.ref_dotRadii);
if ~all( maxRadius(2:end) < minRadius(1:end-1) ) % max radius of level L+1 must be less than the min radius of level L
	error('Size decrease assumption not met.')
end		
			
			% Now, sequence the membership for faster searching later
			this.sequenceMembership()
			
		end
		
		% Helper function to find the faces which contain specified
		% sphere-points. testPoints should be Nx3
		function [faceInds] = search(this,testPoints)
			
			% Normalize test points, just to be safe
			testPoints = testPoints ./ sqrt(sum(testPoints.^2,2));
			
			numTestPoints = size(testPoints,1);
			faceInds = nan(numTestPoints,1);
			for pointInd = 1: numTestPoints
				
				% Extract off the test point in question
				testPoint = testPoints(pointInd,:);
				
				% For each level of reference points, recursively search
				% over possible circumcircle-intersections, then go to the
				% next level.
				worthChecking = 1; % This will lead to the whole first level being checked. Really represents 0th level.
				for level = 1:this.maxLevel
					% Convert to equivalent in THIS level. Use only the
					% intersection of where we previously determined
					% necessarily contained the point.
					worthChecking = repeatedIntersect( this.pertinentSubTriangles{level},worthChecking );
					if this.debugSearching
						this.debugMeshShow(level,worthChecking,false);
					end
					% Check these circumcircles for intersection
					match = sum(this.ref_circumCenters{level}(worthChecking,:) .* testPoint,2) > this.ref_dotRadii{level}(worthChecking);
					% Downsize the list to just what still holds promise
					worthChecking(~match) = [];
				end
				% Now that's done, worthChecking is the list of indices on
				% true points/faces list, and we have no choice but to
				% explicitly check for intersection in these triangles.
				
				foundFace = false;
				for faceInd = worthChecking(:)'
					% Extract off the triangle's vertices
					abc = this.points(this.faces(faceInd,:),:);
					if det([abc([1,2],:);testPoint]) > 0 && ...
					   det([abc([2,3],:);testPoint]) > 0 && ...
					   det([abc([3,1],:);testPoint]) > 0
						% Intersection, can stop searching.
						foundFace = true;
						break
					end
				end
				% Now, either the faces we were given weren't actually a
				% cover for the sphere, or we have terminated successfully
				if ~foundFace
					error('Failed to find [%g,%g,%g]',testPoint);
				end
				if this.debugSearching
					this.debugMeshShow(level,faceInd,false);
				end
				% Assume valid
				faceInds(pointInd) = faceInd;
			end
			
		end
		
	end
	
	methods (Access = private)
		
		% Determine the relative membership of the circles in each layer of
		% the reference data. This preprocessing will make finding
		% point-to-face intersections fast.
		function sequenceMembership(this)
			
			numberOfAnnouncements = 100;
			
			this.pertinentSubTriangles = cell(this.maxLevel,1);
			this.pertinentSubTriangles{1} = {1:this.sizes(1)}; % The first level will be all circles, since at that point we haven't narrowed anything down yet
			for level = 2:this.maxLevel % Check all the finer levels
				
				fprintf('Processing level %u\n\t',level)
				nextThreshold = 1/numberOfAnnouncements;
				
				matchesByCirc2 = cell(this.sizes(level),1);
				for circInd2 = 1:this.sizes(level) % Loop over the highest level of circles
					
					if circInd2 / this.sizes(level) >= nextThreshold
						fprintf('%%')
						nextThreshold = nextThreshold + 1/numberOfAnnouncements;
					end
					
					% Conditionally show debug plotting
					if this.debugSequencing && level == this.maxLevel
						for level_ = 1:this.maxLevel % Hide all
							this.debugMeshShow(level_,false);
						end
						this.debugMeshShow(level,circInd2); % Show only the circle we're working with
						this.globe.lookAtPoint(this.ref_circumCenters{level}(circInd2,:),0);
					end
					
					c2 = this.ref_circumCenters{level}(circInd2,:);
					e2 = this.ref_dotRadii     {level}(circInd2);
					worthwhileList = (1:this.sizes(1))'; % Start by checking the entire first level
					% Check all more macro levels. Replace worthwhileList with a new
					% one representing what to check in the next level.
					for checkLevel = 1:level-1
						% Of all the items at the checkLevel that were deemed
						% worthwhile to check, check them, and see where we intersect.
						matches = false(numel(worthwhileList),1);
						for checkIndInd = 1:numel(worthwhileList)
							checkInd = worthwhileList(checkIndInd);
							matches(checkIndInd) = circumIntersects(...
								c2,...
								e2,...
								this.ref_circumCenters{checkLevel}(checkInd,:),...
								this.ref_dotRadii     {checkLevel}(checkInd)...
								);
						end
						
						% Conditionally show debug plotting
						if this.debugSequencing && level == this.maxLevel
							for flash = 1:3
								this.debugMeshShow(checkLevel,worthwhileList,false); % as updated
								pause(0.15)
								this.debugMeshShow(checkLevel,worthwhileList(matches),false);
								pause(0.15)
							end
							pause(1);
						end
						
						if checkLevel < level-1 % Not the last level before the one we're actually filling in
							try
								% Overwrite with the next level
								worthwhileList = repeatedUnion(... % Be generous with union instead of intersection
									this.pertinentSubTriangles{checkLevel+1},...
									worthwhileList(matches));
							catch
								fprintf('Empty on level %u circle %u, check level %u\n',level,circInd2,checkLevel);
							end
						else % The last check level, exactly one smaller than the one we're filling in
							% Store these matches so they can be
							% conglomerated later. Prepare them to be
							% easily accumarray'd.
							matchesByCirc2{circInd2} = [repmat(circInd2,sum(matches),1),worthwhileList(matches)];
							% In some cases the above operation is the wrong size when
							% empty
							if size(matchesByCirc2{circInd2},2) ~= 2
								matchesByCirc2{circInd2} = nan(0,2);
							end
						end
					end
				end
				fprintf('\n');
				
				% Now that we've gone through all the finest circles of
				% this level, determine every level-0 circle that is
				% pertinent to each (larger) level-1 circle.
				matchPairs = cat(1,matchesByCirc2{:}); % [level ind, level-1 ind]
				pertinent = accumarray(...
					matchPairs(:,2),... % Make the circInd1 the output set (larger circle)
					matchPairs(:,1),... % And the value is the corresponding circInd2 (smaller circle)
					[this.sizes(level-1),1],...
					@(v){sort(v)},... % Package (+sort) all the terms with common circInd1 into a cell array
					{}... % Fill empties with empty cell. It's bad if this happens, but...
				);
				
				% 	for circInd1 = 1:sizes(level-1)
				% 		temp = false(sizes(level-0),1);
				% 		for circInd2 = 1:sizes(level-0)
				% 			temp(circInd2) = circumIntersects(...
				% 				ref_circumCenters{level-1}(circInd1,:),...
				% 				ref_dotRadii     {level-1}(circInd1),...
				% 				ref_circumCenters{level-0}(circInd2,:),...
				% 				ref_dotRadii     {level-0}(circInd2)...
				% 			);
				% 		end
				% 		pertinent{circInd1} = find(temp);
				% 	end
				
				this.pertinentSubTriangles{level} = pertinent;
				
			end
		end
		
	end
	methods (Access = private) % PLOTTING DEBUG
		
		% Prepares the plots
		function prepVisuals(this)
			this.fig = figure('WindowState','maximized');
			this.globe = GlobeManager();
			this.globe.preventCameraTilt = false;
			this.globe.callback_MouseDown = @(info) this.clickCallback(info);
			% this.globe.callback_MouseMove; % leave disabled
			this.globe.callback_MouseDrag = @(info) this.clickCallback(info);
			this.globe.callback_MouseLift = @(info) this.clickCallback(info);
			this.ax = this.globe.getAxesHandle();
			this.fig.SizeChangedFcn = @(~,~) this.figureSizeChanged();
			
			% Place a white opaque sphere at the r=1 sphere.
			patch(...
				'Vertices',this.ref_points{1},... % Use the first reference content, since it will be the smallest, and the coarsest.
				'Faces',this.ref_faces{1},...     % ^
				'FaceColor','w',...
				'EdgeColor','none');
			
			hue = (1:this.maxLevel)/this.maxLevel;
			
			scales = 1 + 0.05 * (1:this.maxLevel);
			
			% Make the patch objects
			this.patches = gobjects(this.maxLevel,1);
			for level = 1:this.maxLevel
				color = hsv2rgb([hue(level),1,1]);
				this.patches(level) = patch(...
					'Vertices',this.ref_points{level}*scales(level),...
					'Faces',this.ref_faces{level},...
					'FaceVertexCData',color,...
					'FaceColor','flat',...
					'EdgeColor','k',...
					'FaceAlpha',0.1,...
					'UserData',color...
				);
			end
			% Make the circles
			this.circles1 = gobjects(this.maxLevel,1);
			this.circles2 = gobjects(this.maxLevel,1);
			for level = 1:this.maxLevel
				color = hsv2rgb([hue(level),1,1]);
				[circlePoints,pointsPerCircle] = this.prepareCircles(level);
				circlePoints = scales(level) * circlePoints; % Rescale the points
				this.circles1(level) = plotMatrix(...
					circlePoints,...
					'Color',color,...
					'LineWidth',3,... % thicker
					'LineStyle','-',... % solid line
					'UserData',struct('pointsPerCircle',pointsPerCircle,'circlePoints',circlePoints)...
				);
				% Repeat for circles2
				this.circles2(level) = plotMatrix(...
					circlePoints,...
					'Color',color,...
					'LineWidth',2,...
					'LineStyle','--',... % dashed
					'UserData',struct('pointsPerCircle',pointsPerCircle,'circlePoints',circlePoints)...
				);
			end
			
			% Invoke the resize function one
			this.figureSizeChanged()
			
			drawnow;
			
		end
		
		% Generate circles
		function [circlePoints,pointsPerCircle] = prepareCircles(this,level)
			
			maxPathLength = 0.02;
			minPoints = 20;
			
			% Make temporary storage for all the data
			separateCirclePoints = cell(this.sizes(level),1);
			
			for circleInd = 1:this.sizes(level)
				c = this.ref_circumCenters{level}(circleInd,:); % center of circumcircle
				cosTheta = this.ref_dotRadii{level}(circleInd);
				sinTheta = sqrt(1-cosTheta^2);
				circumference = 2*pi*1*sinTheta;
				numSteps = max(ceil(circumference / maxPathLength),minPoints);
				gamma_rad = [linspace(0,2*pi,numSteps)';nan]; % Last one is nan, so the circles can be concatenated and not have lines drawn between them
				% Create a normal vector
				p1 = randn(1,3);
				p1 = p1 - c*dot(c,p1);
				p1 = p1/sqrt(sum(p1.^2)); % normalize it
				% Create another
				p2 = cross(c,p1);
				% Define the circle's points
				separateCirclePoints{circleInd} = cosTheta*c + sinTheta*(p1.*cos(gamma_rad) + p2.*sin(gamma_rad));
			end
			
			% Count the number of points in each circle
			pointsPerCircle = cellfun(@(list_) size(list_,1),separateCirclePoints);
			% Unravel the separate lists into a single list.
			circlePoints = cat(1,separateCirclePoints{:});
			
		end
		
		% Specifies what circles/triangles of a specific level are shown
		% showInverse is optional. If present and true, it will show the
		% circles which were not in the selection less prominently.
		function debugMeshShow(this,level,circlesToShow,showInverse)
			
			% If we haven't been initialized yet, do so.
			if isempty(this.globe) || ~isvalid(this.globe)
				this.prepVisuals();
			end
			
			if ~exist('showInverse','var')
				showInverse = false;
			end
			
			% Make a list which will be nan whenever we want to hide a
			% circle
			hideByNan = nan(this.sizes(level),1);
			% Replace the nans with zeros for those we want to show.
			hideByNan(circlesToShow) = 0;
			originalCirclePoints = this.circles1(level).UserData.circlePoints;
			pointsPerCircle = this.circles1(level).UserData.pointsPerCircle;
			shownCirclePoints = originalCirclePoints + repelem(hideByNan,pointsPerCircle);
			updatePlotMatrix(this.circles1(level),shownCirclePoints);
			
			% Handle the 'hidden' circles
			if showInverse
				% Reverse of above
				invHideByNan = zeros(this.sizes(level),1);
				invHideByNan(circlesToShow) = nan;
				shownCirclePoints = originalCirclePoints + repelem(invHideByNan,pointsPerCircle);
				updatePlotMatrix(this.circles2(level),shownCirclePoints);
			else
				updatePlotMatrix(this.circles2(level),nan(0,3));
			end
			
			% Now update the patch
			this.patches(level).Faces = this.ref_faces{level}(circlesToShow,:);
			
		end
		
		% A simple callback for figure size change
		function figureSizeChanged(this)
			width  = this.fig.Position(3);
			height = this.fig.Position(4);
			this.ax.Position = [1,1,width,height];
		end
		
		% A click callback for the globe manager
		function clickCallback(this,info)
			if ~this.debugSearching
				return
			end
			
			this.search(info.xyz_last(:)');
		end
		
	end
	
end