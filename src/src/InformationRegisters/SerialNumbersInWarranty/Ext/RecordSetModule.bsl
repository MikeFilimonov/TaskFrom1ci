// Procedure - handler events Recordset BeforeWrite.
//

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR NOT AdditionalProperties.Property("ForPosting")
		OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If NOT StructureTemporaryTables.Property("RegisterRecordsSerialNumbersInWarrantyUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsSerialNumbersInWarrantyUpdate") AND NOT StructureTemporaryTables.RegisterRecordsSerialNumbersInWarrantyUpdate Then
		
		Query = New Query(
			"SELECT
			|	SerialNumbers.LineNumber AS LineNumber,
			|	SerialNumbers.Products AS Products,
			|	SerialNumbers.Characteristic AS Characteristic,
			|	SerialNumbers.SerialNumber AS SerialNumber,
			|	SerialNumbers.Operation
			|INTO RegisterRecordsSerialNumbersInWarrantyBeforeRecording
			|FROM
			|	InformationRegister.SerialNumbersInWarranty AS SerialNumbers
			|WHERE
			|	SerialNumbers.Recorder = &Recorder
			|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
	Else
		// If the "RegisterRecordsSerialNumbersInWarrantyChange" temporary table exists and
		// contains records on the set change, it means that the set is written not for the first time, and the set was not
		// controlled for balances. Current state of the set and current state of changes are
		// placed into the "RegisterRecordsSerialNumbersInWarrantyBeforeWrite" temporary table in order to get the change of a
		// new set with respect to the initial one when writing.
		Query = New Query(
			"SELECT
			|	RegisterRecordsSerialNumbersInWarrantyUpdate.LineNumber AS LineNumber,
			|	RegisterRecordsSerialNumbersInWarrantyUpdate.Products AS Products,
			|	RegisterRecordsSerialNumbersInWarrantyUpdate.Characteristic AS Characteristic,
			|	RegisterRecordsSerialNumbersInWarrantyUpdate.SerialNumber AS SerialNumber,
			|	RegisterRecordsSerialNumbersInWarrantyUpdate.Operation AS Operation
			|INTO RegisterRecordsSerialNumbersInWarrantyBeforeRecording
			|FROM
			|	RegisterRecordsSerialNumbersInWarrantyUpdate AS RegisterRecordsSerialNumbersInWarrantyUpdate
			|
			|UNION ALL
			|
			|SELECT
			|	SerialNumbers.LineNumber,
			|	SerialNumbers.Products,
			|	SerialNumbers.Characteristic,
			|	SerialNumbers.SerialNumber,
			|	SerialNumbers.Operation
			|FROM
			|	InformationRegister.SerialNumbersInWarranty AS SerialNumbers
			|WHERE
			|	SerialNumbers.Recorder = &Recorder
			|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// The "RegisterRecordsSerialNumbersInWarrantyChange" temporary
	// table is deleted Information on its existence is deleted.
	If StructureTemporaryTables.Property("RegisterRecordsSerialNumbersInWarrantyUpdate") Then
		Query = New Query("DROP RegisterRecordsSerialNumbersInWarrantyUpdate");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSerialNumbersInWarrantyUpdate");
	EndIf;
	
EndProcedure

// Procedure - handler events OnWrite Recordset.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR NOT AdditionalProperties.Property("ForPosting")
		OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Update the new set is calculated relative to the
	// current taking into account the accumulated changes and placed into a temporary table "RegisterRecordsSerialNumbersInWarrantyUpdate".
	
	Query = New Query(
		"SELECT
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Products AS Products,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Characteristic AS Characteristic,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Operation AS Operation,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.SerialNumber AS SerialNumber,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.SerialNumber.Sold AS SerialNumberSold,
		|	SUM(RegisterRecordsSerialNumbersInWarrantyUpdate.ChangeType) AS ChangeType
		|FROM
		|	(SELECT
		|		RegisterRecordsSerialNumbersInWarrantyBeforeRecording.Products AS Products,
		|		RegisterRecordsSerialNumbersInWarrantyBeforeRecording.Characteristic AS Characteristic,
		|		RegisterRecordsSerialNumbersInWarrantyBeforeRecording.Operation AS Operation,
		|		RegisterRecordsSerialNumbersInWarrantyBeforeRecording.SerialNumber AS SerialNumber,
		|		-1 AS ChangeType
		|	FROM
		|		RegisterRecordsSerialNumbersInWarrantyBeforeRecording AS RegisterRecordsSerialNumbersInWarrantyBeforeRecording
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		RegisterRecordsSerialNumbersInWarrantyOnWrite.Products,
		|		RegisterRecordsSerialNumbersInWarrantyOnWrite.Characteristic,
		|		RegisterRecordsSerialNumbersInWarrantyOnWrite.Operation,
		|		RegisterRecordsSerialNumbersInWarrantyOnWrite.SerialNumber,
		|		1
		|	FROM
		|		InformationRegister.SerialNumbersInWarranty AS RegisterRecordsSerialNumbersInWarrantyOnWrite
		|	WHERE
		|		RegisterRecordsSerialNumbersInWarrantyOnWrite.Recorder = &Recorder) AS RegisterRecordsSerialNumbersInWarrantyUpdate
		|
		|GROUP BY
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Products,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Characteristic,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.Operation,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.SerialNumber,
		|	RegisterRecordsSerialNumbersInWarrantyUpdate.SerialNumber.Sold
		|
		|HAVING
		|	SUM(RegisterRecordsSerialNumbersInWarrantyUpdate.ChangeType) <> 0");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	While QueryResultSelection.Next() Do
		
		If QueryResultSelection.Operation = Enums.SerialNumbersOperations.Expense 
			AND NOT QueryResultSelection.SerialNumberSold Then
			SerialNumberObject = QueryResultSelection.SerialNumber.GetObject();
			SerialNumberObject.Sold = True;
			SerialNumberObject.Write();
		ElsIf QueryResultSelection.Operation = Enums.SerialNumbersOperations.Receipt 
			AND QueryResultSelection.SerialNumberSold Then
			SerialNumberObject = QueryResultSelection.SerialNumber.GetObject();
			SerialNumberObject.Sold = False;
			SerialNumberObject.Write();
		EndIf;
		
	EndDo;
	
	// Temporary table "RegisterRecordsSerialNumbersInWarrantyBeforeRecording" is deleted
	Query = New Query("DROP RegisterRecordsSerialNumbersInWarrantyBeforeRecording");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

