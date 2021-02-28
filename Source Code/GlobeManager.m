classdef GlobeManager < handle
	
	properties (GetAccess = private, SetAccess = private)
		
		% Objects
		ax;  % Main axes
		fig; % Containing figure
		
		% Settings
		lookAtPos    = [1;0;0];
		lookUpVector = [0;0;1];
		zoomAmount   = 12.0;
		
		% Parameters
		zoomRate   = 1.025;
		zoomBounds = [0.1,30];
		panSpeeds  = [0.5,1.0]; % deg/scroll increment, [up/down,left/right]
		
		% Temporary
		eventState; % struct, see resetEventState()
		isSustained = false;
		remainingSpin_deg = 0; % Used to spin the up vector to correct orientation over time.
		blindlyRejectEvents = false; % Whether we're spinning the up vector currently
		
	end
	properties (SetAccess = public)
		
		% External Callbacks
		callback_MouseDown  function_handle = @(info) [];
		callback_MouseMove  function_handle = @(info) [];
		callback_MouseDrag  function_handle = @(info) [];
		callback_MouseLift  function_handle = @(info) [];
		callback_ZoomChange function_handle = @(zoomAmount) [];
		
		% When true, the custom click/drag callbacks are overridden and the
		% free-pan is enabled
		clickPanEnabled logical = false;
		
		% Whether to enforce matlab's standard camera orientation
		preventCameraTilt logical = true;
		
	end
	
	methods (Access = public)
		
		% Constructor
		function this = GlobeManager(varargin)
			
			% Initialize the event state
			this.resetEventState()
			
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
		
		% Reset event state
		function resetEventState(this)
			this.eventState = struct(...
				'xyz_start',nan(3,1),...
				'xyz_last', nan(3,1),...
				'wasDirect_start',false,...
				'wasDirect_last', false,...
				'mod_start',{cell(1,0)},...
				'mod_last', {cell(1,0)},...
				'wasDrag',  false ...
			);
			this.isSustained = false;
		end
		
		% Returns the current zoomAmount
		function zoomAmount = getZoomAmount(this)
			zoomAmount = this.zoomAmount;
		end
		
	end
	
	methods (Access = private)
		
		% Figure level click callback
		function clickCallback(this,mode)
			
			% If we're spinning the camera to correct the orientation, this
			% will trigger, so we should not run any processing on mouse
			% events right now
			if this.blindlyRejectEvents
				return
			end
			
			% Determine the mode of operation
			isMouseDown = strcmp(mode,'MouseDown');
			isMouseMove = strcmp(mode,'MouseMove');
			isMouseLift = strcmp(mode,'MouseLift');
			
			
			% Events are rejected if it didn't happen somewhere on the
			% globe, except for edge cases.
			
			% Determine where the cursor is on the globe
			[isOnGlobe,globeClickPos] = this.getCurrentGlobePoint();
			% We need some unreasonably complicated conditional behavior to
			% make the preventCameraTilt cases not be wonky.
			if this.preventCameraTilt
				% When these orientation controls are on, it behaves
				% erratically when you let it update 
				if ~isOnGlobe && isMouseDown
					return
				end
				% If we're not on the globe, and we're sustained, and we
				% are either in a Move or Lift mode, we want to keep the
				% camera still, and not distort any externally meaningful
				% state information.
				if ~isOnGlobe && this.isSustained
					% This will prevent the assignments below from
					% corrupting the event state
					if this.clickPanEnabled
						% Setting this to xyz_start will prevent it from
						% panning
						globeClickPos = this.eventState.xyz_start;
					else
						% Keep the state unchanged
						%    globeClickPos = globeClickPos;
					end
				end
			else % Free pan
				% If its a drag or a lift, its fine
				if ~isOnGlobe && isMouseDown
					return
				end
			end
			
			% New events are discarded if there is a sustained event
			% currently active.
			if this.isSustained && isMouseDown
				return
			end
			% Old events are discarded if they have since been discarded
			if ~this.isSustained && isMouseLift
				return
			end
			
			% If we're starting a NEW sustained event, record that
			if isMouseDown
				this.isSustained = true;
			end
			
			
			% Normal custom callback behavior
			
			% Now update the eventState
			if isMouseDown
				
				this.eventState.xyz_start = globeClickPos;
				this.eventState.xyz_last  = globeClickPos;
				this.eventState.wasDirect_start = isOnGlobe;
				this.eventState.wasDirect_last  = isOnGlobe;
				this.eventState.mod_start = this.fig.CurrentModifier;
				this.eventState.mod_last  = this.fig.CurrentModifier;
				% Leave this.eventState.wasDrag alone
				
				% Invoke callback
				if this.clickPanEnabled % Direct pan mode
					this.panHelper(this.eventState.xyz_start,this.eventState.xyz_last,1.0); % 1.0 = pan by the full amount
					this.updateView();
				else % custom callbacks
					this.callback_MouseDown(this.eventState);
				end
				% No Cleanup now
				
			elseif isMouseMove && ~this.isSustained % no clicking
				
				% Since this event is not sustained, populate all its
				% information fresh
				this.eventState.xyz_start = globeClickPos;
				this.eventState.xyz_last  = globeClickPos;
				this.eventState.wasDirect_start = isOnGlobe;
				this.eventState.wasDirect_last  = isOnGlobe;
				this.eventState.mod_start = this.fig.CurrentModifier;
				this.eventState.mod_last  = this.fig.CurrentModifier;
				this.eventState.wasDrag   = false;
				
				% Invoke callback
				if this.clickPanEnabled % Direct pan mode
					this.panHelper(this.eventState.xyz_start,this.eventState.xyz_last,1.0); % 1.0 = pan by the full amount
					this.updateView();
				else % custom callbacks
					this.callback_MouseMove(this.eventState);
				end
				% Perform cleanup
				this.resetEventState();
				
			elseif isMouseMove && this.isSustained % Moving while clicked
				
				% Leave this.eventState.xyz_start alone
				this.eventState.xyz_last  = globeClickPos;
				% Leave this.eventState.wasDirect_start alone
				this.eventState.wasDirect_last = isOnGlobe;
				% Leave this.eventState.mod_start alone
				this.eventState.mod_last  = this.fig.CurrentModifier;
				this.eventState.wasDrag   = true;
				
				% Invoke callback
				if this.clickPanEnabled % Direct pan mode
					this.panHelper(this.eventState.xyz_start,this.eventState.xyz_last,1.0); % 1.0 = pan by the full amount
					this.updateView();
				else % custom callbacks
					this.callback_MouseDrag(this.eventState);
				end
				% No cleanup now
				
			elseif isMouseLift
				
				% Leave this.eventState.xyz_start alone
				this.eventState.xyz_last  = globeClickPos;
				% Leave this.eventState.wasDirect_start alone
				this.eventState.wasDirect_last = isOnGlobe;
				% Leave this.eventState.mod_start alone
				this.eventState.mod_last  = this.fig.CurrentModifier;
				% Leave this.eventState.wasDrag   alone
				
				% Invoke callback
				if this.clickPanEnabled % Direct pan mode
					this.panHelper(this.eventState.xyz_start,this.eventState.xyz_last,1.0); % 1.0 = pan by the full amount
					this.updateView(this.preventCameraTilt); % Conditionally force the viewed orientation to be normal, now that the user is done clicking
				else % custom callbacks
					this.callback_MouseLift(this.eventState);
				end
				
				% Perform cleanup
				this.resetEventState()
				
			end
			
		end
		% Figure level scroll callback
		function scrollCallback(this,event)
			
			% Check for some modifiers
			isPressed_shift   = ismember('shift',  this.fig.CurrentModifier);
			isPressed_control = ismember('control',this.fig.CurrentModifier);
			
			% Use the event data to determine whether we're zooming in or out
			scrollSign = -event.VerticalScrollCount; % -1 or +1
			
			% If control is pressed, zoom.
			if isPressed_control
				
				% Determine where the cursor is on the globe
				[isOnGlobe,globeClickPos] = this.getCurrentGlobePoint();
				
				% Determine a reference point for the zoom. This will be used
				% to do some slight panning when zooming in
				if isOnGlobe
					zoomRefPos = globeClickPos;
				else % Not on globe, use currently viewed center
					zoomRefPos = this.lookAtPos;
				end
				
				zoomSign = -scrollSign;
				
				oldZoomAmount = this.zoomAmount; % store for comparison later
				% Apply the zoom
				this.zoomAmount = this.zoomAmount * this.zoomRate^zoomSign;
				% Enforce constraints
				this.zoomAmount = max(this.zoomBounds(1),min(this.zoomAmount,this.zoomBounds(2)));
				
				% If we did change anything, update the visuals
				if this.zoomAmount ~= oldZoomAmount
					% If we know there's something to apply, and if we're
					% zooming in, add to the visual smoothness by also panning
					% slightly towards wherever the user's cursor is.
					this.panHelper(zoomRefPos,this.lookAtPos,1-this.zoomRate^(2*zoomSign));
					% Update camera settings
					this.updateView();
					% Call the callback for updating zoom
					this.callback_ZoomChange(this.zoomAmount);
				end
				
			else % no control pressed, just pan
				
				% If shift is pressed, pan = rotate about +z (global yaw)
				if isPressed_shift
					angle_deg = this.panSpeeds(2)*scrollSign * this.zoomAmount;
					R = rotz(angle_deg);
				else % not shifted, pan = rotate towards or away from poles (local pitch)
					angle_deg = this.panSpeeds(1)*scrollSign * this.zoomAmount;
					% Limit this rotation if we're going to rotate past a
					% pole
					bounds_deg = [-1,+1] .* acosd([-1,+1]*dot(this.lookAtPos,[0;0;1])); % find distance to each pole from current position
					angle_deg = max(bounds_deg(1),min(angle_deg,bounds_deg(2)));
					R = this.localToGlobalTransform( roty(angle_deg) );
				end
				
				% Apply that transformation matrix
				this.lookAtPos    = R * this.lookAtPos;
				this.lookUpVector = R * this.lookUpVector;
				
				% Update camera settings
				this.updateView()
				
			end
			
		end
		
		% Determine if and where the user's cursor is intersects the
		% nearest side of the globe. If the cursor is not directly above
		% the globe, the nearest globe point is returned in pos instead.
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
				% In the case we're not on the globe, we could modify the
				% problem solved above to one with a different globe
				% radius. Currently, with radius = 1, the fact that no
				% intersections occur is captured by the discriminant being
				% negative: b^2-4*a*c < 0
				% Since c really takes the form |backPoint|^2 - radius^2
				% making the radius large enough would eventually lead to
				% an intersection, because making c lower makes the
				% discriminant higher, eventually becoming positive.
				% Leveraging this, suppose we enlarge the radius to the
				% exact point this happens, and the discriminat is zero.
				% This point leads to a double root, exactly at -b/2a
				% This is the closest the line gets to the origin, and
				% hence the globe.
				gamma = -b/2/a;
				pos = delta .* gamma + backPoint;
				pos = pos / norm(pos);
			end
			
		end
		
		% Helper function which determines the rotation to achieve a pan.
		% Can pan less or more when panPortion is non-unity
		function panHelper(this,pan1,pan2,panPortion)
			
			pan1 = pan1 / norm(pan1);
			pan2 = pan2 / norm(pan2);
			
			% Create a transformation matrix to rotate pan1 to pan2
			if all(abs(pan1-pan2)<sqrt(eps))
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
			
		end
		% Converts (right-handed) transformation matrices (R) from local
		% Forward-Left-Up coordinate systems to the global coordinates.
		% Matrices are intended to left-multiply column vectors.
		function R_ = localToGlobalTransform(this,R)
			% Create a new set of coordinate axes (orthonormal)
			v1 = -this.lookAtPos; % FORWARD
			v2 = this.lookUpVector - v1 * dot(v1,this.lookUpVector); v2 = v2 / norm(v2); % UP
			v3 = -cross(v1,v2); % already normalized, LEFT
			
			% Represent the R matrix in terms of the global coordinates
			%  1. projecting onto the F-L-U (v1-v3-v2) basis
			%  2. applying a simple rotation about v3
			%  3. recasting the point into the original coordinates
			V = [v1,v3,v2]; % F-L-U (odd number order to be right handed)
			R_ = V * R * V';
		end
		
		% To avoid any weird behavior, renormalize the lookAtPos and
		% lookUpVector. forceOrientation is optional: when true, it will
		% ensure the camera is oriented correctly.
		function doFlip = renormalizeCameraSettings(this,forceOrientation)
			
			% Default to no flipping needed
			doFlip = false;
			
			% Normalize the look at position
			this.lookAtPos = this.lookAtPos / norm(this.lookAtPos);
			
			% Keep the look up vector reasonable. Remove any component
			% which is left/right (oriented by +z and forward look vec)
			z = [0;0;1];
			if this.preventCameraTilt
				leftRight = cross(this.lookAtPos,z);
				if norm(leftRight) < sqrt(eps) % effectively a zero vector
					leftRight(:) = 0; % don't subtract anything.
				else
					leftRight = leftRight / norm(leftRight); % normalize
				end
				this.lookUpVector = this.lookUpVector - leftRight*dot(this.lookUpVector,leftRight);
				this.lookUpVector = this.lookUpVector / norm(this.lookUpVector);
			end
			
			% Ensure the up vector and the lookAtPos are independent
			if abs(dot(this.lookAtPos,this.lookUpVector)) > sqrt(eps)
				this.lookUpVector = cross(cross(-this.lookAtPos,z),this.lookAtPos);
				this.lookUpVector = this.lookUpVector / norm(this.lookUpVector);
			end
			
			% Apply the special correction
			if exist('forceOrientation','var') && forceOrientation % exists and is true
				% If the lookUpVector and +z are in different directions,
				% flip the up vector.
				doFlip = dot(z,this.lookUpVector) < -sqrt(eps);
			end
			
			% Check some extreme failure cases
			if any(isnan(this.lookAtPos)) || any(isnan(this.lookUpVector)) || ...
			   any(isinf(this.lookAtPos)) || any(isinf(this.lookUpVector)) || ...
			   all(this.lookAtPos==0) || all(this.lookUpVector==0)
				this.lookAtPos    = [1;0;0];
				this.lookUpVector = [0;0;1];
			end
		end
		% Update the orientation of the camera. Arguments, if any, get
		% passed to renormalizeCameraSettings.
		function updateView(this,varargin)
			
			% Prevent some wonky behavior... Determine if we need to flip
			% the up vector
			doFlip = this.renormalizeCameraSettings(varargin{:});
			
			% Apply static stuff
			this.ax.CameraViewAngle = 10;
% Hard coded value...
			this.ax.CameraPosition = this.lookAtPos'*(1+this.zoomAmount);
			this.ax.CameraTarget   = this.lookAtPos';
			
			% Update the up vector settings
			if doFlip % Uncommon behavior
				maxFPS_Hz = 60;
				maxTime_s = 0.7;
				this.remainingSpin_deg = 180;
				this.blindlyRejectEvents = true;
				RepeatedTaskPerformer(1/maxFPS_Hz,maxTime_s,...
					@(elapsedTime_s) this.spinUpVector(elapsedTime_s,maxTime_s),... % repeat callback
					@() this.finishUpVectorSpin()); % cleanup callback
			else % Normal behavior
				this.ax.CameraUpVector = this.lookUpVector';
			end
			
		end
		% Asynchronously spins the lookUpVector 180 degrees over a short
		% period of time Does not change the value of this.lookUpVector,
		% just what the camera shows. This function gets called exactly
		% once after the time runs out
		function spinUpVector(this,elapsedTime_s,maxTime_s)
			elapsedSpinProportion = clamp(elapsedTime_s/maxTime_s,0,1);
			previousSpinProportion = (180-this.remainingSpin_deg) / 180;
			deltaSpin_deg = 180 * (elapsedSpinProportion - previousSpinProportion);
			
			% Rotate about the forward vector
			R = rotx(deltaSpin_deg);
			R_ = this.localToGlobalTransform(R);
			this.lookUpVector = R_ * this.lookUpVector;
			% Directly update the camera
			this.ax.CameraUpVector = this.lookUpVector';
			
			% Bookkeeping to make sure we don't spin too far.
			this.remainingSpin_deg = clamp(this.remainingSpin_deg - deltaSpin_deg,0,180);
			
		end
		% Tidies up everything after the spinning.
		function finishUpVectorSpin(this)
			this.blindlyRejectEvents = false;
		end
	end
	
end