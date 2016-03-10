import * as React from "react";
import * as ReactDOM from "react-dom";

export type ReactComponent = React.Component<any, any> & React.ComponentLifecycle<any, any>;

export default class ReactUtils
{
	static hasFocus(component:ReactComponent):boolean
	{
		return ReactDOM.findDOMNode(component).contains(document.activeElement);
	}
	
	/**
	 * Adds undefined values to new state for properties in current state not
	 * found in new state.
	 */
	static includeMissingPropertyPlaceholders(currentState:any, newState:any)
	{
		var key:string;
		for (key in currentState)
			if (!newState.hasOwnProperty(key))
				newState[key] = undefined;
		return newState;
	}
	
	static onUnmount<T extends ReactComponent>(component:T, callback:(component:T)=>void):void
	{
		if (ReactDOM.findDOMNode(component) == null)
			return callback(component);
		
		// add listener to replace instance with placeholder when it is unmounted
		var superWillUnmount = component.componentWillUnmount;
		component.componentWillUnmount = function() {
			if (superWillUnmount)
				superWillUnmount.call(component);
			callback(component);
		};
	}

	static onUpdate<T extends ReactComponent>(component: T, callback: (component: T) => void): void
	{
		var superComponentDidUpdate = component.componentDidUpdate;
		component.componentDidUpdate = function(prevProps: any, prevState: any, prevContext: any) {
			if (superComponentDidUpdate)
				superComponentDidUpdate.call(component, prevProps, prevState, prevContext);
			callback(component);
		};
	}

	static onUpdateRef<T extends ReactComponent>(callback:(component:T)=>void):(component:T)=>void
	{
		var prevCDU:(prevProps:any, prevState:any, prevContext:any)=>void;
		var prevComponent:T;
		return function(component:T):void {
			if (component)
			{
				prevCDU = component.componentDidUpdate;
				component.componentDidUpdate = function(prevProps: any, prevState: any, prevContext: any):void {
					if (prevCDU)
						prevCDU.call(component, prevProps, prevState, prevContext);
					callback(component);
				};
			}
			else if (prevComponent)
			{
				prevComponent.componentDidUpdate = prevCDU;
				prevCDU = null;
			}
			prevComponent = component;
		};
	}
}
