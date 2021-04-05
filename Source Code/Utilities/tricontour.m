% levels = [] to leave as defeault.
function [h,C] = tricontour(faces,points,vals,levels,varargin)
	
	% Determine the full domain of vals present
	pointIndsUsed = unique(faces(:));
	valsSpace = vals(pointIndsUsed);
	valMin = min(valsSpace);
	valMax = max(valsSpace);
	% Make sure levels is defined. By default, use uniformly spaced levels
	if ~exist('levels','var') || isempty(levels)
		levels = 9; % 9 levels by default
	end
	% Fill out the levels definition, following the default contour() func
	if numel(levels) == 1 % levels is number of contours
	   levels = linspace(valMin,valMax,levels+2);
	elseif numel(levels) == 2 && levels(1) == levels(2) % levels is one contour level
	   levels = levels(1);
	else % levels is vector of contour levels
	   levels = sort(levels);
	end
	
	% Employ the (custom) core functionality for generating the contour
	% matrix.
	C = tricontour_core(faces,points,vals,levels);
	
	% Prepare output patch objects
	if nargout > 0
		h = gobjects(0);
	end
	
	% Draw contours
	nextPlotState = get(gca,'NextPlot');
	set(gca,'NextPlot','add');
	refInd = 1;
	is3D = size(C,1) == 3;
	while refInd < size(C,2)
		level = C(1,refInd);
		count = C(2,refInd);
		data = C(:,refInd+(1:count));
		
		colors = repmat(level,count,1);
		
		% If the data is not inherently a closed loop, explicitly prevent
		% it from being closed.
		if ~all(data(:,1) == data(:,end))
			data(:,end+1) = nan; %#ok<AGROW>
			colors(end+1,:) = colors(1,:); %#ok<AGROW>
		end
		if is3D
			h_ = patch('XData',data(1,:),'YData',data(2,:),'ZData',data(3,:),'FaceColor','none','EdgeColor','flat','FaceVertexCData',colors,varargin{:});
		else
			h_ = patch('XData',data(1,:),'YData',data(2,:),                  'FaceColor','none','EdgeColor','flat','FaceVertexCData',colors,varargin{:});
		end
		% Store patch objects in output
		if nargout > 0
			h(end+1) = h_; %#ok<AGROW>
		end
		
		if refInd == 1
			hold on
		end
		refInd = refInd + count + 1;
		
	end
	set(gca,'NextPlot',nextPlotState);
	
end