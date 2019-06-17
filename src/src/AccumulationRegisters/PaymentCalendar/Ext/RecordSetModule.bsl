#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes the order payment schedule.
// Payment date is specified in "Period". When actual
// payment for order happens schedule closing by FIFO.
//
Procedure CalculateOrdersPaymentSchedule(AccountsTable)
	
	RecordSet = InformationRegisters.OrdersPaymentSchedule.CreateRecordSet();
	
	Query = New Query;
	Query.SetParameter("AccountsPayableArray", AccountsTable.UnloadColumn("Quote"));
	Query.Text =
	"SELECT
	|	PaymentCalendarTurnovers.Quote AS Quote,
	|	CASE
	|		WHEN PaymentCalendarTurnovers.AmountTurnover < 0
	|			THEN -1 * PaymentCalendarTurnovers.AmountTurnover
	|		ELSE PaymentCalendarTurnovers.AmountTurnover
	|	END - CASE
	|		WHEN PaymentCalendarTurnovers.PaymentAmountTurnover < 0
	|			THEN -1 * PaymentCalendarTurnovers.PaymentAmountTurnover
	|		ELSE PaymentCalendarTurnovers.PaymentAmountTurnover
	|	END AS PaymentAmountTurnover
	|INTO TU_Turnovers
	|FROM
	|	AccumulationRegister.PaymentCalendar.Turnovers(, , , Quote IN (&AccountsPayableArray)) AS PaymentCalendarTurnovers
	|
	|INDEX BY
	|	Quote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(Table.Period, Day) AS Period,
	|	Table.Quote AS Quote,
	|	SUM(CASE
	|			WHEN Table.Amount < 0
	|				THEN -1 * Table.Amount
	|			ELSE Table.Amount
	|		END) AS AmountPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.PaymentCalendar AS Table
	|WHERE
	|	Table.Quote IN(&AccountsPayableArray)
	|	AND Table.Amount <> 0
	|	AND Table.Active
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.Period, Day),
	|	Table.Quote
	|
	|INDEX BY
	|	Quote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Quote AS Quote,
	|	TU_Table.AmountPlan AS AmountPlan,
	|	ISNULL(TU_Turnovers.PaymentAmountTurnover, 0) AS PaymentAmount
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Turnovers AS TU_Turnovers
	|		ON TU_Table.Quote = TU_Turnovers.Quote
	|
	|ORDER BY
	|	Quote,
	|	Period DESC";
	
	
	Selection = Query.Execute().Select();
	ThereAreRecordsInSelection = Selection.Next();
	
	While ThereAreRecordsInSelection Do
		
		CurQuote = Selection.Quote;
		
		RecordSet.Filter.Quote.Set(CurQuote);
		
		// Delete the closed invoice for payment from the table.
		AccountsTable.Delete(AccountsTable.Find(CurQuote, "Quote"));
		
		TotalAmountBalance = 0;
		If Selection.PaymentAmount > 0 Then
			TotalAmountBalance = Selection.PaymentAmount;
		EndIf;
		
		// Cycle by the invoice for payment.
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.Quote = CurQuote Do
			
			CurAmount = min(Selection.AmountPlan, TotalAmountBalance);
			If CurAmount > 0 Then
				
				StructureRecordSet.Insert("Period", Selection.Period);
				StructureRecordSet.Insert("Quote", Selection.Quote);
				StructureRecordSet.Insert("Amount", CurAmount);
				
			EndIf;
			
			TotalAmountBalance = TotalAmountBalance - CurAmount;
			
			// Go to the following records in the sample.
			ThereAreRecordsInSelection = Selection.Next();
			
		EndDo;
		
		// Record and clearing set.
		If StructureRecordSet.Count() > 0 Then
			Record = RecordSet.Add();
			Record.Period = StructureRecordSet.Period;
			Record.Quote = StructureRecordSet.Quote;
			Record.Amount = StructureRecordSet.Amount;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
EndProcedure

// Procedure calculates and writes the order payment schedule.
// Payment date is specified in "Period". When actual
// payment for order happens schedule closing by FIFO.
//
Procedure CalculatePlanedPayments(AccountsTable)
	
	RecordSet = InformationRegisters.PaymentsSchedule.CreateRecordSet();
	
	Query = New Query;
	Query.SetParameter("AccountsPayableArray", AccountsTable.UnloadColumn("Quote"));
	Query.Text =
	"SELECT
	|	PaymentCalendar.Period AS DayPeriod,
	|	PaymentCalendar.Currency AS Currency,
	|	PaymentCalendar.Quote.Counterparty AS Counterparty,
	|	PaymentCalendar.Item AS Item,
	|	PaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	PaymentCalendar.Quote.DocumentAmount AS DocumentAmount,
	|	PaymentCalendar.AmountTurnover AS AmountTurnover,
	|	PaymentCalendar.PaymentAmountTurnover AS PaymentAmountTurnover,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	PaymentCalendar.Quote.Company AS Company,
	|	PaymentCalendar.Quote AS Quote,
	|	CASE
	|		WHEN VALUETYPE(PaymentCalendar.Quote) = Type(Document.SalesOrder)
	|				OR VALUETYPE(PaymentCalendar.Quote) = Type(Document.CashInflowForecast)
	|				OR VALUETYPE(PaymentCalendar.Quote) = Type(Document.CashTransferPlan)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ThisFlow
	|INTO PaymentCalendarByDocumentByDays
	|FROM
	|	AccumulationRegister.PaymentCalendar.Turnovers(, , Day, Quote IN (&AccountsPayableArray)) AS PaymentCalendar
	|
	|INDEX BY
	|	DayPeriod,
	|	Company,
	|	Currency,
	|	Quote,
	|	BankAccountPettyCash
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendarByDocumentByDays.Quote AS Quote,
	|	SUM(PaymentCalendarByDocumentByDays.AmountTurnover) AS AmountTurnover,
	|	SUM(PaymentCalendarByDocumentByDays.PaymentAmountTurnover) AS PaymentAmountTurnover
	|INTO PaymentCalendarTotalByDocument
	|FROM
	|	PaymentCalendarByDocumentByDays AS PaymentCalendarByDocumentByDays
	|
	|GROUP BY
	|	PaymentCalendarByDocumentByDays.Quote
	|
	|INDEX BY
	|	Quote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendarByDocumentByDays.DayPeriod AS Date,
	|	PaymentCalendarByDocumentByDays.Currency AS Currency,
	|	PaymentCalendarByDocumentByDays.Counterparty AS Counterparty,
	|	PaymentCalendarByDocumentByDays.Item AS Item,
	|	PaymentCalendarByDocumentByDays.Quote AS Quote,
	|	PaymentCalendarByDocumentByDays.BankAccountPettyCash AS BankAccountPettyCash,
	|	CAST(PaymentCalendarByDocumentByDays.DocumentAmount AS NUMBER(15, 2)) AS DocumentAmount,
	|	CAST(CASE
	|			WHEN PaymentCalendarByDocumentByDays.ThisFlow
	|				THEN PaymentCalendarByDocumentByDays.AmountTurnover
	|			ELSE -PaymentCalendarByDocumentByDays.AmountTurnover
	|		END AS NUMBER(15, 2)) AS AmountPlannedAtDateOnDocument,
	|	SUM(CAST(CASE
	|				WHEN PaymentCalendarByDocumentByDays.ThisFlow
	|					THEN PaymentCalendarByDocumentByDays.PaymentAmountTurnover
	|				ELSE -PaymentCalendarByDocumentByDays.PaymentAmountTurnover
	|			END AS NUMBER(15, 2))) AS AmountPaidOnDateOnDocument,
	|	MAX(CAST(CASE
	|				WHEN PaymentCalendarByDocumentByDays.ThisFlow
	|					THEN ISNULL(PaymentCalendarTotalByDocument.PaymentAmountTurnover, 0)
	|				ELSE -ISNULL(PaymentCalendarTotalByDocument.PaymentAmountTurnover, 0)
	|			END AS NUMBER(15, 2))) AS AmountPaidTotalOnDocument,
	|	PaymentCalendarByDocumentByDays.ThisFlow AS ThisFlow,
	|	PaymentCalendarByDocumentByDays.CashAssetsType AS CashAssetsType,
	|	PaymentCalendarByDocumentByDays.Company AS Company
	|FROM
	|	PaymentCalendarByDocumentByDays AS PaymentCalendarByDocumentByDays
	|		LEFT JOIN PaymentCalendarTotalByDocument AS PaymentCalendarTotalByDocument
	|		ON PaymentCalendarByDocumentByDays.Quote = PaymentCalendarTotalByDocument.Quote
	|WHERE
	|	PaymentCalendarByDocumentByDays.AmountTurnover <> 0
	|
	|GROUP BY
	|	PaymentCalendarByDocumentByDays.DayPeriod,
	|	PaymentCalendarByDocumentByDays.Currency,
	|	PaymentCalendarByDocumentByDays.Counterparty,
	|	PaymentCalendarByDocumentByDays.Item,
	|	PaymentCalendarByDocumentByDays.Quote,
	|	PaymentCalendarByDocumentByDays.BankAccountPettyCash,
	|	PaymentCalendarByDocumentByDays.ThisFlow,
	|	PaymentCalendarByDocumentByDays.CashAssetsType,
	|	PaymentCalendarByDocumentByDays.Company,
	|	CAST(PaymentCalendarByDocumentByDays.DocumentAmount AS NUMBER(15, 2)),
	|	CAST(CASE
	|			WHEN PaymentCalendarByDocumentByDays.ThisFlow
	|				THEN PaymentCalendarByDocumentByDays.AmountTurnover
	|			ELSE -PaymentCalendarByDocumentByDays.AmountTurnover
	|		END AS NUMBER(15, 2))
	|
	|ORDER BY
	|	Date
	|TOTALS BY
	|	Quote";
	
	QueryResult = Query.Execute();
	BypassingBillsToPay = QueryResult.Select(QueryResultIteration.ByGroups);
	
	RecordSet = InformationRegisters.PaymentsSchedule.CreateRecordSet();
	
	While BypassingBillsToPay.Next() Do
		
		SumDistribution = BypassingBillsToPay.AmountPaidTotalOnDocument
							- BypassingBillsToPay.AmountPaidOnDateOnDocument;
		
		SelectionDetailRecords = BypassingBillsToPay.Select();
		
		While SelectionDetailRecords.Next() Do
		
			RecordSet.Filter.Period.Set(SelectionDetailRecords.Date);
			RecordSet.Filter.Quote.Set(SelectionDetailRecords.Quote);
			
			NewRecord = RecordSet.Add();
			NewRecord.Currency = SelectionDetailRecords.Currency;
			NewRecord.Quote = SelectionDetailRecords.Quote;
			NewRecord.Counterparty = SelectionDetailRecords.Counterparty;
			NewRecord.Item = SelectionDetailRecords.Item;
			NewRecord.BankAccountPettyCash = SelectionDetailRecords.BankAccountPettyCash;
			NewRecord.CashAssetsType = SelectionDetailRecords.CashAssetsType;
			NewRecord.Period = SelectionDetailRecords.Date;
			NewRecord.Company = SelectionDetailRecords.Company;
			NewRecord.ThisFlow = SelectionDetailRecords.ThisFlow;
			NewRecord.DocumentAmount = SelectionDetailRecords.DocumentAmount;
			
			AmountToEnterOnDate =
				SelectionDetailRecords.AmountPlannedAtDateOnDocument
			  - SelectionDetailRecords.AmountPaidOnDateOnDocument;
			  
			AmountToEnterOnDateDistributed =
				AmountToEnterOnDate
			  - SumDistribution;
			
			If AmountToEnterOnDateDistributed < 0 Then
				SumDistribution = - AmountToEnterOnDateDistributed;
				NewRecord.AmountOfPlanBalance = 0;
			Else
				SumDistribution = 0;
				NewRecord.AmountOfPlanBalance = AmountToEnterOnDateDistributed;
			EndIf;
			
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Procedure forms the accounts (orders) table which
// were previously in the register records, and which will be written now.
//
Procedure GenerateTableOfInvoicesForPayment()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TablePaymentCalendar.Quote AS Quote
	|FROM
	|	AccumulationRegister.PaymentCalendar AS TablePaymentCalendar
	|WHERE
	|	TablePaymentCalendar.Recorder = &Recorder
	|	AND TablePaymentCalendar.Quote <> UNDEFINED";
	
	AccountsTable = Query.Execute().Unload();
	TableOfNewAccounts = Unload(, "Quote");
	TableOfNewAccounts.GroupBy("Quote");
	
	For Each Record In TableOfNewAccounts Do
		If ValueIsFilled(Record.Quote)
		   AND AccountsTable.Find(Record.Quote, "Quote") = Undefined Then
			AccountsTable.Add().Quote = Record.Quote;
		EndIf;
	EndDo;
	
	AdditionalProperties.Insert("AccountsTable", AccountsTable);
	
EndProcedure

// Procedure sets data lock for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation according to the schedule.
	LockItem = Block.Add("AccumulationRegister.PaymentCalendar");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("Quote", "Quote");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrdersPaymentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("Quote", "Quote");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.PaymentsSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("Quote", "Quote");
	
	Block.Lock();
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	GenerateTableOfInvoicesForPayment();
	InstallLocksOnDataForCalculatingSchedule();
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccountsTable = AdditionalProperties.AccountsTable;
	
	If AccountsTable.Count() > 0 Then
		CalculatePlanedPayments(AccountsTable);
		CalculateOrdersPaymentSchedule(AccountsTable);
	EndIf;
	
	RecordSetLinePayments = InformationRegisters.PaymentsSchedule.CreateRecordSet();
	OnlinePaymentOrdersSetRecord = InformationRegisters.OrdersPaymentSchedule.CreateRecordSet();
	
	// By unfinished orders need clear register records.
	AccountsTable.Add().Quote = Undefined;
	If AccountsTable.Count() > 0 Then
		For Each TabRow In AccountsTable Do
			RecordSetLinePayments.Filter.Quote.Set(TabRow.Quote);
			RecordSetLinePayments.Write(True);
			RecordSetLinePayments.Clear();
			OnlinePaymentOrdersSetRecord.Filter.Quote.Set(TabRow.Quote);
			OnlinePaymentOrdersSetRecord.Write(True);
			OnlinePaymentOrdersSetRecord.Clear();
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf