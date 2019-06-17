#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.VATIncurred.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsVATIncurredChange")
		OR StructureTemporaryTables.Property("RegisterRecordsVATIncurredChange")
			AND Not StructureTemporaryTables.RegisterRecordsVATIncurredChange Then
		
		// If the temporary table "RegisterRecordsVATIncurredChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsVATIncurredBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	VATIncurred.LineNumber AS LineNumber,
		|	VATIncurred.Company AS Company,
		|	VATIncurred.Supplier AS Supplier,
		|	VATIncurred.ShipmentDocument AS ShipmentDocument,
		|	VATIncurred.VATRate AS VATRate,
		|	CASE
		|		WHEN VATIncurred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN VATIncurred.AmountExcludesVAT
		|		ELSE -VATIncurred.AmountExcludesVAT
		|	END AS AmountExcludesVATBeforeWrite,
		|	CASE
		|		WHEN VATIncurred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN VATIncurred.VATAmount
		|		ELSE -VATIncurred.VATAmount
		|	END AS VATAmountBeforeWrite
		|INTO RegisterRecordsVATIncurredBeforeWrite
		|FROM
		|	AccumulationRegister.VATIncurred AS VATIncurred
		|WHERE
		|	VATIncurred.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsVATIncurredChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsVATIncurredBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsVATIncurredChange.LineNumber AS LineNumber,
		|	RegisterRecordsVATIncurredChange.Company AS Company,
		|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
		|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
		|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
		|	RegisterRecordsVATIncurredChange.AmountExcludesVAT AS AmountExcludesVATBeforeWrite,
		|	RegisterRecordsVATIncurredChange.VATAmount AS VATAmountBeforeWrite
		|INTO RegisterRecordsVATIncurredBeforeWrite
		|FROM
		|	RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
		|
		|UNION ALL
		|
		|SELECT
		|	VATIncurred.LineNumber,
		|	VATIncurred.Company,
		|	VATIncurred.Supplier,
		|	VATIncurred.ShipmentDocument,
		|	VATIncurred.VATRate,
		|	CASE
		|		WHEN VATIncurred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN VATIncurred.AmountExcludesVAT
		|		ELSE -VATIncurred.AmountExcludesVAT
		|	END,
		|	CASE
		|		WHEN VATIncurred.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN VATIncurred.VATAmount
		|		ELSE -VATIncurred.VATAmount
		|	END
		|FROM
		|	AccumulationRegister.VATIncurred AS VATIncurred
		|WHERE
		|	VATIncurred.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsVATIncurredChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsVATIncurredChange") Then
		
		Query = New Query("DROP RegisterRecordsVATIncurredChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsVATIncurredChange");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsVATIncurredChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsVATIncurredChange.LineNumber) AS LineNumber,
	|	RegisterRecordsVATIncurredChange.Company AS Company,
	|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
	|	SUM(RegisterRecordsVATIncurredChange.AmountExcludesVATBeforeWrite) AS AmountExcludesVATBeforeWrite,
	|	SUM(RegisterRecordsVATIncurredChange.AmountExcludesVATChange) AS AmountExcludesVATChange,
	|	SUM(RegisterRecordsVATIncurredChange.AmountExcludesVATOnWrite) AS AmountExcludesVATOnWrite,
	|	SUM(RegisterRecordsVATIncurredChange.VATAmountBeforeWrite) AS VATAmountBeforeWrite,
	|	SUM(RegisterRecordsVATIncurredChange.VATAmountChange) AS VATAmountChange,
	|	SUM(RegisterRecordsVATIncurredChange.VATAmountOnWrite) AS VATAmountOnWrite
	|INTO RegisterRecordsVATIncurredChange
	|FROM
	|	(SELECT
	|		RegisterRecordsVATIncurredBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsVATIncurredBeforeWrite.Company AS Company,
	|		RegisterRecordsVATIncurredBeforeWrite.Supplier AS Supplier,
	|		RegisterRecordsVATIncurredBeforeWrite.ShipmentDocument AS ShipmentDocument,
	|		RegisterRecordsVATIncurredBeforeWrite.VATRate AS VATRate,
	|		RegisterRecordsVATIncurredBeforeWrite.AmountExcludesVATBeforeWrite AS AmountExcludesVATBeforeWrite,
	|		RegisterRecordsVATIncurredBeforeWrite.AmountExcludesVATBeforeWrite AS AmountExcludesVATChange,
	|		0 AS AmountExcludesVATOnWrite,
	|		RegisterRecordsVATIncurredBeforeWrite.VATAmountBeforeWrite AS VATAmountBeforeWrite,
	|		RegisterRecordsVATIncurredBeforeWrite.VATAmountBeforeWrite AS VATAmountChange,
	|		0 AS VATAmountOnWrite
	|	FROM
	|		RegisterRecordsVATIncurredBeforeWrite AS RegisterRecordsVATIncurredBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsVATIncurredOnWrite.LineNumber,
	|		RegisterRecordsVATIncurredOnWrite.Company,
	|		RegisterRecordsVATIncurredOnWrite.Supplier,
	|		RegisterRecordsVATIncurredOnWrite.ShipmentDocument,
	|		RegisterRecordsVATIncurredOnWrite.VATRate,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsVATIncurredOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsVATIncurredOnWrite.AmountExcludesVAT
	|			ELSE RegisterRecordsVATIncurredOnWrite.AmountExcludesVAT
	|		END,
	|		RegisterRecordsVATIncurredOnWrite.AmountExcludesVAT,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsVATIncurredOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsVATIncurredOnWrite.VATAmount
	|			ELSE RegisterRecordsVATIncurredOnWrite.VATAmount
	|		END,
	|		RegisterRecordsVATIncurredOnWrite.VATAmount
	|	FROM
	|		AccumulationRegister.VATIncurred AS RegisterRecordsVATIncurredOnWrite
	|	WHERE
	|		RegisterRecordsVATIncurredOnWrite.Recorder = &Recorder) AS RegisterRecordsVATIncurredChange
	|
	|GROUP BY
	|	RegisterRecordsVATIncurredChange.Company,
	|	RegisterRecordsVATIncurredChange.Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate
	|
	|HAVING
	|	SUM(RegisterRecordsVATIncurredChange.AmountExcludesVATChange) <> 0
	|		OR SUM(RegisterRecordsVATIncurredChange.VATAmountChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Supplier,
	|	ShipmentDocument,
	|	VATRate");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsVATIncurredChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsVATIncurredChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsVATIncurredBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsVATIncurredBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf