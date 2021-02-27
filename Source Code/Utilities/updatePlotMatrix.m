% Updates the XData, YData, and (if appropriate) ZData on an existing plot.
% Uses data which is saved as a matrix, with rows of points. Supports both
% plot() and plot3().
function updatePlotMatrix(plotObj,matrix)
	
	plotObj.XData = matrix(:,1);
	plotObj.YData = matrix(:,2);
	if size(matrix,2) == 3
		plotObj.ZData = matrix(:,3);
	end
	
end