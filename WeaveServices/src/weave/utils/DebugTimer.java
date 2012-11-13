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

package weave.utils;

/**
 * DebugTimer
 * 
 * @author Andy Dufilie
 */
public class DebugTimer
{
	private long startTime;
	private StringBuilder debugText = new StringBuilder();
	
	public DebugTimer()
	{
		start();
	}
	
	public void start()
	{
		startTime = System.currentTimeMillis();
	}
	
	public long get()
	{
		return System.currentTimeMillis() - startTime;
	}
	
	public void lap(String str)
	{
		String time = "" + get();
		int indentLength = Math.max(0, 5 - time.length());
		debugText.append( "    ", 0, indentLength ).append( time ).append( " ms: " ).append( str ).append( '\n' );
		start();
	}
	
	public void report(String lapText)
	{
		lap(lapText);
		report();
	}
	
	public void report()
	{
		System.out.println(debugText);
		reset();
	}
	
	public void reset()
	{
		debugText.setLength(0);
	}
	
	////////////////////////////////////////
	// static instance ... not thread safe
	
	private static DebugTimer instance = new DebugTimer();
	public static void go()
	{
		instance.start();
	}
	public static void stop(String description)
	{
		if (instance.get() > 0)
			instance.report(description);
		else
			instance.reset();
	}
}
