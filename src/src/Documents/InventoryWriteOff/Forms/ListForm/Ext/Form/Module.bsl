
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Retail") Then
	
		FilterItem = List.SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("StructuralUnit.StructuralUnitType");
		FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		FilterItem.Use = True;
		
		ValueList = New ValueList;
		ValueList.Add(Enums.BusinessUnitsTypes.Retail);
		ValueList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
		
		FilterItem.RightValue = ValueList;
	
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion