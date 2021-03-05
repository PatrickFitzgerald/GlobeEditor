classdef Shape < handle
% A shape object designed for spherical geometry (unit sphere)
	
	properties (GetAccess = public, SetAccess = private)
		isShown    = true;  % Whether the object is shown on the axes or not
		isSelected = false; % Whether the object is highlighted/selected
		isChanging = false; % Whether the object is actively being modified
	end
	properties (Access = public) % With setters associated.
		refPoints (:,3) double = nan(0,3); % Primary data representing the shape
	end
	properties (Access = protected)
		parentAx;
		maxAngleStep_rad;
	end
	
	methods (Access = public)
		
		% Constructor
		function this = Shape(parentAx,maxAngleStep_rad)
			this.parentAx = parentAx;
			this.maxAngleStep_rad = maxAngleStep_rad;
		end
		
		% Select/deselect item
		function select(this)
			this.isSelected = true;
			this.updateVisualsInternal();
		end
		function deselect(this)
			this.isSelected = false;
			this.updateVisualsInternal();
		end
		
		% Show/hide visuals
		function show(this)
			this.isShown = true;
			this.updateVisualsInternal();
		end
		function hide(this)
			this.isShown = false;
			this.updateVisualsInternal();
		end
		
		% Redraw visuals without changing properties
		function redraw(this)
			this.updateVisualsInternal();
		end
		
		% Enter/leave markup mode
		function markup(this)
			this.isChanging = true;
		end
		function finish(this)
			this.isChanging = false;
		end
		
	end
	methods (Access = protected, Abstract)
		% Use isShown state to determine what to show
		updateVisualsInternal(this);
		% Is called whenever refPointsChanged is updated
		refPointsChanged(this);
	end
	methods % Setters
		function set.refPoints(this,val)
			if ~this.isChanging %#ok<MCSUP>
				warning('This shape is not marked for modification');
				return
			end
			oldVal = this.refPoints;
			this.refPoints = val;
			% Test if anything changed
			if ~isequal(this.refPoints,oldVal)
				this.refPointsChanged();
				this.updateVisualsInternal();
			end
		end
	end
	methods (Access = protected)
		
	end
	
end