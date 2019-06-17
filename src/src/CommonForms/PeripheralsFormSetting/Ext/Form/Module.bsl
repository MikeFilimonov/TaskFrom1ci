#Region GeneralPurposeProceduresAndFunctions

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogPeripherals(Command)
	
	If Modified Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is not written yet. You can start editing the ""Companies"" catalog only after the data is written.'");
		Message.Message();
		Return;
	EndIf;
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripherals(Command)
	
	If Modified Then
		Mode = QuestionDialogMode.YesNo;
		MessageText = NStr("en = 'Data is not written yet. You can go to the settings only after the data is written. Write?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("OpenExchangeRulesWithPeripheralsEnd", ThisObject), MessageText, Mode, 0);
        Return;
	EndIf;
	
	OpenExchangeRulesWithPeripheralsFragment();
EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Write();
    Else
        Return;
    EndIf;
    
    OpenExchangeRulesWithPeripheralsFragment();

EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsFragment()
    
    RefreshInterface();
    OpenForm("Catalog.ExchangeWithOfflinePeripheralsRules.ListForm", , ThisForm);

EndProcedure

&AtClient
Procedure OpenWorkplaces(Command)
	
	OpenForm("Catalog.Workplaces.ListForm", , ThisForm);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseOfflineExchangeWithPeripherals;
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshInterface();
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

&AtClient
Procedure FunctionalOptionUseOfflineExchangeWithPeripheralsOnChange(Item)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseOfflineExchangeWithPeripherals;
	
EndProcedure

#EndRegion
