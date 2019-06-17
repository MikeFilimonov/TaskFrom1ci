#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOperation, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	CASE
	|		WHEN AccountingJournalEntries.AccountDr.Currency
	|			THEN AccountingJournalEntries.CurrencyDr
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN AccountingJournalEntries.AccountDr.Currency
	|			THEN AccountingJournalEntries.AmountCurDr
	|		ELSE 0
	|	END AS AmountCurDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	CASE
	|		WHEN AccountingJournalEntries.AccountCr.Currency
	|			THEN AccountingJournalEntries.CurrencyCr
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN AccountingJournalEntries.AccountCr.Currency
	|			THEN AccountingJournalEntries.AmountCurCr
	|		ELSE 0
	|	END AS AmountCurCr,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.Content AS Content
	|FROM
	|	Document.Operation.AccountingRecords AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefOperation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf