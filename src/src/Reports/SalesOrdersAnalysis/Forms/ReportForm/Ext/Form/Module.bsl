
#Region ServiceProceduresAndFunctions

&AtServer
//  Replaces account documents when report call by settlement documents from receipt
//  If receipt by purchase order - the settlement document is the purchase order
//
//  Parameters:
//  Parameters - FormDataStructure - Report parameters
//
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("SalesOrder") Then
		
		ParameterSalesOrder = Parameters.Filter.SalesOrder;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED DISTINCT
		|	SalesInvoiceInventory.Order AS Order
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref IN(&ParameterSalesOrder)";
		
		If AccessRight("Read", Metadata.Documents.InventoryReservation) Then
			Query.Text = Query.Text + "
			|UNION ALL
			|
			|SELECT DISTINCT
			|	InventoryReservation.SalesOrder
			|FROM
			|	Document.InventoryReservation AS InventoryReservation
			|WHERE
			|	InventoryReservation.Ref IN(&ParameterSalesOrder)
			|";
		EndIf;
		
		Query.Text = Query.Text + "
		|UNION ALL
		|
		|SELECT DISTINCT
		|	SalesOrder.Ref
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref IN(&ParameterSalesOrder)";
		
		Query.SetParameter("ParameterSalesOrder", ParameterSalesOrder);
		
		ResultTable 				= Query.Execute().Unload();
		Parameters.Filter.SalesOrder = ResultTable.UnloadColumn("Order");
		
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Report.FilterByOrderStatuses = Items.FilterByOrderStatuses.ChoiceList[0].Value;
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Property("SalesOrder") Then
		
		Items.FilterByOrderStatuses.Enabled = False;
		SetSelectionReport(Parameters);
	
	EndIf;
	
	Parameters.GenerateOnOpen = True;

EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

&AtClient
// Procedure event handler OnChange of the FilterByOrderStatuses attribute 
//
Procedure FilterByOrderStatusesOnChange(Item)
	
	ComposeResult();
	
EndProcedure

#EndRegion

#EndRegion