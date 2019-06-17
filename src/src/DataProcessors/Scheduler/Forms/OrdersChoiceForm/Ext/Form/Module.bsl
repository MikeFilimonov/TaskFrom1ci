
#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FilterParameters") Then
		OrdersList = Parameters.FilterParameters.FilterOrders;
		RepetitionFactorOFDay = Parameters.FilterParameters.RepetitionFactorOFDay;
		TimeLimitTo = Parameters.FilterParameters.TimeLimitTo;
		TimeLimitFrom = Parameters.FilterParameters.TimeLimitFrom;
		ShowWorkOrders = Parameters.FilterParameters.ShowWorkOrders;
		ShowProductionOrders = Parameters.FilterParameters.ShowProductionOrders;
		DriveClientServer.SetListFilterItem(List, "Ref", OrdersList, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	If Items.List.CurrentRow = Undefined Then
		Items.KMListChange.Enabled = False;
		Items.ListChange.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", SelectedRow);
	OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
	OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	OpenParameters.Insert("ShowWorkOrders", ShowWorkOrders);
	OpenParameters.Insert("ShowProductionOrders", ShowProductionOrders);
	
	If TypeOf(SelectedRow) = Type("DocumentRef.ProductionOrder") Then
		OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	SelectedRow = Items.List.CurrentRow;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", SelectedRow);
	OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
	OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	OpenParameters.Insert("ShowWorkOrders", ShowWorkOrders);
	OpenParameters.Insert("ShowProductionOrders", ShowProductionOrders);
	
	If TypeOf(SelectedRow) = Type("DocumentRef.ProductionOrder") Then
		OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

#EndRegion
