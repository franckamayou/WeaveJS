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

package weave.config;

import java.rmi.RemoteException;
import java.security.InvalidParameterException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

import weave.config.ConnectionConfig.DatabaseConfigInfo;
import weave.config.DataConfig.DataEntity;
import weave.config.DataConfig.DataEntityMetadata;
import weave.config.DataConfig.DataType;
import weave.config.DataConfig.PrivateMetadata;
import weave.config.DataConfig.PublicMetadata;
import weave.utils.ListUtils;
import weave.utils.SQLUtils;
import weave.utils.ProgressManager;

/**
 * This class is responsible for migrating from the old SQL config format to a DataConfig object.
 * 
 * @author Andy Dufilie
 */

@Deprecated public class DeprecatedConfig
{
	public static void migrate(ConnectionConfig connConfig, DataConfig dataConfig, ProgressManager progress) throws RemoteException
	{
		final int TOTAL_STEPS = 4;
		int step = 0;
		int total;
		String[] columnNames;
		Connection conn = null;
		Statement stmt = null;
		ResultSet resultSet = null;
		try
		{
			conn = connConfig.getAdminConnection(); // this will fail if DatabaseConfigInfo is missing
			DatabaseConfigInfo dbInfo = connConfig.getDatabaseConfigInfo();
			stmt = conn.createStatement();
			conn.setAutoCommit(false);
			
			/////////////////////////////
			
			// check for problems
			if (dbInfo == null)
				throw new InvalidParameterException("databaseConfig missing");
			if (dbInfo.schema == null || dbInfo.schema.length() == 0)
				throw new InvalidParameterException("DatabaseConfig: Schema not specified.");
			if (dbInfo.geometryConfigTable == null || dbInfo.geometryConfigTable.length() == 0)
				throw new InvalidParameterException("DatabaseConfig: Geometry metadata table name not specified.");
			if (dbInfo.dataConfigTable == null || dbInfo.dataConfigTable.length() == 0)
				throw new InvalidParameterException("DatabaseConfig: Column metadata table name not specified.");
			
			// init temporary lookup tables
			Map<String,String> geomKeyTypeLookup = new HashMap<String,String>();
			Map<String,Integer> tableIdLookup = new HashMap<String,Integer>();
			Map<String,DataEntityMetadata> tableMetadataLookup = new HashMap<String,DataEntityMetadata>();
			
			String quotedOldMetadataTable = SQLUtils.quoteSchemaTable(conn, dbInfo.schema, OLD_METADATA_TABLE);
			String quotedDataConfigTable = SQLUtils.quoteSchemaTable(conn, dbInfo.schema, dbInfo.dataConfigTable);
			String quotedGeometryConfigTable = SQLUtils.quoteSchemaTable(conn, dbInfo.schema, dbInfo.geometryConfigTable);
			
			/////////////////////////////
			// 1. get dublin core metadata for data tables
			
			progress.beginStep("Retrieving old dataset metadata", ++step, TOTAL_STEPS, 0);
			if (SQLUtils.tableExists(conn, dbInfo.schema, OLD_METADATA_TABLE))
			{
				resultSet = stmt.executeQuery(String.format("SELECT * FROM %s", quotedOldMetadataTable));
				while (resultSet.next())
				{
					String tableName = resultSet.getString(OLD_METADATA_COLUMN_ID);
					String property = resultSet.getString(OLD_METADATA_COLUMN_PROPERTY);
					String value = resultSet.getString(OLD_METADATA_COLUMN_VALUE);
					
					if (!tableMetadataLookup.containsKey(tableName))
						tableMetadataLookup.put(tableName, new DataEntityMetadata());
					DataEntityMetadata metadata = tableMetadataLookup.get(tableName);
					metadata.publicMetadata.put(property, value);
				}
				SQLUtils.cleanup(resultSet);
			}
			
			/////////////////////////////
			// 2. get the set of unique dataTable names, create entities for them and remember the corresponding id numbers
			
			total = getSingleIntFromQuery(stmt, String.format("SELECT COUNT(DISTINCT %s) FROM %s", PublicMetadata_DATATABLE, quotedDataConfigTable));
			resultSet = stmt.executeQuery(String.format("SELECT DISTINCT %s FROM %s", PublicMetadata_DATATABLE, quotedDataConfigTable));
			progress.beginStep("Generating table entities", ++step, TOTAL_STEPS, total);
			while (resultSet.next())
			{
				String tableName = resultSet.getString(PublicMetadata_DATATABLE);
				// get or create metadata
				DataEntityMetadata metadata = tableMetadataLookup.get(tableName);
				if (metadata == null)
					metadata = new DataEntityMetadata();
				
				// copy tableName to "title" property if missing
				if (!metadata.publicMetadata.containsKey(PublicMetadata.TITLE))
					metadata.publicMetadata.put(PublicMetadata.TITLE, tableName);
				
				// create the data table entity and remember the new id
				int tableId = dataConfig.addEntity(DataEntity.TYPE_DATATABLE, metadata);
				tableIdLookup.put(tableName, tableId);
                progress.tick();
			}
			SQLUtils.cleanup(resultSet);
			
			/////////////////////////////
			// 3. migrate geometry collections
			
			total = getSingleIntFromQuery(stmt, String.format("SELECT COUNT(*) FROM %s", quotedGeometryConfigTable));
			resultSet = stmt.executeQuery(String.format("SELECT * FROM %s", quotedGeometryConfigTable));
			columnNames = SQLUtils.getColumnNamesFromResultSet(resultSet);
			progress.beginStep("Migrating geometry collections", ++step, TOTAL_STEPS, total);
			while (resultSet.next())
			{
				
				
				
				if(true)
					break; // TEMPORARY
				
				
				
				
				
				
				Map<String,String> geomRecord = getRecord(resultSet, columnNames);
				
				// save name-to-keyType mapping for later
				String name = geomRecord.get(PublicMetadata_NAME);
				String keyType = geomRecord.get(PublicMetadata.KEYTYPE);
				geomKeyTypeLookup.put(name, keyType);
				
				// copy "name" to "title"
				geomRecord.put(PublicMetadata.TITLE, name);
				// set dataType appropriately
				geomRecord.put(PublicMetadata.DATATYPE, DataType.GEOMETRY);
				// rename "schema" to "sqlSchema"
				geomRecord.put(PrivateMetadata.SQLSCHEMA, geomRecord.remove(PrivateMetadata_SCHEMA));
				// rename "tablePrefix" to "sqlTablePrefix"
				geomRecord.put(PrivateMetadata.SQLTABLEPREFIX, geomRecord.remove(PrivateMetadata_TABLEPREFIX));
				
				// if there is a dataTable with the same title, add the geometry as a column under that table.
				Integer parentId = tableIdLookup.get(name);
				if (parentId == null)
					parentId = -1;
				
				// create an entity for the geometry column
				DataEntityMetadata geomMetadata = toDataEntityMetadata(geomRecord);
				int col_id = dataConfig.addEntity(DataEntity.TYPE_COLUMN, geomMetadata);
                dataConfig.addChild(col_id, parentId, 0);
				progress.tick();
			}
			SQLUtils.cleanup(resultSet);
			
			/////////////////////////////
			// 4. migrate columns
			
			total = getSingleIntFromQuery(stmt, String.format("SELECT COUNT(*) FROM %s", quotedDataConfigTable));
			resultSet = stmt.executeQuery(String.format("SELECT * FROM %s", quotedDataConfigTable));
			columnNames = SQLUtils.getColumnNamesFromResultSet(resultSet);
			progress.beginStep("Migrating attribute columns", ++step, TOTAL_STEPS, total);
			while (resultSet.next())
			{
				Map<String,String> columnRecord = getRecord(resultSet, columnNames);
				
				// if key type isn't specified but geometryCollection is, use the keyType of the geometry collection.
				String keyType = columnRecord.get(PublicMetadata.KEYTYPE);
				String geom = columnRecord.get(PublicMetadata_GEOMETRYCOLLECTION);
				if (isEmpty(keyType) && !isEmpty(geom))
					columnRecord.put(PublicMetadata.KEYTYPE, geomKeyTypeLookup.get(geom));
				
				String title = columnRecord.get(PublicMetadata.TITLE);
				String name = columnRecord.get(PublicMetadata_NAME);
				String year = columnRecord.get(PublicMetadata_YEAR);
				// make sure title is set
				if (isEmpty(title))
				{
					title = isEmpty(year) ? name : String.format("%s (%s)", name, year);
					columnRecord.put(PublicMetadata.TITLE, title);
				}
				
				// get the id corresponding to the table
				String dataTableName = columnRecord.get(PublicMetadata_DATATABLE);
				int tableId = tableIdLookup.get(dataTableName);
				
				// create the column entity as a child of the table
				DataEntityMetadata columnMetadata = toDataEntityMetadata(columnRecord);
				int col_id = dataConfig.addEntity(DataEntity.TYPE_COLUMN, columnMetadata);
				dataConfig.addChild(col_id, tableId, 0);
				progress.tick();
			}
			SQLUtils.cleanup(resultSet);
			
			/////////////////////////////
			
			conn.setAutoCommit(true);
		}
		catch (RemoteException e)
		{
			throw e;
		}
		catch (Exception e)
		{
			throw new RemoteException("Unable to migrate old SQL config to new format.", e);
		}
		finally
		{
			SQLUtils.cleanup(resultSet);
			SQLUtils.cleanup(stmt);
		}
	}
	
	private static int getSingleIntFromQuery(Statement stmt, String query) throws SQLException
	{
		ResultSet resultSet = null;
		try
		{
			resultSet = stmt.executeQuery(query);
	        resultSet.next();
	        return resultSet.getInt(1);
		}
		finally
		{
			SQLUtils.cleanup(resultSet);
		}
	}
	
	private static boolean isEmpty(String str)
	{
		return str == null || str.length() == 0;
	}
	
	private static Map<String,String> getRecord(ResultSet rs, String[] columnNames) throws SQLException
	{
		Map<String,String> record = new HashMap<String,String>();
		for (String name : columnNames)
			record.put(name, rs.getString(name));
		return record;
	}
	
	private static DataEntityMetadata toDataEntityMetadata(Map<String,String> record)
	{
		DataEntityMetadata result = new DataEntityMetadata();
		for (String field : record.keySet())
		{
			String value = record.get(field);
			if (isEmpty(value))
				continue;
			if (fieldIsPrivate(field))
				result.privateMetadata.put(field, value);
			else
				result.publicMetadata.put(field, value);
		}
		return result;
	}

	private static final String OLD_METADATA_TABLE = "weave_dataset_metadata";
	private static final String OLD_METADATA_COLUMN_ID = "dataTable";
	private static final String OLD_METADATA_COLUMN_PROPERTY = "element";
	private static final String OLD_METADATA_COLUMN_VALUE = "value";
	private static final String PublicMetadata_NAME = "name";
	private static final String PublicMetadata_YEAR = "year";
	private static final String PublicMetadata_DATATABLE = "dataTable";
	private static final String PublicMetadata_GEOMETRYCOLLECTION = "geometryCollection";
	private static final String PrivateMetadata_SCHEMA = "schema";
	private static final String PrivateMetadata_TABLEPREFIX = "tablePrefix";
	private static final String PrivateMetadata_IMPORTNOTES = "importNotes";
	private static boolean fieldIsPrivate(String propertyName)
	{
		String[] names = {
				PrivateMetadata.CONNECTION,
				PrivateMetadata.SQLQUERY,
				PrivateMetadata.SQLPARAMS,
				PrivateMetadata.SQLSCHEMA,
				PrivateMetadata.SQLTABLEPREFIX,
				PrivateMetadata_SCHEMA,
				PrivateMetadata_TABLEPREFIX,
				PrivateMetadata_IMPORTNOTES
		};
		return ListUtils.findString(propertyName, names) >= 0;
	}
}
