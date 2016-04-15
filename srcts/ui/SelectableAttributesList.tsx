import * as React from "react";
import {HBox, VBox} from "../react-ui/FlexBox";
import IconButton from "../react-ui/IconButton";
import List from "../react-ui/List";
import AttributeSelector from "../ui/AttributeSelector";
import IAttributeColumn = weavejs.api.data.IAttributeColumn;
import ILinkableHashMap = weavejs.api.core.ILinkableHashMap;
import ColumnUtils = weavejs.data.ColumnUtils;
import {ListOption} from "../react-ui/List";
import PopupWindow from "../react-ui/PopupWindow";
import IColumnWrapper = weavejs.api.data.IColumnWrapper;
import ControlPanel from "./ControlPanel";

export interface ISelectableAttributesListProps{
    columns : ILinkableHashMap;
    label:string;
    showLabelAsButton?:boolean;
    linkFunction?:Function;
    selectableAttributes? : Map<string, (IColumnWrapper|ILinkableHashMap)>;
}

export interface ISelectableAttributesListState{
    selectAll:boolean;
}

export default class SelectableAttributesList extends React.Component<ISelectableAttributesListProps, ISelectableAttributesListState>{
    constructor(props:ISelectableAttributesListProps){
        super(props);
        this.state = {
            selectAll :false
        };

        Weave.getCallbacks(this.props.columns).addGroupedCallback(this, this.forceUpdate);
    }
    private selectedColumn:IAttributeColumn;

    removeSelected = ():void =>{
        if(this.state.selectAll)
            this.props.columns.removeAllObjects();
        else{
            var colName = this.props.columns.getName(this.selectedColumn);
            this.props.columns.removeObject(colName);
        }
    };

    handleSelectAll =():void =>{
            this.setState({selectAll : true});
    };

    select =(selectedItems:Array<IAttributeColumn>): void =>{
        if(this.state.selectAll)
            this.setState({selectAll :false});
        this.selectedColumn = selectedItems[0];
    };

    launchAttributeSelector=():ControlPanel=>{
        if(this.props.linkFunction)
        {
            this.props.linkFunction( AttributeSelector.openInWeaveToolEditor("Attribute Selector", this.props.label, this.props.columns, this.props.selectableAttributes))
            return null;
        }
      return AttributeSelector.openInstance(this.props.label, this.props.columns, this.props.selectableAttributes);
    };

    componentWillUnmount(){
        Weave.getCallbacks(this.props.columns).removeCallback(this,this.forceUpdate);
    }

    render(): JSX.Element {
        var labelStyle:React.CSSProperties = {
            fontSize : 'smaller',
            alignSelf:'flex-start',
            borderColor: '#E6E6E6'
        };

        var listStyle:React.CSSProperties = {
            minHeight: '70px',
            overflowY: 'auto',
            border:'1px solid lightgrey'
        };

        let constrollerStyle:React.CSSProperties = {
            justifyContent:'flex-end',
            background:"#F8F8F8"
        }


        var selectedObjects:IAttributeColumn[];
        var columnList: ListOption[] = [];
        var columns = this.props.columns.getObjects(IAttributeColumn);

        //When all options are selected, needed only for restyling the list and re-render
        if(this.state.selectAll)
            selectedObjects = columns;

        columns.forEach((column:IAttributeColumn, index:number)=>{
            let label = ColumnUtils.getColumnListLabel(column);
            columnList.push({label:label, value : column});
        });

        var labelUI:JSX.Element = null;
        if(this.props.showLabelAsButton)
        {
            labelUI = <IconButton style={ labelStyle } clickHandler={ this.launchAttributeSelector }>{ Weave.lang(this.props.label) }</IconButton>;
        }else
        {
            labelUI = <span>{this.props.label}</span>
        }

        return(<VBox className="weave-padded-vbox weave-container" style={ {border:"none"} }>
                    {labelUI}

                    <VBox className="weave-padded-vbox">
                        <HBox style={listStyle}>
                            <List style={ {fontSize: 'smaller'}} selectedValues= { selectedObjects } options={ columnList }  onChange={ this.select }/>
                        </HBox>

                        <HBox className="weave-padded-hbox" style={constrollerStyle}>
                            <IconButton clickHandler={ this.handleSelectAll }
                                        style={ {borderColor:"grey", fontSize:"12px"} }>Select All</IconButton>
                            <IconButton clickHandler={ this.removeSelected }
                                        style={ {borderColor:"grey", fontSize:"12px"} }>Remove Selected</IconButton>
                        </HBox>
                    </VBox>
               </VBox>);
    }
}
