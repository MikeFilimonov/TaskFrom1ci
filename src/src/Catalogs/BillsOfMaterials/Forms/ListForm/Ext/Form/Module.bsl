
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		Products = Parameters.Filter.Owner;
		
		UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
		UseWorkOrders = Constants.UseWorkOrders.Get();
		
		If Not ValueIsFilled(Products)
			OR Products.ProductsType = Enums.ProductsTypes.Service
			OR Products.ProductsType = Enums.ProductsTypes.Operation Then
			
			AutoTitle = False;
			If UseProductionSubsystem AND UseWorkOrders Then
				Title = NStr("en = 'BOMs are stored for inventory and works only'");
			ElsIf UseProductionSubsystem Then
				Title = NStr("en = 'BOMs are stored for inventory only'");
			Else
				Title = NStr("en = 'BOMs are stored for works only'");
			EndIf;
			Items.List.ReadOnly = True;
			
		ElsIf Products.ProductsType = Enums.ProductsTypes.InventoryItem AND Not UseProductionSubsystem Then
			
			AutoTitle = False;
			Title = NStr("en = 'BOMs are stored for works only'");
			Items.List.ReadOnly = True;
			
		ElsIf Products.ProductsType = Enums.ProductsTypes.Work AND Not UseWorkOrders Then
			
			AutoTitle = False;
			Title = NStr("en = 'BOMs are stored for inventory only'");
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingBillsOfMaterials";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningBillsOfMaterials";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion