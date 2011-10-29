/*
Weave (Web-based Analysis and Visualization Environment)
Copyright (C) 2008-2011 University of Massachusetts Lowell

This file is a part of Weave.

Weave is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License, Version 3,
as published by the Free Software Foundation.

Weave is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.visualization.plotters
{
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.net.getClassByAlias;
	
	import weave.Weave;
	import weave.api.WeaveAPI;
	import weave.api.core.ILinkableObject;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.getCallbackCollection;
	import weave.api.linkSessionState;
	import weave.api.newDisposableChild;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.unlinkSessionState;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.SessionManager;
	import weave.data.AttributeColumns.AlwaysDefinedColumn;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.ColorColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.data.AttributeColumns.NumberColumn;
	import weave.data.AttributeColumns.SortedIndexColumn;
	import weave.data.BinningDefinitions.CategoryBinningDefinition;
	import weave.primitives.Bounds2D;
	import weave.primitives.ColorRamp;
	import weave.primitives.Range;
	import weave.utils.BitmapText;
	import weave.visualization.plotters.styles.DynamicLineStyle;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * CompoundBarChartPlotter
	 * 
	 * @author adufilie
	 * @author everyone and their uncle
	 */
	public class CompoundBarChartPlotter extends AbstractPlotter
	{
		public function CompoundBarChartPlotter()
		{
			init();
		}
		private function init():void
		{
			colorColumn.internalDynamicColumn.requestGlobalObject(Weave.DEFAULT_COLOR_COLUMN, ColorColumn, false);

			// get the keys from the sort column
			setKeySource(sortColumn);
			
			// Link the subset key filter to the filter of the private _filteredSortColumn.
			// This is so the records will be filtered before they are sorted in the _sortColumn.
			linkSessionState(_filteredKeySet.keyFilter, _filteredSortColumn.filter);
			
//			_groupByBins = newDisposableChild(this, BinnedColumn);
//			_groupByBins.binningDefinition.requestLocalObject(CategoryBinningDefinition, true);
//			registerSpatialProperty(groupBy, handleGroupBy);//todo: this won't work
			heightColumns.addGroupedCallback(this, heightColumnsGroupCallback);
			registerSpatialProperty(sortColumn);
			
			for each (var child:ILinkableObject in [
				colorColumn,
				Weave.properties.axisFontSize,
				Weave.properties.axisFontColor])
			{
				registerLinkableChild(this, child);
			}
			
			_binnedSortColumn.binningDefinition.requestLocalObject(CategoryBinningDefinition, true); // creates one bin per unique value in the sort column
		}
		
		/**
		 * This is the line style used to draw the outline of the rectangle.
		 */
		public const lineStyle:DynamicLineStyle = registerLinkableChild(this, new DynamicLineStyle(SolidLineStyle));
		public function get colorColumn():AlwaysDefinedColumn { return fillStyle.color; }
		// for now it is a solid fill style -- needs to be updated to be dynamic fill style later
		private const fillStyle:SolidFillStyle = newDisposableChild(this, SolidFillStyle);
		
		public const groupBySortColumn:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false)); // when this is true, we use _binnedSortColumn
		private var _binnedSortColumn:BinnedColumn = newSpatialProperty(BinnedColumn); // only used when groupBySortColumn is true
		private var _sortedIndexColumn:SortedIndexColumn = _binnedSortColumn.internalDynamicColumn.requestLocalObject(SortedIndexColumn, true); // this sorts the records
		private var _filteredSortColumn:FilteredColumn = _sortedIndexColumn.requestLocalObject(FilteredColumn, true); // filters before sorting
		public const positiveError:DynamicColumn = newSpatialProperty(DynamicColumn);
		public const negativeError:DynamicColumn = newSpatialProperty(DynamicColumn);
		public function get sortColumn():DynamicColumn { return _filteredSortColumn.internalDynamicColumn; }
		public const labelColumn:DynamicColumn = newLinkableChild(this, DynamicColumn);
		
		public function sortAxisLabelFunction(value:Number):String
		{
			if (groupBySortColumn.value)
				return _binnedSortColumn.deriveStringFromNumber(value);
			
			// get the sorted keys
			var sortedKeys:Array = _sortedIndexColumn.keys;
			
			// cast the input value from the axis to an int (not ideal at all, need to make this more robust)
			var sortedKeyIndex:int = int(value);
			
			// if this key is out of range, we have a problem
			if (sortedKeyIndex < 0 || sortedKeyIndex > sortedKeys.length-1)
				return "Invalid tick mark value: "+value.toString();
			
			// if the labelColumn doesn't have any data, use default label
			if (labelColumn.internalColumn == null)
				return null;
			
			// otherwise return the value from the labelColumn
			return labelColumn.getValueFromKey(sortedKeys[sortedKeyIndex], String);
		}
		
		public const chartColors:ColorRamp = registerLinkableChild(this, new ColorRamp(ColorRamp.getColorRampXMLByName("Doppler Radar"))); // bars get their color from here
		public const labelBarHeightPercentage:LinkableNumber = registerLinkableChild(this, new LinkableNumber(100));
		public const showValueLabels:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		
		public const heightColumns:LinkableHashMap = registerSpatialProperty(new LinkableHashMap(IAttributeColumn));
		public const horizontalMode:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false));
		public const zoomToSubset:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(true));
		public const barSpacing:LinkableNumber = registerSpatialProperty(new LinkableNumber(0));
		public const groupingMode:LinkableString = registerSpatialProperty(new LinkableString(STACK, verifyGroupingMode));
		public static const GROUP:String = 'group';
		public static const STACK:String = 'stack';
		public static const PERCENT_STACK:String = 'percentStack';
		private function verifyGroupingMode(mode:String):Boolean
		{
			return [GROUP, STACK, PERCENT_STACK].indexOf(mode) >= 0;
		}
		
		private function heightColumnsGroupCallback():void
		{
			var columns:Array = heightColumns.getObjects();
			
			if (sortColumn.internalColumn == null && columns.length > 0)
				sortColumn.copyLocalObject(columns[0]);
		}
		
		// this is a way to get the number of keys (bars or groups of bars) shown
		public function get numBarsShown():int { return _filteredKeySet.keys.length }
		
		public const valueLabelColor:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0));
		
		override public function drawPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			// save local copies of these values to speed up calculations
			var _barSpacing:Number = barSpacing.value;
			var _heightColumns:Array = heightColumns.getObjects().reverse();
			var _groupingMode:String = getActualGroupingMode();
			var _horizontalMode:Boolean = horizontalMode.value;
			var _groupBySortColumn:Boolean = groupBySortColumn.value;
			
			_bitmapText.textFormat.size = Weave.properties.axisFontSize.value;
			_bitmapText.textFormat.underline = Weave.properties.axisFontUnderline.value;
			_bitmapText.textFormat.size = Weave.properties.axisFontSize.value;
			_bitmapText.textFormat.color = valueLabelColor.value;
			
			// BEGIN template code for defining a drawPlot() function.
			//---------------------------------------------------------
			screenBounds.getRectangle(clipRectangle, true);
			clipRectangle.width++; // avoid clipping lines
			clipRectangle.height++; // avoid clipping lines
			var graphics:Graphics = tempShape.graphics;
			var count:int = 0;
			for (var iRecord:int = 0; iRecord < recordKeys.length; iRecord++)
			{
				var recordKey:IQualifiedKey = recordKeys[iRecord] as IQualifiedKey;
				
				//------------------------------------
				// BEGIN code to draw one compound bar
				//------------------------------------
				graphics.clear();
				
				var numHeightColumns:int = _heightColumns.length;
				var shouldDrawBarLabel:Boolean = showValueLabels.value && ((numHeightColumns >= 1 && _groupingMode == GROUP) || numHeightColumns == 1);
				
				// y coordinates depend on height columns
				var yMin:Number = 0; // start first bar at zero
				var yMax:Number = 0;
				var yNegativeMin:Number = 0;
				var yNegativeMax:Number = 0;
				
				// x coordinates depend on sorted index
				var sortedIndex:int;
				if (_groupBySortColumn)
					sortedIndex = _binnedSortColumn.getValueFromKey(recordKey, Number);
				else
					sortedIndex = _sortedIndexColumn.getValueFromKey(recordKey, Number);
				
				var spacing:Number = StandardLib.constrain(_barSpacing, 0, 1) / 2; // max distance between bar groups is 0.5 in data coordinates
				var xMin:Number = sortedIndex - 0.5 + spacing / 2;
				var xMax:Number = sortedIndex + 0.5 - spacing / 2;
				
				var recordWidth:Number = xMax - xMin;
				var groupSegmentWidth:Number = recordWidth / numHeightColumns;
				if (_groupBySortColumn)
				{
					// shrink down bars to fit in one groupSegmentWidth
					var keysInBin:Array = _binnedSortColumn.getKeysFromBinIndex(sortedIndex);
					xMin = xMin + keysInBin.indexOf(recordKey) / keysInBin.length * groupSegmentWidth;
					xMax = xMin + 1 / keysInBin.length * groupSegmentWidth;
					recordWidth /= keysInBin.length;
					groupSegmentWidth /= keysInBin.length;
				}
				
				var totalHeight:Number = 0;
				for (var hCount:int = 0; hCount < _heightColumns.length; hCount++)
				{
					var column:IAttributeColumn = _heightColumns[hCount] as IAttributeColumn;
					var h:Number = column.getValueFromKey(recordKey, Number);
					
					if (isNaN(h))
						continue;
					
					totalHeight = totalHeight + h;
				}
				
				// loop over height columns, incrementing y coordinates
				for (var i:int = 0; i < _heightColumns.length; i++)
				{
					//------------------------------------
					// BEGIN code to draw one bar segment
					//------------------------------------
					var heightColumn:IAttributeColumn = _heightColumns[i] as IAttributeColumn;
					// add this height to the current bar
					var height:Number = heightColumn.getValueFromKey(recordKey, Number);
					var heightMissing:Boolean = isNaN(height);
					if (heightMissing)
					{
						//if height is missing we set it to 0 for 100% stacked bar else
						// we assign average value of the column
						if (_groupingMode == PERCENT_STACK)
							height = 0;
						else
							height = WeaveAPI.StatisticsCache.getMean(heightColumn);		
					}
					if (isNaN(height)) // check again because getMean may return NaN
						height = 0;
					
					if (height >= 0)
					{
						//normalizing to 100% stack
						if (_groupingMode == PERCENT_STACK)
							yMax = yMin + (100 / totalHeight * height);
						else
							yMax = yMin + height;
					}
					else
					{
						if (_groupingMode == PERCENT_STACK)
							yNegativeMax = yNegativeMin + (100 / totalHeight * height);
						else
							yNegativeMax = yNegativeMin + height;
					}
					
					if (!heightMissing)
					{
						// bar starts at bar center - half width of the bar, plus the spacing between this and previous bar
						var barStart:Number = xMin;
						if (_groupingMode == GROUP)
							barStart += i / _heightColumns.length * groupSegmentWidth;
						
						if ( height >= 0)
						{
							// project data coordinates to screen coordinates
							if (_horizontalMode)
							{
								tempPoint.x = yMin; // swapped
								tempPoint.y = barStart;
							}
							else
							{
								tempPoint.x = barStart;
								tempPoint.y = yMin;
							}
						}
						else
						{
							if (_horizontalMode)
							{
								tempPoint.x = yNegativeMax; // swapped
								tempPoint.y = barStart;
							}
							else
							{
								tempPoint.x = barStart;
								tempPoint.y = yNegativeMax;
							}
						}
						// bar ends at bar center + half width of the bar, less the spacing between this and next bar
						var barEnd:Number = xMax;
						if (_groupingMode == GROUP)
							barEnd = barStart + groupSegmentWidth;
						
						dataBounds.projectPointTo(tempPoint, screenBounds);
						tempBounds.setMinPoint(tempPoint);
						
						if (height >= 0)
						{
							if (_horizontalMode)
							{
								tempPoint.x = yMax; // swapped
								tempPoint.y = barEnd;
							}
							else
							{
								tempPoint.x = barEnd;
								tempPoint.y = yMax;
							}
						}
						else
						{
							if (_horizontalMode)
							{
								tempPoint.x = yNegativeMin; // swapped
								tempPoint.y = barEnd;
							}
							else
							{
								tempPoint.x = barEnd;
								tempPoint.y = yNegativeMin;
							}
						}
						dataBounds.projectPointTo(tempPoint, screenBounds);
						tempBounds.setMaxPoint(tempPoint);
						
						//////////////////////////
						// BEGIN draw graphics
						//////////////////////////
						graphics.clear();
						
						var color:Number = chartColors.getColorFromNorm(i / (_heightColumns.length - 1));
						
						// if there is one column, act like a regular bar chart and color in with a chosen color
						if (_heightColumns.length == 1)
							fillStyle.beginFillStyle(recordKey, graphics);
							// otherwise use a pre-defined set of colors for each bar segment
						else
							graphics.beginFill(color, 1);
						
						
						lineStyle.beginLineStyle(recordKey, graphics);
						if(tempBounds.getHeight() == 0)
							graphics.lineStyle(0,0,0);
						
						graphics.drawRect(tempBounds.getXMin(), tempBounds.getYMin(), tempBounds.getWidth(), tempBounds.getHeight());
						
						graphics.endFill();
						destination.draw(tempShape, null, null, null, clipRectangle);
						//////////////////////////
						// END draw graphics
						//////////////////////////
					}						
					
					if (_groupingMode != GROUP)
					{
						// the next bar starts on top of this bar
						if (height >= 0)
							yMin = yMax;
						else
							yNegativeMin = yNegativeMax;
					}
					//------------------------------------
					// END code to draw one bar segment
					//------------------------------------
					
					//------------------------------------
					// BEGIN code to draw one bar value label (directly to BitmapData)
					//------------------------------------
					if (shouldDrawBarLabel && !heightMissing)
					{
						_bitmapText.text = heightColumn.getValueFromKey(recordKey, String);
						var percent:Number = isNaN(labelBarHeightPercentage.value) ? 1 : labelBarHeightPercentage.value / 100;
						if (!_horizontalMode)
						{
							tempPoint.x = (barStart + barEnd) / 2;
							if (height >= 0)
							{
								tempPoint.y = percent * yMax;
								_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_LEFT;
							}
							else
							{
								tempPoint.y = percent * yNegativeMax;
								_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_RIGHT;
							}
							_bitmapText.angle = 270;
							_bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_CENTER;
						}
						else
						{
							tempPoint.y = (barStart + barEnd) / 2;
							if (height >= 0)
							{
								tempPoint.x = percent * yMax;
								_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_LEFT;
							}
							else
							{
								tempPoint.x = percent * yNegativeMax;
								_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_RIGHT;
							}
							_bitmapText.angle = 0;
							_bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_CENTER;
						}
						dataBounds.projectPointTo(tempPoint, screenBounds);
						_bitmapText.x = tempPoint.x;
						_bitmapText.y = tempPoint.y;
						_bitmapText.draw(destination);
					}
					//------------------------------------
					// END code to draw one bar value label (directly to BitmapData)
					//------------------------------------
					
				}
				//------------------------------------
				// END code to draw one compound bar
				//------------------------------------
				
				//------------------------------------
				// BEGIN code to draw one error bar
				//------------------------------------
				if (_heightColumns.length == 1 && this.positiveError.internalColumn != null)
				{
					var errorPlusVal:Number = this.positiveError.getValueFromKey( recordKey, Number);
					var errorMinusVal:Number;
					if (this.negativeError.internalColumn != null)
					{
						errorMinusVal = this.negativeError.getValueFromKey( recordKey , Number);
					}
					else
					{
						errorMinusVal = errorPlusVal;
					}
					if (isFinite(errorPlusVal) && isFinite(errorMinusVal))
					{
						var center:Number = (barStart + barEnd) / 2;
						var width:Number = barEnd - barStart; 
						var left:Number = center - width / 4;
						var right:Number = center + width / 4;
						var top:Number, bottom:Number;
						if (height >= 0)
						{
							top = yMax + errorPlusVal;
							bottom = yMax - errorMinusVal;
						}
						else
						{
							top = yNegativeMax + errorPlusVal;
							bottom = yNegativeMax - errorMinusVal;
						}
						if (top != bottom)
						{
							var coords:Array = []; // each pair of 4 numbers represents a line segment to draw
							if (!_horizontalMode)
							{
								coords.push(left, top, right, top);
								coords.push(center, top, center, bottom);
								coords.push(left, bottom, right, bottom);
							}
							else
							{
								coords.push(top, left, top, right);
								coords.push(top, center, bottom, center);
								coords.push(bottom, left, bottom, right);
							}
							
							// BEGIN DRAW
							graphics.clear();
							for (i = 0; i < coords.length; i += 2) // loop over x,y coordinate pairs
							{
								tempPoint.x = coords[i];
								tempPoint.y = coords[i + 1];
								dataBounds.projectPointTo(tempPoint, screenBounds);
								if (i % 4 == 0) // every other pair
									graphics.moveTo(tempPoint.x, tempPoint.y);
								else
									graphics.lineTo(tempPoint.x, tempPoint.y);
							}
							destination.draw(tempShape, null, null, null, clipRectangle);
							// END DRAW
						}
					}
				}
				//------------------------------------
				// END code to draw one error bar
				//------------------------------------
			}
			
			//---------------------------------------------------------
			// END template code
		}
		
		private const _bitmapText:BitmapText = new BitmapText();
		
		/**
		 * This function takes into account whether or not there is only a single height column specified.
		 * @return The actual grouping mode, which may differ from the session state of the groupingMode variable.
		 */
		public function getActualGroupingMode():String
		{
			return heightColumns.getNames().length == 1 ? STACK : groupingMode.value;
		}
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey):Array
		{
			var errorBounds:IBounds2D = getReusableBounds(); // the bounds of key + error bars
			var keyBounds:IBounds2D = getReusableBounds(); // the bounds of just the key
			var _groupingMode:String = getActualGroupingMode();
			var errorColumnsIncluded:Boolean = false; // this value is true when the i = 1 and i=2 columns are error columns
			var _groupBySortColumn:Boolean = groupBySortColumn.value;
			var _heightColumns:Array = heightColumns.getObjects();
			
			// bar position depends on sorted index
			var sortedIndex:int;
			if (_groupBySortColumn)
				sortedIndex = _binnedSortColumn.getValueFromKey(recordKey, Number);
			else
				sortedIndex = _sortedIndexColumn.getValueFromKey(recordKey, Number);
			var minPos:Number = sortedIndex - 0.5;
			var maxPos:Number = sortedIndex + 0.5;
			var recordWidth:Number = maxPos - minPos;
			if (_groupBySortColumn)
			{
				// shrink down bars to fit in one groupSegmentWidth
				var groupSegmentWidth:Number = recordWidth / _heightColumns.length;
				var keysInBin:Array = _binnedSortColumn.getKeysFromBinIndex(sortedIndex);
				if (keysInBin)
				{
					minPos = minPos + keysInBin.indexOf(recordKey) / keysInBin.length * groupSegmentWidth;
					maxPos = minPos + 1 / keysInBin.length * groupSegmentWidth;
					recordWidth /= keysInBin.length;
				}
			}
			// this bar is between minPos and maxPos in the x or y range
			if (horizontalMode.value)
				keyBounds.setYRange(minPos, maxPos);
			else
				keyBounds.setXRange(minPos, maxPos);
			
			if (_heightColumns.length == 1)
			{
				_heightColumns.push(positiveError);
				_heightColumns.push(negativeError);
				errorColumnsIncluded = true; 
			}
			
			tempRange.setRange(0, 0); // bar starts at zero
			
			
			if (_groupingMode == PERCENT_STACK)
			{
				tempRange.begin = 0;
				tempRange.end = 100;
			}
			else
			{
				// loop over height columns, incrementing y coordinates
				for (var i:int = 0; i < _heightColumns.length; i++)
				{
					var heightColumn:IAttributeColumn = _heightColumns[i] as IAttributeColumn;
					var height:Number = heightColumn.getValueFromKey(recordKey, Number);
					
					if (heightColumn == positiveError)
					{
						if (tempRange.end == 0)
							continue;
					}
					if (heightColumn == negativeError)
					{
						if (isNaN(height))
							height = positiveError.getValueFromKey(recordKey, Number);
						if (tempRange.begin < 0)
							height = -height;
						else
							continue;
					}
					
					if (isNaN(height))
						height = WeaveAPI.StatisticsCache.getMean(heightColumn);
					if (isNaN(height))
						height = 0;
					if (_groupingMode == GROUP)
					{
						tempRange.includeInRange(height);
					}
					else
					{
						// add this height to the current bar, so add to y value
						// avoid adding NaN to y coordinate (because result will be NaN).
						if (isFinite(height))
						{
							if (height >= 0)
								tempRange.end += height;
							else
								tempRange.begin += height;
						}
					}
					
					// if there are no error columns in _heightColumns, 
					// or if there are error columns (which occurs only if there is one height column),
					// we want to include the current range in keyBounds
					if (!errorColumnsIncluded || i == 0) 
					{
						if (horizontalMode.value)
							keyBounds.setXRange(tempRange.begin, tempRange.end);
						else
							keyBounds.setYRange(tempRange.begin, tempRange.end);
					}
				}
			}
			
			if (horizontalMode.value)
				errorBounds.setBounds(tempRange.begin, minPos, tempRange.end, maxPos); // x,y swapped
			else
				errorBounds.setBounds(minPos, tempRange.begin, maxPos, tempRange.end);
			
			return [keyBounds, errorBounds];
		}
		
		override public function getBackgroundDataBounds():IBounds2D
		{
			var bounds:IBounds2D = getReusableBounds();
			if (!zoomToSubset.value)
			{
				tempRange.setRange(0, 0);
				var _heightColumns:Array = heightColumns.getObjects();
				var _groupingMode:String = getActualGroupingMode();
				for each (var column:IAttributeColumn in _heightColumns)
				{
					if (_groupingMode == GROUP)
					{
						tempRange.includeInRange(WeaveAPI.StatisticsCache.getMin(column));
						tempRange.includeInRange(WeaveAPI.StatisticsCache.getMax(column));
					}
					else if (_groupingMode == PERCENT_STACK)
					{
						tempRange.begin = 0;
						tempRange.end = 100;
					}
					else
					{
						var max:Number = WeaveAPI.StatisticsCache.getMax(column);
						var min:Number = WeaveAPI.StatisticsCache.getMin(column);
						if (_heightColumns.length == 1)
						{
							var errorMax:Number = WeaveAPI.StatisticsCache.getMax(positiveError);
							var errorMin:Number = -WeaveAPI.StatisticsCache.getMax(negativeError);
							if (isNaN(errorMin))
								errorMin = errorMax;
							if (max > 0 && errorMax > 0)
								max += errorMax;
							if (min < 0 && errorMin > 0)
								min -= errorMin;
						}
						if (max > 0)
							tempRange.end += max;
						if (min < 0)
							tempRange.begin += min;
					}
				}
				
				if (horizontalMode.value) // x range
					bounds.setBounds(tempRange.begin, NaN, tempRange.end, NaN);
				else // y range
					bounds.setBounds(NaN, tempRange.begin, NaN, tempRange.end);
			}
			return bounds;
		}
		
		
		
		
		private const tempRange:Range = new Range(); // reusable temporary object
		private const tempPoint:Point = new Point(); // reusable temporary object
		private const tempBounds:IBounds2D = new Bounds2D(); // reusable temporary object
		
		// backwards compatibility
		[Deprecated(replacement='groupingMode')] public function set groupMode(value:Boolean):void { groupingMode.value = value ? GROUP : STACK; }
	}
}
