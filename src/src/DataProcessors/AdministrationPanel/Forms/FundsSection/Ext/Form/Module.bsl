
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 1, True);	
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "ExchangeRateDifferencesCalculationFrequencyFO",	"Visible", ConstantsSet.ForeignExchangeAccounting);
			CommonUseClientServer.SetFormItemProperty(Items, "ForeignExchangeGroup",							"Visible", ConstantsSet.ForeignExchangeAccounting);
			CommonUseClientServer.SetFormItemProperty(Items, "PresentationCurrencyAndCatalog",					"Visible", ConstantsSet.ForeignExchangeAccounting);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" Then
		
		ConstantsSet.ForeignExchangeAccounting = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PresentationCurrency" Then
		
		ConstantsSet.PresentationCurrency = CurrentValue;
		
	EndIf;
	
EndProcedure

// Check on the possibility to disable the option ForeignExchangeAccounting.
//
&AtServer
Function CancellationUncheckFunctionalCurrencyTransactionsAccounting()
	
	MessageText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Currencies.Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.Ref <> &FunctionalCurrency"
	);
	
	Query.SetParameter("FunctionalCurrency", Constants.FunctionalCurrency.Get());
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'To disable Foreign currency exchange delete the non-functional currencies first.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

// Check on the possibility to change the established presentation currency.
//
&AtServer
Function CancellationToChangeAccountingCurrency()
	
	MessageText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("FixedAssets");
	ListOfRegisters.Add("CashAssets");
	ListOfRegisters.Add("IncomeAndExpenses");
	ListOfRegisters.Add("IncomeAndExpensesCashMethod");
	ListOfRegisters.Add("UnallocatedExpenses");
	ListOfRegisters.Add("IncomeAndExpensesRetained");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("StockTransferredToThirdParties");
	ListOfRegisters.Add("StockReceivedFromThirdParties");
	ListOfRegisters.Add("EarningsAndDeductions");
	ListOfRegisters.Add("SalesTarget");
	ListOfRegisters.Add("PaymentCalendar");
	ListOfRegisters.Add("Sales");
	ListOfRegisters.Add("TaxPayable");
	ListOfRegisters.Add("Payroll");
	ListOfRegisters.Add("AdvanceHolders");
	ListOfRegisters.Add("AccountsReceivable");
	ListOfRegisters.Add("AccountsPayable");
	ListOfRegisters.Add("FinancialResult");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister In ListOfRegisters Do
		
		If Query.Text = "" Then
			Query.Text = "SELECT ALLOWED TOP 1
			|	AccumulationRegisterValue.Company
			|FROM
			|	ValueAccumulationRegister AS AccumulationRegisterValue";
		Else
			Query.Text = Query.Text + 
			" 
			|
			|UNION ALL 
			|
			|SELECT TOP 1 
			|	AccumulationRegisterValue.Company
			|FROM
			|	ValueAccumulationRegister AS AccumulationRegisterValue";
		EndIf;
		
		Query.Text = StrReplace(Query.Text, "ValueAccumulationRegister", "AccumulationRegister." + AccumulationRegister.Value);
	
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			
			AccumulationRegistersCounter = 0;
			
			Try
				QueryResult	= Query.Execute();
				AreRecords	= Not QueryResult.IsEmpty();
			Except				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf;
			
			Query.Text = "";
			
		EndIf;
		
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except		
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Company
	|FROM
	|	AccumulationRegister.Inventory AS Inventory";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		MessageText = NStr("en = 'You can not change the presentation currency after having journal and registers entries.'");	
		
	EndIf;
	
	Return MessageText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are catalog items "Currencies" except the predefined, it is not allowed to clear the
	// ForeignExchangeAccounting check box
	If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" Then
		
		If Constants.ForeignExchangeAccounting.Get() <> ConstantsSet.ForeignExchangeAccounting 
			AND (NOT ConstantsSet.ForeignExchangeAccounting) Then
			
			ErrorText = CancellationUncheckFunctionalCurrencyTransactionsAccounting();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
	
	EndIf;
	
	If AttributePathToData = "ConstantsSet.PresentationCurrency" Then
		
		If Constants.PresentationCurrency.Get() <> ConstantsSet.PresentationCurrency Then
			
			ErrorText = CancellationToChangeAccountingCurrency();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Constants.PresentationCurrency.Get());
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CatalogCurrencies.
//
&AtClient
Procedure CatalogCurrencies(Command)
	
	OpenForm("Catalog.Currencies.ListForm");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the ForeignExchangeAccounting field.
//
&AtClient
Procedure FunctionalCurrencyTransactionsAccountingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the FunctionalCurrency field.
//
&AtClient
Procedure NationalCurrencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the PresentationCurrency field.
//
&AtClient
Procedure AccountingCurrencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - click reference handler ForeignCurrencyRevaluationPeriodicity.
//
&AtClient
Procedure ExchangeRateDifferencesCalculationFrequencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the SetOffAdvancePaymentsAutomatically field.
//
&AtClient
Procedure RegistrateDebtsAdvancesAutomaticallyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UsePaymentCalendar field.
//
&AtClient
Procedure FunctionalOptionPaymentCalendarOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseBankChargesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion