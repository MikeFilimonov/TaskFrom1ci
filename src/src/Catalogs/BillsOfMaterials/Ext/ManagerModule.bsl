#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsType;
			
			If (OwnerType = Enums.ProductsTypes.Operation
				OR OwnerType = Enums.ProductsTypes.Service
				OR (NOT Constants.UseProductionSubsystem.Get() AND OwnerType = Enums.ProductsTypes.InventoryItem)
				OR (NOT Constants.UseWorkOrders.Get() AND OwnerType = Enums.ProductsTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en = 'BOM is not specified for products of the %EtcProducts% type.'");
				LabelText = StrReplace(LabelText, "%EtcProducts%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf
