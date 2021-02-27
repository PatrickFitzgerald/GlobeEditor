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
			
			% Manage matlab path
			AddPaths;
			
			% Load settings, if available
			this.loadSettings();
			
			% Create the graphics for the editor
			this.createGraphics();
			
			% Enable the default tool
			this.tool_enable_pan();
			
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
			userDataDir = fullfile(installDir,'User Data');
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
			'toolButtonHeight',  30,...
			'toolButtonWidth',   50,...
			'toolButtonVSpacing',10,...
			'toolButtonHSpacing',10 ...
		);
		palette = struct(...
			'space',[1,1,1]*0.1,...
			'uiBackground',[1,1,1]*0.2 ...
		);
		settings = struct(... % UPDATE set.settings() and loadSettings() TO MATCH
			'figurePosition',[100,100,1200,900],...
			'doAutosave',true,...
			'autosavePeriod_s',300,...
			'lockCameraOrientation',true...
		);
	end
	methods (Access = private)
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
				'figurePosition',        @(v) isnumeric(v) && isvector(v) && numel(v)==4 && all(imag(v)==0) && all(v(3:4)>0);
				'doAutosave',            @(v) isScalarBool(v);
				'autosavePeriod_s',      @(v) isnumeric(v) && isscalar(v) && imag(v)==0 && v>0;
				'lockCameraOrientation', @(v) isScalarBool(v);
			};
			% Loop over each expected field. All we know right now is that
			% settingsL is a struct.
			fields_ = fields(settingsL);
			for checkInd = 1:size(checks,1)
				expectedField = checks{checkInd,1};
				checkFunc     = checks{checkInd,2};
				% Check for the existence of the field, and then check its
				% value
				if ~ismember(expectedField,fields_) && checkFunc( settingsL.(expectedField) )
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
			settingsPath = getSettingsAutosavePath();
			
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
			% not been instantiated yet.
			if ~this.isInitialized %#ok<MCSUP>
				return;
			end
			
			
			% Perform any necessary updating now. Separate IF checks in
			% case multiple changed.
			if ismember('figurePosition',changedFields)
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
			
		end
	end
	
	
	% * * * * * * * * * * * * TOOL MANEGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
		activeTool   = 'none';
		toolLiveData = struct();
		toolIsLive   = false;
		
		tool_callback_confirm   = @() [];
		tool_callback_reject    = @() [];
		tool_callback_localUndo = @() [];
	end
	methods (Access = private)
		% Enable select tool
		function tool_enable_select(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Mark this tool as active
			this.activeTool = 'select';
			
		end
		% Enable pan tool
		function tool_enable_pan(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Enable the pan feature on the GlobeManager
			this.globeManager.clickPanEnabled = true;
			
			% Mark this tool as active
			this.activeTool = 'pan';
			
		end
		% Enable pencil tool
		function tool_enable_pencil(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Assign the pertinent callbacks
			% External
			this.globeManager.callback_MouseDown = @(info)this.tool_function_pencil('fresh',  info);
			this.globeManager.callback_MouseMove = @(info)this.tool_function_pencil('trial',  info);
			this.globeManager.callback_MouseDrag = @(info)this.tool_function_pencil('replace',info);
			this.globeManager.callback_MouseLift = @(info)this.tool_function_pencil('finish', info);
			% Internal
			this.tool_callback_confirm   = @()this.tool_function_pencil('confirm',[]);
			this.tool_callback_reject    = @()this.tool_function_pencil('reject', []);
			this.tool_callback_localUndo = @()this.tool_function_pencil('undo',   []);
			
			% Prepare the working data
			this.toolLiveData = struct(...
				'refNodes',nan(0,3)...
			);
			
			% Mark this tool as active
			this.activeTool = 'pencil';
			
		end
		% Enable drag tool
		function tool_enable_drag(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Mark this tool as active
			this.activeTool = 'drag';
			
		end
		% Enable stretch tool
		function tool_enable_stretch(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Mark this tool as active
			this.activeTool = 'stretch';
			
		end
		% Cleanup current tool
		function tool_cleanup(this)
			
			% Reset the event state of the GlobeManager to prevent stale
			% events from continuing
			this.globeManager.resetEventState();
			
			% Perform tool-specific cleanup
			switch this.activeTool
				case 'select'
					
				case 'pan'
					this.globeManager.clickPanEnabled = false;
				case 'pencil'
					
				case 'drag'
					
				case 'stretch'
					
			end
			
			% Record the new lack of tool
			this.activeTool = 'none';
			% Record that we're not actively in a live tool
			this.toolLiveData = struct();
			this.toolIsLive = false;
			
			% Restore the callbacks
			% External
			this.globeManager.callback_MouseDown = @(~)[];
			this.globeManager.callback_MouseMove = @(~)[];
			this.globeManager.callback_MouseDrag = @(~)[];
			this.globeManager.callback_MouseLift = @(~)[];
			% Internal
			this.tool_callback_confirm   = @()[];
			this.tool_callback_reject    = @()[];
			this.tool_callback_localUndo = @()[];
			
		end
% 		% 
% 		function tool_cleanupLight(this)
% 			
% 		end
		
		% Pencil tool functionality
		function tool_function_pencil(this,mode,info)
			
			% Holding ALT when dragging will place many reference nodes
			if strcmp(mode,'replace') && ismember('alt',info.mod_last)
				mode = 'fresh'; % This already has all the behavior we need
			end
			
			switch mode
				case 'fresh' % Fresh click. Try starting anew, or just appending a new reference node.
					
					% If the user didn't click directly on the globe,
					% discard the click.
					if ~info.wasDirect_last
						return
					end
					
					% If we're not currently live, start anew. Record this
					% reference node twice, so we can modify the second
					% entry after (with a drag) without removing the
					% original
					if ~this.toolIsLive
						this.toolIsLive = true;
						this.toolLiveData.refNodes(1:2,:) = repmat(info.xyz_last',2,1);
					else % Otherwise, add this point to the reference nodes
						this.toolLiveData.refNodes(end+1,:) = info.xyz_last;
					end
					
				case 'trial'
					
return % for now
					
				case 'replace' % Drag portion of click-and-drag. Just update the last reference node to match
					
					this.toolLiveData.refNodes(end,:) = info.xyz_last;
					
				case 'finish' % Click release. 
					
% Nothing to do yet
					
			end
			
			% If we're still running, something was updated, so update the
			% shown plot
			updatePlotMatrix(this.plot_,slerp(this.toolLiveData.refNodes,this.maxAngleStep_rad));
			
		end
	end
	
	
	% * * * * * * * * * * * GRAPHICS MANAGEMENT * * * * * * * * * * * * * *
	properties (Access = private)
		fig;
		globeManager;
		globeAx;
		
		toolButtons = struct();
		generalButtons = struct();
		
		backgroundSphereRadius = 0.999;
		
		sphereMeshPatch;
	end
	methods (Access = private)
		% Creates all necessary graphics
		function createGraphics(this)
			
			% Ensure that any plot3 lines drawn on the map have this
			% maximum angular spacing, to ensure they never interpolate
			% underneath the background map components.
			this.maxAngleStep_rad = 2*acos(this.backgroundSphereRadius);
			
			% Make the figure
			this.fig = figure(...
				'Position',this.settings.figurePosition,...
				'Color',this.palette.space,...
				'DockControls','off',...
				'MenuBar','none',...
				'Name','Map Editor',...
				'NumberTitle','off');
			
			% On that figure, create a set of axes with convenient
			% callbacks and state management.
			this.globeManager = GlobeManager();
			% Apply some settings right away:
			this.globeManager.preventCameraTilt = this.settings.lockCameraOrientation;
			% Get the underlying axes so we can plot to it.
			this.globeAx = this.globeManager.getAxesHandle();
			% These axes are designed for 3D plotting on the unit sphere.
			
			toolOptions = {...
			%    field name   tooltip                       callback
				'select',    'Select features',             @(~,~)this.tool_enable_select();
				'pan',       'Pan with click+drag',         @(~,~)this.tool_enable_pan();
				'pencil',    'Draw lines and boundaries',   @(~,~)this.tool_enable_pencil();
				'drag',      'Smoothly drag features',      @(~,~)this.tool_enable_drag();
				'stretch',   'Stretch and shrink features', @(~,~)this.tool_enable_stretch();
			};
			numTools = size(toolOptions,1);
			width  = this.sizes.toolButtonWidth;
			height = this.sizes.toolButtonHeight;
			vertSpacing = this.sizes.toolButtonVSpacing;
			horzSpacing = this.sizes.toolButtonHSpacing;
			startHeight = vertSpacing + flip(0:numTools-1) * (height+vertSpacing);
			
			for toolInd = 1:numTools
				this.toolButtons.(toolOptions{toolInd,1}) = uicontrol(...
					'Style','pushbutton',...
					'String','',...
					'Position',[horzSpacing,startHeight(toolInd),width,height],...
					'Tooltip',toolOptions{toolInd,2},...
					'Callback',toolOptions{toolInd,3},...
					'BackgroundColor',this.palette.uiBackground,...
					'Parent',this.fig...
				);
			end
			
			% Create the helper buttons (confirm, reject)
			this.generalButtons.confirm = uicontrol(...
					'Style','pushbutton',...
					'String','',...
					'Position',[horzSpacing,startHeight(toolInd),width,height],...
					'Tooltip','Confirm Changes [ENTER]',...
					'Callback',@(~,~) this.tool_callback_confirm(),...
					'BackgroundColor',this.palette.uiBackground,...
					'Parent',this.fig...
			);
			this.setupImageButton(...
				this.generalButtons.confirm,...
				'green_check.png');
			
			
this.plot_ = plot(nan,nan,'Color',[0,0,0],'LineWidth',2);

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
			
		end
		% Sets up the provided uicontrol button with the specified image
		% file. imPath is relative to the GUI Assets folder.
		function setupImageButton(this,uic,imPath)
			
		end
	end
	
	
	% * * * * * * * * * * * * DATA MANAGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
	end
	methods (Access = private)
		% When loading a file from file, set the lastSaveDatenum to now()
	end
	
	
	% * * * * * * * * * * * * * * TEMPORARY * * * * * * * * * * * * * * * *
	properties (Access = public)
		plot_;
		dataStack = [];
		maxAngleStep_rad = 0.02;
	end
	methods (Access = public)
		function stop(this)
			this.toolIsLive = false;
			this.toolLiveData.refNodes = nan(0,3);
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
	
	% When that special behavior triggers inside GlobeManager>renormalizeCameraSettings()   
	% then perform an animation to rotate the camera into place over 0.5 or
	% 1.0 sec.
	
	
	% export maps renders
		% final destination: flat (no 1/sin() scaling on border widths)   
		% final destination: edit as raster and bring back to globe (apply scaling so returning it looks good)
	% export map vector images??
	
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
	
end