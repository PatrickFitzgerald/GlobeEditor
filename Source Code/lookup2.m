[points,faces,circumCenters,dotRadii] = IrregularSpherePoints(1000);

% tic()
% sm = SphereMesh(points,faces,circumCenters,dotRadii);
% toc()

ps = PerlinSurface(1000);