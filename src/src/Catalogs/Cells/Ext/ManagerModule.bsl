﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner")
		AND ValueIsFilled(Parameters.Filter.Owner)
		AND (Parameters.Filter.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Parameters.Filter.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot use storage bins in a retail store.'");
		Message.Message();
		StandardProcessing = False;
		
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
