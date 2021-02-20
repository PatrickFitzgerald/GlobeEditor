function [points,faces,circumCenters,dotRadii] = IrregularSpherePoints(numPoints)
	% Finds saved set with that many points, or makes it.
	
	[folder,~,~] = fileparts(mfilename('fullpath'));
	path_ = fullfile(folder,sprintf('sphere points %u.mat',numPoints));
	if exist(path_,'file')
		try
			load(path_,'points','faces','circumCenters','dotRadii');
			% If the load was successful return those loaded values.
			return
		catch err %#ok<NASGU>
		end
	end
	fprintf('Pre-generated mesh not available. Generating fresh.\n');
	
	% Define the initial points
	% It turns out placing them all COMPLETELY randomly is a poor starting
	% condition
	% 	irregSpherePoints = randn(numPoints,1,3); % effectively zero chance they're zero vectors
	% 	irregSpherePoints = irregSpherePoints ./ dist(irregSpherePoints,0);
	dTheta_rad = sqrt(4*pi/numPoints);
	dTheta_rad = pi / ceil(pi / dTheta_rad);
	thetas_rad = dTheta_rad/2 : dTheta_rad : pi; % use the thetas on center
	irregSpherePoints = nan(numPoints*2,1,3); % Oversize
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
		irregSpherePoints(newRows,1,1) = cos(tempPhi_rad) .* sin(tempTheta_rad);
		irregSpherePoints(newRows,1,2) = sin(tempPhi_rad) .* sin(tempTheta_rad);
		irregSpherePoints(newRows,1,3) = ones(numToAdd,1) .* cos(tempTheta_rad);
		lastRow = lastRow + numToAdd;
	end
	% Trim off unused rows
	irregSpherePoints(lastRow+1:end,:,:) = [];
	% To make them a bit more random, let's jitter their locations
	% irregSpherePoints = irregSpherePoints + randn(size(irregSpherePoints)) * dTheta_rad/7;
	% irregSpherePoints = irregSpherePoints ./ dist(irregSpherePoints,0);
	
	
	
	f = figure;
	plot_ = plot3(irregSpherePoints(:,1,1),irregSpherePoints(:,1,2),irregSpherePoints(:,1,3),'k.');
	hold on;
	daspect([1,1,1]);
	axis vis3d;
	axis([-1,1,-1,1,-1,1])
	
	[x,y,z] = sphere(500);
	shrink = 0.99;
	surf(x*shrink,y*shrink,z*shrink,'EdgeColor','none','FaceColor','w')
	
	drawnow
	
	% Now perturb the points to be as far away as possible from the other
	% points
	convergenceSpeed = 0.05;% 5e-2/numPoints;
	oldPoints = inf(size(irregSpherePoints));
	iter = 0;
	while max(max(abs(irregSpherePoints - oldPoints))) > 1e-4
		
		oldPoints = irregSpherePoints;
		
		displace = nansum( force(irregSpherePoints,permute(irregSpherePoints,[2,1,3])), 2); % force of a point on itself will be nan, omit from sum
		displace = displace / max(dist(displace,0));
		irregSpherePoints = irregSpherePoints + displace * convergenceSpeed / (1+(iter/10)^2);
		irregSpherePoints = irregSpherePoints ./ dist(irregSpherePoints,0); % renormalize
		plot_.XData = irregSpherePoints(:,1,1);
		plot_.YData = irregSpherePoints(:,1,2);
		plot_.ZData = irregSpherePoints(:,1,3);
		drawnow
		pause(0.05)
		iter = iter + 1;
		fprintf('.')
	end
	fprintf('\n')
	
	points = permute(irregSpherePoints,[1,3,2]);
	faces  = convhulln(points);
	
	
	% Clean up the results
	faces = correctEdgeOrder(faces,points); % Ensure the edges are in CCW order
	[circumCenters,dotRadii] = getCircumcircle(faces,points); % Determine circumcenters and dotradii
	
	
	
	save(path_,'points','faces','circumCenters','dotRadii');
	
	clf
	patch('Vertices',points,'Faces',faces,'FaceColor','w')
	daspect([1,1,1]);
	axis vis3d
	
	pause(3)
	close(f);
	
	
	function dist_ = dist(a,b)
		dist_ = sqrt(sum((a-b).^2,3)); % x,y,z are along third dim
	end
	function force_ = force(a,b)
		dist_ = dist(a,b);
		mag = 1./dist_.^2;
		effMinDist = 20e-3;
		mag = min(mag,1/effMinDist^2);
		force_ = (a-b) ./ dist_ .* mag;
	end

end
