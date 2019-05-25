package tink.core;

import tink.core.Future;
import tink.core.Callback;

/**
 * For controlling a maximum number of concurrency tasks.
 */
class Quota {
	var current = 0;
	var max:Int;
	var pending:Array<FutureTrigger<CallbackLink>> = [];
	
	public function new(max:Int) {
		this.max = max;
	}
	
	/**
	 * Aquire a ticket. Returns a `Future` that will be resolved:
	 * - immediately if maximum concurrency not reached
	 * - when previous tasks returns the ticket otherwise
	 * Dissolve the `CallbackLink` when the task is finished.
	 * @return Future<CallbackLink>
	 */
	public function acquire():Future<CallbackLink> {
		return
			if(current < max) {
				current++;
				Future.sync((release:CallbackLink));
			} else {
				pending[pending.length] = Future.trigger();
			}
	}
	
	function release() {
		current--;
		switch pending.shift() {
			case null: // no one is waiting
			case trigger: trigger.trigger(release);
		}
	}
}