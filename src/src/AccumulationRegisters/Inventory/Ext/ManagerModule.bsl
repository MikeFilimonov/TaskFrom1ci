#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.Quantity AS QuantityBeforeWrite,
	|	Inventory.Quantity AS QuantityChange,
	|	Inventory.Quantity AS QuantityOnWrite,
	|	Inventory.Amount AS SumBeforeWrite,
	|	Inventory.Amount AS AmountChange,
	|	Inventory.Amount AS AmountOnWrite
	|INTO RegisterRecordsInventoryChange
	|FROM
	|	AccumulationRegister.Inventory AS Inventory");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryChange", False);
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	DebitNote.Ref AS Ref
	|INTO DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	DebitNote.Posted
	|	AND DebitNote.AmountIncludesVAT
	|	AND DebitNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNotes.Ref AS Ref,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.Products AS Products,
	|	SUM(DebitNoteInventory.Amount) AS Amount,
	|	SUM(DebitNoteInventory.VATAmount) AS VATAmount,
	|	DebitNoteInventory.VATRate AS VATRate
	|INTO DebitNoteInventory
	|FROM
	|	DebitNotes AS DebitNotes
	|		LEFT JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNotes.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.VATAmount <> 0
	|
	|GROUP BY
	|	DebitNotes.Ref,
	|	DebitNoteInventory.Batch,
	|	DebitNoteInventory.Characteristic,
	|	DebitNoteInventory.Products,
	|	DebitNoteInventory.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Recorder AS Ref
	|FROM
	|	DebitNoteInventory AS DebitNoteInventory
	|		INNER JOIN AccumulationRegister.Inventory AS Inventory
	|		ON DebitNoteInventory.Ref = Inventory.Recorder
	|			AND DebitNoteInventory.Products = Inventory.Products
	|			AND DebitNoteInventory.Characteristic = Inventory.Characteristic
	|			AND DebitNoteInventory.Batch = Inventory.Batch
	|			AND DebitNoteInventory.VATRate = Inventory.VATRate
	|			AND DebitNoteInventory.Amount = Inventory.Amount";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		Query.Text = 
		"SELECT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.Department AS Department,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	Inventory.Amount AS Amount
		|INTO Inventory
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.Amount - DebitNoteInventory.VATAmount AS Amount,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.Department AS Department,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	Inventory AS Inventory
		|		INNER JOIN DebitNoteInventory AS DebitNoteInventory
		|		ON Inventory.Recorder = DebitNoteInventory.Ref
		|			AND Inventory.Products = DebitNoteInventory.Products
		|			AND Inventory.Characteristic = DebitNoteInventory.Characteristic
		|			AND Inventory.Batch = DebitNoteInventory.Batch
		|			AND Inventory.VATRate = DebitNoteInventory.VATRate";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.Inventory.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

// Fill the SalesDocument and CorrGLAccount in register records.
//
Procedure FillCorrAttributes() Export
	
	Query = New Query(
	"SELECT
	|	Table.Recorder AS Ref
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|		INNER JOIN Document.GoodsReturn AS GoodsReturn
	|		ON Table.Recorder = GoodsReturn.Ref
	|WHERE
	|	Table.SourceDocument = UNDEFINED
	|	AND GoodsReturn.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.SourceDocument = UNDEFINED
	|	AND VALUETYPE(Table.Recorder) = VALUE(Document.DebitNote)
	|
	|UNION ALL
	|
	|SELECT
	|	Records.Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Records
	|		INNER JOIN Document.InventoryWriteOff AS InventoryWriteOff
	|		ON Records.Recorder = InventoryWriteOff.Ref
	|WHERE
	|	InventoryWriteOff.Correspondence <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	AND Records.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	Records.Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Records
	|		INNER JOIN Document.InventoryTransfer AS InventoryTransfer
	|		ON Records.Recorder = InventoryTransfer.Ref
	|WHERE
	|	Records.StructuralUnitCorr = VALUE(Catalog.BusinessUnits.EmptyRef)");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		BeginTransaction();
		
		DocObject = Selection.Ref.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		Documents[DocObject.Metadata().Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableInventory")
			And DocObject.AdditionalProperties.TableForRegisterRecords.TableInventory.Count() Then
			DriveServer.ReflectInventory(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
		EndIf;
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	EndDo;
	
EndProcedure

// Replacing Sales order empty ref to UNDEFINED
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	Inventory.Recorder AS Ref
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	(Inventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			OR Inventory.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef))";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		Query.Text = 
		"SELECT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Active AS Active,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	CASE
		|		WHEN Inventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE Inventory.SalesOrder
		|	END AS SalesOrder,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.Amount AS Amount,
		|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
		|	Inventory.CorrGLAccount AS CorrGLAccount,
		|	Inventory.ProductsCorr AS ProductsCorr,
		|	Inventory.CharacteristicCorr AS CharacteristicCorr,
		|	Inventory.BatchCorr AS BatchCorr,
		|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
		|	Inventory.Specification AS Specification,
		|	Inventory.SpecificationCorr AS SpecificationCorr,
		|	CASE
		|		WHEN Inventory.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE Inventory.CorrSalesOrder
		|	END AS CorrSalesOrder,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.Department AS Department,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.FixedCost AS FixedCost,
		|	Inventory.ProductionExpenses AS ProductionExpenses,
		|	Inventory.Return AS Return,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
		|	Inventory.OfflineRecord AS OfflineRecord
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.Inventory.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		
		Try
			RegisterRecords.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.Inventory,
				,
				ErrorDescription);
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndIf