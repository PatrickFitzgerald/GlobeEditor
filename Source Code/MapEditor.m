classdef MapEditor < handle
	
	% * * * * * * * * * * * SETTINGS MANAGEMENT * * * * * * * * * * * * * *
	properties (Access = private)
		sizes = struct(...
			'figurePosition',[100,100,1200,900]...
		);
		palette = struct(...
			'backgroundColor',[1,1,1]*0.1 ...
		);
	end
	methods (Access = private)
	end
	
	% * * * * * * * * * * * * TOOL MANEGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
		activeTool = 'none';
	end
	methods (Access = private)
		% Enable select tool
		function tool_enable_select(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
		end
		% Enable pan tool
		function tool_enable_pan(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
			% Enable the pan feature on the GlobeManager
			this.globeManager.clickPanEnabled = true;
			
		end
		% Enable pencil tool
		function tool_enable_pencil(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
		end
		% Enable drag tool
		function tool_enable_drag(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
		end
		% Enable stretch tool
		function tool_enable_stretch(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
		end
		% Enable shrink tool
		function tool_enable_shrink(this)
			
			% Start by cleaning up whatever tool was previously working
			this.tool_cleanup();
			
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
					
				case 'shrink'
					
			end
			
			% Record the new lack of tool
			this.activeTool = 'none';
			
		end
	end
	
	% * * * * * * * * * * * GRAPHICS MANAGEMENT * * * * * * * * * * * * * *
	properties (Access = private)
		fig;
		globeManager;
		globeAx;
	end
	methods (Access = private)
	end
	
	% * * * * * * * * * * * * DATA MANAGEMENT * * * * * * * * * * * * * * *
	properties (Access = private)
	end
	methods (Access = private)
	end
	
	% Graphics objects
	properties (Access = private)
		
		patchSurface;
		linework;
	end
	
	% Working data
	properties
		workingPoints;
	end
	
	% Functions
	methods
		
		function this = MapEditor()
			this.fig = figure(...
				'Position',this.sizes.figurePosition,...
				'Color',this.palette.backgroundColor,...
				'DockControls','off',...
				'MenuBar','none',...
				'Name','Map Editor',...
				'NumberTitle','off');
			
			this.globeManager = GlobeManager();
			% Assign callbacks
			this.globeManager.callback_MouseDown = @this.clickDown;
			this.globeManager.callback_MouseMove = @this.clickMove;
			this.globeManager.callback_MouseLift = @this.clickLift;
			this.globeManager.clickPanEnabled = false;
			
			this.globeAx = this.globeManager.getAxesHandle();
% 			this.ax = axes(...
% 				'Units','normalized',...
% 				'Position',[0,0,1,1],...
% 				'NextPlot','add',...
% 				'Visible','off'...
% 			);
			
			load('C:\Users\Patrick\Desktop\Globe Viewer\Irregular Sphere Meshes\sphere points 20000.mat','points','faces');
			this.patchSurface = patch('Vertices',points,'Faces',faces,...
				'FaceColor','w',...
				'EdgeColor','none',...
				'SpecularStrength',0.5);
			
			lightPosition = [5,0,1.5];
			lightColor = [255,247,164]/255;
			light('Color',lightColor,'Position',lightPosition);
			
			this.linework = plot3(this.globeAx,nan,nan,nan,'-o');
			
% 			this.points = this.origPoints;
% 			this.redraw();
			%
			
			
			
			dataFolder = 'Earth Data';
% 			dataName = '\110m_cultural\ne_110m_admin_0_countries'; % omit .shp
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
			
			
			this.tool_enable_pan();
			
			% make land masses
			% paint fill
			% layer management
			% draw lines/borders.
			% randomize borders, coastlines. Don't modify existing ones,
			%	just make new borders. This way they can be updated
			% import raster images
			% text??? maybe just do this in photoshop? maybe try to
			%    support vector graphics here?
			
			% export maps renders
				% final destination: flat (no 1/sin() scaling on border widths)   
				% final destination: edit as raster and bring back to globe (apply scaling so returning it looks good)
			% export map vector images??
			
			% how to efficiently find which facets a border falls into, and
			%    subdivide the facets to color them
			% when lines get stretched out, split them into more segments
			%    maybe also the reverse, if they're straight enough
			% undo/redo functionality
			% import/save/export
			
		end
		
		function redraw(this)
			
			this.linework.XData = this.workingPoints(:,1);
			this.linework.YData = this.workingPoints(:,2);
			this.linework.ZData = this.workingPoints(:,3);
			
		end
		
		function clickDown(this,eventInfo)
			
		end
		function clickMove(this,eventInfo)
			
		end
		function clickLift(this,eventInfo)
			
		end
		
		function click(this,event,mode)
			
			isScrollEvent = mode == 4;
			
			
			if mode == 2 && this.isClicked || mode == 3
				
				pos = this.getCurrentPoint();
				this.updatePoints(pos-this.refPos);
				this.redraw();
				if mode == 3
					this.origPoints = this.points;
					this.isClicked = false;
					this.refPos = nan(1,2);
				end
			elseif mode == 1 % Click activated
				this.isClicked = true;
				this.refPos = this.getCurrentPoint();
			elseif isScrollEvent
				disp('scrolled') % event
			end
			
		end
		
		function pos = getCurrentPoint(this)
			xyz = get(this.ax,'CurrentPoint');
			frontPoint = xyz(1,:);
			backPoint  = xyz(2,:);
			
			pos = frontPoint(1:2);
		end
		
		function updatePoints(this,translation)
			
			points_ = this.origPoints;
			
			% measure the distance between points and the reference
			range = 1;
			strength = exp(-sum((this.refPos - points_).^2,2)/2/range^2);
			correctedTranslation = translation .* strength;
			
			this.points = points_ + correctedTranslation;
			
		end
		
	end
	
end