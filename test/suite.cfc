component extends="testbox.system.BaseSpec"{

	function beforeAll(){
		variables.tempXlsPath = ExpandPath( "temp.xls" );
	}

	function afterAll(){}

	function run( testResults,testBox ){

		describe( "spreadsheet test suite",function() {
     
			beforeEach( function( currentSpec ) {
			  variables.s = New root.spreadsheet();
			  makePublic( s,"sheetToQuery" );
			});

			afterEach(function( currentSpec ) {
		    if( FileExists( tempXlsPath ) )
					FileDelete( tempXlsPath );
			});

			include "tests/addColumn.cfm";
			include "tests/addRow.cfm";
			include "tests/addRows.cfm";
			include "tests/binaryFromQuery.cfm";
			include "tests/cellComment.cfm";
			include "tests/cellFormula.cfm";
			include "tests/cellValue.cfm";
			include "tests/createSheet.cfm";
			include "tests/deleteColumn.cfm";
			include "tests/deleteColumns.cfm";
			include "tests/deleteRow.cfm";
			include "tests/deleteRows.cfm";
			include "tests/formatColumn.cfm";
			include "tests/formatColumns.cfm";
			include "tests/formatRows.cfm";
			include "tests/info.cfm";
			include "tests/isXmlOrBinaryFormat.cfm";
			include "tests/mergeCells.cfm";
			include "tests/new.cfm";
			include "tests/read.cfm";
			include "tests/readBinary.cfm";
			include "tests/removeSheet.cfm";
			include "tests/removeSheetNumber.cfm";
			include "tests/renameSheet.cfm";
			include "tests/setActiveSheet.cfm";
			include "tests/setActiveSheetNumber.cfm";
			include "tests/shiftColumns.cfm";
			include "tests/shiftRows.cfm";
			include "tests/workbookFromQuery.cfm";
			include "tests/write.cfm";
			include "tests/writeFileFromQuery.cfm";

		});

	}

	//dump( expected );dump( actual );abort;

}
