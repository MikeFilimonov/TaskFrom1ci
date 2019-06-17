#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

// Procedure - handler of the PopulationProcessing event of the object.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Employees") Then
		
		Employee = FillingData;
		LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		If FillingData.Property("Employee") AND 
			ValueIsFilled(FillingData.Employee) Then
			
			Employee = FillingData;
			Counterparty = Catalogs.Counterparties.EmptyRef();
			LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement;
			
		EndIf;
		
		If FillingData.Property("Counterparty") AND
			ValueIsFilled(FillingData.Counterparty) Then
			
			Employee = Catalogs.Employees.EmptyRef();
			Counterparty = FillingData.Counterparty;
			LoanKind = Enums.LoanContractTypes.Borrowed;
			
		EndIf;
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

// Procedure - handler of the BeforeWriting event of the object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Counterparty = Undefined;
	Else
		Employee = Undefined;
		ChargeFromSalary = False;
	EndIf;
	
EndProcedure

// Procedure - handler of the PostingProcessing event.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties to post the document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.LoanContract.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Prepare record sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.RecordLoanRepaymentSchedule(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of record sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - handler of the PopulationCheckProcessing event.
//
Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "CommissionGLAccount");
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "CommissionType");
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Employee");
		If CommissionType = Enums.LoanCommissionTypes.No Then
			DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "CommissionGLAccount");
		EndIf;
		
	EndIf;
	
	If GLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses AND
		CommissionGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses AND
		InterestGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses 
	Then
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "StructuralUnit");
	EndIf;
	
EndProcedure

// Procedure - handler of the PostingDeletionProcessing of the object event.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to post the document
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Prepare record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of record sets
	DriveServer.WriteRecordSets(ThisObject);

EndProcedure

#EndRegion

#EndIf