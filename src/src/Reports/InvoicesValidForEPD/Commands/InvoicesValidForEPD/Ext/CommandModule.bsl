#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = GetFilterStructure(CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "InvoicesValidForEPD");
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True); 
	FormParameters.Insert("ReportVariantsCommandsVisible", False);
	
	OpenForm("Report.InvoicesValidForEPD.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetFilterStructure(Document)
	
	FilterStructure = New Structure("Recorder, Company, Counterparty, Currency, Period");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CashVoucher.Ref AS Recorder,
		|	ENDOFPERIOD(CashVoucher.Date, DAY) AS Period,
		|	CashVoucher.Company AS Company,
		|	CashVoucher.Counterparty AS Counterparty,
		|	CashVoucher.CashCurrency AS Currency
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|WHERE
		|	CashVoucher.Ref = &Document
		|
		|UNION ALL
		|
		|SELECT
		|	PaymentExpense.Ref,
		|	CASE
		|		WHEN PaymentExpense.PaymentDate <> DATETIME(1, 1, 1)
		|			THEN ENDOFPERIOD(PaymentExpense.PaymentDate, DAY)
		|		ELSE ENDOFPERIOD(PaymentExpense.Date, DAY)
		|	END,
		|	PaymentExpense.Company,
		|	PaymentExpense.Counterparty,
		|	PaymentExpense.CashCurrency
		|FROM
		|	Document.PaymentExpense AS PaymentExpense
		|WHERE
		|	PaymentExpense.Ref = &Document";
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(FilterStructure, Selection); 
	EndIf;
	
	Return FilterStructure;
	
EndFunction

#EndRegion