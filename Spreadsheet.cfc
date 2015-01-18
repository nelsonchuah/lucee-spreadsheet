component{

	variables.defaultFormats = { DATE = "m/d/yy", TIMESTAMP = "m/d/yy h:mm", TIME = "h:mm:ss" };
	variables.exceptionType	=	"cfsimplicity.Railo.Spreadsheet";

	function init( string sheetName="Sheet1" ){
		variables.workbook = createWorkBook( sheetName.Left( 31 ) );
		variables.formatting = New formatting( workbook,exceptionType );
		variables.tools = New tools( workbook,formatting,defaultFormats,exceptionType );
		tools.createSheet( sheetName );
		tools.setActiveSheet( sheetName );
		return this;
	}

	private function createWorkBook( required string sheetName ){
		return CreateObject( "Java","org.apache.poi.hssf.usermodel.HSSFWorkbook" );
	}

	/* CUSTOM METHODS */

	binary function binaryFromQuery( required query data,boolean addHeaderRow=true,boldHeaderRow=true ){
		/* Pass in a query and get a spreadsheet binary file ready to stream to the browser */
		if( addHeaderRow ){
			var columns	=	QueryColumnArray( data );
			this.addRow( columns.ToList() );
			if( boldHeaderRow )
				this.formatRow( { bold=true },1 );
			this.addRows( data,2,1 );
		} else {
			this.addRows( data );
		}
		return this.readBinary();
	}

	/* STANDARD CFML API */

	void function addColumn(
		required string data /* Delimited list of cell values */
		,numeric startRow
		,numeric column
		,boolean insert=true
		,required string delimiter
	){
		var row 				= 0;
		var cell 				= 0;
		var oldCell 		= 0;
		var rowNum 			= 0;
		var cellNum 		= 0;
		var lastCellNum = 0;
		var cellValue 	= 0;
		if( arguments.KeyExists( "startRow" ) )
			rowNum = startRow-1;
		if( arguments.KeyExists( "column" ) ){
			cellNum = column-1;
		} else {
			row = tools.getActiveSheet().getRow( rowNum );
			/* if this row exists, find the next empty cell number. note: getLastCellNum() 
				returns the cell index PLUS ONE or -1 if not found */
			if( !IsNull( row ) AND row.getLastCellNum() GT 0 )
				cellNum = row.getLastCellNum();
			else
				cellNum = 0;
		}
		var columnData = data.ToArray( delimiter );
		for( var cellValue in columnData ){
			/* if rowNum is greater than the last row of the sheet, need to create a new row  */
			if( rowNum GT tools.getActiveSheet().getLastRowNum() OR IsNull( tools.getActiveSheet().getRow( rowNum ) ) )
				row = tools.createRow( rowNum );
			else
				row = tools.getActiveSheet().getRow( rowNum );
			/* POI doesn't have any 'shift column' functionality akin to shiftRows() so inserts get interesting */
			/* ** Note: row.getLastCellNum() returns the cell index PLUS ONE or -1 if not found */
			if( insert AND cellNum LT row.getLastCellNum() ){
				/*  need to get the last populated column number in the row, figure out which 
						cells are impacted, and shift the impacted cells to the right to make 
						room for the new data */
				lastCellNum = row.getLastCellNum();
				for( var i=lastCellNum; i EQ cellNum; i-- ){
					oldCell	=	row.getCell( JavaCast( "int",i-1 ) );
					if( !IsNull( oldCell ) ){
						/* TODO: Handle other cell types ?  */
						cell = tools.createCell( row,i );
						cell.setCellStyle( oldCell.getCellStyle() );
						cell.setCellValue( oldCell.getStringCellValue() );
						cell.setCellComment( oldCell.getCellComment() );
					}
				}
			}
			cell = tools.createCell( row,cellNum );
			cell.setCellValue( JavaCast( "string",cellValue ) );
			rowNum++;
		}
	}

	void function addRow(
		required string data /* Delimited list of data */
		,numeric startRow
		,numeric startColumn=1
		,boolean insert=true
		,string delimiter=","
		,boolean handleEmbeddedCommas=true /* When true, values enclosed in single quotes are treated as a single element like in ACF. Only applies when the delimiter is a comma. */
	){
		var lastRow = tools.getNextEmptyRow();
		//If the requested row already exists ...
		if( arguments.KeyExists( "startRow" ) AND startRow LTE lastRow ){
			shiftRows( startRow,lastRow,1 );//shift the existing rows down (by one row)
		else
			deleteRow( startRow );//otherwise, clear the entire row
		}
		var theRow = arguments.KeyExists( "startRow" )? tools.createRow( arguments.startRow-1 ): tools.createRow();
		var rowValues = tools.parseRowData( data,delimiter,handleEmbeddedCommas );
		var cellNum = startColumn - 1;
		var dateUtil = tools.getDateUtil();
		for( var cellValue in rowValues ){
			cellValue=cellValue.Trim();
			var oldWidth = tools.getActiveSheet().getColumnWidth( cellNum );
			var cell = tools.createCell( theRow,cellNum );
			var isDateColumn  = false;
			var dateMask  = "";
			if( IsNumeric( cellValue ) and !cellValue.REFind( "^0[\d]+" ) ){
				/*  NUMERIC  */
				/*  skip numeric strings with leading zeroes. treat those as text  */
				cell.setCellType( cell.CELL_TYPE_NUMERIC );
				cell.setCellValue( JavaCast( "double",cellValue ) );
			} else if( IsDate( cellValue ) ){
				/*  DATE  */
				cellFormat = tools.getDateTimeValueFormat( cellValue );
				cell.setCellStyle( formatting.buildCellStyle( { dataFormat=cellFormat } ) );
				cell.setCellType( cell.CELL_TYPE_NUMERIC );
				/*  Excel's uses a different epoch than CF (1900-01-01 versus 1899-12-30). "Time" 
				only values will not display properly without special handling - */
				if( cellFormat EQ variables.defaultFormats.TIME ){
					cellValue = TimeFormat( cellValue, "HH:MM:SS" );
				 	cell.setCellValue( dateUtil.convertTime( cellValue ) );
				} else {
					cell.setCellValue( ParseDateTime( cellValue ) );
				}
				dateMask = cellFormat;
				isDateColumn = true;
			} else if( cellValue.Len() ){
				/* STRING */
				cell.setCellType( cell.CELL_TYPE_STRING );
				cell.setCellValue( JavaCast( "string",cellValue ) );
			} else {
				/* EMPTY */
				cell.setCellType( cell.CELL_TYPE_BLANK );
				cell.setCellValue( "" );
			}
			tools.autoSizeColumnFix( cellNum,isDateColumn,dateMask );
			cellNum++;
		}
	}

	void function addRows( required query data,numeric row,numeric column=1,boolean insert=true ){
		var lastRow = tools.getNextEmptyRow();
		if( arguments.KeyExists( "row" ) AND row LTE lastRow AND insert )
			shiftRows( row,lastRow,data.recordCount );
		var rowNum	=	arguments.keyExists( "row" )? row-1: tools.getNextEmptyRow();
		var queryColumns = tools.getQueryColumnFormats( data );
		var dateUtil = tools.getDateUtil();
		var dateColumns  = {};
		for( dataRow in data ){
			/* can't just call addRow() here since that function expects a comma-delimited 
					list of data (probably not the greatest limitation ...) and the query 
					data may have commas in it, so this is a bit redundant with the addRow() 
					function */
			var theRow = tools.createRow( rowNum,false );
			var cellNum = ( arguments.column-1 );
			/* Note: To properly apply date/number formatting:
   				- cell type must be CELL_TYPE_NUMERIC
   				- cell value must be applied as a java.util.Date or java.lang.Double (NOT as a string)
   				- cell style must have a dataFormat (datetime values only) */
   		/* populate all columns in the row */
   		for( var column in queryColumns ){
   			var cell 	= tools.createCell( theRow, cellNum, false );
				var value = dataRow[ column.name ];
				var forceDefaultStyle = false;
				column.index = cellNum;

				/* Cast the values to the correct type, so data formatting is properly applied  */
				if( column.cellDataType IS "DOUBLE" AND isNumeric( value ) ){
					cell.setCellValue( JavaCast("double", Val( value) ) );
				} else if( column.cellDataType IS "TIME" AND IsDate( value ) ){
					value = TimeFormat( ParseDateTime( value ),"HH:MM:SS");				
					cell.setCellValue( dateUtil.convertTime( value ) );
					forceDefaultStyle = true;
					var dateColumns[ column.name ] = { index=cellNum,type=column.cellDataType };
				} else if( column.cellDataType EQ "DATE" AND IsDate( value ) ){
					/* If the cell is NOT already formatted for dates, apply the default format 
					brand new cells have a styleIndex == 0  */
					var styleIndex = cell.getCellStyle().getDataFormat();
					var styleFormat = cell.getCellStyle().getDataFormatString();
					if( styleIndex EQ 0 OR NOT dateUtil.isADateFormat( styleIndex,styleFormat ) )
						forceDefaultStyle = true;
					cell.setCellValue( ParseDateTime( value ) );
					dateColumns[ column.name ] = { index=cellNum,type=column.cellDataType };
				} else if( column.cellDataType EQ "BOOLEAN" AND IsBoolean( value ) ){
					cell.setCellValue( JavaCast( "boolean",value ) );
				} else if( IsSimpleValue( value ) AND value.isEmpty() ){
					cell.setCellType( cell.CELL_TYPE_BLANK );
				} else {
					cell.setCellValue( JavaCast( "string",value ) );
				}
				/* Replace the existing styles with custom formatting  */
				if( column.KeyExists( "customCellStyle" ) ){
					cell.setCellStyle( column.customCellStyle );
					/* Replace the existing styles with default formatting (for readability). The reason we cannot 
					just update the cell's style is because they are shared. So modifying it may impact more than 
					just this one cell. */
				} else if( column.KeyExists( "defaultCellStyle" ) AND forceDefaultStyle ){
					cell.setCellStyle( column.defaultCellStyle );
				}
				cellNum++;
   		}
   		rowNum++;
		}
	}

	void function deleteRow( required numeric rowNum ){
		/* Deletes the data from a row. Does not physically delete the row. */
		var rowToDelete = rowNum - 1;
		if( rowToDelete GTE tools.getFirstRowNum() AND rowToDelete LTE tools.getLastRowNum() ) //If this is a valid row, remove it
			tools.getActiveSheet().removeRow( tools.getActiveSheet().getRow( JavaCast( "int",rowToDelete ) ) );
	}

	void function formatCell( required struct format,required numeric row,required numeric column,any cellStyle ){
		var cell = tools.initializeCell( row,column );
		if( arguments.KeyExists( "cellStyle" ) )
			cell.setCellStyle( cellStyle );// reuse an existing style
		else
			cell.setCellStyle( formatting.buildCellStyle( format ) );
	}

	void function formatRow( required struct format,required numeric rowNum ){
		var theRow = tools.getActiveSheet().getRow( arguments.rowNum-1 );
		if( IsNull( theRow ) )
			return;
		var cellIterator = theRow.cellIterator();
		while( cellIterator.hasNext() ){
			formatCell( format,rowNum,cellIterator.next().getColumnIndex()+1 );
		}
	}

	void function shiftRows( required numeric startRow,numeric endRow=startRow,numeric offest=1 ){
		tools.getActiveSheet().shiftRows(
			JavaCast( "int",arguments.startRow - 1 )
			,JavaCast( "int",arguments.endRow - 1 )
			,JavaCast( "int",arguments.offset )
		);
	}

	binary function readBinary(){
		var baos = CreateObject( "Java","org.apache.commons.io.output.ByteArrayOutputStream" ).init();
		workbook.write( baos );
		baos.flush();
		return baos.toByteArray();
	}


	/* NOT YET IMPLEMENTED */

	private void function notYetImplemented(){
		throw( type=exceptionType,message="Function not yet implemented" );
	}

	function addFreezePane(){ notYetImplemented(); }
	function addImage(){ notYetImplemented(); }
	function addInfo(){ notYetImplemented(); }
	function addSplitPlane(){ notYetImplemented(); }
	function autoSizeColumn(){ notYetImplemented(); }
	function clearCellRange(){ notYetImplemented(); }
	function createSheet(){ notYetImplemented(); }
	function deleteColumn(){ notYetImplemented(); }
	function deleteColumns(){ notYetImplemented(); }
	function deleteRows(){ notYetImplemented(); }
	function formatCellRange(){ notYetImplemented(); }
	function formatColumn(){ notYetImplemented(); }
	function formatColumns(){ notYetImplemented(); }
	function formatRows(){ notYetImplemented(); }
	function getCellComment(){ notYetImplemented(); }
	function getCellFormula(){ notYetImplemented(); }
	function getCellValue(){ notYetImplemented(); }
	function info(){ notYetImplemented(); }
	function mergeCells(){ notYetImplemented(); }
	function read(){ notYetImplemented(); }
	function removeSheet(){ notYetImplemented(); }
	function removeSheetNumber(){ notYetImplemented(); }
	function setActiveSheet(){ notYetImplemented(); }
	function setActiveSheetNumber(){ notYetImplemented(); }
	function setCellComment(){ notYetImplemented(); }
	function setCellFormula(){ notYetImplemented(); }
	function setCellValue(){ notYetImplemented(); }
	function setColumnWidth(){ notYetImplemented(); }
	function setHeader(){ notYetImplemented(); }
	function setRowHeight(){ notYetImplemented(); }
	function shiftColumns(){ notYetImplemented(); }
	function write(){ notYetImplemented(); }

}