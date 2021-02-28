classdef RepeatedTaskPerformer < handle
	
	properties (Access = private)
		startTime_d;
		timerObj;
		minPeriod_s;
		maxRunDuration_s;
		callback = @(elapsedTime_s) [];
		cleanupFunc = @() [];
		earlyHalt = false;
	end
	
	methods (Access = public)
		% Constructor
		function this = RepeatedTaskPerformer(minPeriod_s,maxRunDuration_s,callback,cleanupFunc)
			
			% To avoid a warning, truncate the minPeriod_s to milliseconds
			minPeriod_s = round(minPeriod_s,3);
			
			% Instantiate the timer object
			this.timerObj = timer();
			set(this.timerObj,...
				'TimerFcn',@(~,~)this.internalCallback(),...
				'BusyMode','queue',...
				'ExecutionMode','fixedRate',...
				'Period',minPeriod_s,...
				'TasksToExecute',inf ...
			);
			this.maxRunDuration_s = maxRunDuration_s;
			this.startTime_d = now();
			this.callback = callback;
			this.cleanupFunc = cleanupFunc;
			% Start the timer.
			start(this.timerObj);
		end
		% A helper function to stop the timer early.
		function terminate(this)
			this.earlyHalt = true;
			try
				stop(this.timerObj);
			catch err %#ok<NASGU>
			end
			delete(this.timerObj);
		end
	end
	methods (Access = private)
		% Manages when to call the external callback.
		function internalCallback(this)
			% Cut it off at the bud if we've been told to stop, or
			% something is broken.
			if this.earlyHalt || ~isvalid(this.timerObj)
				return
			end
			% Otherwise keep running
			
			elapsedTime_d = now() - this.startTime_d;
			elapsedTime_s = elapsedTime_d * 24*3600;
			
			% Invoke the external callback
			this.callback(elapsedTime_s);
			
			% Prevent this from running again in the future.
			if elapsedTime_s > this.maxRunDuration_s
				% Invoke the cleanup function
				this.cleanupFunc();
				% And halt the timer going forward
				this.terminate();
			end
		end
	end
	
end