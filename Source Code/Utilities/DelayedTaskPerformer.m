classdef DelayedTaskPerformer < handle
	
	properties (Access = private)
		delay_s;
		timerObj;
		callback = @() [];
		earlyHalt = false;
	end
	
	methods (Access = public)
		% Constructor
		function this = DelayedTaskPerformer(delay_s,callback,startImmediately)
			% Store properties.
			this.delay_s = round(delay_s,3);
			this.callback = callback;
			
			if startImmediately
				% Make and start the timer
				this.makeAndStartTimer();
			end
		end
		% Restarts timer, instead of needing a new instance. If currently
		% running already, the timer countdown just resets.
		function restart(this)
			this.earlyHalt = false;
			this.makeAndStartTimer(); % Restarts timer.
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
		% Makes a timer object
		function makeAndStartTimer(this)
			% Don't do anything if we've been marked as finished
			if this.earlyHalt
				return
			end
			% Delete any existing timer object
			if ~isempty(this.timerObj) && isvalid(this.timerObj)
				stop(this.timerObj);
				delete(this.timerObj);
			end
			% Instantiate the timer object
			this.timerObj = timer();
			set(this.timerObj,...
				'TimerFcn',@(~,~)this.internalCallback(),...
				'BusyMode','queue',...
				'ExecutionMode','singleShot',...
				'StartDelay',this.delay_s...
			);
			% Start the timer
			start(this.timerObj);
		end
		% Manages when to call the external callback.
		function internalCallback(this)
			
			% Cut it off at the bud if we've been told to stop, or
			% something is broken.
			if this.earlyHalt || ~isvalid(this.timerObj)
				return
			end
			% Otherwise keep running
			
			% Invoke the external callback
			this.callback();
			
			% Terminate everything for good measure
			this.terminate();
			
		end
	end
	
end