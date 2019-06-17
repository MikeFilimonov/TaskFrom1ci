#Region ExportProceduresAndFunctions

// Get value of Session current date
//
Function GetSessionCurrentDate() Export
	
	Return CurrentSessionDate();
	
EndFunction

// Function returns default value for transferred user and setting.
//
// Parameters:
//  User - current user
//  of application Setup    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueByDefaultUser(User, Setting, EmptyValue = Undefined) Export

	Query = New Query;
	Query.SetParameter("User"   , User);
	Query.SetParameter("Setting", ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	If EmptyValue = Undefined Then
		EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();
	КонецЕсли;

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction

// Function returns default value for transferred user and setting.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueOfSetting(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction

// Returns True or False - specified setting of user is in the header.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function AttributeInHeader(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	DefaultValue = True;

	If Selection.Count() = 0 Then
		
		Return DefaultValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return DefaultValue;
		Else
			Return Selection.Value = Enums.AttributeStationing.InHeader;
		EndIf;

	Else
		Return DefaultValue;

	EndIf;

EndFunction

// Function returns the flag of commercial equipment use.
//
Function UsePeripherals() Export
	
	 Return GetFunctionalOption("UsePeripherals")
		   AND TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.Users");
	 
EndFunction

// Function receives parameters of CR cash register.
//
Function CashRegistersGetParameters(CashCR) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CASE
	|		WHEN CashRegisters.CashCRType = VALUE(Enum.CashRegisterTypes.FiscalRegister)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsFiscalRegister,
	|	CashRegisters.Peripherals AS DeviceIdentifier,
	|	CashRegisters.UseWithoutEquipmentConnection AS UseWithoutEquipmentConnection
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	CashRegisters.Ref = &Ref";
	
	Query.SetParameter("Ref", CashCR);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Selection.DeviceIdentifier,
			Selection.UseWithoutEquipmentConnection,
			Selection.IsFiscalRegister
		);
		
	Else
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Catalogs.Peripherals.EmptyRef(),
			False,
			False
		);
		
	EndIf;
	
EndFunction

// Function checks if it is necessary to monitor the contracts of counterparties.
//
Function CounterpartyContractsControlNeeded() Export
	
	SetPrivilegedMode(True);
	
	If (NOT CommonUseReUse.DataSeparationEnabled() AND Not GetFunctionalOption("UseDataSync")) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Function returns the value of advances offset setup.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetAdvanceOffsettingSettingValue() Export
	
	OffsetAutomatically = GetValueOfSetting("SetOffAdvancePaymentsAutomatically");
	If Not ValueIsFilled(OffsetAutomatically) Then
		OffsetAutomatically = Constants.SetOffAdvancePaymentsAutomatically.Get();
	EndIf;
	
	Return OffsetAutomatically;
	
EndFunction

// Function determines for which operation mode of the application synchronization settings should be used.
//
Function SettingsForSynchronizationSaaS() Export

	Return GetFunctionalOption("StandardSubsystemsSaaS");

EndFunction

Function GetCurrentUserLanguageCode() Export
	
	CurrentUser = InfobaseUsers.CurrentUser();
	Return ?(CurrentUser.Language = Undefined, Metadata.DefaultLanguage.LanguageCode, CurrentUser.Language.LanguageCode);	
	
EndFunction

// PROCEDURES AND FUNCTIONS FOR WORK WITH VAT RATES

// Get value of VAT rate.
//
Function GetVATRateValue(VATRate) Export
	
	Return ?(ValueIsFilled(VATRate), CommonUse.ObjectAttributeValue(VATRate, "Rate"), 0);

EndFunction

// PROCEDURES AND FUNCTIONS FOR WORK WITH CONSTANTS

// Function returns the functional currency
//
Function GetNationalCurrency() Export
	
	Return Constants.FunctionalCurrency.Get();
	
EndFunction

// Function returns presentation currency
//
Function GetAccountCurrency() Export
	
	Return Constants.PresentationCurrency.Get();
	
EndFunction

// Function returns the state in progress for sales orders
//
Function GetStatusInProcessOfSalesOrders() Export
	
	Return Constants.SalesOrdersInProgressStatus.Get();
	
EndFunction

// Function returns the state completed for sales orders
//
Function GetStatusCompletedSalesOrders() Export
	
	Return Constants.StateCompletedSalesOrders.Get();
	
EndFunction

// Function returns the state in progress for sales orders
//
Function GetStatusInProcessOfWorkOrders() Export
	
	SetPrivilegedMode(True);
	Return Constants.WorkOrdersInProgressStatus.Get();
	
EndFunction

// Function returns the state completed for sales orders
//
Function GetStatusCompletedWorkOrders() Export
	
	SetPrivilegedMode(True);
	Return Constants.StateCompletedWorkOrders.Get();
	
EndFunction

Function GetOrderStatus(CatalogName, StatusName) Export
	
	Query = New Query;
	Query.SetParameter("OrderStatus", Enums.OrderStatuses[StatusName]);
	QueryText = 
	"SELECT TOP 1
	|	OrderStatuses.Ref AS Status
	|FROM
	|	&CatalogTable AS OrderStatuses
	|WHERE
	|	OrderStatuses.OrderStatus = &OrderStatus
	|	AND NOT OrderStatuses.DeletionMark";
	
	Query.Text = StrReplace(QueryText, "&CatalogTable", "Catalog." + CatalogName);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Status;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Status with purpose %1 is not found.'"), Enums.OrderStatuses[StatusName]);
	EndIf;
	
EndFunction

#EndRegion
