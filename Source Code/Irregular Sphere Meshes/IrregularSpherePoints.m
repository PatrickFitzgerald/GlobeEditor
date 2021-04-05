function [points,faces,circumCenters,dotRadii,hash] = IrregularSpherePoints(numPoints)
	% Finds saved set with that many points, or makes it.
	
	visualsMode = 1; % facet perimeter
% 	visualsMode = 2; % point velocities
% 	visualsMode = 3; % no coloring
% 	visualsMode = 4; % no visuals at all
	
	plotChance = 1.0;
	absTol = 1e-4; % denotes sufficient convergence
	maxDisplacement = 0.005;
	maxTimeStep = 1;
	timeSlowAmount = 50;
	
	maxTimeIterCap = 1;
	maxTimeGrowth = 0;
	
	oscillationSlowPower = 0.9;
	
	printoutPeriod_s = 5;
	
	[folder,~,~] = fileparts(mfilename('fullpath'));
	path_ = fullfile(folder,sprintf('sphere points %u.mat',numPoints));
	if exist(path_,'file')
		try
			load(path_,'points','faces','circumCenters','dotRadii','hash');
			% If the load was successful return those loaded values.
			return
		catch err %#ok<NASGU>
		end
	end
	fprintf('Pre-generated mesh not available. Generating fresh.\n');
	
	% Define the initial points
	% It turns out placing them all COMPLETELY randomly is a poor starting
	% condition
	dTheta_rad = sqrt(4*pi/numPoints);
	dTheta_rad = pi / ceil(pi / dTheta_rad);
	thetas_rad = dTheta_rad/2 : dTheta_rad : pi; % use the thetas on center
	points = nan(numPoints*2,3); % Oversize
	lastRow = 0;
	maxJitter = 1; % relative to that dimension's spacing
	for theta_rad = thetas_rad
		arcLength = 2*pi*sin(theta_rad);
		numToAdd = ceil(arcLength / dTheta_rad);
		dPhi_rad = 2*pi / numToAdd;
		phis_rad = (  dPhi_rad/2 : dPhi_rad : 2*pi  )' + 2*pi*rand;
		newRows = lastRow + (1:numToAdd);
		tempTheta_rad = theta_rad + dTheta_rad * maxJitter * (rand(numToAdd,1)-0.5);
		tempPhi_rad   = phis_rad  + dPhi_rad   * maxJitter * (rand(numToAdd,1)-0.5);
		points(newRows,1) = cos(tempPhi_rad) .* sin(tempTheta_rad);
		points(newRows,2) = sin(tempPhi_rad) .* sin(tempTheta_rad);
		points(newRows,3) = ones(numToAdd,1) .* cos(tempTheta_rad);
		lastRow = lastRow + numToAdd;
	end
	% Trim off unused rows
	points(lastRow+1:end,:) = [];
	% To make them a bit more random, let's jitter their locations
	% irregSpherePoints = irregSpherePoints + randn(size(irregSpherePoints)) * dTheta_rad/7;
	% irregSpherePoints = irregSpherePoints ./ dist(irregSpherePoints,0);
	
	
	
	numPoints = size(points,1);
	
	
	
	if visualsMode == 1 % facet perimeter
		patchSettings = {'FaceColor','flat','EdgeColor','none','FaceVertexCData',nan(0,3)};
	elseif visualsMode == 2 % point velocities
		patchSettings = {'FaceColor','interp','EdgeColor','none','FaceVertexCData',nan(0,3)};
	elseif visualsMode == 3 % No coloring
		patchSettings = {'FaceColor','k','EdgeColor','w'};
	end
	
	if visualsMode ~= 4
		close all
		figure('Position',[100,200,800,800],'DockControls','off','MenuBar','none','ToolBar','default','Color','k')
		globeManager = GlobeManager();
		ax1 = globeManager.getAxesHandle();
		colormap(hot(512));
		patch_ = patch('Parent',ax1,'Vertices',points,'Faces',nan(0,3),patchSettings{:});
		ax2 = axes('OuterPosition',[0.5,0,0.5,0.1]);
		ax3 = axes('OuterPosition',[0,0,0.5,0.1]);
		pause(0.3)
	end
	
	
	oldPoints = inf(1,3);
	oldFaces  = nan(1,3);
	oldVelocities = zeros(numPoints,3);
	oscillationLifetimes = zeros(numPoints,1);
	iter = 0;
	timer_ = tic();
	lastPrintout = toc(timer_);
	while true
		
		faces = convhulln(points);
		edges = [faces(:,[1,2]);faces(:,[2,3]);faces(:,[3,1])]; % Kx2, each direction is its own vector
		displacements = points(edges(:,2),:) - points(edges(:,1),:);
		lengths = sqrt(sum(displacements.^2,2));
		forces_e = (1 - mean(lengths)./lengths) .* displacements; % equivalent to (lengths - mean(lengths(:))) .* edgeDirs; with edgeDirs as unit vectors
		
		forces_p = nan(numPoints,3);
		forces_p(:,1) = accumarray([edges(:,1);edges(:,2)],[forces_e(:,1);-forces_e(:,1)],[numPoints,1]);
		forces_p(:,2) = accumarray([edges(:,1);edges(:,2)],[forces_e(:,2);-forces_e(:,2)],[numPoints,1]);
		forces_p(:,3) = accumarray([edges(:,1);edges(:,2)],[forces_e(:,3);-forces_e(:,3)],[numPoints,1]);
		
		velocities = forces_p / 1.0;
		
		velMag = sqrt(sum(velocities.^2,2));
		maxVelMag = max(velMag);%sqrt(max(sum(velocities.^2,2)));
		dt_s = maxDisplacement / maxVelMag * timeSlowAmount^2/(timeSlowAmount^2+iter^2);
		dt_s = min(dt_s,maxTimeStep*sqrt(1+maxTimeGrowth^2*iter^2/maxTimeIterCap^2)); % Time cap will be small at first, the grow linearly
		
		
		flippedDirection = sum(velocities .* oldVelocities,2) < 0;
		oscillationLifetimes(~flippedDirection) = 0;
		oscillationLifetimes(flippedDirection) = oscillationLifetimes(flippedDirection) + 1;
		
		
		points = points + velocities * dt_s .* oscillationSlowPower .^ oscillationLifetimes;
		points = points ./ sqrt(sum(points.^2,2)); % Normalize points
		
		if visualsMode ~= 4 && rand < plotChance
			
			patch_.Vertices = points;
			patch_.Faces = faces;
			
			if visualsMode == 1 % facet perimeter
				% There are exactly 3x more edges than faces
				perimeters = lengths(1:end/3) + lengths(end/3+1:2*end/3) + lengths(2*end/3+1:end);
				patch_.FaceVertexCData = perimeters;
			elseif visualsMode == 2 % point velocities
				patch_.FaceVertexCData = velMag;
			elseif visualsMode == 3 % No coloring
				% nothing
			end
			if ismember(visualsMode,[1,2])
				caxis(ax1,[min(patch_.FaceVertexCData),max(patch_.FaceVertexCData)])
% 				caxis(ax1,[0,2*mean(patch_.FaceVertexCData)])
			end
			
			histogram(ax2,lengths/mean(lengths),'FaceColor','w','FaceAlpha',1,'EdgeColor','none');
			xlim(ax2,[0,2])
			ax2.Visible = 'off';
			
			histogram(ax3,log(velMag),'FaceColor','w','FaceAlpha',1,'EdgeColor','none');
			xlim(ax3,[-10,0])
			ax3.Visible = 'off';
			
			drawnow
		end
		
		pointChange = sqrt(max(sum((oldPoints-points).^2)));
		if (isequal(oldFaces,faces) || toc(timer_)>15*60) && pointChange < absTol
			break
		end
		oldPoints = points;
		oldFaces  = faces;
		oldVelocities = velocities;
		iter = iter + 1;
		fprintf('.')
		if (toc(timer_) - lastPrintout) > printoutPeriod_s
			lastPrintout = toc(timer_);
			fprintf(' Delta = %.2e, Time = %.1f sec\n',pointChange,lastPrintout);
		end
		
	end
	
	
	
	faces  = convhulln(points);
	
	
	% Clean up the results
	faces = correctEdgeOrder(faces,points); % Ensure the edges are in CCW order
	[circumCenters,dotRadii] = getCircumcircle(faces,points); % Determine circumcenters and dotradii
	
	hash = DataHash(...
		points,... % Everything is determined from points, so may as well only depend on that.
		'array','base64','MD5');
	
	save(path_,'points','faces','circumCenters','dotRadii','hash');
	
	fprintf('\nDone.\n\n')
	
	pause(3)
	close(gcf);

end
