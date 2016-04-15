import * as React from 'react';
import {IVisTool, IVisToolProps, IVisToolState, renderSelectableAttributes} from "../IVisTool";
import {HBox, VBox} from "../../react-ui/FlexBox";
import ReactUtils from "../../utils/ReactUtils";
import {ListOption} from "../../react-ui/List";
import List from "../../react-ui/List";
import * as lodash from "lodash";
import HSlider from "../../react-ui/RCSlider/HSlider";
import VSlider from "../../react-ui/RCSlider/VSlider";

import IColumnWrapper = weavejs.api.data.IColumnWrapper;
import LinkableHashMap = weavejs.core.LinkableHashMap;
import LinkableString = weavejs.core.LinkableString;
import LinkableVariable = weavejs.core.LinkableVariable;
import LinkableWatcher = weavejs.core.LinkableWatcher;
import ILinkableHashMap = weavejs.api.core.ILinkableHashMap;
import ILinkableObject = weavejs.api.core.ILinkableObject;
import ColumnUtils = weavejs.data.ColumnUtils;
import WeaveAPI = weavejs.WeaveAPI;
import IAttributeColumn = weavejs.api.data.IAttributeColumn;
import SliderOption from "../../react-ui/RCSlider/RCSlider";
import Dropdown from "../../semantic-ui/Dropdown";

const LAYOUT_LIST:string = "List";
const LAYOUT_COMBO:string = "ComboBox";
const LAYOUT_VSLIDER:string = "VSlider";
const LAYOUT_HSLIDER:string = "HSlider";

const menuOptions:string[] = [LAYOUT_LIST, LAYOUT_COMBO, LAYOUT_HSLIDER, LAYOUT_VSLIDER];

export interface IAttributeMenuToolState extends IVisToolState{

}

export default class AttributeMenuTool extends React.Component<IVisToolProps, IAttributeMenuToolState> implements IVisTool
{
    //session properties
    public choices = Weave.linkableChild(this, new LinkableHashMap(IAttributeColumn), this.forceUpdate, true );//this will re render the TOOL (callbacks attached in TOOL)
    public layoutMode = Weave.linkableChild(this, new LinkableString(LAYOUT_LIST), this.forceUpdate, true);//this will re render the TOOL (callbacks attached in TOOL)
    public selectedAttribute = Weave.linkableChild(this, new LinkableString, this.forceUpdate, true);

    public targetToolPathWatcher = Weave.linkableChild(this, new LinkableWatcher());//this will re render the EDITOR (callbacks attached in editor)

    public targetToolPath:LinkableVariable = Weave.linkableChild(this, new LinkableVariable(Array));
    public targetAttribute = Weave.linkableChild(this, new LinkableVariable(null));//this will re render the EDITOR (callbacks attached in editor)

    constructor (props:IVisToolProps){
        super(props);
        this.state = {};
    }

    get title():string{
        return Weave.lang('Attribute Menu Tool');
    }

    get selectableAttributes()
    {
        return new Map<string, IColumnWrapper | LinkableHashMap>().set("Choices", this.choices);
    }

    get options (){
        return(this.choices.getObjects().map((column:IAttributeColumn) =>{
            return {label: ColumnUtils.getTitle(column), value : column};//TODO replace getTitle with metadata title property?
        }));
    };

    handleSelection = (selectedValues:any[]):void =>{
        var root = Weave.getRoot(selectedValues[0]);//get root hashmap
        var tool = Weave.followPath(root, this.targetToolPath.state as string[]) as IVisTool;//retrieve tool from targetTool Path

	    var targetCol = tool.selectableAttributes.get(this.targetAttribute.state as string) as IColumnWrapper;
	    var targetInternalCol = ColumnUtils.hack_findInternalDynamicColumn(targetCol);

        //use selected column to set session state of target column
        var selectedColumn = selectedValues[0] as IAttributeColumn;
        this.selectedAttribute.state = this.choices.getName(selectedColumn);//for the list UI to re render

        targetInternalCol.requestLocalObjectCopy(selectedColumn) ;//TODO handle selectable attributes hashmaps eg height columns barchart

    };

    renderEditor():JSX.Element{
        return(<VBox>
            <AttributeMenuTargetEditor attributeMenuTool={ this }/>
            { renderSelectableAttributes(this, null) }
        </VBox>);
    }

    render():JSX.Element{

        let selectedAttribute = this.choices.getObject(this.selectedAttribute.state as string) as IAttributeColumn;//get object from name

        switch(this.layoutMode.value){
            case(LAYOUT_LIST):
                return(<VBox><List options={ this.options }  onChange={ this.handleSelection.bind(this) } selectedValues={ [selectedAttribute] }/></VBox>);
            case(LAYOUT_HSLIDER):
                return(<VBox style={{ padding: "70px" }}>
                    <HSlider options={ this.options } onChange={ this.handleSelection} selectedValues={ [selectedAttribute] } type={ "categorical" }/></VBox>);
            case(LAYOUT_VSLIDER):
                return(<VBox><VSlider options={ this.options } onChange={ this.handleSelection } selectedValues={ [selectedAttribute] } type={ "categorical" }/>
                </VBox>)
        }
    }
}

Weave.registerClass(
    AttributeMenuTool,
    ["weave.ui::AttributeMenuTool", "weavejs.tool.AttributeMenu"],
    [weavejs.api.ui.IVisTool],
    "Attribute Menu Tool"
);

//EDITOR for the Attribute Menu Tool

interface IAttributeMenuTargetEditorProps {
    attributeMenuTool:AttributeMenuTool;
}

interface IAttributMenuToolEditorState {
    openTools?:any[];
}

class AttributeMenuTargetEditor extends React.Component<IAttributeMenuTargetEditorProps, IAttributMenuToolEditorState>
{
    constructor(props:IAttributeMenuTargetEditorProps){
        super(props);
        this.weaveRoot = Weave.getRoot(this.props.attributeMenuTool);

        this.weaveRoot.childListCallbacks.addGroupedCallback(this, this.getOpenVizTools,true);//will be called whenever a new tool is added

        Weave.getCallbacks(this.props.attributeMenuTool.targetToolPathWatcher).addGroupedCallback(this, this.forceUpdate);//registering callbacks

        this.props.attributeMenuTool.targetToolPath.addImmediateCallback(this, this.setTargetToolPathWatcher, true);
        this.props.attributeMenuTool.targetAttribute.addGroupedCallback(this, this.forceUpdate);
    }

    componentWillReceiveProps(nextProps:IAttributeMenuTargetEditorProps)
    {
        if(this.props.attributeMenuTool != nextProps.attributeMenuTool)
        {
            this.weaveRoot.childListCallbacks.removeCallback(this, this.getOpenVizTools);
            Weave.getCallbacks(this.props.attributeMenuTool.targetToolPathWatcher).removeCallback(this, this.forceUpdate);
            this.props.attributeMenuTool.targetToolPath.removeCallback(this, this.setTargetToolPathWatcher);
            this.props.attributeMenuTool.targetAttribute.removeCallback(this, this.forceUpdate);

            this.weaveRoot = Weave.getRoot(nextProps.attributeMenuTool);
            this.weaveRoot.childListCallbacks.addGroupedCallback(this, this.getOpenVizTools,true);//will be called whenever a new tool is added
            Weave.getCallbacks(nextProps.attributeMenuTool.targetToolPathWatcher).addGroupedCallback(this, this.forceUpdate);//registering callbacks
            nextProps.attributeMenuTool.targetToolPath.addImmediateCallback(this, this.setTargetToolPathWatcher, true);
            nextProps.attributeMenuTool.targetAttribute.addGroupedCallback(this, this.forceUpdate);
        }


    }

    state : {openTool:any[]};
    private openTools:any [];//visualization tools open at the given time
    private weaveRoot:ILinkableHashMap;

    getOpenVizTools=():void =>
    {
        this.openTools = [];

        this.weaveRoot.getObjects().forEach((tool:any):void=>
        {
            if(tool.selectableAttributes && tool != this.props.attributeMenuTool)//excluding AttributeMenuTool from the list
                this.openTools.push(this.weaveRoot.getName(tool));
        });
        this.setState({openTools: this.openTools});
    };

    //UI event handler for target Tool
    handleTargetToolChange = (selectedItem:string):void =>
    {
        this.props.attributeMenuTool.targetToolPath.state = [selectedItem ];
    };

    //UI event handler for target attribute (one of the selectable attributes of the target tool)
    handleTargetAttributeChange =(selectedItem:string):void =>
    {
        this.props.attributeMenuTool.targetAttribute.state = selectedItem ;
    };

    //UI event handler for attribute menu layout
    handleMenuLayoutChange = (selectedItem:string):void =>{
        this.props.attributeMenuTool.layoutMode.state = selectedItem;// will re render the tool with new layout
    };

    //callback for targetToolPath
    setTargetToolPathWatcher = ():void=>{
        var amt = this.props.attributeMenuTool;
        if(amt.targetToolPath.state)
            amt.targetToolPathWatcher.targetPath = amt.targetToolPath.state as string[];
    };

    get tool():IVisTool{
        if(this.props.attributeMenuTool.targetToolPath.state)
            return Weave.followPath(this.weaveRoot, this.props.attributeMenuTool.targetToolPath.state as string[]) as IVisTool;
    }

    getTargetToolAttributeOptions():string[] {
        let tool:IVisTool = this.tool;
        let attributes:string[] =[];
        if(tool)
	        attributes= Array.from(tool.selectableAttributes.keys()) as string[];
        return attributes;
    }

    getTargetToolPath= ():string =>{
        let toolPath = this.props.attributeMenuTool.targetToolPath.state as string[];
        return (toolPath[0] as string);
    };

    get toolConfigs():[string, JSX.Element][]{

        var toolName:string;
        var menuLayout:string = this.props.attributeMenuTool.layoutMode.state as string;
	    
        if(this.props.attributeMenuTool.targetToolPath.state){
            toolName = this.getTargetToolPath();
        }


        return[
            [
                Weave.lang("Visualization Tool"),
                <Dropdown className="weave-sidbar-dropdown" placeholder="Select a visualization"
							value={ toolName } selectFirstOnInvalid={ true }
							options={ this.openTools } onChange={ this.handleTargetToolChange } />
            ],
            [
                Weave.lang("Visualization Attribute"),

                <Dropdown className="weave-sidebar-dropdown" placeholder="Select an attribute"
							value={ this.props.attributeMenuTool.targetAttribute.state} selectFirstOnInvalid={ true }
							options={ this.getTargetToolAttributeOptions() } onChange={ this.handleTargetAttributeChange }  />
            ],
            [
                Weave.lang("Menu Layout"),
                <Dropdown className="weave-sidebar-dropdown"
							value={ menuLayout }
							options={ menuOptions } onChange={ this.handleMenuLayoutChange }/>
            ]
        ];
    }


    render ():JSX.Element{
        var tableStyles = {
            table: { width: "100%", fontSize: "smaller" },
            td: [
                { paddingBottom: 10, textAlign: "right", whiteSpace: "nowrap", paddingRight: 5 },
                { paddingBottom: 10, textAlign: "right", width: "100%" }
            ]
        };

        return (<VBox>
            {this.openTools && this.openTools.length >0 ? ReactUtils.generateTable(null, this.toolConfigs, tableStyles):null}
        </VBox>);
    }

}