#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each LineIncome In Incomings Do
			
			If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
				LineIncome.BusinessLine = Catalogs.LinesOfBusiness.Other;
			Else
				LineIncome.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
			
		EndDo;
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
				OR RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.LoanInterest Then
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.Other;
			Else
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("PlanningPeriod", PlanningPeriod);
	StructureAdditionalProperties.ForPosting.Insert("Periodicity", PlanningPeriod.Periodicity);
	StructureAdditionalProperties.ForPosting.Insert("StartDate", PlanningPeriod.StartDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDate", PlanningPeriod.EndDate);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each LineIncome In Incomings Do
	
		If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.Revenue Then
			
			If Not ValueIsFilled(LineIncome.StructuralUnit) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					"Department is not indicated on string. Fillings is required for basic activity incomings.",
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
		
		If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
			
			If ValueIsFilled(LineIncome.BusinessLine) AND (LineIncome.BusinessLine <> Catalogs.LinesOfBusiness.Other) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					"The type of activity specified in the row differs from 'Other'. For other income, it is necessary to specify the other type of activity.",
					"Incomings",
					LineIncome.LineNumber,
					"BusinessLine",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(LineIncome.StructuralUnit) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					"Department is indicated on string. For the income from other types of business activity, filling is not required.",
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
	For Each RowsExpenses In Expenses Do
		
		If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
		 OR RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.LoanInterest Then
			
			If Not ValueIsFilled(RowsExpenses.BusinessLine) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					"Activity direction is indicated on string.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessLine",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(RowsExpenses.BusinessLine) AND (RowsExpenses.BusinessLine <> Catalogs.LinesOfBusiness.Other) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					"The type of activity specified in the row differs from 'Other'. For other expenses, it is necessary to specify the other type of activity.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessLine",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					"Department is indicated on string. For expenses on other type of activities, filling is not required.",
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		Else
			
		EndIf;
		
		If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.CostOfSales Then
			
			If Constants.UseSeveralLinesOfBusiness.Get() AND
				(NOT ValueIsFilled(RowsExpenses.BusinessLine) OR (RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.Other)) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					"The main business activity is not indicated on string. The basic activity indication is required for cost of sales.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessLine",
					Cancel
				);
				
			EndIf;
			
			If Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject, 
					"Department is not indicated on string. Filling is required for cost of sales at basic activities.",
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Initialization of document data
	Documents.Budget.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectCashBudget(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesBudget(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFinancialResultForecast(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf