% Returns a uicontrol with some extra functionality. Removes assignments to
% BackgroundColor, since it breaks stuff. borderThickness will be rounded
% up to the nearest multiple of 2.
function uic = BetterButton(bevelHighlightColor,bevelShadowColor,borderThickness,varargin)
	
	backgroundColor = [1,1,1]*0.94; % matlab default.
	
	isString = cellfun(@(e)isa(e,'char'),varargin);
	strings = repmat({''},size(varargin));
	strings(isString) = cellfun(@(s)lower(s),varargin(isString),'UniformOutput',false);
	matchInds = find(strcmp('backgroundcolor',strings));
	if ~isempty(matchInds)
		% Record those
		backgroundColor = varargin{matchInds(end)+1};
		% Remove the match inds name value pairs
		varargin(matchInds(:)+(0:1)) = [];
	end
	
	% Construct the uicontrol
	uic = uicontrol(varargin{:});
	% Find its corresponding java handle
	uic_j = findjobj(uic);
	
	% Create the border objects
	highlightColor_j  = java.awt.Color(bevelHighlightColor(1),bevelHighlightColor(2),bevelHighlightColor(3));
	shadowColor_j     = java.awt.Color(   bevelShadowColor(1),   bevelShadowColor(2),   bevelShadowColor(3));
	borderThickness   = ceil(borderThickness/2)*2; % Round up, can only do even numbers
	bevelRefNormal_j  = javax.swing.border.BevelBorder( 0, highlightColor_j,highlightColor_j,shadowColor_j,shadowColor_j);
	bevelRefPressed_j = javax.swing.border.BevelBorder( 1, highlightColor_j,highlightColor_j,shadowColor_j,shadowColor_j);
	% Copy these as the first iteration of the loop
	bevelNormal_j     = bevelRefNormal_j;
	bevelPressed_j    = bevelRefPressed_j;
	for extraThickness = 1:borderThickness/2-1
		bevelNormal_j  = javax.swing.border.CompoundBorder(bevelNormal_j, bevelRefNormal_j );
		bevelPressed_j = javax.swing.border.CompoundBorder(bevelPressed_j,bevelRefPressed_j);
	end
	
	uic.UserData = struct(...
		'backgroundColor',backgroundColor,...
		'borderThickness',borderThickness,...
		'forceRefresh',@()refresh(uic),...
		'javaObject',  uic_j,...
		'bevelNormal', bevelNormal_j,...
		'bevelPressed',bevelPressed_j,...
		'borderIsUpdating',false,...
		'isClicked',false,...
		'isPressed',false...
	);
	
	% Assign custom callbacks
	uic_j.MouseEnteredCallback   = @(~,~)mouseCallback('entered',   uic); % Maintains visual state
	uic_j.MouseExitedCallback    = @(~,~)mouseCallback('exited',    uic); % ^
	uic_j.MousePressedCallback   = @(~,~)mouseCallback('mouseDown', uic); % ^
	uic_j.MouseReleasedCallback  = @(~,~)mouseCallback('mouseUp',   uic); % ^
	uic_j.PropertyChangeCallback = @(~,e)propertyChanged(e,uic); % Prevents matlab from ovwrwriting our settings
	% Occasions that the propertyChange callback doesn't catch the ML
	% change before a redraw are rare.
	
	% Forcibly update the graphics once
	uic.UserData.forceRefresh();
	
	function mouseCallback(mode,uic)
		
		% Extract some variables for convenience
		wasPressed = uic.UserData.isPressed; % Solely for the button state
		wasClicked = uic.UserData.isClicked; % Solely for the mouse button state
		
		switch mode
			case 'entered'
				% If we were previously clicked, resume being pressed
				doPress = wasClicked;
				doClick = wasClicked; % Don't change the click status
			case 'exited'
				doPress = false;
				doClick = wasClicked; % Don't change the click status
			case 'mouseDown'
				% No questions, border should be in pressed state
				doPress = true;
				doClick = true;
			case 'mouseUp'
				doPress = false;
				doClick = false;
		end
		
		
		% Only apply a border update if there's a change
		% If we're becoming pressed
		if doPress && ~wasPressed
			uic.UserData.borderIsUpdating = true;
			uic.UserData.javaObject.Border = uic.UserData.bevelPressed;
			uic.UserData.borderIsUpdating = false;
		% If we're becoming not pressed
		elseif ~doPress && wasPressed
			uic.UserData.borderIsUpdating = true;
			uic.UserData.javaObject.Border = uic.UserData.bevelNormal;
			uic.UserData.borderIsUpdating = false;
		end
		
		% Store state
		uic.UserData.isPressed = doPress;
		uic.UserData.isClicked = doClick;
		
	end
	
	function refresh(uic)
		uic.UserData.borderIsUpdating = true;
		if uic.UserData.isPressed
			uic.UserData.javaObject.Border = uic.UserData.bevelPressed;
		else
			uic.UserData.javaObject.Border = uic.UserData.bevelNormal;
		end
		uic.UserData.borderIsUpdating = false;
	end
	
	function propertyChanged(e,uic)
		if ~strcmp( get(e,'propertyName'), 'border')
			return
		end
		if ~uic.UserData.borderIsUpdating
			uic.UserData.forceRefresh();
		end
	end
	
end