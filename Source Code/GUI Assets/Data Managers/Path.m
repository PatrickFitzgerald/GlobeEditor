classdef Path < Shape
% A path designed for spherical geometry (unit sphere)
	
	properties (GetAccess = public, SetAccess = private)
		isClosed = false;
	end
	properties (Access = protected)
		pathPlot;
	end
	
	methods (Access = public)
		
		% Constructor
		function this = Path(varargin)
			this = this@Shape(varargin{:});
			this.pathPlot = plot3(this.parentAx,nan,nan,nan);
		end
		% Destructor
		function delete(this)
			delete(this.pathPlot);
		end
		
	end
	methods (Access = protected)
		% Use isShown state to determine what to show
		function updateVisualsInternal(this)
			
			if this.isShown
				if size(this.refPoints,1) < 2 % Too few to interpolate
					% No line to show
					slerpedData = nan(0,3);
				else % Enough to interpolate
					slerpedData = slerp(this.refPoints,this.maxAngleStep_rad);
				end
			else % not shown
				slerpedData = nan(0,3);
			end
			updatePlotMatrix(this.pathPlot,slerpedData);
			
		end
		% Is called whenever refPointsChanged is updated
		function refPointsChanged(this)
			this.isClosed = size(this.refPoints,1)>1 && all(this.refPoints(1,:) == this.refPoints(end,:));
		end
	end
	
end