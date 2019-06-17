// Parameters:
// Parameters - FormDataStructure - Report parameters
//
&AtServer
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("PurchaseOrder") Then
		
		DocumentParameter = Parameters.Filter.PurchaseOrder;
		If TypeOf(DocumentParameter) = Type("Array") Then
			DocumentType = TypeOf(DocumentParameter[0]);		
		Else
			DocumentType = TypeOf(DocumentParameter);		
		EndIf;
		
		If DocumentType <> Type("DocumentRef.PurchaseOrder") Then
		
			Query = New Query("SELECT DISTINCT
			                      |	DocumentSource.Order AS PurchaseOrder
			                      |FROM
			                      |	Document.SupplierInvoice.Inventory AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)
			                      |
			                      |UNION ALL
			                      |
			                      |SELECT DISTINCT
			                      |	DocumentSource.PurchaseOrder
			                      |FROM
			                      |	Document.SupplierInvoice.Expenses AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)
			                      |
			                      |UNION ALL
			                      |
			                      |SELECT DISTINCT
			                      |	DocumentSource.BasisDocument
			                      |FROM
			                      |	Document.SubcontractorReport AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)
			                      |
			                      |UNION ALL
			                      |
			                      |SELECT DISTINCT
			                      |	DocumentSource.PurchaseOrder
			                      |FROM
			                      |	Document.AdditionalExpenses AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)");
								  
			Query.SetParameter("DocumentParameter", DocumentParameter);
			ResultTable = Query.Execute().Unload();
			Parameters.Filter.PurchaseOrder = ResultTable.UnloadColumn("PurchaseOrder");			
		
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlers

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetSelectionReport(Parameters);
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

#EndRegion
