/*
	This Source Code Form is subject to the terms of the
	Mozilla Public License, v. 2.0. If a copy of the MPL
	was not distributed with this file, You can obtain
	one at https://mozilla.org/MPL/2.0/.
*/
package
{
	import weavejs.api.core.ILinkableVariable;
	import weavejs.api.data.IAttributeColumn;
	import weavejs.api.data.IPrimitiveColumn;
	import weavejs.api.data.IQualifiedKey;
	import weavejs.api.data.IWeaveTreeNodeWithPathFinding;
	import weavejs.api.data.IDataSource;
	import weavejs.core.EventCallbackCollection;
	import weavejs.core.LinkableBoolean;
	import weavejs.core.LinkableCallbackScript;
	import weavejs.core.LinkableDynamicObject;
	import weavejs.core.LinkableFunction;
	import weavejs.core.LinkableHashMap;
	import weavejs.core.LinkableNumber;
import weavejs.core.LinkablePromise;
import weavejs.core.LinkableString;
	import weavejs.core.LinkableSynchronizer;
	import weavejs.core.LinkableVariable;
	import weavejs.core.LinkableWatcher;
	import weavejs.core.SessionStateLog;
	import weavejs.data.bin.AbstractBinningDefinition;
	import weavejs.data.bin.CategoryBinningDefinition;
	import weavejs.data.bin.CustomSplitBinningDefinition;
	import weavejs.data.bin.DynamicBinningDefinition;
	import weavejs.data.bin.EqualIntervalBinningDefinition;
	import weavejs.data.bin.ExplicitBinningDefinition;
	import weavejs.data.bin.NaturalJenksBinningDefinition;
	import weavejs.data.bin.NumberClassifier;
	import weavejs.data.bin.QuantileBinningDefinition;
	import weavejs.data.bin.SimpleBinningDefinition;
	import weavejs.data.bin.SingleValueClassifier;
	import weavejs.data.bin.StandardDeviationBinningDefinition;
	import weavejs.data.bin.StringClassifier;
	import weavejs.data.column.AbstractAttributeColumn;
	import weavejs.data.column.AlwaysDefinedColumn;
	import weavejs.data.column.BinnedColumn;
	import weavejs.data.column.CSVColumn;
	import weavejs.data.column.ColorColumn;
	import weavejs.data.column.ColumnDataTask;
	import weavejs.data.column.CombinedColumn;
	import weavejs.data.column.DateColumn;
	import weavejs.data.column.DynamicColumn;
	import weavejs.data.column.EquationColumn;
	import weavejs.data.column.ExtendedDynamicColumn;
	import weavejs.data.column.FilteredColumn;
	import weavejs.data.column.GeometryColumn;
	import weavejs.data.column.KeyColumn;
	import weavejs.data.column.NormalizedColumn;
	import weavejs.data.column.NumberColumn;
	import weavejs.data.column.ProxyColumn;
	import weavejs.data.column.ReferencedColumn;
	import weavejs.data.column.SecondaryKeyNumColumn;
	import weavejs.data.column.SortedColumn;
	import weavejs.data.column.SortedIndexColumn;
	import weavejs.data.column.StringColumn;
	import weavejs.data.column.StringLookup;
	import weavejs.data.hierarchy.WeaveRootDataTreeNode;
	import weavejs.data.key.DynamicKeyFilter;
	import weavejs.data.key.DynamicKeySet;
	import weavejs.data.key.FilteredKeySet;
	import weavejs.data.key.KeyFilter;
	import weavejs.data.key.KeySet;
	import weavejs.data.key.KeySetCallbackInterface;
	import weavejs.data.key.KeySetUnion;
	import weavejs.data.key.SortedKeySet;
import weavejs.geom.GeometryStreamDecoder;
import weavejs.geom.TempHack_SolidFillStyle;
	import weavejs.geom.TempHack_SolidLineStyle;
	import weavejs.geom.Range;
	import weavejs.geom.ZoomBounds;
	import weavejs.geom.LinkableBounds2D;
	import weavejs.path.ExternalTool;
	import weavejs.util.BackwardsCompatibility;
	import weavejs.util.JS;
import weavejs.util.JSByteArray;
import weavejs.util.WeaveMenuItem;

	import org.vanrijkom.dbf.DbfError;
	import org.vanrijkom.dbf.DbfField;
	import org.vanrijkom.dbf.DbfFilter;
	import org.vanrijkom.dbf.DbfHeader;
	import org.vanrijkom.dbf.DbfRecord;
	import org.vanrijkom.dbf.DbfTools;
	import org.vanrijkom.shp.ShpError;
	import org.vanrijkom.shp.ShpHeader;
	import org.vanrijkom.shp.ShpObject;
	import org.vanrijkom.shp.ShpPoint;
	import org.vanrijkom.shp.ShpPointZ;
	import org.vanrijkom.shp.ShpPolygon;
	import org.vanrijkom.shp.ShpRecord;
	import org.vanrijkom.shp.ShpTools;
	import org.vanrijkom.shp.ShpType;

	public class WeaveTest
	{
		private static const dependencies:Array = [
			ILinkableVariable,
			LinkableNumber,LinkableString,LinkableBoolean,LinkableVariable,
			LinkableHashMap,LinkableDynamicObject,LinkableWatcher,
			LinkableCallbackScript,LinkableSynchronizer,LinkableFunction,

			DynamicKeyFilter,
			DynamicKeySet,
			FilteredKeySet,
			KeyFilter,
			KeySet,
			KeySetCallbackInterface,
			KeySetUnion,
			SortedKeySet,
			
			AbstractBinningDefinition,
			CategoryBinningDefinition,
			CustomSplitBinningDefinition,
			DynamicBinningDefinition,
			EqualIntervalBinningDefinition,
			ExplicitBinningDefinition,
			NaturalJenksBinningDefinition,
			NumberClassifier,
			QuantileBinningDefinition,
			SimpleBinningDefinition,
			SingleValueClassifier,
			StandardDeviationBinningDefinition,
			StringClassifier,
			
			AbstractAttributeColumn,
			AlwaysDefinedColumn,
			BinnedColumn,
			ColorColumn,
			ColumnDataTask,
			CombinedColumn,
			CSVColumn,
			DateColumn,
			DynamicColumn,
			EquationColumn,
			ExtendedDynamicColumn,
			FilteredColumn,
			GeometryColumn,
			NormalizedColumn,
			NumberColumn,
			ProxyColumn,
			ReferencedColumn,
			SecondaryKeyNumColumn,
			SortedColumn,
			SortedIndexColumn,
			StringColumn,
			StringLookup,
			KeyColumn,
			ExternalTool,
			WeaveMenuItem,
			ZoomBounds,
			WeaveRootDataTreeNode,
			TempHack_SolidLineStyle,
			TempHack_SolidFillStyle,
			EventCallbackCollection,
			BackwardsCompatibility,
			Range,
			LinkableBounds2D,
			DbfError,
			DbfField,
			DbfFilter,
			DbfHeader,
			DbfRecord,
			DbfTools,
			ShpError,
			ShpHeader,
			ShpObject,
			ShpPoint,
			ShpPointZ,
			ShpPolygon,
			ShpRecord,
			ShpTools,
			ShpType,
			IPrimitiveColumn,
			IWeaveTreeNodeWithPathFinding,
			LinkablePromise,
			JSByteArray,
			GeometryStreamDecoder,
			//EntityNodeSearch, //TODO - resolve circular dependency issue
			null
		];
		
		public static function test(weave:Weave):void
		{
			SessionStateLog.debug = true;
			
			var lv:LinkableString = weave.root.requestObject('ls', LinkableString, false);
			lv.addImmediateCallback(weave, function():void { JS.log('immediate', lv.state); }, true);
			lv.addGroupedCallback(weave, function():void { JS.log('grouped', lv.state); }, true);
			lv.state = 'hello';
			lv.state = 'hello';
			weave.path('ls').state('hi').addCallback(null, function():void { JS.log(this+'', this.getState()); });
			lv.state = 'world';
			weave.path('script')
				.request('LinkableCallbackScript')
				.state('script', 'console.log(Weave.className(this), this.get("ldo").target.value, Weave.getState(this));')
				.push('variables', 'ldo')
					.request('LinkableDynamicObject')
					.state(['ls']);
			lv.state = '2';
			lv.state = 2;
			lv.state = '3';
			weave.path('ls2').request('LinkableString');
			weave.path('sync')
				.request('LinkableSynchronizer')
				.state('primaryPath', ['ls'])
				.state('primaryTransform', 'state + "_transformed"')
				.state('secondaryPath', ['ls2'])
				.call(function():void { JS.log(this.weave.path('ls2').getState()) });
			var print:Function = function():void {
				JS.log("column", this.getMetadata("title"));
				for each (var key:IQualifiedKey in this.keys)
					JS.log(key, this.getValueFromKey(key), this.getValueFromKey(key, Number), this.getValueFromKey(key, String));
			};
		}
	}
}
