classdef GlobeManager < handle
	
	properties (GetAccess = private, SetAccess = private)
		
		% Objects
		ax;  % Main axes
		fig; % Containing figure
		
		% Settings
		lookAtPos    = [1;0;0];
		lookUpVector = [0;0;1];
		isCustomized = false;
		zoomAmount   = 10.0;
		
		% Parameters
		lockUpVector = false;
		zoomRate     = 1.02;
		zoomBounds   = [0.1,30];
		
		% Temporary
		isClicked_pan    = false;
		isClicked_custom = false;
		globePos_pan1    = nan(3,1);
		globePos_pan2    = nan(3,1);
		globePos_custom1 = nan(3,1);
		globePos_custom2 = nan(3,1);
		
	end
	
	methods (Access = public)
		
		% Constructor
		function this = GlobeManager(varargin)
			% Create the axes
			this.ax = axes(varargin{:},...
				'Projection','Perspective',...
				'NextPlot','add',...
				'Visible','off',...
				'DataAspect',[1,1,1],...
				'Clipping','off',...
				'XLim',[-1,1],...
				'YLim',[-1,1],...
				'ZLim',[-1,1],...
				'CameraPositionMode','manual',...
				'CameraTargetMode','manual',... % up vector managed separately
				'CameraViewAngleMode','manual');
			this.setLockUpVector(this.lockUpVector);
			axis(this.ax,'vis3d');
			
			% Search in the succession of parents until we find the figure
			fig_ = this.ax;
			while ~isa(fig_,'matlab.ui.Figure')
				fig_ = fig_.Parent;
			end
			this.fig = fig_;
			
% ENSURE ROTATE3D, ETC ARE OFF.
			
			% When that terminates, fig will be a figure.
			set(this.fig,...
				'DockControls','off',...
				'MenuBar','none',...
				'ToolBar','none',...
				'WindowButtonDownFcn',  @(~,~) this.clickCallback('MouseDown'),...
				'WindowButtonMotionFcn',@(~,~) this.clickCallback('MouseMove'),...
				'WindowButtonUpFcn',    @(~,~) this.clickCallback('MouseLift'),...
				'WindowScrollWheelFcn', @(~,e) this.scrollCallback(e));
			
			this.updateView();
			
		end
		
		% Returns a handle to the underlying axes. Plot on these
		function ax = getAxesHandle(this)
			ax = this.ax;
		end
		
		
	end
	
	methods (Access = private)
		
		% Figure level callback for anything the user does with their
		% mouse. Clicking, dragging
		function clickCallback(this,mode)
			
			% Determine the mode of operation
			isMouseDown = strcmp(mode,'MouseDown');
			isMouseMove = strcmp(mode,'MouseMove');
			isMouseLift = strcmp(mode,'MouseLift');
			isShifted = ismember('shift',this.fig.CurrentModifier);
			
			% Determine where the cursor is on the globe
			[isOnGlobe,globeClickPos] = this.getCurrentGlobePoint();
			
			% If no click event is active
			if ~this.isClicked_pan && ~this.isClicked_custom
				
				% To start a new action, the event must be MouseDown
				if ~isMouseDown
					return
				end
				
				% To do anything useful, require a valid click location
				if ~isOnGlobe
					return
				end
				
				% If shift is active, enable a PAN mode. If no custom
				% behavior is assigned, treat it as PAN anyways.
				if isShifted || ~this.isCustomized
					this.activate_pan(globeClickPos);
				% Otherwise, enable a CUSTOM mode
				else
					this.activate_custom(globeClickPos);
				end
				
			% If we're explicitly in a pan operation
			elseif this.isClicked_pan && ~this.isClicked_custom
				
				% If the user clicked down twice, something went wrong.
				if isMouseDown
					this.forciblyDeactivate();
					
				% If cursor moved
				elseif isMouseMove && isOnGlobe
					this.update_pan(globeClickPos);
					
				% If click was released
				elseif isMouseLift
					this.deactivate_pan();
					
				end
					
				
			% If we're explicitly in a custom operation
			elseif ~this.isClicked_pan && this.isClicked_custom
				
				% If the user clicked down twice?, something went wrong.
				if isMouseDown
					this.forciblyDeactivate();
					
				% If cursor moved
				elseif isMouseMove && isOnGlobe
					this.update_custom(globeClickPos);
					
				% If click was released
				elseif isMouseLift
					this.deactivate_custom();
					
				end
				
			else % Both are active. Should not be possible
				this.forciblyDeactivate();
			end
			
		end
		function scrollCallback(this,event)
			
			% Determine where the cursor is on the globe
			[isOnGlobe,globeClickPos] = this.getCurrentGlobePoint();
			
			% Determine a reference point for the zoom. This will be used
			% to do some slight panning when zooming in
			if isOnGlobe
				zoomRefPos = globeClickPos;
			else % Not on globe, use currently viewed center
				zoomRefPos = this.lookAtPos;
			end
			
			% Use the event data to determine whether we're zooming in or
			% out
			zoomSign = event.VerticalScrollCount; % -1 or +1
			
			oldZoomAmount = this.zoomAmount; % store for comparison later
			% Apply the zoom
			this.zoomAmount = this.zoomAmount * this.zoomRate^zoomSign;
			% Enforce constraints
			this.zoomAmount = max(this.zoomBounds(1),min(this.zoomAmount,this.zoomBounds(2)));
			
			% See if we changed anything.
			didZoom = this.zoomAmount ~= oldZoomAmount;
			
			% If we did change anything, update the visuals
			if didZoom
				% If we know there's something to apply, and if we're
				% zooming in, add to the visual smoothness by also panning
				% slightly towards wherever the user's cursor is.
				if zoomSign < 0
					this.panHelper(zoomRefPos,this.lookAtPos,this.zoomRate-1);
% I would like to make the pan amount more precise -- to keep the reference
% point under the same pixel on the user's screen -- but this seems fine
% for now.
				end
				% Update camera settings
				this.updateView()
			end
			
		end
		
		% Activates PAN mode
		function activate_pan(this,globePos)
			this.isClicked_pan = true;
			this.globePos_pan1 = globePos;
			this.globePos_pan2 = globePos;
		end
		% Activates CUSTOM mode
		function activate_custom(this,globePos)
			this.isClicked_custom = true;
			this.globePos_custom1 = globePos;
			this.globePos_custom2 = globePos;
		end
		% Update PAN mode
		function update_pan(this,globePos)
			this.globePos_pan2 = globePos;
			
			% Offload the panning to this helper function
			this.panHelper(this.globePos_pan1,this.globePos_pan2,1.0); % 1.0 = pan by the full amount
			
			% Update the camera settings
			this.updateView();
			
		end
		% Update CUSTOM mode
		function update_custom(this,globePos)
			this.globePos_custom2 = globePos;
		end
		% Deactivates PAN mode
		function deactivate_pan(this)
			this.isClicked_pan = false;
			this.globePos_pan1 = nan(3,1);
			this.globePos_pan2 = nan(3,1);
		end
		% Deactivates CUSTOM mode
		function deactivate_custom(this)
			this.isClicked_custom = false;
			this.globePos_custom1 = nan(3,1);
			this.globePos_custom2 = nan(3,1);
		end
		% Forcibly deactivate all modes
		function forciblyDeactivate(this)
			% Reset the current state
			this.deactivate_pan();
			this.deactivate_custom();
			% Throw an error. This will terminate anything running, but
			% with the state fixed, the user should be able to resume.
			warning('The GlobeAxes somehow entered an invalid state.')
		end
		
		% Determine if and where the user's cursor is intersects the
		% nearest side of the globe.
		function [isOnGlobe,pos] = getCurrentGlobePoint(this)
			
			% Extract where the user's cursor is in 3D space.
			xyz = get(this.ax,'CurrentPoint');
			frontPoint = xyz(1,:)';
			backPoint  = xyz(2,:)';
			
			% Suppose we have a line defined as 
			%    p(gamma) = (f-b)*gamma + b
			% where f and b are the front and back vectors.
			% Test for when this line has unit distance from the origin.
			% Let delta be f-b
			delta = frontPoint - backPoint;
			%   1 = sqrt( p dot p )
			%   1 = p dot p
			%   1 = (dg+b) dot (dg+b)
			%   1 = d^2g^2 + 2(d dot b)g + b^2
			%   0 = (d^2)g + (2(d dot b))g + (b^2-1)
			a = norm(delta)^2;
			b = 2 * dot(delta,backPoint);
			c = norm(backPoint)^2 - 1;
			gamma = (  -b + [+1,-1] * sqrt( b^2-4*a*c )  )/(2*a);
			
			% If there was a valid solution, then the user clicked on the
			% globe.
			isOnGlobe = all(imag(gamma) == 0);
			
			if isOnGlobe
				% Evaluate the line at both gammas
				pos = delta .* gamma + backPoint; % [pos1,pos2]
				% Choose the one which is closer to where we're currently
				% looking
				forwardFacing = this.lookAtPos;
				dots = sum(forwardFacing.*pos,1);
				[~,best] = max(dots);
				% Just to be safe, normalize it.
				pos = pos(:,best) / norm(pos(:,best));
			else
				pos = nan(3,1);
			end
			
		end
		
		% Helper function which determines the rotation to achieve a pan.
		% Can pan less or more when panPortion is non-unity
		function panHelper(this,pan1,pan2,panPortion)
			
			% Create a transformation matrix to rotate pan1 to pan2
			if all(pan1 == pan2)
				R = eye(3);
			else % not equal, actual change between them
				% Create a new set of coordinate axes (orthonormal)
				v1 = pan1;
				v2 = pan2 - v1 * dot(v1,pan2); v2 = v2 / norm(v2);
				v3 = cross(v1,v2); % already normalized
				% The rotation takes place exclusively in the v1-v2 plane.
				% The rotation angle about v3 will always be in [0,pi), CCW
				rot_deg = acosd(dot(pan1,pan2)) * panPortion;  % rotz below takes degrees
				
				% Define the rotation matrix to be
				%  1. projecting onto the v1-v2-v3 basis
				%  2. applying a simple rotation about v3
				%  3. recasting the point into the original coordinates
				V = [v1,v2,v3];
				R = V * rotz(rot_deg) * V';
			end
			
			% Apply that transformation matrix, and update the axes to
			% point that way.
			this.lookAtPos    = R' * this.lookAtPos; % transpose to undo this, to bring the points into coincidence
			this.lookUpVector = R' * this.lookUpVector; % transform in unison
			
			% Conditionally force the up vector to the normal behavior
			if this.lockUpVector
				this.lookUpVector = [0;0;1];
			end
			
			% Just to be safe, renormalize these vectors
			this.lookAtPos    = this.lookAtPos    / norm(this.lookAtPos   );
			this.lookUpVector = this.lookUpVector / norm(this.lookUpVector);
			
		end
		
		% Update the orientation of the camera
		function updateView(this)
			this.ax.CameraPosition = this.lookAtPos'*(1+this.zoomAmount);
			this.ax.CameraTarget   = this.lookAtPos';
			if ~this.lockUpVector
				this.ax.CameraUpVector = this.lookUpVector';
			end
			this.ax.CameraViewAngle = 10;
% Hard coded value...
		end
		
		% In an attempt to make the up vector behavior more reasonable, I
		% tried this wrapper. Doesn't seem to have fixed anything.
		function setLockUpVector(this,doLock)
			this.lockUpVector = doLock;
			if doLock
				this.ax.CameraUpVector = [0,0,1];
				this.ax.CameraUpVectorMode = 'auto';
			else
				this.ax.CameraUpVectorMode = 'manual';
			end
		end
		
	end
	
	% get high res screen shot
	% manage undoing/redoing
	
end