#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonUseClientServer.SetFormItemProperty(Items, "Rate",		"Visible", Not Object.NotTaxable);
	CommonUseClientServer.SetFormItemProperty(Items, "Calculated",	"Visible", Not Object.NotTaxable);
	
	CommonUseClientServer.SetFormItemProperty(Items, "NotTaxable",	"ReadOnly", Object.Predefined);
	CommonUseClientServer.SetFormItemProperty(Items, "Rate",		"ReadOnly", Object.Predefined);
	CommonUseClientServer.SetFormItemProperty(Items, "Calculated",	"ReadOnly", Object.Predefined);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of the NotTaxable input fields.
//
Procedure NotTaxableOnChange(Item)
	
	If Object.NotTaxable Then
		
		Object.Rate		= 0;
		Object.Calculated	= False;
		
	EndIf;
	
	CommonUseClientServer.SetFormItemProperty(Items, "Rate",		"Visible", Not Object.NotTaxable);
	CommonUseClientServer.SetFormItemProperty(Items, "Calculated",	"Visible", Not Object.NotTaxable);
	
EndProcedure

#EndRegion
