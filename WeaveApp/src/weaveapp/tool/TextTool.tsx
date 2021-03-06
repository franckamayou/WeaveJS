import * as React from "react";
import * as weavejs from "weavejs";
import $ from "weaveapp/modules/jquery";
import {Weave} from "weavejs";

import MouseEvent = React.MouseEvent;
import CSSProperties = React.CSSProperties;
import MiscUtils = weavejs.util.MiscUtils;
import HBox = weavejs.ui.flexbox.HBox;
import VBox = weavejs.ui.flexbox.VBox;
import StatefulTextField = weavejs.ui.StatefulTextField;
import StatefulTextArea = weavejs.ui.StatefulTextArea;
import WeaveReactUtils = weavejs.util.WeaveReactUtils
import ReactUtils = weavejs.util.ReactUtils;
import StandardLib = weavejs.util.StandardLib;
import LinkableString = weavejs.core.LinkableString
import LinkableNumber = weavejs.core.LinkableNumber;
import LinkableHashMap = weavejs.core.LinkableHashMap;
import IColumnWrapper = weavejs.api.data.IColumnWrapper;
import ILinkableHashMap = weavejs.api.core.ILinkableHashMap;
import ILinkableObjectWithNewProperties = weavejs.api.core.ILinkableObjectWithNewProperties;
import IVisTool from "weaveapp/api/ui/IVisTool";
import {IVisToolProps} from "weaveapp/api/ui/IVisTool";
import {IVisToolState} from "weaveapp/api/ui/IVisTool";

export default class TextTool extends React.Component<IVisToolProps, IVisToolState> implements IVisTool
{
	static WEAVE_INFO = Weave.setClassInfo(TextTool, {
		id: "weavejs.tool.Text",
		label: "Text",
		interfaces: [IVisTool, ILinkableObjectWithNewProperties],
		deprecatedIds: ["weave.ui::TextTool"]
	});

	htmlText = Weave.linkableChild(this, new LinkableString(""));
	padding = Weave.linkableChild(this, new LinkableNumber(4));
	panelBackgroundColor = Weave.linkableChild(this, LinkableNumber);
	panelBorderColor = Weave.linkableChild(this, LinkableNumber);

	private element:HTMLElement;
	private textToolContainerClass:string;

	constructor(props:IVisToolProps)
	{
		super(props);

		this.textToolContainerClass = "text-tool-container";

		this.htmlText.addGroupedCallback(this, this.forceUpdate);
		this.padding.addGroupedCallback(this, this.forceUpdate);
		this.panelBackgroundColor.addGroupedCallback(this, this.forceUpdate);
		this.panelBorderColor.addGroupedCallback(this, this.forceUpdate)

	}

	panelTitle = Weave.linkableChild(this, LinkableString);
	altText:LinkableString = Weave.linkableChild(this, new LinkableString(this.panelTitle.value));

	get title():string
	{
		return MiscUtils.evalTemplateString(this.panelTitle.value, this) || this.defaultPanelTitle;
	}

	get selectableAttributes()
	{
		return new Map<string, IColumnWrapper | ILinkableHashMap>();
	}

	get defaultPanelTitle():string
	{
		return Weave.lang("Text Tool");
	}

	getTitlesEditor():React.ReactChild[][]
	{
		return [
			[
				Weave.lang("Chart"),
				this.panelTitle,
				this.defaultPanelTitle
			]
		].map((row:[string, LinkableString]) => {

			return [
				Weave.lang(row[0]),
				<StatefulTextField ref={ WeaveReactUtils.linkReactStateRef(this, {value: row[1]})} placeholder={row[2] as string}/>
			]
		});
	}

	renderEditor =(pushCrumb:Function = null):JSX.Element =>
	{
		return (
			<VBox>
			{
				ReactUtils.generateTable({
					body: [].concat(
						this.getTitlesEditor(),
						[
							[
								Weave.lang("Text"),
								<StatefulTextArea ref={ WeaveReactUtils.linkReactStateRef(this, {value: this.htmlText}) }/>
							],
							[
								'',
								<span>{ Weave.lang("Use '<br>' for a new line") }</span>
							]
						]
					),
					classes: {
						td: [
							"weave-left-cell",
							"weave-right-cell"
						]
					}
				})
			}
			</VBox>
		);
	}

	get deprecatedStateMapping()
	{
		return {
			"htmlText": this.htmlText,
			"padding": this.padding,
			"panelBackgroundColor": this.panelBackgroundColor,
			"panelBorderColor": this.panelBorderColor
		};
	}

	componentDidUpdate()
	{
		$(this.element).empty();
		//parse html, stripping out <script> tags
		let htmlElements:any[] = $.parseHTML("<div>"+MiscUtils.evalTemplateString(this.htmlText.value,this)+"</div>",null,false);
		if (htmlElements) {
			htmlElements.forEach((element:any) => {
				if (element.outerHTML)
					$(this.element).append(element.outerHTML);
			});
		}
	}

	render()
	{
		let bgColor:string = this.panelBackgroundColor.value ? StandardLib.getHexColor(this.panelBackgroundColor.value) : "#FFFFFF";
		return (<div style={{flex: 1, padding:this.padding.value, backgroundColor:bgColor, overflow:"auto"}}
					 ref={(c:HTMLElement) => { this.element = c }}
					 className={this.textToolContainerClass}></div>);
	}
}
