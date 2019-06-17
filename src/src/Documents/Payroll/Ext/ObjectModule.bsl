#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function calculates the document amount.
//
Function GetDocumentAmount() Export

	TableEarnings = New ValueTable;
    Array = New Array;
	ReturnStructure = New Structure("AmountAccrued, AmountWithheld, DocumentAmount, AmountCharged", 0, 0, 0, 0);
	
	Array.Add(Type("CatalogRef.EarningAndDeductionTypes"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableEarnings.Columns.Add("EarningAndDeductionType", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableEarnings.Columns.Add("Amount", TypeDescription);
	
	For Each TSRow In EarningsDeductions Do
		NewRow = TableEarnings.Add();
        NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	For Each TSRow In IncomeTaxes Do
		NewRow = TableEarnings.Add();
        NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	
	Query = New Query(
	"SELECT
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Amount
	|INTO TableEarningsDeductions
	|FROM
	|	&TableEarningsDeductions AS TableEarningsDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN PayrollEarningRetention.Amount
	|			ELSE 0
	|		END) AS AmountAccrued,
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN 0
	|			ELSE PayrollEarningRetention.Amount
	|		END) AS AmountWithheld,
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN PayrollEarningRetention.Amount
	|			ELSE -1 * PayrollEarningRetention.Amount
	|		END) AS DocumentAmount
	|FROM
	|	TableEarningsDeductions AS PayrollEarningRetention");
	
	Query.SetParameter("TableEarningsDeductions", TableEarnings);
	QueryResult = Query.ExecuteBatch();
	
	ReturnStructure.Insert("AmountCharged", LoanRepayment.Total("PrincipalCharged") + LoanRepayment.Total("InterestCharged"));
	
	If QueryResult[1].IsEmpty() Then
		ReturnStructure.DocumentAmount = ReturnStructure.DocumentAmount - ReturnStructure.AmountCharged;
		Return ReturnStructure;	
	Else
		FillPropertyValues(ReturnStructure, QueryResult[1].Unload()[0]);
		
		If ValueIsFilled(ReturnStructure.DocumentAmount) Then
			ReturnStructure.DocumentAmount = ReturnStructure.DocumentAmount - ReturnStructure.AmountCharged;
		Else 
			ReturnStructure.DocumentAmount = -ReturnStructure.AmountCharged;
		EndIf;
		
		Return ReturnStructure;	
	EndIf; 

EndFunction

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = GetDocumentAmount().DocumentAmount;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each EarningDetentionRow In EarningsDeductions Do
			
			If EarningDetentionRow.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				EarningDetentionRow.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Payroll.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectEarningsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Account for loans to employees
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);	

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf