#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure inserts the text which is passed as a parameter to the tabular document field.
// 
Procedure InsertTextInFormula(Indicator)
	
	FormulaText = FormulaText + " [" + TrimAll(Indicator) + "] ";
			
EndProcedure

&AtServerNoContext
// Function receives the indicator ID.
//
Function GetIndicatorID(DataStructure)
	
	Return TrimAll(DataStructure.SelectedRow.ID);

EndFunction

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TextIndicators = NStr("en = 'To add an indicator to the formula, double-click it'");
	
	If Parameters.Property("FormulaText") Then
		
		FormulaText = Parameters.FormulaText;
		
	EndIf;	
	
EndProcedure

#Region FormButtonItemEventHandlers

&AtClient
// Procedure - button click handler OK
//
Procedure CommandOK(Command)
	
	Close(FormulaText);
	
EndProcedure

#EndRegion

#Region DynamicListEventHandlersCalculationParameters

&AtClient
// Procedure - event handler Selection of dynamic list ProductParameters.
//
Procedure EarningsCalculationParametersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	DataStructure = New Structure("SelectedRow", SelectedRow);
	
	TextInFormula = GetIndicatorID(DataStructure);
    InsertTextInFormula(TextInFormula);

EndProcedure

#EndRegion

#EndRegion
