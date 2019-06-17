
#Region GeneralPurposeProceduresAndFunctions

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	Inventory.Period,
	|	Inventory.Recorder,
	|	Inventory.LineNumber,
	|	Inventory.Active,
	|	Inventory.RecordType,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.SalesOrder,
	|	Inventory.Quantity,
	|	Inventory.Amount,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.CorrGLAccount,
	|	Inventory.ProductsCorr,
	|	Inventory.CharacteristicCorr,
	|	Inventory.BatchCorr,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.Specification,
	|	Inventory.SpecificationCorr,
	|	Inventory.CorrSalesOrder,
	|	Inventory.SourceDocument,
	|	Inventory.Department,
	|	Inventory.Responsible,
	|	Inventory.VATRate,
	|	Inventory.FixedCost,
	|	Inventory.ProductionExpenses,
	|	Inventory.Return,
	|	Inventory.ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Products = &Products
	|	OR Inventory.ProductsCorr = &Products");
	
	Query.SetParameter("Products", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InventoryGLAccount = Parameters.InventoryGLAccount;
	ExpensesGLAccount = Parameters.ExpensesGLAccount;
	Ref = Parameters.Ref;
	
	// FD Use Production subsystems.
	UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
	
	Items.InventoryGLAccount.Visible = ?(
		(NOT ValueIsFilled(Parameters.ProductsType))
		 OR Parameters.ProductsType = Enums.ProductsTypes.InventoryItem,
		True,
		False
	);
	
	Items.ExpensesGLAccount.Visible = ?(
		(NOT ValueIsFilled(Parameters.ProductsType))
		 OR Parameters.ProductsType = Enums.ProductsTypes.InventoryItem
		 // AND NOT UseProductionSubsystem)
		 OR Parameters.ProductsType = Enums.ProductsTypes.Work
		 OR Parameters.ProductsType = Enums.ProductsTypes.Operation
		 OR Parameters.ProductsType = Enums.ProductsTypes.Service,
		True,
		False
	);
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for these products in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	DefaultAtServer();
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	If Items.InventoryGLAccount.Visible Then
		InventoryGLAccount = GetDefaultGLAccount("Inventory");
	EndIf;
	
	If Items.ExpensesGLAccount.Visible Then
		If UseProductionSubsystem Then
			ExpensesGLAccount = GetDefaultGLAccount("WorkInProcess");
		Else
			ExpensesGLAccount = GetDefaultGLAccount("Expenses");
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"InventoryGLAccount, ExpensesGLAccount",
		InventoryGLAccount, ExpensesGLAccount
	);
	
	Notify("ProductsAccountsChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure InventoryGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(InventoryGLAccount) Then
		InventoryGLAccount = GetDefaultGLAccount("Inventory");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure ExpensesGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(ExpensesGLAccount) Then
		If UseProductionSubsystem Then
			ExpensesGLAccount = GetDefaultGLAccount("WorkInProcess");
		Else
			ExpensesGLAccount = GetDefaultGLAccount("Expenses");
		EndIf;
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
