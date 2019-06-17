#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

// Function returns the list of key attribute names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("SettlementsCurrency");
	
	Return Result;
	
EndFunction

// Initializes value tables containing data of the document tabular sections.
// Saves value tables to properties of the "AdditionalProperties" structure.
Procedure InitializeDocumentData(DocumentRefLoanContract, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	LoanContract.Ref AS LoanContract,
	|	LoanContract.CashAssetsType AS CashAssetsType,
	|	LoanContract.InflowItem AS InflowItem,
	|	LoanContract.PettyCash AS PettyCash,
	|	LoanContract.BankAccount AS BankAccount,
	|	LoanContract.Order AS Order,
	|	LoanContract.SettlementsCurrency AS SettlementsCurrency,
	|	LoanContract.Company AS Company,
	|	LoanContract.OutflowItem AS OutflowItem,
	|	LoanContract.LoanKind AS LoanKind,
	|	LoanContract.ChargeFromSalary AS ChargeFromSalary,
	|	LoanContract.Issued AS Issued
	|INTO Document
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS LoanContract,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate AS Period,
	|	LoanContractPaymentsAndAccrualsSchedule.Principal AS Principal,
	|	LoanContractPaymentsAndAccrualsSchedule.Interest AS Interest,
	|	LoanContractPaymentsAndAccrualsSchedule.Commission AS Commission
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS Register,
	|	Document.Issued AS Period,
	|	SUM(CASE
	|			WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				THEN LoanContractPaymentsAndAccrualsSchedule.Principal
	|			WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|				THEN -LoanContractPaymentsAndAccrualsSchedule.Principal
	|		END) AS Amount,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	Document.CashAssetsType AS CashAssetsType,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN Document.InflowItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN Document.OutflowItem
	|	END AS Item,
	|	Document.Company AS Company,
	|	Document.SettlementsCurrency AS Currency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS Quote,
	|	CASE
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|
	|GROUP BY
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN Document.InflowItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN Document.OutflowItem
	|	END,
	|	CASE
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	Document.Company,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	Document.CashAssetsType,
	|	Document.Issued,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN -LoanContractPaymentsAndAccrualsSchedule.PaymentAmount
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN LoanContractPaymentsAndAccrualsSchedule.PaymentAmount
	|	END,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	Document.CashAssetsType,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN Document.OutflowItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN Document.InflowItem
	|	END,
	|	Document.Company,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	CASE
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)";
	
	Query.SetParameter("Ref", DocumentRefLoanContract);
	
	ResultArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanRepaymentSchedule", ResultArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", ResultArray[2].Unload());
	
EndProcedure

// Receives the counterparty contract by default considering filter conditions. Main contract, a single contract, or an
// empty reference is returned.
//
// The
//  Counterparty	parameters	- 
//							<CatalogRef.Counterparties> Counterparty whose
//  contract	to	be 
//							received Company - <CatalogRef.Companies> Company
//  whose	contract	to be received LoanKindList - <Array> or <ValueList> 
//							consisting of values of the <EnumRef.LoanKinds> type Necessary contract kinds
//
// Returns:
//   <CatalogRef.CounterpartyContracts> - found contract or null reference
//
Function ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList = Undefined) Export
	
	If Not ValueIsFilled(Counterparty) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	LoanContract.Ref
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.Counterparty = &Counterparty
	|	AND LoanContract.Company = &Company
	|	AND LoanContract.Posted"
	+ ?(LoanKindList <> Undefined,"
	|	AND LoanContract.LoanKind IN (&LoanKindList)","");
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Company", Company);
	Query.SetParameter("LoanKindList", LoanKindList);
	
	If TypeOf(Counterparty) = Type("CatalogRef.Employees") Then
		QueryText = StrReplace(QueryText, 
			"LoanContract.Counterparty = &Counterparty", 
			"LoanContract.Employee = &Counterparty");
	EndIf;
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	Selection = Result.Select();
	If Selection.Count() = 1 
		AND Selection.Next() Then
			LoanContract = Selection.Ref;
	Else
		LoanContract = Undefined;
	EndIf;
	
	Return LoanContract;
	
EndFunction

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

// Defines object settings for the ObjectVersioning subsystem.
//
// Parameters:
//  Settings - Structure - subsystem settings.
Procedure WhenDefiningObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region PrintInterface

// Fills the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see field content in the PrintManagement.CreatePrintCommandCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
		
EndProcedure

#EndRegion

#EndIf
