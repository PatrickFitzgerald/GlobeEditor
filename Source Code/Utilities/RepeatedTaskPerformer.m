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
		function this = RepeatedTaskPerformer(minPeriod_s,maxRunDuration_s,callback,cleanupFunc,startImmediately)
			
			% To avoid a warning, truncate the minPeriod_s to milliseconds
			minPeriod_s = round(minPeriod_s,3);
			
			% Instantiate the timer object
			this.timerObj = timer();
			set(this.timerObj,...
				'TimerFcn',@(~,~)this.internalCallback(),...
				'BusyMode','drop',...
				'ExecutionMode','fixedRate',...
				'Period',minPeriod_s,...
				'TasksToExecute',inf ...
			);
			this.maxRunDuration_s = maxRunDuration_s;
			this.startTime_d = now();
			this.callback = callback;
			this.cleanupFunc = cleanupFunc;
			
			% Conditionally start the timer immediately
			if startImmediately
				% Start the timer.
				start(this.timerObj);
			end
		end
		% Starts the timer. Does nothing if it was already started, or if
		% it has already finished or been terminated early.
		function start(this)
			if ~this.earlyHalt && strcmp(this.timerObj.Running,'off')
				start(this.timerObj);
			end
		end
		% A helper function to stop the timer early. Calls the cleanup
		% function (as long as the timer is running)
		function terminate(this)
			wasRunning = isvalid(this.timerObj) && strcmp(this.timerObj.Running,'on');
			this.earlyHalt = true;
			try
				stop(this.timerObj);
			catch err %#ok<NASGU>
			end
			delete(this.timerObj);
			% Only run the cleanup function if the timer was ever started
			if wasRunning
				this.cleanupFunc();
			end
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
				% Cleans up the timer object, and calls the cleanup
				% function.
				this.terminate();
			end
		end
	end
	
end