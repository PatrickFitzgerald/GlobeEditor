[points,faces,circumCenters,dotRadii] = IrregularSpherePoints(300000);

tic()
sm = SphereMesh(points,faces,circumCenters,dotRadii);
toc()

