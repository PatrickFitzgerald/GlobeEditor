% Plots data which is saved as a matrix, with rows of points. Supports both
% plot() and plot3().
function obj = plotMatrix(matrix,varargin)
	switch size(matrix,2)
		case 2
			obj = plot( matrix(:,1),matrix(:,2),varargin{:});
		case 3
			obj = plot3(matrix(:,1),matrix(:,2),matrix(:,3),varargin{:});
		otherwise
			error('Unsupported matrix dimension.');
	end
end