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
	
	import mx.collections.ArrayCollection;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ArrayUtil;
	
	import weave.Weave;
	import weave.api.disposeObjects;
	import weave.api.getCallbackCollection;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.primitives.Range;
	import weave.services.WeaveRServlet;
	import weave.services.addAsyncResponder;
	import weave.services.beans.RResult;
	import weave.utils.ColumnUtils;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * RegressionLinePlotter
	 * 
	 * @author kmanohar
	 */
	public class RegressionLinePlotter extends AbstractPlotter
	{
		public function RegressionLinePlotter()
		{
			Weave.properties.rServiceURL.addImmediateCallback(this, resetRService, true);
			spatialCallbacks.addImmediateCallback(this, resetRegressionLine );
			spatialCallbacks.addGroupedCallback(this, calculateRRegression );
			setColumnKeySources([xColumn, yColumn]);
			
			// hack to fix old session states
			_filteredKeySet.addImmediateCallback(this, function():void {
				if (_filteredKeySet.keyFilter.internalObject == null)
					_filteredKeySet.keyFilter.globalName = Weave.DEFAULT_SUBSET_KEYFILTER;
			});
		}
		
		public const drawLine:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false));
		
		public const xColumn:DynamicColumn = newSpatialProperty(DynamicColumn);
		public const yColumn:DynamicColumn = newSpatialProperty(DynamicColumn);
		
		public const lineStyle:SolidLineStyle = newLinkableChild(this, SolidLineStyle);

		private var rService:WeaveRServlet = null;
		
		private function resetRService():void
		{
			rService = new WeaveRServlet(Weave.properties.rServiceURL.value);
		}
		
		private function resetRegressionLine():void
		{
			coefficients = null;
			rSquared = 0;
		}
		private function calculateRRegression():void
		{
				var Rstring:String = null;
				var dataXY:Array = null;
				var token:AsyncToken = null;
				
			if (currentTrendline.value == LINEAR)
			{
				//trace( "calculateRegression() " + xColumn.toString() );
				Rstring = "fit <- lm(y~x)\n"
					+"coef <- coefficients(fit)\n" 
					+"rSquared <- summary(fit)$r.squared\n";
			}
				
			if (currentTrendline.value == POLYNOMIAL)
			{
				Rstring = "fit <- lm(y ~ poly(x, " + polynomialDegree.value.toString() + ", raw = TRUE))\n"
					+"coef <- coefficients(fit)\n" 
					+"rSquared <- summary(fit)$r.squared\n";			
			}
			
			if (currentTrendline.value == LOGARITHMIC)
			{
				Rstring = "fit <- lm( y ~ log(x) )\n" 
					+"coef <- coefficients(fit)\n" 
					+"rSquared <- summary(fit)$r.squared\n";
			}
			
			
			if (currentTrendline.value == EXPONENTIAL)
			{
				Rstring = "fit <- lm( log(y) ~ x )\n" 
					+"coef <- coefficients(fit)\n" 
					+"rSquared <- summary(fit)$r.squared\n";	
			}
			
			if (currentTrendline.value == POWER)
			{
				Rstring = "fit <- lm( log(y) ~ x )\n" 
					+"coef <- coefficients(fit)\n" 
					+"rSquared <- summary(fit)$r.squared\n";
			}
			
			dataXY = ColumnUtils.joinColumns([xColumn, yColumn], Number, false, filteredKeySet.keys);
			
			// sends a request to Rserve to calculate the coefficients of the regression lograrithmic function to xColumn and yColumn
			token = rService.runScript(null, ["x","y"], [dataXY[1], dataXY[2]], ["coef"], Rstring, "", false, false, false);
			addAsyncResponder(token, handleLinearRegressionResult, handleLinearRegressionFault, ++requestID);

		}
		
		private var requestID:int = 0; // ID of the latest request, used to ignore old results
		private function handleLinearRegressionResult(event:ResultEvent, token:Object=null):void
		{
			if (this.requestID != int(token))
			{
				// ignore outdated results
				return;
			}
			
			var Robj:Array = event.result as Array;
			if (Robj == null)
				return;
			
			var RresultArray:Array = new Array();
			
			//collecting Objects of type RResult(Should Match result object from Java side)
			for(var i:int = 0; i<Robj.length; i++)
			{
				var rResult:RResult = new RResult(Robj[i]);
				RresultArray.push(rResult);				
			}
			
//			if (RresultArray.length > 1) // ToDo ??? why?
			if (RresultArray.length > 1)
			{
				coefficients = ((RresultArray[0] as RResult).value as Array != coefficients) ? (RresultArray[0] as RResult).value as Array : null;
				rSquared = Number((RresultArray[2] as RResult).value);
				getCallbackCollection(this).triggerCallbacks();	
			}
		}
		
		private function handleLinearRegressionFault(event:FaultEvent, token:Object = null):void
		{
			if (this.requestID != int(token))
			{
				// ignore outdated results
				return;
			}
			
			reportError(event);
			coefficients = null;
			rSquared = NaN;
			getCallbackCollection(this).triggerCallbacks();
		}
		
		public function getCoefficients():Array { return coefficients; }		
		public function getrSquared():Number { return rSquared; }
		
		private var rSquared:Number = NaN;
		private var coefficients:Array = null;
		
		private var tempRange:Range = new Range();
		private var tempPoint:Point = new Point();
		private var tempPoint2:Point = new Point();

		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var g:Graphics = tempShape.graphics;
			g.clear();
			
			if(currentTrendline.value == LINEAR)
			{
				
				points = new Vector.<Number>;
				drawCommand = new Vector.<int>;

				g.clear();
//				if(!isNaN(intercept))
//				{
//					tempPoint.x = dataBounds.getXMin();
//					tempPoint2.x = dataBounds.getXMax();
//					
//					tempPoint.y = (slope*tempPoint.x)+intercept;
//					tempPoint2.y = (slope*tempPoint2.x)+intercept;
//					
//					tempRange.setRange( dataBounds.getYMin(), dataBounds.getYMax() );
//					
//					// constrain yMin to be within y range and derive xMin from constrained yMin
//					tempPoint.x = tempPoint.x + (tempRange.constrain(tempPoint.y) - tempPoint.y) / slope;
//					tempPoint.y = tempRange.constrain(tempPoint.y);
//					
//					// constrain yMax to be within y range and derive xMax from constrained yMax
//					tempPoint2.x = tempPoint.x + (tempRange.constrain(tempPoint2.y) - tempPoint.y) / slope;
//					tempPoint2.y = tempRange.constrain(tempPoint2.y);
//					
//					dataBounds.projectPointTo(tempPoint,screenBounds);
//					dataBounds.projectPointTo(tempPoint2,screenBounds);
//					lineStyle.beginLineStyle(null,g);
//					//g.lineStyle(lineThickness.value, lineColor.value,lineAlpha.value,true,LineScaleMode.NONE);
//					g.moveTo(tempPoint.x,tempPoint.y);
//					g.lineTo(tempPoint2.x,tempPoint2.y);
//					
//					destination.draw(tempShape);
//				}
			}	
			else 
			{
				
				if (coefficients != null)
				{
					// ToDo Use screenBounds to determine how many points should be drawn
					// Preprocess coefficients ==> It might return NaN in higher degree
					// where it should in fact be 0.
					for (var i:int = 0; i < coefficients.length; i++)
					{
						if (isNaN(coefficients[i]))
						{
							coefficients[i] = 0;
						}
					}

					var flag:Boolean = true;
					 for (var x:int = dataBounds.getXMin(); x < dataBounds.getXMax(); x++)
					 {
						tempPoint.x = x;
						
						tempPoint.y = 
						tempPoint.y = evalFunction(currentTrendline.value, coefficients, x);
						if (isNaN(tempPoint.y))
						{
							// technically this is a problem
						}
						
						dataBounds.projectPointTo(tempPoint, screenBounds);
						points.push(tempPoint.x);
						points.push(tempPoint.y);
						
						if (flag == true)
						{
							drawCommand.push(1);
							flag = false;
						}
//						else if (tempPoint.y > screenBounds.getYMax() || tempPoint.y < screenBounds.getYMin())
//							drawCommand.push(1);
						else drawCommand.push(2);
					}

					g.lineStyle(1);
					g.drawPath(drawCommand, points);					
					
					destination.draw(tempShape);
				}
			}
		}
		override public function dispose():void
		{
			super.dispose();
			requestID = 0; // forces all results from previous requests to be ignored
		}
		
		
		private var points:Vector.<Number> = null;
		private var drawCommand:Vector.<int> = null;
		
		
		/**
		 * 	@author Yen-Fu 
		 *	This function evaluates a polynomial, given the coefficients (a, b, c,..) and the value x. 
		 * 	ax^n-1+bx^n-2+...
		 **/
		private function evalFunction(type:String, coefficients:Array, xValue:Number):Number
		{
			
			if (type == POLYNOMIAL) 
			{
				var result:Number = 0;
				var degree:int = coefficients.length - 1;
				for (var i:int = 0; i <= degree; i++)
				{
					result += coefficients[i] * Math.pow(xValue, degree - i);
				}
			
				return result;
			}
			else if (type == LOGARITHMIC) 
			{				
				return coefficients[0]*Math.log(xValue) + coefficients[1];
			}
			
			else if (type == EXPONENTIAL) 
			{
				return coefficients[0]*Math.exp(xValue) + coefficients[1];
			}
			else if (type == POWER) 
			{
				return coefficients[0]*Math.pow(xValue, coefficients[1]);	
			}
			else
			{
				return NaN;
			}
		}
			
		// Trendlines
		public const polynomialDegree:LinkableNumber = registerLinkableChild(this, new LinkableNumber(2), calculateRRegression);
		public const currentTrendline:LinkableString = registerLinkableChild(this, new LinkableString(""), calculateRRegression);

		[Bindable] public var trendlines:Array = [LINEAR, POLYNOMIAL, LOGARITHMIC, EXPONENTIAL, POWER];
		public static const LINEAR:String = "Linear";
		public static const POLYNOMIAL:String = "Polynomial";
		public static const LOGARITHMIC:String = "Logarithmic";
		public static const EXPONENTIAL:String = "Exponential";
		public static const POWER:String = "Power";
	}
}
