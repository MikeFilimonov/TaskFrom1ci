#Region Variables

&AtClient
Var InterruptIfNotCompleted;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
// Procedure initializes the month end according to IB kind.
//
Procedure InitializeMonthEnd()
	
	Completed = False;
	ExecuteMonthEndAtServer();
	
	If Completed Then
		ActualizeDateBanEditing();
	Else
		
		InterruptIfNotCompleted = False;
		Items["Pages" + String(CurMonth)].CurrentPage = Items["LongOperation" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled	= False;
		Items.CancelMonthEnd.Enabled	= False;
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure manages the actualizing of edit prohibition date in appendix
// 
Procedure ActualizeDateBanEditing()

	If UseProhibitionDatesOfDataImport
		AND Not ValueIsFilled(SetClosingDateOnMonthEndClosing) Then
		
		Response = Undefined;
		OpenForm("DataProcessor.MonthEndClosing.Form.SetClosingDateOnMonthEndClosing",,,,,, New NotifyDescription("ActualizeDateBanEditingEnd", ThisObject));
		
		Return;
		
	ElsIf UseProhibitionDatesOfDataImport
		AND SetClosingDateOnMonthEndClosing = PredefinedValue("Enum.YesNo.Yes") Then
			ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualizeDateBanEditingEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If ValueIsFilled(Response) AND Response = DialogReturnCode.Yes Then
        ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
    EndIf;
    
EndProcedure

&AtServerNoContext
// Function reads and returns the form attribute value for the specified month
// 
Function AttributeValueFormsOnValueOfMonth(ThisForm, NameOfFlag, CurMonth)
	
	Return ThisForm[NameOfFlag + String(CurMonth)];
	
EndFunction

&AtServer
// Function forms the parameter structure from the form attribute values
//
Function GetStructureParametersAtServer()
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("CurMonth", CurMonth);
	ParametersStructure.Insert("CurYear", CurYear);
	ParametersStructure.Insert("Company", Object.Company);
	
	ExecuteCalculationOfDepreciation = AttributeValueFormsOnValueOfMonth(ThisForm, "AccrueDepreciation", CurMonth);
	ParametersStructure.Insert("ExecuteCalculationOfDepreciation", ExecuteCalculationOfDepreciation);
	
	// Fill the array of operations which are required for month end
	OperationArray = New Array;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "VerifyTaxInvoices", CurMonth) Then		
		OperationArray.Add("VerifyTaxInvoices");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisObject, "VATPayableCalculation", CurMonth) Then
		OperationArray.Add("VATPayableCalculation");
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "DirectCostCalculation", CurMonth) Then		
		OperationArray.Add("DirectCostCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "CostAllocation", CurMonth) Then		
		OperationArray.Add("CostAllocation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ActualCostCalculation", CurMonth) Then		
		OperationArray.Add("ActualCostCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "RetailCostCalculation", CurMonth) Then		
		OperationArray.Add("RetailCostCalculationEarningAccounting");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ExchangeDifferencesCalculation", CurMonth) Then		
		OperationArray.Add("ExchangeDifferencesCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "FinancialResultCalculation", CurMonth) Then		
		OperationArray.Add("FinancialResultCalculation");		
	EndIf;
	
	ParametersStructure.Insert("OperationArray", OperationArray);
	
	Return ParametersStructure;
	
EndFunction

&AtServer
// Procedure executes the month end
//
Procedure ExecuteMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	
	If CommonUse.FileInfobase() Then
		
		DataProcessors.MonthEndClosing.ExecuteMonthEnd(ParametersStructure);
		Completed = True;
		
		GetInfoAboutPeriodsClosing();
		
	Else
		ExecuteClosingMonthInLongOperation(ParametersStructure);
		CheckAndDisplayError(ParametersStructure);
	EndIf;
	
EndProcedure

&AtServer
// Procedure of the month end cancellation.
// It posts month end documents and updates the form state
//
Procedure CancelMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	DataProcessors.MonthEndClosing.CancelMonthEnd(ParametersStructure);
	GetInfoAboutPeriodsClosing();
	
EndProcedure
// LongActions

&AtServer
// Procedure checks and displays the error
//
Procedure CheckAndDisplayError(ParametersStructure)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MonthEndErrors.ErrorDescription
	|FROM
	|	InformationRegister.MonthEndErrors AS MonthEndErrors
	|WHERE
	|	MonthEndErrors.Period >= &BeginOfPeriod
	|	AND MonthEndErrors.Period <= &EndOfPeriod";
	
	Query.SetParameter("BeginOfPeriod", BegOfMonth(Date(ParametersStructure.CurYear, ParametersStructure.CurMonth, 1)));
	Query.SetParameter("EndOfPeriod", EndOfMonth(Date(ParametersStructure.CurYear, ParametersStructure.CurMonth, 1)));
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		MessageText = NStr("en = 'Warnings were generated on month-end closing. For more information, see the month-end closing report.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks the state of the month ending
//
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted Then
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled = True;
		Items.CancelMonthEnd.Enabled = True;
		
		ActualizeDateBanEditing();
		
	ElsIf InterruptIfNotCompleted Then
		
		DetachIdleHandler("CheckExecution");
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled	= True;
		Items.CancelMonthEnd.Enabled	= True;
		
		ActualizeDateBanEditing();
		
	Else		
		If BackgroundJobIntervalChecks < 15 Then			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;		
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);		
	EndIf;
	
EndProcedure

&AtServer
// Procedure executes the month end in long actions (in the background)
//
Procedure ExecuteClosingMonthInLongOperation(ParametersStructureBackgroundJob)
	
	AssignmentResult = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.MonthEndClosing.ExecuteMonthEnd",
		ParametersStructureBackgroundJob,
		NStr("en = 'Month-end closing is in progress'")
	);
	
	Completed = AssignmentResult.JobCompleted;
	
	If Completed Then		
		GetInfoAboutPeriodsClosing();		
	Else		
		BackgroundJobID				= AssignmentResult.JobID;
		BackgroundJobStorageAddress	= AssignmentResult.StorageAddress;		
	EndIf;
	
EndProcedure

&AtServer
// Procedure checks the tabular document filling end on server
//
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		Completed					= True;
		CheckResult.JobCompleted	= True;
		CheckResult.Value			= GetFromTempStorage(BackgroundJobStorageAddress);
		
	ElsIf InterruptIfNotCompleted Then		
		LongActions.CancelJobExecution(BackgroundJobID);		
	EndIf;
	
	Return CheckResult;
	
EndFunction

&AtServerNoContext
// Function checks the state of the background job by variable form value
//
Function InProgressBackgroundJob(BackgroundJobID)
	
	If CommonUse.FileInfobase() Then		
		Return False;		
	EndIf;
	
	Task = BackgroundJobs.FindByUUID(BackgroundJobID);
	
	Return (Task <> Undefined) AND (Task.State = BackgroundJobState.Active);
	
EndFunction

&AtClient
// Procedure warns user about action executing impossibility
//
// It is used when closing form, canceling results of closing month
//
Procedure WarnAboutActiveBackgroundJob(Cancel = True)
	
	Cancel = True;
	WarningText = NStr("en = 'Please wait while the process is finished (recommended) or cancel it manually.'");
	ShowMessageBox(Undefined, WarningText, 10, NStr("en = 'it is impossible to close form.'"));
	
EndProcedure

// End LongActions

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Object.Company = Catalogs.Companies.MainCompany;
	
	CurDate		= CurrentDate();
	CurYear		= Year(CurDate);
	CurMonth	= Month(CurDate);
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Object.Company = Constants.ParentCompany.Get();
		Items.Company.Enabled = False;
	EndIf;
	
	SetLabelsText();
	
	GetInfoAboutPeriodsClosing();
	
	PropertyAccounting				= Constants.UseFixedAssets.Get();
	UseRetail				= Constants.UseRetail.Get();
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	For Ct = 1 To 12 Do
		Items.Find("GroupAccrueDepreciation" + Ct).Visible				= PropertyAccounting;
		Items.Find("GroupRetailCostCalculation" + Ct).Visible			= UseRetail;
		Items.Find("GroupExchangeDifferencesCalculation" + Ct).Visible	= ForeignExchangeAccounting;
	EndDo;
	
	SectionsProperties				= ClosingDatesServiceReUse.SectionsProperties();
	UseProhibitionDatesOfDataImport	= SectionsProperties.UseProhibitionDatesOfDataImport;
	SetClosingDateOnMonthEndClosing		= Constants.SetClosingDateOnMonthEndClosing.Get();
	
	DateProhibition = GetEditProhibitionDate();
	
	If ValueIsFilled(DateProhibition) Then
		EditProhibitionDate = DateProhibition;
	Else
		Items.EditProhibitionDate.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - The AtOpen form event handler
//
Procedure OnOpen(Cancel)
	
	SetMarkCurMonth();
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted		
			WarnAboutActiveBackgroundJob(Cancel);		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtServer
Function GetEditProhibitionDate()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ClosingDates.Section,
	|	ClosingDates.Object,
	|	ClosingDates.User,
	|	ClosingDates.ProhibitionDate,
	|	ClosingDates.ProhibitionDateDescription,
	|	ClosingDates.Comment
	|FROM
	|	InformationRegister.ClosingDates AS ClosingDates
	|WHERE
	|	ClosingDates.User = &User
	|	AND ClosingDates.Object = &Object";
	
	Query.SetParameter("User",  Enums.ClosingDateAreas.ForAllUsers);
	Query.SetParameter("Object", ChartsOfCharacteristicTypes.ClosingDateSections.EmptyRef());
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.ProhibitionDate;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtServer
Procedure SetLabelsText()
	
	Items.YearAgo.Title		= "" + Format((CurYear - 1), "NG=0") + " <<";
	Items.NextYear.Title	= ">> " + Format((CurYear + 1), "NG=0");
	Items.NextYear.Enabled	= Not (CurYear + 1 > Year(CurrentDate()));
	
EndProcedure

&AtClient
Procedure SetMarkCurMonth()
	
	Items.Months.CurrentPage		= Items.Find("M" + CurMonth);
	
EndProcedure

&AtServer
Procedure ExecuteChangeProhibitionDatePostpone(Date)
	
	RecordSet = InformationRegisters.ClosingDates.CreateRecordSet();
	
	NewRow = RecordSet.Add();
	NewRow.User				= Enums.ClosingDateAreas.ForAllUsers;
	NewRow.Object			= ChartsOfCharacteristicTypes.ClosingDateSections.EmptyRef();
	NewRow.ProhibitionDate	= Date;
	NewRow.Comment			= "(Default)";
	
	RecordSet.Write(True);
	
	EditProhibitionDate = Date;
	Items.EditProhibitionDate.Visible = True;
	
	SetClosingDateOnMonthEndClosing = Constants.SetClosingDateOnMonthEndClosing.Get();
	
EndProcedure

&AtServer
Procedure GetInfoAboutPeriodsClosing()
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	// Coloring of tabs and operations.
	TableMonths = New ValueTable;
	
	TableMonths.Columns.Add("Year",		New TypeDescription("Number"));
	TableMonths.Columns.Add("Month",	New TypeDescription("Number"));
	TableMonths.Columns.Add("Date",		New TypeDescription("Date"));
	
	For Ct = 1 To 12 Do
		NewRow = TableMonths.Add();
		NewRow.Year		= CurYear;
		NewRow.Month	= Ct;
		NewRow.Date		= Date(Format(NewRow.Year, "NFD=0; NG=") + Format(NewRow.Month, "ND=2; NFD=0; NLZ=; NG=") + "01");
	EndDo;
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	TableMonths.Year AS Year,
	|	TableMonths.Month AS Month,
	|	TableMonths.Date AS Date
	|INTO TempTableMonths
	|FROM
	|	&TableMonths AS TableMonths
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NOT AccountingPolicy.PostVATEntriesBySourceDocuments AS UseTaxInvoices,
	|	AccountingPolicy.Period AS Period
	|INTO TempAccountingPolicy
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Year AS Year,
	|	TableMonths.Month AS Month,
	|	TableMonths.Date AS Date,
	|	TempAccountingPolicy.UseTaxInvoices AS UseTaxInvoices,
	|	TempAccountingPolicy.Period AS Period
	|INTO TableMonthsAndPolicy
	|FROM
	|	TempTableMonths AS TableMonths
	|		LEFT JOIN TempAccountingPolicy AS TempAccountingPolicy
	|		ON TableMonths.Date >= TempAccountingPolicy.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Date AS Date,
	|	MAX(TableMonths.Period) AS MaxPeriod
	|INTO TableMonthsMax
	|FROM
	|	TableMonthsAndPolicy AS TableMonths
	|
	|GROUP BY
	|	TableMonths.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonthsAndPolicy.Year AS Year,
	|	TableMonthsAndPolicy.Month AS Month,
	|	TableMonthsAndPolicy.Date AS Date,
	|	TableMonthsAndPolicy.UseTaxInvoices AS UseTaxInvoices,
	|	TableMonthsAndPolicy.Period AS Period
	|INTO TableMonths
	|FROM
	|	TableMonthsMax AS TableMonthsMax
	|		INNER JOIN TableMonthsAndPolicy AS TableMonthsAndPolicy
	|		ON TableMonthsMax.Date = TableMonthsAndPolicy.Date
	|			AND TableMonthsMax.MaxPeriod = TableMonthsAndPolicy.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN COUNT(FixedAssetsDepreciation.Ref) > 0
	|			THEN 1
	|		ELSE 0
	|	END AS AccrueDepreciation,
	|	YEAR(FixedAssetsDepreciation.Date) AS Year,
	|	MONTH(FixedAssetsDepreciation.Date) AS Month
	|INTO NestedSelectDepreciation
	|FROM
	|	Document.FixedAssetsDepreciation AS FixedAssetsDepreciation
	|WHERE
	|	FixedAssetsDepreciation.Posted = TRUE
	|	AND YEAR(FixedAssetsDepreciation.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN FixedAssetsDepreciation.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(FixedAssetsDepreciation.Date),
	|	MONTH(FixedAssetsDepreciation.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(MonthEndClosing.Ref) AS CountRef,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.DirectCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS DirectCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.CostAllocation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS CostAllocation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.ActualCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ActualCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.FinancialResultCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS FinancialResultCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.ExchangeDifferencesCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ExchangeDifferencesCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.RetailCostCalculationEarningAccounting, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS RetailCostCalculationEarningAccounting,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.VerifyTaxInvoices, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS VerifyTaxInvoices,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.VATPayableCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS VATPayableCalculation,
	|	YEAR(MonthEndClosing.Date) AS Year,
	|	MONTH(MonthEndClosing.Date) AS Month
	|INTO NestedSelect
	|FROM
	|	Document.MonthEndClosing AS MonthEndClosing
	|WHERE
	|	MonthEndClosing.Posted
	|	AND YEAR(MonthEndClosing.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEndClosing.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(MonthEndClosing.Date),
	|	MONTH(MonthEndClosing.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Month AS Month,
	|	TableMonths.Year AS Year,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndIsNecessary,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|					AND (ISNULL(NestedSelect.DirectCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.CostAllocation, 0) = 0
	|						OR ISNULL(NestedSelect.ActualCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.FinancialResultCalculation, 0) = 0)
	|				OR COUNT(POSSummary.Recorder) > 0
	|					AND ISNULL(NestedSelect.RetailCostCalculationEarningAccounting, 0) = 0
	|				OR COUNT(ExchangeRates.Currency) > 0
	|					AND ISNULL(NestedSelect.ExchangeDifferencesCalculation, 0) = 0
	|				OR COUNT(FixedAssets.FixedAsset) > 0
	|					AND ISNULL(NestedSelectDepreciation.AccrueDepreciation, 0) = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AreNecessaryUnperformedSettlements,
	|	CASE
	|		WHEN COUNT(POSSummary.Recorder) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(ExchangeRates.Currency) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(FixedAssets.FixedAsset) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciationIsNecessary,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndWasPerformed,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation = 0
	|				OR NestedSelect.CostAllocation = 0
	|				OR NestedSelect.ActualCostCalculation = 0
	|				OR NestedSelect.FinancialResultCalculation = 0
	|				OR NestedSelect.ExchangeDifferencesCalculation = 0
	|				OR NestedSelect.RetailCostCalculationEarningAccounting = 0
	|				OR NestedSelectDepreciation.AccrueDepreciation = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsNonProducedCalculations,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DirectCostCalculation,
	|	CASE
	|		WHEN NestedSelect.CostAllocation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CostAllocation,
	|	CASE
	|		WHEN NestedSelect.ActualCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ActualCostCalculation,
	|	CASE
	|		WHEN NestedSelect.FinancialResultCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FinancialResultCalculation,
	|	CASE
	|		WHEN NestedSelect.ExchangeDifferencesCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.RetailCostCalculationEarningAccounting > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationEarningAccounting,
	|	CASE
	|		WHEN TableMonths.UseTaxInvoices
	|			THEN CASE
	|					WHEN NestedSelect.VerifyTaxInvoices > 0
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		ELSE FALSE
	|	END AS VerifyTaxInvoices,
	|	CASE
	|		WHEN NestedSelect.VATPayableCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS VATPayableCalculation,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS HasErrors,
	|	CASE
	|		WHEN NestedSelectDepreciation.AccrueDepreciation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciation,
	|	NOT TableMonths.UseTaxInvoices AS NoUseTaxInvoice
	|FROM
	|	TableMonths AS TableMonths
	|		LEFT JOIN AccumulationRegister.Inventory.Turnovers(, , Month, ) AS InventoryTurnover
	|		ON (TableMonths.Month = MONTH(InventoryTurnover.Period))
	|			AND (TableMonths.Year = YEAR(InventoryTurnover.Period))
	|			AND (InventoryTurnover.Company = &Company)
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (TableMonths.Month = MONTH(ExchangeRates.Period))
	|			AND (TableMonths.Year = YEAR(ExchangeRates.Period))
	|		LEFT JOIN AccumulationRegister.POSSummary AS POSSummary
	|		ON (TableMonths.Month = MONTH(POSSummary.Period))
	|			AND (TableMonths.Year = YEAR(POSSummary.Period))
	|			AND (POSSummary.Active = TRUE)
	|			AND (POSSummary.Company = &Company)
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(, , Month, , ) AS FixedAssets
	|		ON (TableMonths.Month = MONTH(FixedAssets.Period))
	|			AND (TableMonths.Year = YEAR(FixedAssets.Period))
	|			AND (FixedAssets.Company = &Company)
	|		LEFT JOIN NestedSelectDepreciation AS NestedSelectDepreciation
	|		ON TableMonths.Year = NestedSelectDepreciation.Year
	|			AND TableMonths.Month = NestedSelectDepreciation.Month
	|		LEFT JOIN NestedSelect AS NestedSelect
	|		ON TableMonths.Year = NestedSelect.Year
	|			AND TableMonths.Month = NestedSelect.Month
	|		LEFT JOIN InformationRegister.MonthEndErrors AS MonthEndErrors
	|		ON (TableMonths.Year = YEAR(MonthEndErrors.Period))
	|			AND (TableMonths.Month = MONTH(MonthEndErrors.Period))
	|			AND (CASE
	|				WHEN &FilterByCompanyIsNecessary
	|					THEN MonthEndErrors.Recorder.Company = &Company
	|				ELSE TRUE
	|			END)
	|
	|GROUP BY
	|	TableMonths.Month,
	|	TableMonths.Year,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN ISNULL(FixedAssets.CostClosingBalance, 0) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN NestedSelectDepreciation.AccrueDepreciation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.DirectCostCalculation,
	|	NestedSelect.CostAllocation,
	|	NestedSelect.ActualCostCalculation,
	|	NestedSelect.FinancialResultCalculation,
	|	NestedSelect.RetailCostCalculationEarningAccounting,
	|	NestedSelectDepreciation.AccrueDepreciation,
	|	NestedSelect.ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.VerifyTaxInvoices,
	|	TableMonths.UseTaxInvoices,
	|	CASE
	|		WHEN NestedSelect.VATPayableCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.VATPayableCalculation
	|
	|ORDER BY
	|	Year,
	|	Month";
	
	Query.SetParameter("Company",						ParentCompany);
	Query.SetParameter("FilterByCompanyIsNecessary",	Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("TableMonths",					TableMonths);
	Query.SetParameter("Year",							CurYear);
	
	CurrentMonth	= Month(CurrentDate());
	CurrentYear		= Year(CurrentDate());
	Result			= Query.Execute();
	Selection		= Result.Select();
	
	While Selection.Next() Do
		
		Items["M" + Selection.Month].Enabled = True;
		
		// Bookmarks.
		If Selection.Year = CurrentYear
			AND Selection.Month = CurrentMonth
			AND Not Selection.MonthEndWasPerformed
			AND Not Selection.AccrueDepreciation Then
			
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
				
		ElsIf (Selection.Month > CurrentMonth AND Selection.Year = CurrentYear)
			OR Selection.Year > CurrentYear Then
			
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
			Items["M" + Selection.Month].Enabled = False;
				
		ElsIf (Selection.MonthEndIsNecessary
				AND Not Selection.MonthEndWasPerformed)
			OR (Selection.RetailCostCalculationIsNecessary
				AND Not Selection.RetailCostCalculationEarningAccounting)
			OR (Selection.ExchangeDifferencesCalculationIsNecessary
				AND Not Selection.ExchangeDifferencesCalculation)
			OR (Selection.AccrueDepreciationIsNecessary
				AND Not Selection.AccrueDepreciation) Then
				
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
				
		ElsIf (Selection.MonthEndIsNecessary
				AND Selection.MonthEndWasPerformed
				AND Selection.AreNecessaryUnperformedSettlements)
			OR Selection.HasErrors Then
			
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
			
		Else
			Items["M" + Selection.Month].Picture = Items.Green.Picture;
		EndIf;
		
		// Operations.
		ThisForm["CostAllocation" + Selection.Month]					= Selection.CostAllocation;
		ThisForm["ExchangeDifferencesCalculation" + Selection.Month]	= Selection.ExchangeDifferencesCalculation;
		ThisForm["DirectCostCalculation" + Selection.Month]				= Selection.DirectCostCalculation;
		ThisForm["RetailCostCalculation" + Selection.Month]				= Selection.RetailCostCalculationEarningAccounting;
		ThisForm["ActualCostCalculation" + Selection.Month]				= Selection.ActualCostCalculation;
		ThisForm["FinancialResultCalculation" + Selection.Month]		= Selection.FinancialResultCalculation;
		ThisForm["AccrueDepreciation" + Selection.Month]				= Selection.AccrueDepreciation;
		ThisForm["VerifyTaxInvoices" + Selection.Month]					= Selection.VerifyTaxInvoices;
		ThisForm["VATPayableCalculation" + Selection.Month]				= Selection.VATPayableCalculation;
		
		If Selection.NoUseTaxInvoice Then
			Items.Find("GroupVerifyTaxInvoices" + Selection.Month).Visible = False;
		EndIf;
		
		If Selection.MonthEndIsNecessary Then
			
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= ?(ThisForm["CostAllocation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= ?(ThisForm["DirectCostCalculation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= ?(ThisForm["ActualCostCalculation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= ?(ThisForm["FinancialResultCalculation" + Selection.Month],
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.GreenIsNotRequired.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			
		ElsIf Selection.Month > CurrentMonth
			OR Selection.Year > CurrentYear Then
			  
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= Items.Gray.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= Items.Gray.Picture;
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.Gray.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			
		Else
			
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= Items.GreenIsNotRequired.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= Items.GreenIsNotRequired.Picture;
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.GreenIsNotRequired.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			
		EndIf;
		
		If Selection.ExchangeDifferencesCalculationIsNecessary Then
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.RetailCostCalculationIsNecessary Then
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.AccrueDepreciationIsNecessary Then
			Items.Find("AccrueDepreciationPicture" + Selection.Month).Picture = 
				?(ThisForm["AccrueDepreciation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("AccrueDepreciationPicture" + Selection.Month).Picture = 
				?(ThisForm["AccrueDepreciation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		ThisForm["TextErrorCostAllocation" + Selection.Month]					= "";
		ThisForm["TextErrorDirectCostCalculation" + Selection.Month]			= "";
		ThisForm["TextErrorActualCostCalculation" + Selection.Month]			= "";
		ThisForm["TextErrorFinancialResultCalculation" + Selection.Month]		= "";
		ThisForm["TextErrorExchangeDifferencesCalculation" + Selection.Month]	= "";
		ThisForm["TextErrorCalculationPrimecostInRetail" + Selection.Month]		= "";
		ThisForm["TextErrorAccrueDepreciation" + Selection.Month]				= "";
		ThisForm["TextErrorVerifyTaxInvoices" + Selection.Month]				= "";
		ThisForm["TextErrorVATPayableCalculation" + Selection.Month]			= "";

	EndDo;
	
	// Errors.
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	MONTH(MonthEndErrors.Period) AS Month,
	|	MonthEndErrors.OperationKind,
	|	MonthEndErrors.ErrorDescription
	|FROM
	|	InformationRegister.MonthEndErrors AS MonthEndErrors
	|WHERE
	|	MonthEndErrors.Active
	|	AND YEAR(MonthEndErrors.Period) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEndErrors.Recorder.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	Month";
	
	Query.SetParameter("FilterByCompanyIsNecessary",	Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("Company",						ParentCompany);
	Query.SetParameter("Year",							CurYear);
	
	SelectionErrors = Query.Execute().Select();
	
	While SelectionErrors.Next() Do
		
		If TrimAll(SelectionErrors.OperationKind) = "CostAllocation" Then
			Items.Find("CostAllocationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCostAllocation" + SelectionErrors.Month] = 
					NStr("en = 'While cost allocation the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ExchangeDifferencesCalculation" Then
			Items.Find("ExchangeDifferencesCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While currency difference calculation the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "DirectCostCalculation" Then
			Items.Find("DirectCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While direct cost calculation the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "RetailCostCalculation" Then
			Items.Find("RetailCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month] = 
					NStr("en = 'While calculation of primecost in retail the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ActualCostCalculation" Then
			Items.Find("ActualCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While actual primecost calculation the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "FinancialResultCalculation" Then
			Items.Find("FinancialResultCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While the financial result calculation the errors have occurred. 
					     |For more details see the closing month report'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "AccrueDepreciation" Then
			Items.Find("AccrueDepreciationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month] = 
					NStr("en = 'While depreciation charging the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "Verify tax invoices" Then
			Items.Find("VerifyTaxInvoicesPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month] = 
					NStr("en = 'While verifing tax invoice the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "VAT payable calculation" Then
			Items.Find("VATPayableCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While VAT payable calculation the errors have occurred. 
					     |See details in the month end report.'");
			EndIf;
		EndIf;
		
	EndDo;
	
	For Ct = 1 To 12 Do
			
		If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + Ct]) Then
			If Items.Find("CostAllocationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'");						
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Costs are not allocated.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Red.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Cost allocation is required.'");			
			EndIf;			
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + Ct]) Then
			If Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs are calculated.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is not required.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs were not calculated.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + Ct]) Then
			If Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost is calculated successfully.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is not required.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation was not performed.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + Ct]) Then
			If Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result is calculated.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result calculation is not required.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result was not calculated.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result calculation is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + Ct]) Then
			If Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are successfully calculated.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not required.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not calculated.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + Ct]) Then
			If Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is not calculated.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + Ct]) Then
			If Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is accrued.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not required.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not accrued.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + Ct]) Then
			If Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoices are verified.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not required.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not accrued.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is required.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + Ct]) Then
			If Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable is calculated.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is not required.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable was not calculated.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is required.'");
			EndIf;
		EndIf;
		
		If Items.Find("CostAllocationPicture" + Ct).Picture							= Items.GreenIsNotRequired.Picture
			AND Items.Find("DirectCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("ActualCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("FinancialResultCalculationPicture" + Ct).Picture		= Items.GreenIsNotRequired.Picture
			AND Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture	= Items.GreenIsNotRequired.Picture
			AND Items.Find("RetailCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("AccrueDepreciationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture					= Items.GreenIsNotRequired.Picture
			AND Items.Find("VATPayableCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture Then
			
			Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = 
				NStr("en = 'Month-end closing is not required as there is no data for calculation.'");
			
		Else
			Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = "";
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AccrueDepreciationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorAccrueDepreciation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure DirectCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorDirectCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure CostAllocationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorCostAllocation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ActualCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorActualCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure RetailCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorCalculationPrimecostInRetail" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ExchangeDifferencesCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorExchangeDifferencesCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure FinancialResultCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorFinancialResultCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure VerifyTaxInvoicesPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorVerifyTaxInvoices" + CurMonth]);
	
EndProcedure

&AtClient
Procedure VATPayableCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorVATPayableCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure MonthsOnCurrentPageChange(Item, CurrentPage)
	
	If Not Completed 
		AND ValueIsFilled(BackgroundJobID) Then
		
		Return;
		
	EndIf;
	
	If Items.Months.CurrentPage = Items.M1 Then
		CurMonth = 1;
	ElsIf Items.Months.CurrentPage = Items.M2 Then
		CurMonth = 2;
	ElsIf Items.Months.CurrentPage = Items.M3 Then
		CurMonth = 3;
	ElsIf Items.Months.CurrentPage = Items.M4 Then
		CurMonth = 4;
	ElsIf Items.Months.CurrentPage = Items.M5 Then
		CurMonth = 5;
	ElsIf Items.Months.CurrentPage = Items.M6 Then
		CurMonth = 6;
	ElsIf Items.Months.CurrentPage = Items.M7 Then
		CurMonth = 7;
	ElsIf Items.Months.CurrentPage = Items.M8 Then
		CurMonth = 8;
	ElsIf Items.Months.CurrentPage = Items.M9 Then
		CurMonth = 9;
	ElsIf Items.Months.CurrentPage = Items.M10 Then
		CurMonth = 10;
	ElsIf Items.Months.CurrentPage = Items.M11 Then
		CurMonth = 11;
	ElsIf Items.Months.CurrentPage = Items.M12 Then
		CurMonth = 12;
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If ValueIsFilled(Object.Company) Then
		Items.Months.Enabled = True;
		GetInfoAboutPeriodsClosing();
	Else
		Items.Months.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditProhibitionDateClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	OpenForm("InformationRegister.ClosingDates.Form.ClosingDates", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
// Procedure is the ExecuteMonthEnd command handler
//
Procedure ExecuteMonthEnd(Command)
	
	If EndOfMonth(Date(CurYear, CurMonth, 1)) <= EndOfDay(EditProhibitionDate) Then
		ShowMessageBox(Undefined, NStr("en = 'Cannot close the month as it belongs to the period prohibited for editing.'"));
		Return;
	EndIf;
	
	InitializeMonthEnd();
	
EndProcedure

&AtClient
Procedure NextYear(Command)
	
	CurYear = CurYear + 1;
	SetLabelsText();
	GetInfoAboutPeriodsClosing();

EndProcedure

&AtClient
Procedure YearAgo(Command)
	
	CurYear = ?(CurYear = 1, CurYear, CurYear - 1);
	SetLabelsText();
	GetInfoAboutPeriodsClosing();
	
EndProcedure

&AtClient
Procedure CancelMonthEnd(Command)
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted		
			WarnAboutActiveBackgroundJob();		
	Else		
		CancelMonthEndAtServer();	
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateReport(Command)
	
	FormParameters = New Structure(
		"BeginOfPeriod, EndOfPeriod, Company, GeneratingDate",
		BegOfMonth(Date(CurYear, CurMonth, 1)), 
		EndOfMonth(Date(CurYear, CurMonth, 1)), 
		Object.Company, 
		CurrentDate());
	OpenForm("Report.MonthEndReport.ObjectForm", FormParameters);
	
EndProcedure

// LongActions

&AtClient
// Procedure-handler of the command "Abort month closing in long Operations"
//
Procedure AbortClosingMonthInLongOperation(Command)
	
	InterruptIfNotCompleted = True;
	CheckExecution();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditProhibitionDatesOnClose" Then
		
		ProhibitionDate = GetEditProhibitionDate();
		
		If ValueIsFilled(ProhibitionDate) Then
			EditProhibitionDate = ProhibitionDate;
		Else
			Items.EditProhibitionDate.Visible = False;
		EndIf;
		
	EndIf;
	
EndProcedure

// End LongActions

&AtClient
Procedure ExecutePreliminaryAnalysis(Command)
	
	FormParameters = New Structure(
		"BeginOfPeriod, EndOfPeriod, Company, MonthEndContext",
		BegOfMonth(Date(CurYear, CurMonth, 1)), 
		EndOfMonth(Date(CurYear, CurMonth, 1)), 
		Object.Company,
		True);		
	OpenForm("DataProcessor.AccountingCorrectnessControl.Form.Form", FormParameters);
	
EndProcedure

#EndRegion
