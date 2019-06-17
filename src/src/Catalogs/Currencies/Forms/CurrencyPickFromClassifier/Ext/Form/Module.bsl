
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Filling currency list from IUC.
	CloseOnChoice = False;
	FillCurrenciesTable();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCurrencyList

&AtClient
Procedure CurrencyListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessChoiceInCurrencyList(StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseRun()
	
	ProcessChoiceInCurrencyList();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillCurrenciesTable()
	
	ClassifierTable = WorkWithExchangeRates.GetCurrencyClassifierTable();
	
	For Each Row In ClassifierTable Do
		NewRow = Currencies.Add();
		NewRow.DigitalCurrencyCode				= Row.Code;
		NewRow.AlphabeticCurrencyCode			= Row.CodeSymbol;
		NewRow.Description						= Row.Name;
		NewRow.CountriesAndTerritories			= Row.Description;
		NewRow.Importing						= False;
		NewRow.InWordParametersInHomeLanguage	= Row.NumerationItemOptions;
	EndDo;
	
EndProcedure

&AtServer
Function SaveSelectedRows(Val SelectedRows, IsRates)
	
	IsRates = False;
	CurrentRef = Undefined;
	
	For Each LineNumber In SelectedRows Do
		CurrentData = Currencies[LineNumber];
		
		RowInBase = Catalogs.Currencies.FindByCode(CurrentData.DigitalCurrencyCode);
		If ValueIsFilled(RowInBase) Then
			If LineNumber = Items.CurrenciesList.CurrentRow Or CurrentRef = Undefined Then
				CurrentRef = RowInBase;
			EndIf;
			Continue;
		EndIf;
		
		NewRow = Catalogs.Currencies.CreateItem();
		NewRow.Code                       = CurrentData.DigitalCurrencyCode;
		NewRow.Description              = CurrentData.AlphabeticCurrencyCode;
		NewRow.DescriptionFull        = CurrentData.Description;
		If CurrentData.Importing Then
			NewRow.SetRateMethod = Enums.ExchangeRateSetupMethod.ExportFromInternet;
		Else
			NewRow.SetRateMethod = Enums.ExchangeRateSetupMethod.ManualInput;
		EndIf;
		NewRow.InWordParametersInHomeLanguage = CurrentData.InWordParametersInHomeLanguage;
		NewRow.Write();
		
		If LineNumber = Items.CurrenciesList.CurrentRow Or CurrentRef = Undefined Then
			CurrentRef = NewRow.Ref;
		EndIf;
		
		If CurrentData.Importing Then 
			IsRates = True;
		EndIf;
		
	EndDo;
	
	Return CurrentRef;

EndFunction

&AtClient
Procedure ProcessChoiceInCurrencyList(StandardProcessing = Undefined)
	Var IsRates;
	
	// Add catalog item and display result to user.
	StandardProcessing = False;
	
	CurrentRef = SaveSelectedRows(Items.CurrenciesList.SelectedRows, IsRates);
	
	NotifyChoice(CurrentRef);
	
	ShowUserNotification(
		NStr("en = 'Currencies are added.'"), ,
		?(StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled AND IsRates, 
			NStr("en = 'Rates will be automatically imported after some time.'"), ""),
		PictureLib.Information32);
	Close();
	
EndProcedure

#EndRegion
