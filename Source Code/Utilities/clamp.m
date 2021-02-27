% This function enforces the bounds a <= x <= b. If x does not meet this
% constraint, that value is replaced with the nearer of a,b. a,b need not
% be in the correct order, they will be swapped as needed.
function x_ = clamp(x,a,b)
	a_ = min(a,b);
	b_ = max(a,b);
	x_ = min(max(a_,x),b_);
end