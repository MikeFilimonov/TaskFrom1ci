#Region FormHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Retail") Then
		
		ValueList = New ValueList;
		ValueList.Add(Enums.BusinessUnitsTypes.Retail);
		ValueList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
		
		DriveClientServer.SetListFilterItem(List,"StructuralUnit.StructuralUnitType",ValueList,True,DataCompositionComparisonType.InList);
	
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
