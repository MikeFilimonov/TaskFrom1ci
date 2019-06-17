
#Region Variables

&AtClient
Var PriceKindOnOpen;

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PriceKind = Parameters.PriceKind;
	
EndProcedure

// Procedure - OnOpen form event handler
// The procedure implements
// - initializing the form parameters.
//
&AtClient
Procedure OnOpen(Cancel)
	
	PriceKindOnOpen = PriceKind;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	Cancel = False;
	If RefillPrices AND Not ValueIsFilled(PriceKind) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Price kind for population is not selected.'");
		Message.Field = "PriceKind";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not Cancel Then
		If PriceKindOnOpen <> PriceKind OR RefillPrices Then
			WereMadeChanges = True;
		Else
			WereMadeChanges = False;
		EndIf;
		StructureOfFormAttributes = New Structure;
		StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
		StructureOfFormAttributes.Insert("RefillPrices", RefillPrices);
		StructureOfFormAttributes.Insert("PriceKind", PriceKind);
		Close(StructureOfFormAttributes);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the PriceKind input field.
//
&AtClient
Procedure PriceKindOnChange(Item)
	
	If ValueIsFilled(PriceKind) Then
		If PriceKindOnOpen <> PriceKind Then
			RefillPrices = True;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
