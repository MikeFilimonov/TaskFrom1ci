#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)

	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ObsoleteWorkOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectObsoleteWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
   
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Participants.Count() > 0 Then
			NewRow = Works.Add();
			NewRow.Customer = FillingData.Participants[0].Contact;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder")
		AND (FillingData.OperationKind = Enums.OperationTypesSalesOrder.OrderForSale
		OR FillingData.OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing) Then	
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SalesOrder.Company AS Company,
		|	SalesOrder.PriceKind AS PriceKind,
		|	SalesOrder.SalesStructuralUnit AS StructuralUnit,
		|	SalesOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		ShipmentDate AS Day,
		|		Price AS Price,
		|		Amount AS Amount,
		|		Ref AS Customer
		|	)
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref = &BasisDocument
		|	AND (SalesOrder.Inventory.Products.ProductsType = VALUE(Enum.ProductsTypes.Service)
		|			OR SalesOrder.Inventory.Products.ProductsType = VALUE(Enum.ProductsTypes.Work))";
		
		Query.SetParameter("BasisDocument", FillingData);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			Works.Load(QueryResultSelection.Inventory.Unload());
			
		Else
			
			NewRow = Works.Add();
			NewRow.Customer = FillingData;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		If FillingData.Property("Works") Then	
			For Each WorkRow In FillingData.Works Do
				NewRow = Works.Add();
				FillPropertyValues(NewRow, WorkRow);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
If DataExchange.Load Then
		Return;
	EndIf;

	If WorkKindPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Works Do
			TabularSectionRow.WorkKind = WorkKind;
		EndDo;
	EndIf;
			
	DocumentAmount = Works.Total("Amount");
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If DataExchange.Load Then
		Return;
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)

	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf