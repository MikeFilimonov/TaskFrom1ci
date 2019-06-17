
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
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If NOT WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If NOT WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.UseSeveralCompanies" OR AttributePathToData = "" Then
			ConstantsSet.UseSeveralCompanies = GetFunctionalOption("UseSeveralCompanies");
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogCompanies", "Enabled", ConstantsSet.UseSeveralCompanies);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSeveralDepartments" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogBusinessUnitsDepartment", "Enabled", ConstantsSet.UseSeveralDepartments);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogLinesOfBusiness", "Enabled", ConstantsSet.UseSeveralLinesOfBusiness);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseResourcesWorkloadPlanning" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogCompanyResources", "Enabled", ConstantsSet.UseResourcesWorkloadPlanning);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "UseTaxInvoices", "Enabled", ConstantsSet.FunctionalOptionUseVAT);
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
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
	
	If AttributePathToData = "ConstantsSet.UseSeveralDepartments" Then
		
		ConstantsSet.UseSeveralDepartments = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" Then
		
		ConstantsSet.UseSeveralLinesOfBusiness = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseFixedAssets" Then
		
		ConstantsSet.UseFixedAssets = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" Then
		
		ConstantsSet.FunctionalOptionUseVAT = CurrentValue;
		
	EndIf;
	
EndProcedure

// Check on the option disable possibility AccountingBySeveralLinesOfBusiness.
//
&AtServer
Function CancellationUncheckAccountingBySeveralLinesOfBusiness() 
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	OtherActivity = Catalogs.LinesOfBusiness.Other;
	SelectionOfBusinessLine = Catalogs.LinesOfBusiness.Select();
	While SelectionOfBusinessLine.Next() Do
		
		If SelectionOfBusinessLine.Ref <> Catalogs.LinesOfBusiness.MainLine
			AND SelectionOfBusinessLine.Ref <> OtherActivity Then
			
			RefArray = New Array;
			RefArray.Add(SelectionOfBusinessLine.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				ErrorText = NStr("en = 'Lines of business which are different from the main one are used in the infobase. Cannot disable the option.'");
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseSeveralDepartments.
//
&AtServer
Function CancellationUncheckAccountingBySeveralDepartments() 
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	BusinessUnits.Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.StructuralUnitType = &StructuralUnitType
		|	AND BusinessUnits.Ref <> &MainDepartment"
	);
	
	Query.SetParameter("StructuralUnitType", Enums.BusinessUnitsTypes.Department);
	Query.SetParameter("MainDepartment", Catalogs.BusinessUnits.MainDepartment);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Departments which are different from the main one are used in the infobase. Cannot disable the option.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseFixedAssets.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingFixedAssets()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	FixedAssets.Company
		|FROM
		|	AccumulationRegister.FixedAssets AS FixedAssets"
	);
	
	QueryResult = Query.Execute();
	Cancel = NOT QueryResult.IsEmpty();
	
	If NOT Cancel Then
	
		Query = New Query(
			"SELECT TOP 1
			|	FixedAssetUsage.Company
			|FROM
			|	AccumulationRegister.FixedAssetUsage AS FixedAssetUsage"
		);
		
		QueryResult = Query.Execute();
		Cancel = NOT QueryResult.IsEmpty(); 
		
	EndIf;
	
	If Cancel Then
		
		ErrorText = NStr("en = 'There are capital asset movements in the infobase. Cannot clear the check box.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseVAT.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseVAT()
		
	ErrorText = "";
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ISNULL(SUM(NestedQuery.VATAmountTurnover), 0) AS VATAmountTurnover
	|FROM
	|	(SELECT
	|		SalesTurnovers.VATAmountTurnover AS VATAmountTurnover
	|	FROM
	|		AccumulationRegister.Sales.Turnovers AS SalesTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PurchasesTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.Purchases.Turnovers AS PurchasesTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VATOutputTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.VATOutput.Turnovers AS VATOutputTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VATInputTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.VATInput.Turnovers AS VATInputTurnovers) AS NestedQuery";
	
	QueryResult = Query.Execute();

	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		
		If Selection.Next() 
			AND Selection.VATAmountTurnover > 0 Then		
				ErrorText = NStr("en = 'There are subject to VAT documents. Cannot clear the check box.'");
		EndIf;
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	ErrorText = "";	
	
	// If there are references on departments unequal main department then it is not allowed to delete flag UseSeveralDepartments
	If AttributePathToData = "ConstantsSet.UseSeveralDepartments" Then		
		If Constants.UseSeveralDepartments.Get() <> ConstantsSet.UseSeveralDepartments
			AND (NOT ConstantsSet.UseSeveralDepartments) Then
				ErrorText = CancellationUncheckAccountingBySeveralDepartments();		
		EndIf;	
	EndIf;
	
	// If there are references on company unequal main company then it is not allowed to delete flag AccountingBySeveralLinesOfBusiness
	If AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" Then		
		If Constants.UseSeveralLinesOfBusiness.Get() <> ConstantsSet.UseSeveralLinesOfBusiness
			AND (NOT ConstantsSet.UseSeveralLinesOfBusiness) Then
				ErrorText = CancellationUncheckAccountingBySeveralLinesOfBusiness();	
		EndIf;
	EndIf;
		
	// If there are records by register "Property" or "Property selection" then it is not allowed to delete flag FunctionalOptionFixedAssetsAccounting	
	If AttributePathToData = "ConstantsSet.UseFixedAssets" Then
		If Constants.UseFixedAssets.Get() <> ConstantsSet.UseFixedAssets 
			AND (NOT ConstantsSet.UseFixedAssets) Then 	
				ErrorText = CancellationUncheckFunctionalOptionAccountingFixedAssets();
		EndIf;	
	EndIf;
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" Then		
		If Constants.FunctionalOptionUseVAT.Get() <> ConstantsSet.FunctionalOptionUseVAT 
			AND (NOT ConstantsSet.FunctionalOptionUseVAT) Then 
			
			ErrorText = CancellationUncheckFunctionalOptionUseVAT();
			
			If IsBlankString(ErrorText) 
				AND ConstantsSet.UseTaxInvoices Then
				// Turn off tax invoices
				ConstantsSet.UseTaxInvoices = False;
				SaveAttributeValue("ConstantsSet.UseTaxInvoices", New Structure());
			EndIf;			
		EndIf;		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseTaxInvoices" Then		
		If Constants.UseTaxInvoices.Get() <> ConstantsSet.UseTaxInvoices 
			AND ConstantsSet.UseTaxInvoices Then 		
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Turn on ""Use tax invoice"" option in accounting policy of a company, for the changes to take effect.'"));		
		EndIf;		
	EndIf;
	
	If Not IsBlankString(ErrorText) Then		
		Result.Insert("Field", 			AttributePathToData);
		Result.Insert("ErrorText", 		ErrorText);
		Result.Insert("CurrentValue",	True);		
	EndIf;	
	
EndFunction

// Procedure updates the constant set write and calls interface update
//
// NameRecords - String. Record name of constant set.
//
&AtServer
Procedure UpdateRecordSetOfConstants(NameRecords)
	
	If NameRecords = "UseSeveralCompanies" OR NameRecords = "" Then
		
		ConstantsSet[NameRecords] = GetFunctionalOption("UseSeveralCompanies");
		SetEnabled("ConstantsSet.UseSeveralCompanies");
		
	EndIf;
	
EndProcedure

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogCompanies(Command)
	
	OpenForm("Catalog.Companies.ListForm");
	
EndProcedure

// Procedure - command handler SettingAccountingByCompanies
//
&AtClient
Procedure SettingAccountingOnCounterpartysCompanies(Command)
	
	OpenForm("DataProcessor.AdministrationPanel.Form.SettingAccountingByCompanies");
	
EndProcedure

// Procedure - command handler CatalogBusinessUnitsDepartment.
//
&AtClient
Procedure CatalogBusinessUnitsDepartment(Command)
	
	FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
	OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
	
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogLinesOfBusiness(Command)
	
	OpenForm("Catalog.LinesOfBusiness.ListForm");
	
EndProcedure

// Procedure - command handler CatalogCompanyResources.
//
&AtClient
Procedure CatalogCompanyResources(Command)
	
	OpenForm("Catalog.CompanyResources.ListForm");
	
EndProcedure

// Procedure - command handler CatalogJobAndEventStatuses.
//
&AtClient
Procedure CatalogJobAndEventStatuses(Command)
	
	OpenForm("Catalog.JobAndEventStatuses.ListForm");
	
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

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet"
		AND Source = "UseSeveralCompanies" Then
		
		UpdateRecordSetOfConstants(Source);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange field UseSeveralDepartments.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleDepartmentsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field UseSeveralLinesOfBusiness.
//
&AtClient
Procedure AccountingByMultipleLinesOfBusinessOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionPlanCompanyResourcesImport.
//
&AtClient
Procedure UseResourcesWorkloadPlanningOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field AddItemNumberToProductDescriptionOnPrinting.
//
&AtClient
Procedure ProductsSKUInContentOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field UseBudgeting.
//
&AtClient
Procedure FunctionalOptionUseBudgetingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionFixedAssetsAccounting.
//
&AtClient
Procedure FunctionalOptionAccountingFixedAssetsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseCounterpartyContractTypesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion
