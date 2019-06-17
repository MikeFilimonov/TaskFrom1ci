#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

#Region DocumentFilling

// Procedure of document filling based on the settlement reconciliation
//
Procedure FillByReconciliationStatement(DocumentReconciliationStatement)
	
	BasisDocument 	= DocumentReconciliationStatement;
	Company			= DocumentReconciliationStatement.Company;
	
	For Each CounterpartyContractString In DocumentReconciliationStatement.CounterpartyContracts Do
		
		If CounterpartyContractString.Select Then		
			CounterpartyContract = CounterpartyContractString.Contract;
			Break;		
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(CounterpartyContract) Then
		
		If CounterpartyContract.ContractKind		= Enums.ContractType.WithCustomer 
			OR CounterpartyContract.ContractKind	= Enums.ContractType.WithAgent Then
			
			OperationKind		= Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment;
			CounterpartySource	= DocumentReconciliationStatement.Counterparty;
			
		ElsIf CounterpartyContract.ContractKind		= Enums.ContractType.WithVendor 
			OR CounterpartyContract.ContractKind	= Enums.ContractType.FromPrincipal Then
			
			OperationKind	= Enums.OperationTypesArApAdjustments.VendorDebtAdjustment;
			Counterparty		= DocumentReconciliationStatement.Counterparty;
			
		EndIf;
		
		BalanceByCompanyData	= DocumentReconciliationStatement.CompanyData.Total("ClientDebtAmount") - DocumentReconciliationStatement.CompanyData.Total("CompanyDebtAmount");
		BalanceByCounterpartyData	= DocumentReconciliationStatement.CounterpartyData.Total("CompanyDebtAmount") - DocumentReconciliationStatement.CounterpartyData.Total("ClientDebtAmount");
		Discrepancy					= BalanceByCompanyData - BalanceByCounterpartyData;
		
		Correspondence = ?(Discrepancy < 0, Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome"), Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(AccountsDocument) Then
		AccountsDocument = Undefined;
	EndIf;
	
	For Each CurRow In Debitor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	For Each CurRow In Creditor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(Order) Then
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
			Order = Documents.SalesOrder.EmptyRef();
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
			Order = Documents.PurchaseOrder.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind = Enums.OperationTypesArApAdjustments.ArApAdjustments Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		If DebitorSumOfAccounting <> CreditorAccountingSum Then
			MessageText = NStr("en = 'The amount of the receivables tabular section is not equal to the amount of payables tabular section.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Debitor",
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow In Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow In Creditor Do
				TSRow.Contract = Counterparty.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		MessageText = NStr("en = 'The amount is not equal to the amount in the receivables tabular section.'");
		
		If DebitorSumOfAccounting <> AccountingAmount Then
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow In Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		EndIf;

	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
		
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		If CreditorAccountingSum <> AccountingAmount Then
			MessageText = NStr("en = 'Account amount is not equal to amount in the tabular section ""Accounts payable"".'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow In Creditor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		If Not CounterpartySource.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If Not Counterparty.DoOperationsByDocuments Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			For Each TSRow In Debitor Do
				TSRow.Contract = CounterpartySource.ContractByDefault;
			EndDo;
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CounterpartySource");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			For Each TSRow In Creditor Do
				TSRow.Contract = Counterparty.ContractByDefault;
			EndDo;
		EndIf;
			
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		
	EndIf
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.ArApAdjustments.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ArApAdjustments.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ArApAdjustments.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - handler of item event Filling
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.ReconciliationStatement") Then
		
		FillByReconciliationStatement(FillingData);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
