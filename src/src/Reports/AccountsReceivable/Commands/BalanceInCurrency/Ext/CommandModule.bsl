
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = GetFilterStructure(CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "BalanceInCurrency");
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True); 
	FormParameters.Insert("ReportVariantsCommandsVisible", False);
	
	OpenForm("Report.AccountsReceivable.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GetFilterStructure(Document)
	
	FilterStructure = New Structure("Recorder, Company, Counterparty, Contract");	
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	SalesInvoice.Ref AS Recorder,
		|	SalesInvoice.Company AS Company,
		|	SalesInvoice.Counterparty AS Counterparty,
		|	SalesInvoice.Contract AS Contract
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Ref = &Document";
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(FilterStructure, Selection); 
	EndIf;
	
	Return FilterStructure;
	
EndFunction
