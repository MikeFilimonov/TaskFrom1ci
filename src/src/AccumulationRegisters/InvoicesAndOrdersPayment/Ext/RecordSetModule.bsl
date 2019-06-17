#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes payment order.
// Payment date is specified in "Period". When actual
// payment for order happens schedule closing by FIFO.
//
Procedure CalculatePaymentOfOrders()
	
	AccountsTable = AdditionalProperties.AccountsTable;
	Query = New Query;
	Query.SetParameter("AccountsPayableArray", AccountsTable.UnloadColumn("Quote"));
	Query.Text =
	"SELECT
	|	InvoicesAndOrdersPaymentTurnovers.Quote AS Quote,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.AmountTurnover) AS Amount,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) AS AdvanceAmount,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover) AS PaymentAmount
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment.Turnovers(, , , Quote IN (&AccountsPayableArray)) AS InvoicesAndOrdersPaymentTurnovers
	|
	|GROUP BY
	|	InvoicesAndOrdersPaymentTurnovers.Quote";
	
	RecordSet = InformationRegisters.OrderPayments.CreateRecordSet();
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		CurQuote = Selection.Quote;
		
		RecordSet.Filter.Quote.Set(CurQuote);
		
		// Delete the closed invoice for payment from the table.
		AccountsTable.Delete(AccountsTable.Find(CurQuote, "Quote"));
		
		Record = RecordSet.Add();
		Record.Quote = Selection.Quote;
		Record.Amount = Selection.Amount;
		Record.AdvanceAmount = Selection.AdvanceAmount;
		Record.PaymentAmount = Selection.PaymentAmount;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// By unfinished orders need clear register records.
	If AccountsTable.Count() > 0 Then
		For Each TabRow In AccountsTable Do
			
			RecordSet.Filter.Quote.Set(TabRow.Quote);
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
	EndIf;
	
EndProcedure

// Procedure forms the accounts (orders) table  which
// were previously in the register records and which will be written now.
//
Procedure GenerateTableOfInvoicesForPayment()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TableInvoicesAndOrdersPayment.Quote AS Quote
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment AS TableInvoicesAndOrdersPayment
	|WHERE
	|	TableInvoicesAndOrdersPayment.Recorder = &Recorder";
	
	AccountsTable = Query.Execute().Unload();
	TableOfNewAccounts = Unload(, "Quote");
	TableOfNewAccounts.GroupBy("Quote");
	For Each Record In TableOfNewAccounts Do
		
		If AccountsTable.Find(Record.Quote, "Quote") = Undefined Then
			AccountsTable.Add().Quote = Record.Quote;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("AccountsTable", AccountsTable);
	
EndProcedure

// Procedure sets data lock for payment calculation.
//
Procedure SetLockDataForCalculationOfPayment()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation according to the schedule.
	LockItem = Block.Add("AccumulationRegister.InvoicesAndOrdersPayment");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("Quote", "Quote");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderPayments");
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
	SetLockDataForCalculationOfPayment();
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CalculatePaymentOfOrders();
	
EndProcedure

#EndRegion

#EndIf