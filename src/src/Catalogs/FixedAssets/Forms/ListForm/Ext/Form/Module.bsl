#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnabled()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		If Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = FixedAssetsStatesStructure.AcceptedForAccounting Then
			
			Items.ListChangeParameters.Enabled = True;
			Items.ListWriteOff.Enabled = True;
			Items.ListSell.Enabled = True;
			If CurrentData.DepreciationMethod = StructureMethodsOfDepreciationCalculation.ProportionallyToProductsVolume Then
				Items.ListEnterDepreciation.Enabled = True;
			Else
				Items.ListEnterDepreciation.Enabled = False;
			EndIf;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = FixedAssetsStatesStructure.RemoveFromAccounting Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = "Not accepted for accounting" Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = True;
			
		Else
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Function receives the period of the last depreciation calculation.
//
&AtServerNoContext
Function GetPeriodOfLastDepreciation(Val Company)
	
	Query = New Query(
	"SELECT TOP 1
	|	FixedAssets.Period AS Date
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Company = &Company
	|	AND VALUETYPE(FixedAssets.Recorder) = Type(Document.FixedAssetsDepreciation)
	|
	|ORDER BY
	|	FixedAssets.Period DESC");
	
	Company = ?(GetFunctionalOption("UseSeveralCompanies"), Company, Catalogs.Companies.MainCompany);
	
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return NStr("en = 'Last Earning:'") + " " + Format(Selection.Date, "DLF=DD");
	Else
		Return "";
	EndIf;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FixedAssetsStatesStructure = New Structure;
	FixedAssetsStatesStructure.Insert("AcceptedForAccounting", Enums.FixedAssetStatus.AcceptedForAccounting);
	FixedAssetsStatesStructure.Insert("RemoveFromAccounting", Enums.FixedAssetStatus.RemoveFromAccounting);
	
	StructureMethodsOfDepreciationCalculation = New Structure;
	StructureMethodsOfDepreciationCalculation.Insert("Linear", Enums.FixedAssetDepreciationMethods.Linear);
	StructureMethodsOfDepreciationCalculation.Insert("ProportionallyToProductsVolume", Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	State = Settings.Get("State");
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "State", State, ValueIsFilled(State));
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "TextUpdatePeriodOfLastDepreciationCalculation" Then
		PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	ElsIf EventName = "FixedAssetsStatesUpdate" Then
		SetEnabled();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of clicking AcceptForAccounting button.
//
&AtClient
Procedure AcceptForAccounting(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetRecognition.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking ChangeParameters button.
//
&AtClient
Procedure ChangeParameters(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetDepreciationChanges.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking ChargeDepreciation button.
//
&AtClient
Procedure ChargeDepreciation(Command)
	
	ListOfParameters = New Structure("Basis", Company);
	
	OpenForm("Document.FixedAssetsDepreciation.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking Sell button.
//
&AtClient
Procedure Sell(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetSale.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking WriteOff button.
//
&AtClient
Procedure WriteOff(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetWriteOff.ObjectForm", ListOfParameters);
	
EndProcedure

// Procedure - handler of clicking EnterWorkOutput button.
//
&AtClient
Procedure EnterWorkOutput(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetUsage.ObjectForm", ListOfParameters);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure

// Procedure - event handler OnChange of the State input field.
//
&AtClient
Procedure StatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "State", State, ValueIsFilled(State));
	
EndProcedure

// Procedure - event handler OnActivateRow of the List tabular section.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure

#EndRegion
