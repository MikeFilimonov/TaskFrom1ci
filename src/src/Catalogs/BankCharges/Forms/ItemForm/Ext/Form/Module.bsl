
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	SetValueVisibility();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "GLAccountsChanged" Then
		Object.GLAccount		= Parameter.GLAccount;
		Object.GLExpenseAccount	= Parameter.GLExpenseAccount;
		Modified				= True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure ChargeTypeOnChange(Item)
	SetValueVisibility();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetValueVisibility()
	
	If Object.ChargeType = Enums.ChargeMethod.SpecialExchangeRate Then 
		Value = 0;
		Items.Value.Enabled = False;
	Else
		Items.Value.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion
