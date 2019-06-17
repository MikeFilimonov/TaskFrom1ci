#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Adds the record in the register by passing parameters
//
// Parameters:
//	Month - Data - Date of the beginning of month.
//	Company - Catalog.Companies - Company for tasks.
//	Document - Documents.Ref - This document was changed.
//
Procedure CreateRegisterRecord(Month, Company = Undefined, Document = Undefined) Export
	
	If ExchangePlans.MasterNode() <> Undefined Then // Records are creating only in the master node.
		Return;
	EndIf;
	
	ArrayOfCompanies = New Array;
	
	If Not ValueIsFilled(Company) Then
		ArrayOfCompanies.Add(Catalogs.Companies.CompanyByDefault());
	ElsIf TypeOf(Company) = Type("Array") Then
		ArrayOfCompanies = Company;
	Else
		ArrayOfCompanies.Add(Company);
	EndIf;
	
	BeginTransaction();
	
	Try
		
		For Each CurrentCompany In ArrayOfCompanies Do
			Record = InformationRegisters.TasksForCostsCalculation.CreateRecordManager();
			Record.Month = BegOfMonth(Month);
			Record.TaskNumber = CurrentNumber();
			Record.Document = Document;
			Record.Company = CurrentCompany;
			Record.Write(True);
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		ErrorText = DetailErrorDescription(ErrorInfo());
		Raise ErrorText;
	EndTry;
	
EndProcedure

// Get constant value and increase it.
//
// Returned value:
//	Number - old constant value.
//
Function IncreaseTaskNumber() Export
	
	TaskNumberBeforeCalculation = 0;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock;
		DataLockItem = Lock.Add("Constant.CostCalculationTaskNumber");
		DataLockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();
		
		TaskNumberBeforeCalculation = CurrentNumber();
		Constants.CostCalculationTaskNumber.Set(TaskNumberBeforeCalculation + 1);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorInformation = DetailErrorDescription(ErrorInfo())
			+ StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Constant %1 value is %2'"),
				"Constant.CostCalculationTaskNumber",
				TaskNumberBeforeCalculation);
				
		WriteLogEvent(
			NStr("en = 'FIFO.Increase task number'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorInformation);
			
		Raise ErrorInformation;
		
	EndTry;
	
	Return TaskNumberBeforeCalculation;
EndFunction

// Get constant value
//
// Returned value:
//	Number - constant value.
//
Function CurrentNumber() Export
	SetPrivilegedMode(True);
	Return Constants.CostCalculationTaskNumber.Get();
EndFunction

// Method set data lock to the "Tasks..." register
//
// Parameters:
//	TaskNumber - Number - End of lock boundary.
//
Procedure LockRegister(TaskNumber) Export
	
	DataLock = New DataLock;
	
	DataLockItem = DataLock.Add("InformationRegister.TasksForCostsCalculation");
	DataLockItem.SetValue("TaskNumber", New Range(Undefined, TaskNumber));
	DataLockItem.Mode = DataLockMode.Exclusive;
	
	DataLock.Lock();
	
EndProcedure

// Delete records which less then CurrentPeriod and add new records.
//
// Parameters:
//	CurrentPeriod - Date - The boundary of period.
//	ArrayOfCompanies - Array - Array of companies
//	 TempTablesManager - With the "SourceTasks" temp table.
//
Procedure MoveBoundaryToNextPeriod(CurrentPeriod, ArrayOfCompanies, TempTables) Export
	
	If ExchangePlans.MasterNode() <> Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginOfCurrentPeriod = BegOfMonth(CurrentPeriod);
	EndOfCurrentPeriod = EndOfMonth(CurrentPeriod);
	
	If TheEarliestPeriod(CurrentPeriod, ArrayOfCompanies) < BeginOfCurrentPeriod Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	OldTasks.Month AS Month,
	|	OldTasks.TaskNumber AS TaskNumber,
	|	OldTasks.Company AS Company,
	|	OldTasks.Document AS Document
	|INTO TasksToDelete
	|FROM
	|	SourceTasks AS OldTasks
	|WHERE
	|	OldTasks.MONTH BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&NextMonth AS Month,
	|	MAX(TasksToDelete.TaskNumber) AS TaskNumber,
	|	TasksToDelete.Company AS Company,
	|	UNDEFINED AS Document
	|INTO NewBoundary
	|FROM
	|	TasksToDelete AS TasksToDelete
	|
	|GROUP BY
	|	TasksToDelete.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SourceTasks.Month AS Month,
	|	SourceTasks.TaskNumber AS TaskNumber,
	|	SourceTasks.Company AS Company,
	|	SourceTasks.Document AS Document
	|INTO TempSourceTasks
	|FROM
	|	SourceTasks AS SourceTasks
	|WHERE
	|	NOT(SourceTasks.MONTH BETWEEN &BeginOfPeriod AND &EndOfPeriod)
	|
	|UNION ALL
	|
	|SELECT
	|	NewBoundary.Month,
	|	NewBoundary.TaskNumber,
	|	NewBoundary.Company,
	|	NewBoundary.Document
	|FROM
	|	NewBoundary AS NewBoundary
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SourceTasks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SourceTasks.Month AS Month,
	|	SourceTasks.TaskNumber AS TaskNumber,
	|	SourceTasks.Company AS Company,
	|	SourceTasks.Document AS Document
	|INTO SourceTasks
	|FROM
	|	TempSourceTasks AS SourceTasks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TasksToDelete.Month AS Month,
	|	TasksToDelete.TaskNumber AS TaskNumber,
	|	TasksToDelete.Company AS Company,
	|	TasksToDelete.Document AS Document
	|FROM
	|	TasksToDelete AS TasksToDelete
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewBoundary.Month AS Month,
	|	NewBoundary.TaskNumber AS TaskNumber,
	|	NewBoundary.Company AS Company,
	|	NewBoundary.Document AS Document
	|FROM
	|	NewBoundary AS NewBoundary
	|");
	
	Query.TempTablesManager = TempTables;
	Query.SetParameter("BeginOfPeriod", BeginOfCurrentPeriod);
	Query.SetParameter("EndOfPeriod", EndOfCurrentPeriod);
	Query.SetParameter("NextMonth", EndOfCurrentPeriod + 1);
	Query.SetParameter("ArrayOfCompanies", ArrayOfCompanies);
	
	Results = Query.ExecuteBatch();
	
	BeginTransaction();
	
	Try
		
		// Clearing old periods
		Selection = Results[5].Select();
		While Selection.Next() Do
			RecordSet = InformationRegisters.TasksForCostsCalculation.CreateRecordSet();
			RecordSet.Filter.Month.Set(Selection.Month);
			RecordSet.Filter.TaskNumber.Set(Selection.TaskNumber);
			RecordSet.Filter.Company.Set(Selection.Company);
			RecordSet.Filter.Document.Set(Selection.Document);
			RecordSet.Write(True);
		EndDo;
		
		// Move the boundaries
		Selection = Results[6].Select();
		While Selection.Next() Do
			RecordSet = InformationRegisters.TasksForCostsCalculation.CreateRecordSet();
			RecordSet.Filter.Month.Set(Selection.Month);
			RecordSet.Filter.TaskNumber.Set(Selection.TaskNumber);
			RecordSet.Filter.Company.Set(Selection.Company);
			RecordSet.Filter.Document.Set(Selection.Document);
			RecordLine = RecordSet.Add();
			FillPropertyValues(RecordLine, Selection);
			RecordSet.Write(True);
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		LanguageCode = CommonUseClientServer.MainLanguageCode();
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Errors on moving boundaries to the next period %1 by reason:
				|| %2'", LanguageCode),
			CurrentPeriod,
			DetailErrorDescription(ErrorInfo()));
			
		WriteLogEvent(
			NStr("en = 'FIFO.Moving boundaries'", LanguageCode),
			EventLogLevel.Information,
			CurrentPeriod,
			ErrorText);
			
	EndTry;
	
	Query.Text = 
	"DROP TasksToDelete
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP NewBoundary
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TempSourceTasks";
	
	Query.Execute();
	
EndProcedure

// Returns all records in the "Tasks.." register
//
// Parameters:
//	OldTaskNumber - Number - Tasks will be selected only equal or less then OldTaskNumber.
//	Companies - Array - Tasks will be selected only equal this parameter.
//
// Returned value:
//	 TempTablesManager - With the "SourceTasks" temp table.
//
Function GetTempTableOfTasks(OldTaskNumber, Companies) Export
	
	Query = New Query("
	|SELECT
	|	Tasks.Month AS Month,
	|	Tasks.TaskNumber AS TaskNumber,
	|	Tasks.Company AS Company,
	|	Tasks.Document AS Document
	|INTO SourceTasks
	|FROM
	|	InformationRegister.TasksForCostsCalculation AS Tasks
	|WHERE
	|	Tasks.TaskNumber <= &TaskNumber
	|	AND Tasks.Company IN (&ArrayOfCompanies)
	|");
	
	TempTableOfTasks = New TempTablesManager;
	
	Query.SetParameter("TaskNumber", OldTaskNumber);
	Query.SetParameter("ArrayOfCompanies", DriveClientServer.ArrayFromItem(Companies));
	Query.TempTablesManager = TempTableOfTasks;
	
	Query.Execute();
	
	Return TempTableOfTasks;
EndFunction

Function TheEarliestPeriod(Date, ArrayOfCompanies)
	
	TheEarliestPeriod = Undefined;
	
	Query = New Query("
	|SELECT
	|	Companies.Ref AS Company,
	|	MIN(BEGINOFPERIOD(Tasks.Month, MONTH)) AS Month
	|INTO TasksPeriods
	|FROM
	|	Catalog.Companies AS Companies
	|		LEFT JOIN InformationRegister.TasksForCostsCalculation AS Tasks
	|		ON Companies.Ref = Tasks.Company
	|WHERE
	|	Companies.Ref IN(&ArrayOfCompanies)
	|
	|GROUP BY
	|	Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(Period.Month) AS BeginOfPeriod
	|FROM
	|	TasksPeriods AS Period
	|WHERE
	|	Period.Month IS NOT NULL 
	|	AND Period.Month <= &Date
	|
	|HAVING
	|	MIN(Period.Month) IS NOT NULL
	|");
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("ArrayOfCompanies", DriveClientServer.ArrayFromItem(ArrayOfCompanies));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		TheEarliestPeriod = ?(ValueIsFilled(Selection.BeginOfPeriod), BegOfMonth(Selection.BeginOfPeriod), Undefined);
	EndIf;
	
	If Not ValueIsFilled(TheEarliestPeriod) Then
		TheEarliestPeriod = EndOfMonth(Date) + 1;
	EndIf;
	
	Return TheEarliestPeriod;
	
EndFunction

#EndRegion

#EndIf