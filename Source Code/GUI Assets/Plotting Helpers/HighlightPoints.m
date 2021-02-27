classdef HighlightPoints < handle
	
	properties (Access = public)
		color        (1,3) double = rand(1,3);
		centerPoints (:,3) double = nan(0,3);
		radius       (1,1) double = 0.03;
		lineWidth    (1,1) double = 1;
	end
	
	properties (Access = private)
		plotHandle;
		curveDensity = 25;
	end
	
	methods (Access = public)
		% Constructor
		function this = HighlightPoints(parentAx)
			this.plotHandle = plot3(nan,nan,nan,...
				'Color',this.color,...
				'LineWidth',this.lineWidth,...
				'Parent',parentAx);
		end
	end
	methods % Setters
		function set.color(this,val)
			this.color = val;
			this.plotHandle.Color = this.color; %#ok<MCSUP>
		end
		function set.lineWidth(this,val)
			this.lineWidth = val;
			this.plotHandle.LineWidth = this.lineWidth; %#ok<MCSUP>
		end
		function set.centerPoints(this,val)
			this.centerPoints = val;
			this.updatePlotData();
		end
		function set.radius(this,val)
			this.radius = val;
			this.updatePlotData();
		end
	end
	methods (Access = private)
		% Updates the plot to match any new radius or centers.
		function updatePlotData(this)
			
			% No need to generate these template points more than once.
			persistent templatePoints
			
			% Generate the geometry for a single center point, as if it was
			% placed at the origin, oriented towards +z
			if isempty(templatePoints)
				% Generate all points in {-1,0,1}^3. Discard entries which
				% are just the negative of another in the set. Also discard
				% the zero vector.
				normalCoords = nan(13,3); % (3^2-1)/2
				ind = 1;
				for x = [-1,0,1]
					for y = [-1,0,1]
						for z = [-1,0,1]
							% Test if redundant
							newCoord = [x,y,z];
							if ~any(all(normalCoords == -newCoord,2)) && norm(newCoord)~=0
								normalCoords(ind,:) = newCoord;
								ind = ind + 1;
							end
						end
					end
				end
				numNormals = size(normalCoords,1);
				batchSize = (this.curveDensity+1);
				templatePoints = nan(batchSize*numNormals,3);
				for normalInd = 1:numNormals
					templatePoints((normalInd-1)*batchSize+(1:batchSize),:) = make3DUnitCircle(this,normalCoords(normalInd,:));
				end
				% templatePoints now has many unit circles, perpendicular
				% to the specified normals, separated with a single nan
				% vector.
				
			end
			
			% Adapt the template to fit all the centers we have.
			numCenters = size(this.centerPoints,1);
			
			batchSize = size(templatePoints,1);
			allPoints = nan(numCenters*batchSize,3);
			for centerInd = 1:numCenters
				center = this.centerPoints(centerInd,:);
				% Determine how to rotate the templates to be oriented more
				% towards the center point
				yaw_deg = atan2d(center(2),center(1)); % y,x
				coaltitude_deg = acosd(center(3)/norm(center));
				R = rotz(yaw_deg) * roty(coaltitude_deg); % Rotate down to correct coaltitude, then rotate yaw to correct place.
				% Apply this rotation, scale by the radius, and center on
				% the centerPoint
				allPoints((centerInd-1)*batchSize+(1:batchSize),:) = center + this.radius*templatePoints * R'; % Right multiply by transpose on row vectors = left multiply by original on column vectors
			end
			
			% Assign this data to the plot
			this.plotHandle.XData = allPoints(:,1);
			this.plotHandle.YData = allPoints(:,2);
			this.plotHandle.ZData = allPoints(:,3);
			
		end
		% Makes a set of points which form a unit circle, in the plane
		% perpendicular to the specified normal. The last point is all
		% nans, and the number of rows in points is this.curveDensity+1.
		function points = make3DUnitCircle(this,normal)
			% Perform bookkeeping, determine a basis for the perpendicular
			% plane.
			v1 = normal / norm(normal);
			v2 = randn(1,3); v2 = v2 - v1*dot(v1,v2); v2 = v2 / norm(v2);
			v3 = cross(v1,v2);
			theta_rad = [linspace(0,2*pi,this.curveDensity)';nan];
			% Create the circle in the perpendicular plane (v2-v3) as a
			% sinusoidally weighted linear combination of those orthogonal
			% directions.
			points = v2 .* cos(theta_rad) + v3 .* sin(theta_rad);
		end
	end
	
end