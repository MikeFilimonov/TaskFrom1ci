#Region CatalogProcessingProceduresAndFunctionsCashierWorkplaceSettings

// The function receives FIA setup for a working place
//
// Parameters:
//  Workplace - Catalog.Workplaces - current working place (for working with connected equipment)
//
Function GetCWPSetup(Workplace) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED TOP 1
		|	CashierWorkplaceSettings.Ref
		|FROM
		|	Catalog.CashierWorkplaceSettings AS CashierWorkplaceSettings
		|WHERE
		|	CashierWorkplaceSettings.Workplace = &Workplace
		|	AND NOT CashierWorkplaceSettings.DeletionMark";
	
	Query.SetParameter("Workplace", Workplace);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		NewCWPSetting = Catalogs.CashierWorkplaceSettings.CreateItem();
		NewCWPSetting.FillInButtonsTableFromLayout();
		NewCWPSetting.Workplace = Workplace;
		NewCWPSetting.Description = TrimAll(Workplace.Description);
		Try
			NewCWPSetting.Write();
			
			Return NewCWPSetting.Ref;
		Except
			Message = New UserMessage;
			Message.Text = ErrorDescription();
			Message.Message();
			
			Return Undefined;
		EndTry;
	EndIf;
	
EndFunction

// The procedure writes the new value of the attribute DonNotShowWhenCashdeskChoiceFormIsOpened
//
// Parameters:
//  CWPSetting - Catalog.CashierWorkplaceSettings - Current CWP settings (determined by
//  working place) DonNotShowWhenCashdeskChoiceFormIsOpened - Boolean - New value of attribute
//
Procedure UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm) Export
	
	SetPrivilegedMode(True);
	
	If Not CWPSetting.IsEmpty() AND CWPSetting.DontShowOnOpenCashdeskChoiceForm <> DontShowOnOpenCashdeskChoiceForm Then
		SetupCWPObject = CWPSetting.GetObject();
		SetupCWPObject.DontShowOnOpenCashdeskChoiceForm = DontShowOnOpenCashdeskChoiceForm;
		Try
			SetupCWPObject.Write();
		Except
			Message = New UserMessage;
			Message.Text = NStr("en = 'Failed to make changes.'") + 
									" " + Chars.LF + ErrorDescription();
			Message.Field = "DontShowOnOpenCashdeskChoiceForm";
			Message.Message();
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

// The function receives cash register by default.
//
// It returns cash CR, if one It returns was found.
// It returns Undefined, if It returns wasn't found or more than one.
//
//  Returns:
//	CatalogRef.CashRegisters - founded cash CR
//
Function GetDefaultCashRegisterAndTerminal() Export
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("CashCR",				Catalogs.CashRegisters.EmptyRef());
	ParametersStructure.Insert("POSTerminal",			Catalogs.POSTerminals.EmptyRef());
	ParametersStructure.Insert("POSTerminalQuantity",	0);
	ParametersStructure.Insert("Company",				Catalogs.Companies.EmptyRef());
	ParametersStructure.Insert("StructuralUnit",		Catalogs.BusinessUnits.EmptyRef());
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 2
	|	CashRegisters.Ref AS CashCR,
	|	CashRegisters.StructuralUnit AS StructuralUnit,
	|	CashRegisters.Owner AS Company
	|INTO CashRegisters
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	NOT CashRegisters.DeletionMark
	|	AND CashRegisters.CashCRType = &CashCRType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ISNULL(POSTerminals.Ref, VALUE(Catalog.POSTerminals.EmptyRef)) AS POSTerminals,
	|	CashRegisters.CashCR AS CashCR,
	|	CashRegisters.StructuralUnit AS StructuralUnit,
	|	CashRegisters.Company AS Company
	|FROM
	|	CashRegisters AS CashRegisters
	|		LEFT JOIN Catalog.POSTerminals AS POSTerminals
	|		ON (POSTerminals.PettyCash = CashRegisters.CashCR)
	|WHERE
	|	NOT POSTerminals.DeletionMark
	|	AND POSTerminals.PettyCash.CashCRType = &CashCRType
	|TOTALS
	|	MAX(StructuralUnit),
	|	MAX(Company)
	|BY
	|	CashCR";
	
	Query.SetParameter("CashCRType", Enums.CashRegisterTypes.FiscalRegister);
	
	QueryResult = Query.Execute();
	CashCRSelection = QueryResult.Select(QueryResultIteration.ByGroups);
	CashCRSelection.Next();
	
	If CashCRSelection.Count() = 1 Then
		ParametersStructure.CashCR			= CashCRSelection.CashCR;
		ParametersStructure.StructuralUnit	= CashCRSelection.StructuralUnit;
		ParametersStructure.Company			= CashCRSelection.Company;
		
		POSTerminals = CashCRSelection.Select();
		POSTerminals.Next();
		POSTerminalQuantity = POSTerminals.Count();
		ParametersStructure.POSTerminalQuantity = POSTerminalQuantity;
		
		If POSTerminalQuantity = 1 Then
			ParametersStructure.POSTerminal	= POSTerminals.POSTerminals;
		EndIf;
	EndIf;
	
	Return ParametersStructure;

EndFunction

#EndRegion