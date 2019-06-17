
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IncludeCostOfOther		= False;
	IncludeInIncomeOther	= False;
	
	// To display other expenses together with the principal expenses.
	If Parameters.Property("IncludeCostOfOther") Then
		IncludeCostOfOther = Parameters.IncludeCostOfOther;
	EndIf;
	
	// To display other income together with the principal one.
	If Parameters.Property("IncludeInIncomeOther") Then
		IncludeInIncomeOther = Parameters.IncludeInIncomeOther;
	EndIf;
	
	// To change the form header.
	If Parameters.Property("InvoiceHeader") Then
		Title = Parameters.InvoiceHeader;
	EndIf;
	
	// To change the form header.
	If Parameters.Property("ExcludePredefinedAccount") Then
		ExcludePredefinedAccount = Parameters.ExcludePredefinedAccount;
	EndIf;

	If Parameters.Property("CurrentRow") Then
		CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Count() > 0 Then
			Filter = Parameters.Filter;
	Else
		ShowAllAccounts					= True;
		Items.ShowAllAccounts.Visible	= False;
	EndIf;
	
	If Parameters.Property("AllowHeaderAccountsSelection") Then
		AllowHeaderAccountsSelection = Parameters.AllowHeaderAccountsSelection;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ShowAllAccountsOnChange(Undefined);
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure HierarchyOnActivateRow(Item)
	
	If Items.Hierarchy.CurrentData <> Undefined
		AND CurHierarchy <> Items.Hierarchy.CurrentData.Value Then
		
		SetFilterOnClient(Items.Hierarchy.CurrentData.Value);
		CurHierarchy = Items.Hierarchy.CurrentData.Value;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowAllAccountsOnChange(Item)
	
	If ShowAllAccounts Then	
		ShowAllAccountsAtServer();		
	Else
		CurHierarchy = Undefined;
		Items.DistributionDirection.Visible = True;
		SetFilter();
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Not AllowHeaderAccountsSelection Then
		
		ListRow = Item.RowData(SelectedRow);
		
		If Not ListRow = Undefined Then
			
			If ListRow.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Header") Then
				
				StandardProcessing = False;
				
				If Items.List.Representation = TableRepresentation.HierarchicalList Then
					Item.CurrentParent = NewParent(Item.CurrentParent, SelectedRow);
				EndIf;
				
				If Items.List.Representation = TableRepresentation.Tree Then
					If Item.Expanded(SelectedRow) Then
						Item.Collapse(SelectedRow);
					Else
						Item.Expand(SelectedRow);
					EndIf;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If Not AllowHeaderAccountsSelection Then
		
		ListRow = Item.RowData(Value);
		
		If Not ListRow = Undefined Then
			
			If ListRow.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Header") Then
				
				StandardProcessing = False;
				
				MessageText = NStr(
					"en = 'Select an item, not a group.
					|To expand a group use ""Ctrl"" and the Up Arrow and Down Arrow keys or ""+"" and ""-"" keys on the number pad.'");
				
				ShowMessageBox(Undefined, MessageText);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function NewParent(CurrentParent, CurrentItem)
	
	CurrentItemParent = CommonUse.ObjectAttributeValue(CurrentItem, "Parent");
	
	If Not ValueIsFilled(CurrentItemParent) Then
		CurrentItemParent = Undefined;
	EndIf;
		
	If CurrentParent = CurrentItemParent Then
		Return CurrentItem;
	Else
		Return CurrentItemParent;
	EndIf;
	
EndFunction

&AtServer
Procedure AddHierarchy(GLAccountsTypes = Undefined, TypeOfAccount = Undefined)
	
	UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
	
	Ct = 0;
	CurHierarchyRow = 0;
	
	If TypeOf(GLAccountsTypes) = Type("FixedArray") Then
		For Each CurAccountType In GLAccountsTypes Do
			InvoiceHeader = "";
			If CurAccountType = Enums.GLAccountsTypes.Expenses Then
				InvoiceHeader = NStr("en = 'Expenses allocated to the financial result (Indirect)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherExpenses Then
				InvoiceHeader = NStr("en = 'Other expenses allocated to the financial result'");
			ElsIf  CurAccountType = Enums.GLAccountsTypes.Revenue Then
				InvoiceHeader = NStr("en = 'Income allocated to the financial result'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherIncome Then
				InvoiceHeader = NStr("en = 'Other income allocated to the financial result'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsReceivable Then
				InvoiceHeader = NStr("en = 'Other debtors (debt to us)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsPayable Then
				InvoiceHeader = NStr("en = 'Other creditors (our debt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.CashAndCashEquivalents Then
				InvoiceHeader = NStr("en = 'Funds transfer'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LongtermLiabilities Then
				InvoiceHeader = NStr("en = 'Long-term liabilities'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.Capital Then
				InvoiceHeader = NStr("en = 'Capital'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LoansBorrowed Then
				InvoiceHeader = NStr("en = 'Credits and Loans'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.WorkInProcess Then
				InvoiceHeader = NStr("en = 'Expenses related to product release (Direct)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
				InvoiceHeader = NStr("en = 'Costs allocated to product release cost (Indirect)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherCurrentAssets Then
				InvoiceHeader = NStr("en = 'Other Current Assets'");
			EndIf;
			If (UseProductionSubsystem
				  OR (CurAccountType <> Enums.GLAccountsTypes.WorkInProcess
					   AND CurAccountType <> Enums.GLAccountsTypes.IndirectExpenses))
			   AND (NOT IncludeCostOfOther
				  OR (IncludeCostOfOther
					   AND CurAccountType <> Enums.GLAccountsTypes.OtherExpenses))
			   AND (NOT IncludeInIncomeOther
				  OR (IncludeInIncomeOther
					   AND CurAccountType <> Enums.GLAccountsTypes.OtherIncome)) Then // adding hierarchy if the filter corresponds to conditions.
				Hierarchy.Add(CurAccountType, InvoiceHeader);
				If CurAccountType = TypeOfAccount
					OR (IncludeCostOfOther AND TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses AND CurAccountType = Enums.GLAccountsTypes.Expenses)
					OR (IncludeInIncomeOther AND TypeOfAccount = Enums.GLAccountsTypes.OtherIncome AND CurAccountType = Enums.GLAccountsTypes.Revenue) Then
					CurHierarchyRow = Ct;
				EndIf;
				Ct = Ct + 1;
			EndIf;
		EndDo;
	ElsIf ValueIsFilled(GLAccountsTypes) Then
		Hierarchy.Add(GLAccountsTypes);
		CurHierarchyRow = 0;
	Else
		For Ct = 0 To Enums.GLAccountsTypes.Count() - 1 Do
			Hierarchy.Add(Enums.GLAccountsTypes[Ct]);
		EndDo;
		CurHierarchyRow = 0;
	EndIf;
	
	For Ct = 0 To Hierarchy.Count() - 1 Do
		Hierarchy[Ct].Picture = PictureLib.Folder;
	EndDo;
	
	Items.Hierarchy.CurrentRow = CurHierarchyRow;
	
EndProcedure

&AtClient
Procedure SetFilterOnClient(TypeOfAccount = Undefined)
	
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	
	If ExcludePredefinedAccount Then
		
		FilterList = SetFilterOnServer(); // Accounts matching accumulation registers shall be excluded from the filter for other operations.
		
		FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue		= New DataCompositionField("Ref");
		FilterItem.ComparisonType	= DataCompositionComparisonType.NotInList;
		FilterItem.Use			= True;
		FilterItem.RightValue		= FilterList;
		
	EndIf;
	
	If ValueIsFilled(TypeOfAccount) Then
		
		FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("TypeOfAccount");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.Use = True;
		
		If TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Expenses")
			AND IncludeCostOfOther = True Then
			
			FilterList = New ValueList();
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.Expenses"));
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.OtherExpenses"));
			FilterItem.ComparisonType	= DataCompositionComparisonType.InList;
			FilterItem.RightValue		= FilterList;
			
		ElsIf TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
			AND IncludeInIncomeOther = True Then
			
			FilterList = New ValueList();
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.Revenue"));
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.OtherIncome"));
			FilterItem.ComparisonType	= DataCompositionComparisonType.InList;
			FilterItem.RightValue		= FilterList;
			
		Else
			FilterItem.RightValue = TypeOfAccount;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowAllAccountsAtServer()
	
	Items.DistributionDirection.Visible = False;
	Items.List.Representation			= TableRepresentation.HierarchicalList;
	
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	List.Filter.Items.Clear();
	
EndProcedure

&AtServer
Procedure SetFilter()
	
	Hierarchy.Clear();
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	Items.List.Representation = TableRepresentation.List;
	
	If ValueIsFilled(Filter) AND Filter.Property("TypeOfAccount") Then
		CommonUseClientServer.AddCompositionItem(List.Filter, "TypeOfAccount", DataCompositionComparisonType.Equal, Filter.TypeOfAccount,, True);
	EndIf;
	
	FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("Ref");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.Use				= True;
		
	If ValueIsFilled(CurrentRow)
	   AND TypeOf(CurrentRow) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts")
	   AND ValueIsFilled(Filter)
	   AND Filter.Property("TypeOfAccount") Then // if the account is already selected.
			AddHierarchy(Filter.TypeOfAccount, CurrentRow.TypeOfAccount);
			FilterItem.RightValue = CurrentRow; // to exclude blinking at filter setting.
	ElsIf ValueIsFilled(Filter)
		AND Filter.Property("TypeOfAccount") Then // if the account isn't selected.
			AddHierarchy(Filter.TypeOfAccount);
			FilterItem.RightValue = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef(); // to exclude blinking at filter setting.
	Else
		AddHierarchy();
		FilterItem.RightValue = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;	

EndProcedure

&AtServer
Function SetFilterOnServer()
	
	FilterList = New ValueList(); // Accounts matching accumulation registers shall be excluded from the filter for other operations.
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxRefund"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvancesToSuppliers"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CustomerAdvances"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsReceivable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable"));
	
	Return FilterList;
	
EndFunction

#EndRegion
