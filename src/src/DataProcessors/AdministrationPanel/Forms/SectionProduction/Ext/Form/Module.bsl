
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
	
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsProductionOrder",	"Enabled", ConstantsSet.UseProductionSubsystem);
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsOthers", 				"Enabled", ConstantsSet.UseProductionSubsystem);
		
		If ConstantsSet.UseProductionSubsystem Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus","Enabled", Not ConstantsSet.UseProductionOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStatuses);
			
		Else
			
			Constants.UseSubcontractingManufacturing.Set(False);
			Constants.UseOperationsManagement.Set(False);
			
		EndIf;
		
	EndIf;
	
	If (RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData())
		AND ConstantsSet.UseProductionSubsystem Then
		
		If AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus","Enabled", Not ConstantsSet.UseProductionOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStatuses);
			
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
	
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" Then
		
		ConstantsSet.UseProductionSubsystem = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" Then
		
		ConstantsSet.UseProductionOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		ConstantsSet.ProductionOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersCompletionStatus" Then
		
		ConstantsSet.ProductionOrdersCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractingManufacturing" Then
		
		ConstantsSet.UseSubcontractingManufacturing = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseOperationsManagement" Then
		
		ConstantsSet.UseOperationsManagement = CurrentValue;
		
	EndIf;
	
EndProcedure

// The removal control procedure of the Use production by registers option.
//
&AtServer
Function CheckRecordsByProductionSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Inventory.Company AS Company
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	(Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))";
	
	Result = Query.Execute();
	
	// Inventory Register.
	If Not Result.IsEmpty() Then
		ErrorText = NStr("en = 'There are records in the ""Inventory"" register where the GL account is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// The removal control procedure of the Use production option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseSubsystemProduction()
	
	ErrorText = "";
	
	Cancel = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ProductionOrder.Ref
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Production.Ref
	|FROM
	|	Document.Production AS Production
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	DockCostAllocation.Ref
	|FROM
	|	Document.CostAllocation AS DockCostAllocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SalesOrder.Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	JobSheet.Ref
	|FROM
	|	Document.JobSheet AS JobSheet
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	IntraWarehouseTransfer.Ref
	|FROM
	|	Document.IntraWarehouseTransfer AS IntraWarehouseTransfer
	|WHERE
	|	IntraWarehouseTransfer.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryTransfer.Ref
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	((InventoryTransfer.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|				OR InventoryTransfer.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))
	|				AND InventoryTransfer.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|			OR InventoryTransfer.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OpeningBalanceEntryFixedAssets.Ref
	|FROM
	|	Document.OpeningBalanceEntry.FixedAssets AS OpeningBalanceEntryFixedAssets
	|WHERE
	|	(OpeningBalanceEntryFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR OpeningBalanceEntryFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	OpeningBalanceEntryInventory.Ref
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
	|WHERE
	|	OpeningBalanceEntryInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	EnteringOpeningBalancesDirectCost.Ref
	|FROM
	|	Document.OpeningBalanceEntry.DirectCost AS EnteringOpeningBalancesDirectCost
	|WHERE
	|	EnteringOpeningBalancesDirectCost.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	FixedAssetRecognitionFixedAssets.Ref
	|FROM
	|	Document.FixedAssetRecognition.FixedAssets AS FixedAssetRecognitionFixedAssets
	|WHERE
	|	(FixedAssetRecognitionFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR FixedAssetRecognitionFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryIncrease.Ref
	|FROM
	|	Document.InventoryIncrease AS InventoryIncrease
	|WHERE
	|	InventoryIncrease.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	BudgetBalance.Ref
	|FROM
	|	Document.Budget.Balance AS BudgetBalance
	|WHERE
	|	(BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetIndirectExpenses.Ref
	|FROM
	|	Document.Budget.IndirectExpenses AS BudgetIndirectExpenses
	|WHERE
	|	(BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetDirectCost.Ref
	|FROM
	|	Document.Budget.DirectCost AS BudgetDirectCost
	|WHERE
	|	(BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	BudgetOperations.Ref
	|FROM
	|	Document.Budget.Operations AS BudgetOperations
	|WHERE
	|	(BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ChangingParametersFAFixedAssets.Ref
	|FROM
	|	Document.FixedAssetDepreciationChanges.FixedAssets AS ChangingParametersFAFixedAssets
	|WHERE
	|	(ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PayrollEarningRetention.Ref
	|FROM
	|	Document.Payroll.EarningsDeductions AS PayrollEarningRetention
	|WHERE
	|	(PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TaxAccrualTaxes.Ref
	|FROM
	|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
	|WHERE
	|	(TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TransactionAccountingRecords.Ref
	|FROM
	|	Document.Operation.AccountingRecords AS TransactionAccountingRecords
	|WHERE
	|	(TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OtherExpensesCosts.Ref
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	(OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Products.Ref
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	(Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			OR Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	BusinessUnits.Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	(BusinessUnits.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			OR BusinessUnits.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			OR BusinessUnits.RecipientOfWastes.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Order for production Document.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'There are ""Production order"" documents in the infobase. You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 2. Production Document.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Production"" documents in the infobase. You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 3. The Cost allocation document.
	If Not ResultsArray[2].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'The infobase contains documents ""Cost allocation"". Cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 4. Sales order (Order for processing) document.
	If Not ResultsArray[3].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Sales order"" documents with operation kind ""Processing order"" in the infobase. Cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 5. The Job sheet document
	If Not ResultsArray[4].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Job sheet"" kind in the infobase. Cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 6. Transfer between cells document (transfer - department).
	If Not ResultsArray[5].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Intra-warehouse transfer"" kind in the infobase where business unit of the company is of ""Department"" type. You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 7. The Inventory transfer document (department, indirect costs).
	If Not ResultsArray[6].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Inventory transfer"" kind in the infobase where business unit of the company is of ""Department"" type and/or the account of expenses is of type ""Indirect costs"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 8. Enter opening balance document (department, indirect costs).
	If Not ResultsArray[7].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Enter opening balance"" kind in the infobase where business unit of the company is of ""Department"" type and/or the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 9. Fixed assets enter document (unfinished production, indirect costs).
	If Not ResultsArray[8].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Fixed asset recognition"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 10. Document Inventory receipt (department).
	If Not ResultsArray[9].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Inventory increase"" kind in the infobase where business unit of the company is of ""Department"" type. You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 11. The Budget document (unfinished production, indirect costs).
	If Not ResultsArray[10].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Budget"" documents in the infobase where the accounts of expenses are of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 12. The Fixed asserts modernization document (unfinished production, indirect costs).
	If Not ResultsArray[11].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Fixed asset parameter change"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 13. Payroll document (unfinished production, indirect costs).
	If Not ResultsArray[12].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Salary accounting"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 14. Tax Earning document (unfinished production, indirect costs).
	If Not ResultsArray[13].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Tax Earning"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 15. The Operation document (unfinished production, indirect costs).
	If Not ResultsArray[14].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Operation"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 16. The Other expenses document (unfinished production,indirect costs).
	If Not ResultsArray[15].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Other expenses"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 17. Catalog Products (unfinished production, indirect costs).
	If Not ResultsArray[16].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Products"" catalog items in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"" and stock replenishment method is of type ""Production"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	// 18. Catalog Structural units (department).
	If Not ResultsArray[17].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Business units"" catalog items in the infobase where the auto movement parameter (movement, picking) is of type ""Department"". You cannot clear the ""Production"" check box.'");
		
	EndIf;
	
	If IsBlankString(ErrorText) Then
		
		ErrorText = CheckRecordsByProductionSubsystemRegisters();
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseProductionOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseProductionOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ProductionOrder.Ref,
	|	ProductionOrder.OrderState.OrderStatus AS OrderStatus
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	(ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT ProductionOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'The base contains the documents ""Production order"" with the ""Opened"" and/or ""Executed (not closed)"" status.
		                 |Disabling the option is prohibited.
		                 |Note:
		                 |If there are documents in the state with
		                 |the status ""Open"", set them to state with the status ""In progress""
		                 |or ""Executed (closed)"" If there are documents in the state
		                 |with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'"
		);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseTechoperations option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseTechOperations()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Workload.Operation
		|FROM
		|	AccumulationRegister.Workload AS Workload"
	);
	
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are documents of the ""Job sheet"" kind or information on work center load in the infobase. You cannot clear the check box.'");
		
	EndIf;
	
	Query.Text = "Select top 1 * From Catalog.Products AS CtlProducts Where CtlProducts.ProductsType = Value(Enum.ProductsTypes.Operation)";
	
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'There are products of the ""Operation"" kind in the infobase. You cannot clear the check box.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Include/remove Production section
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" Then
		
		If Constants.UseProductionSubsystem.Get() <> ConstantsSet.UseProductionSubsystem
			AND (NOT ConstantsSet.UseProductionSubsystem) Then
		
			ErrorText = CancellationUncheckFunctionalOptionUseSubsystemProduction();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are the Production Order documents with the status different from Executed, the flag removal is prohibited.
	If AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" Then
		
		If Constants.UseProductionOrderStatuses.Get() <> ConstantsSet.UseProductionOrderStatuses
			AND (NOT ConstantsSet.UseProductionOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseProductionOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If InProcessStatus for the Production order documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several production order states"" check box is cleared but the ""In progress"" production order state parameter is not filled in.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If StatusExecuted for the ProductionOrders documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersCompletionStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersCompletionStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several production order states"" check box is cleared, but the ""Completed"" production order state parameter is not filled in.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersCompletionStatus.Get());
			
		EndIf; 
		
	EndIf;
	
	// If there are any activities on the registers "Work centers loading", on the register "Job sheet" or the products
	// with the Operation type, the removal of the UseOperationsManagement flag is prohibited
	If AttributePathToData = "ConstantsSet.UseOperationsManagement" Then
		
		If Constants.UseOperationsManagement.Get() <> ConstantsSet.UseOperationsManagement 
			AND (NOT ConstantsSet.UseOperationsManagement) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseTechOperations();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
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

// Procedure - handler of the ProductionOrderstatusesCatalog command.
//
&AtClient
Procedure CatalogProductionOrderStates(Command)
	
	OpenForm("Catalog.ProductionOrderStatuses.ListForm");
	
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
	
	// Additionally
	CommonUseClientServer.SetFormItemProperty(Items, "SettingsProcessingOfTollingFO", "Enabled", ConstantsSet.UseBatches);
	
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
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "UseBatches" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "Group4", "Enabled", Parameter.Value);
			
		EndIf;
		
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

// Procedure - handler of the OnChange event of the UseProductionOrderStatuses field
//
&AtClient
Procedure FunctionalOptionUseSubsystemProductionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseProductionOrderStatuses field
//
&AtClient
Procedure UseStatusesProductionOrderOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CompletedStatus field.
//
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - the OnChange event handler of the UseOperationsManagement field.
//
&AtClient
Procedure FunctionalOptionUseTechOperationsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - the OnChange event handler of the UseOperationsManagement field.
//
&AtClient
Procedure FunctionalOptionTollingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion