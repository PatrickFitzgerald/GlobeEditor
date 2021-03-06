classdef MapEditor < handle
	
	% * * * * * * * * * * * * * * GENERAL * * * * * * * * * * * * * * * * *
	properties (Access = private)
		lastFullSaveDatenum = nan; % never saved
		lastAutoSaveDatenum = nan; % never saved
		lastModifiedDatenum = nan; % never modified
		
		isInitialized = false;
	end
	methods (Access = public)
		% Constructor
		function this = MapEditor()
			
			% Initialize settings save delay manager
			this.initSettingsSaving();
			% Load settings, if available
			this.loadSettings();
			
			
			% Create the graphics for the editor
			this.createGraphics();
			
			% Prepare the callbacks
			this.globeManager.callback_MouseDown  = @(info)this.toolCallback('mousedown',info);
			this.globeManager.callback_MouseMove  = @(info)this.toolCallback('mousemove',info);
			this.globeManager.callback_MouseDrag  = @(info)this.toolCallback('mousedrag',info);
			this.globeManager.callback_MouseLift  = @(info)this.toolCallback('mouselift',info);
			this.globeManager.callback_ZoomChange = @(zoomAmount)this.updateZoomAmount(zoomAmount);
			% The internal callbacks are populated by keyPressCallback()
			
			% Enable the default tool
			this.tool_enable_pencil();
			
			% Now that we've finished the constructor, mark this object as
			% initialized.
			this.isInitialized = true;
			
		end
	end
	methods (Access = private)
		% Returns install directory
		function installDir = getInstallDir(~)
			[installDir,~,~] = fileparts(mfilename('fullpath'));
		end
		% Returns the path to the user data directory stored next to the
		% install. If the folder doesn't exist yet, it makes it.
		function userDataDir = getUserDataDir(this)
			% Determine the path of the user data
			installDir = this.getInstallDir();
			userDataDir = fullfile(installDir,'..','User Data'); % Not in code directory...
			% Safely make the folder if it doesn't exist, leave it alone if
			% it does.
			[~,~,~] = mkdir(userDataDir);
		end
		% Perform autosave
		function autosave(this)
			% update lastAutoSaveDatenum
			% NOT DONE
		end
		% Cleanup autosave content
		function haltAutosave(this)
			% clean up autosave files
			% NOT DONE
		end
	end
	
	
	% * * * * * * * * * * * SETTINGS MANAGEMENT * * * * * * * * * * * * * *
	properties (Access = private)
		sizes = struct(...
			'toolButtonSize',   45,...
			'toolButtonPadding',10,...
			'pointHighlightRadius',0.0012,...
			'highlightProximityFactor',2,... % in units of radii ^
			'buttonBorderThickness',4 ... % keep it a multiple of 2
		);
		palette = struct(...
			'space',            [1,1,1]*0.1,...
			'uiBackground',     [1,1,1]*0.2,...
			'buttonBackground', [1,1,1]*0.45,...
			'buttonBevelBright',[1,1,1]*0.45*1.3,...
			'buttonBevelDark',  [1,1,1]*0.45/1.3,...
			'highlightColor1',  [1,1,1]*1,...
			'highlightColor2',  [1,1,1]*0 ...
		);
		settings = struct(... % UPDATE set.settings() and loadSettings() TO MATCH
			'figurePosition',[100,100,1200,900],...
			'windowState','normal',...
			'doAutosave',true,...
			'autosavePeriod_s',300,...
			'lockCameraOrientation',true,...
			'numUndoRedoWhenShifted',10 ...
		);
		settingsSaveDelay_s = 1.0; % Wait this long after settings modification to save. Timer resets upon rapidfire changes.
		settingsSaveTimer;
	end
	methods (Access = private)
		% Creates the settingsSaveTimer, which will wait until a specific
		% amount of time has passed since the last settings update to save
		% anything. This means rapidfire settings modifications will only
		% save when they finish (e.g. figure size change)
		function initSettingsSaving(this)
			this.settingsSaveTimer = DelayedTaskPerformer(...
				this.settingsSaveDelay_s,...
				@()this.saveSettings(),...
				false...
			);
		end
		% Returns the path to the settings file. Makes folders as necessary
		function settingsPath = getSettingsPath(this)
			% Get the path to the user data directory. Guarantees folder
			% existence.
			userDataDir = this.getUserDataDir();
			% Specify the settings path relative to that.
			settingsPath = fullfile(userDataDir,'settings.mat');
		end
		% Load settings from file. Load status = 0 means nothing was
		% loaded. 1 means everything was loaded without issue. 0.5 means
		% not all the saved settings could be loaded.
		function loadStatus = loadSettings(this)
			% Get the settings path. Guarantees folder exists, but not
			% necessarily the file exists.
			settingsPath = this.getSettingsPath();
			
			% As a fallback, state that nothing was loaded.
			loadStatus = 0;
			
			% Carefully check the file
			if exist(settingsPath,'file')
				try
					% Try to load the data
					loadedData = load(settingsPath,'settings');
					settingsL = loadedData.settings; % L = loaded
					% Settings must be a struct
					if ~isa(settingsL,'struct')
						error('');
					end
				catch err %#ok<NASGU>
					fprintf(1,'Settings file existed but was invalid.\n');
				end
			else
				return
			end
			
			% If that was successful (i.e. we're still running), copy over
			% the parameters which are valid.
			% Default to everything being loaded correctly
			loadStatus = 1;
			settingsU = this.settings; % U = usable, overwrite current values.
			% These checks aren't going to be exhaustive...
			isScalarBool = @(v) isscalar(v) && (isa(v,'logical') || ismember(v,[0,1]));
			checks = {
				'figurePosition',         @(v) isnumeric(v) && isvector(v) && numel(v)==4 && all(imag(v)==0) && all(v(3:4)>0); % valid position 4-vector
				'windowState',            @(v) ischar(v) && ismember(v,{'normal','maximized'}); % supported charvector
				'doAutosave',             @(v) isScalarBool(v); % scalar bool
				'autosavePeriod_s',       @(v) isnumeric(v) && isscalar(v) && imag(v)==0 && v>0; % positive real scalar
				'lockCameraOrientation',  @(v) isScalarBool(v); % scalar bool
				'numUndoRedoWhenShifted', @(v) isnumeric(v) && isscalar(v) && imag(v)==0 && v>0 && floor(v)==v; % positive real scalar integer
			};
			% Loop over each expected field. All we know right now is that
			% settingsL is a struct.
			fields_ = fields(settingsL);
			for checkInd = 1:size(checks,1)
				expectedField = checks{checkInd,1};
				checkFunc     = checks{checkInd,2};
				% Check for the existence of the field, and then check its
				% value
				if ismember(expectedField,fields_) && checkFunc( settingsL.(expectedField) )
					% Passed check, copy it into settingsU
					settingsU.(expectedField) = settingsL.(expectedField);
				else
					% Failed at least once, mark it as such.
					loadStatus = 0.5;
				end
			end
			
			% Now apply the settings. The set.settings() method handles
			% checking what actually changed.
			this.settings = settingsU;
			
		end
		% Save settings to file
		function saveSettings(this)
			% Get the settings path. Guarantees folder exists.
			settingsPath = this.getSettingsPath();
			
			% Extract off a copy of everything we plan to save
			settings = this.settings; %#ok<NASGU,PROP>
			
			try
				save(settingsPath,'settings');
			catch err
				fprintf(1,'Something went wrong when trying to save the settings.\n');
				rethrow(err);
			end
		end
	end
	methods
		% This effectively catches whenever the settings are modified
		function set.settings(this,settingsNew)
			
			% Make a copy of the old settings, in case we need to compare
			settingsOld = this.settings;
			
			% Determine what changed
			changedFields = {};
			for field = fields(settingsNew)'
				if ~isequal( settingsOld.(field{1}), settingsNew.(field{1}) )
					changedFields(end+1) = field; %#ok<AGROW>
				end
			end
			
			% Assign the settings
			this.settings = settingsNew;
			
			
			% Don't update settings elsewhere if most of the MapEditor has
			% not been instantiated yet. Do this after the values have been
			% assigned.
			if ~this.isInitialized %#ok<MCSUP>
				return;
			end
			
			
			% Perform any necessary updating now. Separate IF checks in
			% case multiple changed.
			if ismember('figurePosition',changedFields)
				% Nothing here, this setting happens after the GUI is
				% updated
			end
			if ismember('windowState',changedFields)
				% Nothing here, this setting happens after the GUI is
				% updated
			end
			if ismember('doAutosave',changedFields)
				if settingsNew.doAutosave % New settings are to autosave
					this.autosave();
				else
					this.haltAutosave();
				end
			end
			if ismember('autosavePeriod_s',changedFields)
				% Just to be lazy, simply run a new autosave, let it handle
				% the details.
				this.autosave();
			end
			if ismember('lockCameraOrientation',changedFields)
				% Update this setting in the globe manager
				this.globeManager.preventCameraTilt = this.settings.lockCameraOrientation; %#ok<MCSUP>
			end
			if ismember('numUndoRedoWhenShifted',changedFields)
				% Nothing needs updating, this is actively checked whenever
				% it's used.
			end
			
			
			% Save these settings to file
			if ~isempty(changedFields)
				% Restart the timer. If it's currently inactive, it starts
				% it. If it's already running, it resets the timer.
				restart(this.settingsSaveTimer); %#ok<MCSUP>
			end
			
		end
	end
	
	
	% * * * * * * * * * * * * TOOL MANEGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
		activeTool   = 'none';
		toolLiveData = struct();
		toolIsLive   = false;
		toolCallback = @(varargin) [];
	end
	methods (Access = private)
		% Enable select tool
		function tool_enable_select(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup_heavy();
			
			% Mark this tool as active
			this.activeTool = 'select';
			
		end
		% Enable pencil tool
		function tool_enable_pencil(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup_heavy();
			
			% Assign the callback manager
			this.toolCallback = @(varargin) this.tool_function_pencil(varargin{:});
			
			% Mark this tool as active
			this.activeTool = 'pencil';
			% Prepare the working data's initial state
			this.tool_cleanup_light(); % call after assigning activeTool
			
		end
		% Enable drag tool
		function tool_enable_drag(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup_heavy();
			
			% Mark this tool as active
			this.activeTool = 'drag';
			
		end
		% Enable stretch tool
		function tool_enable_stretch(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup_heavy();
			
			% Mark this tool as active
			this.activeTool = 'stretch';
			
		end
		% Cleanup current tool
		function tool_cleanup_heavy(this)
			
			% Reset the event state of the GlobeManager to prevent stale
			% events from continuing
			this.globeManager.resetEventState();
			
			% Perform tool-specific cleanup
			switch this.activeTool
				case 'select'
					
				case 'pencil'
					
				case 'drag'
					
				case 'stretch'
					
			end
			
			% Record the new lack of tool
			this.activeTool = 'none';
			% Record that we're not actively in a live tool
			this.toolLiveData = struct();
			this.toolIsLive = false;
			
			% Disconnect the callback manager
			this.toolCallback = @(varargin) [];
			
		end
		% Overwrites existing toolLiveData to match a clean slate,
		% specialized to that currently active tool.
		function tool_cleanup_light(this)
			
			% Mark as not live
			this.toolIsLive = false;
			
			% Apply custom light cleaning/reset for the specific tool
			switch this.activeTool
				case 'select'
					
				case 'pencil'
					this.toolLiveData = struct(...
						'refNodes',nan(0,3),...
						'undoData',nan(0,3),...
						'PathObj',Path(this.globeAx,this.maxAngleStep_rad)...
					);
				case 'drag'
					
				case 'stretch'
					
				case 'none'
					% Nothing to do here.
				otherwise
					error('Invalid tool')
			end
			
			% Revert some temporary plotting items to their default state
			this.highlight1.centerPoints = nan(0,3);
			this.highlight2.centerPoints = nan(0,3);
			
		end
		
		% Pencil tool functionality
		function tool_function_pencil(this,mode,varargin)
			
			% Extract this path object for easier usage
			pathObj = this.toolLiveData.PathObj;
			
			% Whether to show special highlighting in closing-loop
			% situations. Gets updated conditionally below.
			closeTheLoop = false;
			
			% Handle the different modes in groups, since many have common
			% checks
			switch mode
				% INITIAL OPERATIONS, MODIFICATIONS
				case {'mousedown','mousemove','mousedrag','mouselift'}
					
					% varargin{1} stores the 'info' struct from the
					% GlobeManager about where the mouse event happened on the
					% globe.
					info = varargin{1};
					
					% Holding ALT when dragging will place many reference nodes
					doContinuousDraw = false;
					if strcmp(mode,'mousedrag') && ismember('alt',info.mod_last)
						mode = 'mousedown'; % This already has all the behavior we need
						doContinuousDraw = true;
					end
					
					% If the tool is not live, and it wasn't a mousedown,
					% discard the event. Only mouse down events can invoke
					% live status
					if ~this.toolIsLive && ~strcmp(mode,'mousedown')
						% Discard
						return
					end
					
					% Perform some special stuff to perform the
					% complete-loop highlighting
					% Check if the xyz_last and the initial point are close
					% enough. Require at least 3 points in the list before
					% allowing it.
					if size(this.toolLiveData.refNodes,1) > 2 + strcmp(mode,'mousedrag') ...% when dragging, there's kind of one fake point
						&& ~doContinuousDraw % One last requirement: don't do it while in the continuous draw mode
						
						angleDistance_rad = acos(dot(info.xyz_last',this.toolLiveData.refNodes(1,:)));
						zoomAmount = this.globeManager.getZoomAmount();
						pointRadius = this.sizes.pointHighlightRadius*zoomAmount; % As performed in updateZoomAmount()
						% If the new point and the starting point are close
						% enough
						if angleDistance_rad <= pointRadius * this.sizes.highlightProximityFactor
							closeTheLoop = true;
							% Overwrite the xyz_last with the snapped
							% coordinate.
							info.xyz_last = this.toolLiveData.refNodes(1,:)';
						end
					end
					
					switch mode
						case 'mousedown' % Fresh click. Try starting anew, or just appending a new reference node.
							
							% If the user didn't click directly on the globe,
							% discard the click.
							if ~info.wasDirect_last
								return
							end
							
							% If we're still running, then we're adding at least
							% one point. Discard the undo data
							this.toolLiveData.undoData = nan(0,3);
							
							% If we're not currently live, start anew. Record this
							% reference node twice, so we can modify the second
							% entry after (with a drag) without removing the
							% original
							if ~this.toolIsLive
								this.replaceSelection(pathObj); % Mark as selected
								this.toolIsLive = true;
								markup(this.toolLiveData.PathObj); % Enables markup mode
								this.toolLiveData.refNodes(1:2,:) = repmat(info.xyz_last',2,1);
							else % Otherwise, add this point to the reference nodes
								% Make sure we don't record if the user clicks the
								% same point twice in a row. Be safe when the user
								% has undone all the points.
								if size(this.toolLiveData.refNodes,1)==0 || ~isequal(this.toolLiveData.refNodes(end,:),info.xyz_last')
									this.toolLiveData.refNodes(end+1,:) = info.xyz_last;
								end
								% To avoid some funky behavior that manifests with
								% my double-assignment in the other IF section,
								% check for duplicates which should have been
								% removed. Remove them if not. This happens if you
								% click twice without dragging.
								if size(this.toolLiveData.refNodes,1) == 3 && isequal(this.toolLiveData.refNodes(1,:),this.toolLiveData.refNodes(2,:))
									this.toolLiveData.refNodes(1,:) = [];
								end
							end
							
						case 'mousemove'
							
							if size(this.toolLiveData.refNodes,1) > 1
								
							end
							
						case 'mousedrag' % Drag portion of click-and-drag. Just update the last reference node to match
							
							this.toolLiveData.refNodes(end,:) = info.xyz_last;
							
							% If we're still running, then we're adding at least
							% one point. Discard the undo data
							this.toolLiveData.undoData = nan(0,3);
							
						case 'mouselift' % Click release.
							
							% If the path has been closed and the user
							% releases the click, treat it as finalized,
							% and invoke the CONFIRM callback. Don't
							% trigger when there are not enough points.
							% Otherwise we don't need to do anything.
							if size(pathObj.refPoints,1)>2 && pathObj.isClosed
								this.tool_function_pencil('confirm');
							end
							return
							
					end
					
				% INTERMEDIATE OPERATIONS
				case {'redo','undo'}
					
					% Number to undo is stored in varargin{1}
					numNodesToUndo = varargin{1};
					
					% If the tool is not live, we should not have received
					% this callback
					if ~this.toolIsLive
						% Discard event
						return
					end
					
					switch mode
						case 'undo'
							% Make a copy of what we're removing
							this.toolLiveData.undoData = [this.toolLiveData.refNodes(max(1,end-numNodesToUndo+1):end,:);this.toolLiveData.undoData];
							% And remove it from the refNodes
							this.toolLiveData.refNodes(max(1,end-numNodesToUndo+1):end,:) = [];
						case 'redo'
							% Grab content from the undoData
							this.toolLiveData.refNodes = [this.toolLiveData.refNodes;this.toolLiveData.undoData(1:min(numNodesToUndo,end),:)];
							% Now remove that from the undoData, so it's not
							% duplicated
							this.toolLiveData.undoData(1:min(numNodesToUndo,end),:) = [];
					end
					
					% Continue running to update the graphics after the
					% main switch-case.
					
				% FINAL OPERATIONS
				case {'confirm','reject'}
					
					% No extra varargin
					
					% If the tool is not live, we should not have received
					% this callback
					if ~this.toolIsLive
						% Discard event
						return
					end
					
					switch mode
						case 'confirm'
							% Keep pathObj selected
							finish(pathObj); % Disable markup mode.
							% Save the path object
this.layers(end+1,1) = pathObj;
							% Reset the tool: set to not-live, and wipe the storage
							this.tool_cleanup_light();
						case 'reject'
							% Remove previous PathObj
							delete(this.toolLiveData.PathObj);
							% Don't save anything
							% Reset the tool: set to not-live, and wipe the storage
							this.tool_cleanup_light();
					end
					
					% We're done, nothing to manually modify on the plots.
					% Either they were deleted, or they will update
					% automatically.
					return
					
				otherwise
					error('Invalid tool mode ''%s''.',mode);
			end
			
			
			% If we're still running, update the shown plot
			this.toolLiveData.PathObj.refPoints = this.toolLiveData.refNodes; % Automatic redraw, only if necessary
			
			% Manage the highlight points
			switch size(this.toolLiveData.refNodes,1)
				case 0 % No points
					this.highlight1.centerPoints = nan(0,3);
					this.highlight2.centerPoints = nan(0,3);
				case 1 % Exactly one point
					% Only show the first point
					this.highlight1.centerPoints = nan(0,3);
					this.highlight2.centerPoints = this.toolLiveData.refNodes(1,:);
				otherwise % More than one point
					% Show the first and last point
					if closeTheLoop
						this.highlight1.centerPoints = nan(0,3);
						this.highlight2.centerPoints = this.toolLiveData.refNodes([1,end],:);
					else % Normal operation
						this.highlight1.centerPoints = this.toolLiveData.refNodes(1,:);
						this.highlight2.centerPoints = this.toolLiveData.refNodes(end,:);
					end
			end
			
		end
	end
	
	
	% * * * * * * * * * * * GRAPHICS MANAGEMENT * * * * * * * * * * * * * *
	properties (Access = private)
		fig;
		globeManager;
		globeAx;
		
		windowStateCheckDelay_s = 0.1; % should be less than the settings save delay
		windowStateChecker;
		
		topLeftPanel;
		bottomLeftPanel;
		
		toolButtons = struct();
		generalButtons = struct();
		highlight1;
		highlight2;
		
		backgroundSphereRadius = 0.999;
		maxAngleStep_rad; % Will be updated based on backgroundSphereRadius
		
		sphereMeshPatch;
	end
	methods (Access = private)
		% Creates all necessary graphics
		function createGraphics(this)
			
			% Ensure that any plot3 lines drawn on the map have this
			% maximum angular spacing, to ensure they never interpolate
			% underneath the background map components.
			this.maxAngleStep_rad = 2*acos(this.backgroundSphereRadius);
			
			% Make the figure. Make it invisible to start.
			this.fig = figure(...
				'Position',this.settings.figurePosition,...
				'WindowState',this.settings.windowState,...
				'Color',this.palette.space,...
				'DockControls','off',...
				'MenuBar','none',...
				'Name','Map Editor',...
				'NumberTitle','off',...
				'WindowKeyPressFcn',@(o,e)this.keyPressCallback(o,e),...
				'SizeChangedFcn',@(~,~)this.figureResizeFunc(),...
				'Visible','off');
			
			% On that figure, create a set of axes with convenient
			% callbacks and state management.
			this.globeManager = GlobeManager();
			% Apply some settings right away:
			this.globeManager.preventCameraTilt = this.settings.lockCameraOrientation;
			% Get the underlying axes so we can plot to it.
			this.globeAx = this.globeManager.getAxesHandle();
			% These axes are designed for 3D plotting on the unit sphere.
			
			this.globeAx.Units = 'pixels';
			this.globeAx.Position = [1,1,100,100]; % Will be updated in figureResizeFunc()
			
			toolOptions = {...
			%    field name   tooltip                       callback
				'select',    'Select features',             @(~,~)this.tool_enable_select();
				'pencil',    'Draw lines and boundaries',   @(~,~)this.tool_enable_pencil();
				'drag',      'Smoothly drag features',      @(~,~)this.tool_enable_drag();
				'stretch',   'Stretch and shrink features', @(~,~)this.tool_enable_stretch();
			};
			numTools = size(toolOptions,1);
			width  = this.sizes.toolButtonSize;
			height = this.sizes.toolButtonSize;
			vertSpacing = this.sizes.toolButtonPadding;
			horzSpacing = this.sizes.toolButtonPadding;
			startHeight = vertSpacing + flip(0:numTools-1) * (height+vertSpacing);
			borderThickness = this.sizes.buttonBorderThickness;
			buttonBevelBright = this.palette.buttonBevelBright;
			buttonBevelDark   = this.palette.buttonBevelDark;
			
			this.bottomLeftPanel = uipanel(...
				'Parent',this.fig,...
				'BackgroundColor',this.palette.uiBackground,...
				'BorderType','none',...
				'Units','pixels',...
				'Position',[0,0,width+2*horzSpacing,numTools*(height+vertSpacing)+horzSpacing]); % Absolute placement will be updated in figureResizeFunc();
			for toolInd = 1:numTools
				this.toolButtons.(toolOptions{toolInd,1}) = BetterButton(...
					buttonBevelBright,buttonBevelDark,borderThickness,...
					'Style','pushbutton',...
					'String','',...
					'Position',[horzSpacing+1,startHeight(toolInd)+1,width,height],...
					'Tooltip',toolOptions{toolInd,2},...
					'Callback',toolOptions{toolInd,3},...
					'BackgroundColor',this.palette.buttonBackground,...
					'Parent',this.bottomLeftPanel...
				);
			end
			
			buttonOptions = {
			%    field name   tooltip                callback                              coords  image path    
				'confirm', 'Confirm Changes [ENTER]', @(~,~) this.toolCallback('confirm'),  [1,1], 'green_check.png';
				'reject',  'Reject Changes [ESCAPE]', @(~,~) this.toolCallback('reject'),   [1,2], 'red_x.png';
				'undo',    'Undo [CTRL+Z]',           @(~,~) this.undoRedoCallback('undo'), [2,1], 'blue_circle.png';
				'redo',    'Redo [CTRL+Y]',           @(~,~) this.undoRedoCallback('redo'), [2,2], 'orange_circle.png';
			};
			this.topLeftPanel = uipanel(...
				'Parent',this.fig,...
				'BackgroundColor',this.palette.uiBackground,...
				'BorderType','none',...
				'Units','pixels',...
				'Position',[0,0,1,1]*(width*2+horzSpacing*3)); % Absolute placement will be updated in figureResizeFunc();
			for btnInd = 1:size(buttonOptions,1)
				coords = buttonOptions{btnInd,4};
				startHeight = (height+vertSpacing)*coords(1) - height;
				startWidth  = (width +horzSpacing)*coords(2) - width;
				% Create the helper buttons (confirm, reject, undo, redo)
				this.generalButtons.(buttonOptions{btnInd,1}) = BetterButton(...
					buttonBevelBright,buttonBevelDark,borderThickness,...
					'Style','pushbutton',...
					'String','',...
					'Units','pixels',...
					'Position',[startWidth+1,startHeight+1,width,height],...
					'Tooltip',buttonOptions{btnInd,2},...
					'Callback',buttonOptions{btnInd,3},...
					'BackgroundColor',this.palette.buttonBackground,...
					'Parent',this.topLeftPanel...
				);
				this.setupImageButton(...
					this.generalButtons.(buttonOptions{btnInd,1}),...
					buttonOptions{btnInd,5});
			end
			
			this.highlight1 = HighlightPoints(this.globeAx);
			this.highlight2 = HighlightPoints(this.globeAx);
			this.highlight1.color = this.palette.highlightColor1;
			this.highlight2.color = this.palette.highlightColor2;
			this.updateZoomAmount(); % updates highlightX.radius
			
			
			% Create an object which will help catch whether the window
			% state changed after a figure resize. It doesn't seem to be
			% available immediately when the resize callback is invoked.
			this.windowStateChecker = DelayedTaskPerformer(...
				this.windowStateCheckDelay_s,...
				@()this.checkWindowState(),...
				false...
			);
			
[points,faces,~,~] = IrregularSpherePoints(3e4);
this.sphereMeshPatch = patch(...
	'Vertices',points*this.backgroundSphereRadius,...
	'Faces',faces,...
	'FaceColor','w',...
	'EdgeColor','none',...
	'SpecularStrength',0.5);

lightPosition = [5,0,1.5];
lightColor = [255,247,164]/255;
light('Color',lightColor,'Position',lightPosition);
% 
% this.linework = plot3(this.globeAx,nan,nan,nan,'-o');

dataFolder = 'Earth Data';
% dataName = '\110m_cultural\ne_110m_admin_0_countries'; % omit .shp
dataName = '\50m_cultural\ne_50m_admin_0_countries'; % omit .shp
mapData = shaperead(fullfile(dataFolder,[dataName,'.shp']));

for ind = 1:numel(mapData)
	
	lat = mapData(ind).Y;
	lon = mapData(ind).X;
	
	% All lat-lon lists are terminated with a [nan,nan] pair. Separate
	% lists describe different closed domains
	% Loop over each closed domain
	stopStartInds = [0,find(isnan(lat))];
	for domainInd = 1:numel(stopStartInds)-1
		coordInds = stopStartInds(domainInd+0)+1:stopStartInds(domainInd+1)-1;
		lat_ = lat(coordInds);
		lon_ = lon(coordInds);
		
		pos = lla2ecef([lat_',lon_',zeros(numel(lat_),1)]);
		pos = pos ./ sqrt(sum(pos.^2,2));
		
		plot3(this.globeAx,pos(:,1),pos(:,2),pos(:,3),'k');
		
	end
	
end
			%
			
			
			% Forcibly invoke a figure resize event, so the graphics can be
			% laid out correctly
			this.figureResizeFunc();
			
			% Now show the figure
			this.fig.Visible = 'on';
			
			% Add a callback for movement, which won't trigger resizing
			% callback
			figureJavaHandle = findjobj(this.fig,'class','com.mathworks.hg.peer.FigureFrameProxy$FigureFrame'); % This took a lot of trial and error :/
			set(figureJavaHandle,'ComponentMovedCallback',@(~,~) this.figureMovedFunc()); % first one seems to be sufficient
			
		end
		% Sets up the provided uicontrol button with the specified image
		% file. imPath is relative to the GUI Assets folder.
		function setupImageButton(this,uic,imPath)
			[im,~,tr] = imread(fullfile(this.getInstallDir(),'GUI Assets',imPath));
			bgColor = permute(uic.UserData.backgroundColor,[1,3,2]);
			im = double(im)/255;
			tr = double(tr)/255;
			im_ = im .* tr + (1-tr).*bgColor;
			finalSize = uic.Position(3:4);
			uic.CData = clamp(imresize(im_,finalSize-2*uic.UserData.borderThickness),0,1);
		end
		% The callback for keypresses
		function keyPressCallback(this,~,event)
			
			% ENTER = confirm local changes
			% ESCAPE = reject local changes
			% CTRL+Z = undo 1 local action
			% CTRL+Y = redo 1 local action
			% CTRL+SHIFT+Z = undo many local actions
			% CTRL+SHIFT+Y = redo many local actions
			
			if strcmp(event.Key,'return') % CONFIRM
				if this.toolIsLive
					this.toolCallback('confirm');
				end
			elseif strcmp(event.Key,'z') && ismember('control',event.Modifier) % UNDO
				this.undoRedoCallback('undo');
			elseif strcmp(event.Key,'y') && ismember('control',event.Modifier) % REDO
				this.undoRedoCallback('redo');
			elseif strcmp(event.Key,'escape')
				if this.toolIsLive
					this.toolCallback('reject');
				end
			end
			
		end
		% Updates things tied to the zoom level of the GlobeManager.
		% Argument is optional
		function updateZoomAmount(this,zoomAmount)
			
			% Handle the optional input
			if ~exist('zoomAmount','var')
				zoomAmount = this.globeManager.getZoomAmount();
			end
			
			% Update items which depend on the zoom amount.
			this.highlight1.radius = this.sizes.pointHighlightRadius * zoomAmount;
			this.highlight2.radius = this.sizes.pointHighlightRadius * zoomAmount;
			
		end
		% The figure resize callback
		function figureResizeFunc(this)
			
			% Discard this callback if the figure isn't fully created yet
			if isempty(this.fig)
				return
			end
			
			figWidth  = this.fig.Position(3);
			figHeight = this.fig.Position(4);
			
			% Update the figure position/window state. Will save these
			% settings to file. The saving will not happen excessively
			% frequently.
			this.settings.figurePosition = this.fig.Position;
			% Restart the timer. If it's currently inactive, it starts
			% it. If it's already running, it resets the timer.
			restart(this.windowStateChecker)
			
			% Prepare storage for the list of Position-style rectangles to
			% discard globe-managed clicks within
			noClickZones = nan(0,4);
			
			% Relocate the panels
			
			this.topLeftPanel.Position(1:2) = [1,figHeight-this.topLeftPanel.Position(4)+1];
			noClickZones(end+1,:) = this.topLeftPanel.Position;
			
			this.bottomLeftPanel.Position(1:2) = [1,1];
			noClickZones(end+1,:) = this.bottomLeftPanel.Position;
			
			% Reposition the axes
			axesSize = min([figWidth,figHeight]);
			this.globeAx.Position = [floor(1+figWidth/2-axesSize/2),floor(1+figHeight/2-axesSize/2),axesSize,axesSize];
			
			this.globeManager.noClickZones = noClickZones;
			
		end
		function checkWindowState(this)
			% Only bother if its a reasonable window state
			if ismember(this.fig.WindowState,{'normal','maximized'})
				% Let the set.settings functionality handle whether it
				% changed or not.
				this.settings.windowState = this.fig.WindowState;
			end
		end
		function figureMovedFunc(this)
			% Update the figure position. Will save these settings to file.
			% The saving will not happen excessively frequently.
			this.settings.figurePosition = this.fig.Position;
		end
	end
	
	
	% * * * * * * * * * * * * DATA MANAGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
		selection = {};
	end
	methods (Access = private)
		% Callbacks for undo/redo. mode is 'undo' or 'redo'
		function undoRedoCallback(this,mode)
			
			% Determine how to apply the undo call (locally or globally)
			if this.toolIsLive % relinquish action to tool
				% Determine how many items to undo
				if ismember('shift',this.fig.CurrentModifier)
					undoRedoNum = this.settings.numUndoRedoWhenShifted;
				else
					undoRedoNum = 1;
				end
				% Have the tool perform the undoing itself
				this.toolCallback(mode,undoRedoNum);
			else % Global undo
				this.operationManager(mode);
			end
			
		end
		
		% When loading a file from file, set the lastSaveDatenum to now()
		
		function operationManager(this,mode)
			disp(mode);
		end
		
		function replaceSelection(this,shapeObj)
			this.removeSelection();
			this.addToSelection(shapeObj);
		end
		function addToSelection(this,shapeObj)
			this.selection{end+1} = shapeObj;
			select(shapeObj)
		end
		function removeSelection(this)
			for ind = 1:numel(this.selection)
				if isvalid(this.selection{ind})
					deselect(this.selection{ind});
				end
			end
			this.selection = {};
		end
	end
	
	
	% * * * * * * * * * * * * * * TEMPORARY * * * * * * * * * * * * * * * *
	properties (Access = public)
		layers = Shape.empty(0,1);
	end
	methods (Access = public)
		function lookAtRand(this)
			this.globeManager.lookAtPoint(rand(1,3));
			this.globeManager.lookAtPoint(rand(1,3));
		end
	end
	
	% * * * * * * * * * * * * * * * IDEAS * * * * * * * * * * * * * * * * *
	% make land masses
	% paint fill
	% layer management
	% draw lines/borders.
	% randomize borders, coastlines. Don't modify existing ones,
	%	just make new borders. This way they can be updated
	%   use a seed for the randomization, so we can easily reproduce it
	% import raster images
	% text??? maybe just do this in photoshop? maybe try to
	%    support vector graphics here?
	% Custom cursors for each tool
	% button to reset camera view when things get weird.
	% Checkbox for 'lock selection'
	% copy paste??? What sort of functionality does matlab support in
	% interfacing with the clipboard?
	
	% autosave: doAutosave, autosavePeriod_s
	% populate autosave
	% Checkbox for whether to allow globe tilt/roll
	% retain settings between sessions. update set.settings()
	% modify settings.figurePosition and object placement on figure resize
	% option to snap to nearby points. Prevent snapping to invalid points,
	% such as the previous point in a line.
	
	% Make a closing prompt, informing user of unsaved content, etc. 
	% Make sure any settings changes, etc, get saved before closing.
	
	% While in the pencil mode (and likely others) these are the controls
		% CLICK = place point
		% CLICKDRAG = dynamically update the current point
		% CLICKDRAG+ALT = place points as quickly as the graphics update
		% ENTER = confirm local changes
		% ESCAPE = reject local changes
		% CTRL+Z = undo 1 local action
		% CTRL+Y = redo 1 local action
		% CTRL+SHIFT+Z = undo many local actions
		% CTRL+SHIFT+Y = redo many local actions
	
	% export maps renders
		% final destination: flat (no 1/sin() scaling on border widths)   
		% final destination: edit as raster and bring back to globe (apply scaling so returning it looks good)
	% export map vector images??
	
	% Flesh out the operation manager (undo/redo)
	
	% how to efficiently find which facets a border falls into, and
	%    subdivide the facets to color them
	% when lines get stretched out, split them into more segments
	%    maybe also the reverse, if they're straight enough
	% undo/redo functionality
	%    local undo before finalizing an operation
	%    global undo for full completed operations
	%    could either support a rollback, or have like an effects
	%        layer/layer modifier which can have the underlying borders
	%        modified separately.
	% import/save/export
	
	
	% FIX:
	%    GlobeManager.runningAnimTimer isn't working correctly,
	%    specifically GlobeManager.lookAtPoint(). Running several of those
	%    in quick succession does not terminate earlier ones. It's acting
	%    like it's running sequentially, but the external code execution
	%    finishes very quickly.
	
	
end