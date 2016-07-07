import * as React from "react";
import * as ReactDOM from "react-dom";
import AbstractVisTool from "./AbstractVisTool";
import {IVisToolProps, IVisToolState} from "./IVisTool";
import * as PIXI from "pixi.js";
import IPlotter from "../plot/IPlotter";
import ScatterPlotPlotter from "../plot/ScatterPlotPlotter";
import Bounds2D = weavejs.geom.Bounds2D;
import DynamicComponent from "../../outts/ui/DynamicComponent";
import IPlotTask from "../plot/IPlotTask";
import DOMUtils from "../../outts/utils/DOMUtils";

export interface PIXIScatterPlotProps extends IVisToolProps
{

}

export interface PIXIScatterPlotState extends IVisToolState
{

}

export default class PIXIScatterPlot extends AbstractVisTool<IVisToolProps, IVisToolState>
{
	element:HTMLDivElement;
	renderer:PIXI.WebGLRenderer | PIXI.CanvasRenderer;
	graphics:PIXI.Graphics = new PIXI.Graphics();
	stage:PIXI.Container = new PIXI.Container();
	plotter:ScatterPlotPlotter = Weave.linkableChild(this, ScatterPlotPlotter, this.forceUpdate);

	constructor(props:PIXIScatterPlotProps)
	{
		super(props);
		console.log('IPlotter', IPlotter);
		this.plotter.spatialCallbacks.addGroupedCallback(this, this.forceUpdate);
		this.plotter.filteredKeySet.keyFilter.targetPath = ['defaultSubsetKeyFilter'];
	}

	componentDidMount()
	{
		var canvas = ReactDOM.findDOMNode(this) as HTMLCanvasElement;
		this.renderer = PIXI.autoDetectRenderer(800, 600, {
			view: canvas,
			transparent: true,
			resolution: DOMUtils.getWindow(canvas).devicePixelRatio
		});
		this.renderer.autoResize = true;
		this.renderer.clearBeforeRender = true;
		this.stage.addChild(this.graphics);
	}

	componentDidUpdate()
	{
		var db = new Bounds2D();
		this.plotter.getBackgroundDataBounds(db);
		var task = {
			buffer: this.graphics,
			dataBounds: db,
			screenBounds: new Bounds2D(0, 600, 800, 0),
			recordKeys: this.plotter.filteredKeySet.keys,
			iteration: 0,
			iterationStopTime: Infinity,
			asyncState: {},
			progress: 0
		};
		while (task.progress < 1)
		{
			task.progress = this.plotter.drawPlotAsyncIteration(task);
			task.iteration++;
		}
		this.renderer.render(this.stage);
	}

	render()
	{
		return (
			<canvas style={{flex: 1}}/>
		);
	}
}

Weave.registerClass(
	PIXIScatterPlot,
	["weavejs.tool.PIXIScatterPlot", "weave.visualization.tools::ScatterPlotTool"],
	[
		weavejs.api.ui.IVisTool_Basic,
		weavejs.api.core.ILinkableObjectWithNewProperties,
		weavejs.api.data.ISelectableAttributes,
	],
	"Scatter Plot"
);