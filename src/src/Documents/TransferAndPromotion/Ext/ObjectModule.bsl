#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Function returns the tabular section filled with
// the scheduled earnings and deductions of employee
//
// Parameters:
//  FilterStructure - Structure contained data of person
//                 for who it is necessary to find earnings or deductions      
//
// Returns:
//  ValueTable with received earnings or deductions.
//
Function FindEmployeeEarningsDeductions(FilterStructure, Tax = False) Export

	Query = New Query;
	Query.Text = "SELECT
	               |	CompensationPlanSliceLast.EarningAndDeductionType,
	               |	CompensationPlanSliceLast.Currency,
	               |	CompensationPlanSliceLast.GLExpenseAccount,
	               |	CompensationPlanSliceLast.Amount,
	               |	CompensationPlanSliceLast.Actuality
	               |FROM
	               |	InformationRegister.CompensationPlan.SliceLast(
	               |			&Date,
	               |			Employee = &Employee
	               |				AND Company = &Company
	               |				AND Recorder <> &Recorder
	               |				AND CASE
	               |					WHEN &Tax
	               |						THEN EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	               |					ELSE EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	               |				END) AS CompensationPlanSliceLast
	               |WHERE
	               |	CompensationPlanSliceLast.Actuality";
	
	Query.SetParameter("Employee", FilterStructure.Employee);
	Query.SetParameter("Company", DriveServer.GetCompany(FilterStructure.Company));
	Query.SetParameter("Date", FilterStructure.Date);
	Query.SetParameter("Recorder", Ref); 
	Query.SetParameter("Tax", Tax);
	
	ResultTable = Query.Execute().Unload();
	ResultArray = New Array;
    For Each TSRow In ResultTable Do
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("EarningAndDeductionType", TSRow.EarningAndDeductionType);
        TabularSectionRow.Insert("Currency", 				TSRow.Currency);
		TabularSectionRow.Insert("GLExpenseAccount", 			TSRow.GLExpenseAccount);
		TabularSectionRow.Insert("Amount", 					TSRow.Amount);
		TabularSectionRow.Insert("Actuality", 			TSRow.Actuality);
		
		ResultArray.Add(TabularSectionRow);
		
	EndDo;
	
	Return ResultArray;
	
EndFunction

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel) 
	
	Query = New Query(
	"SELECT
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEmployees.ConnectionKey
	|INTO TableEmployees
	|FROM
	|	Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEarningsDeductions.LineNumber,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Currency,
	|	TableEmployees.Employee,
	|	TableEmployees.Period
	|INTO TableEarningsDeductions
	|FROM
	|	Document.TransferAndPromotion.EarningsDeductions AS TableEarningsDeductions
	|		INNER JOIN TableEmployees AS TableEmployees
	|		ON TableEarningsDeductions.ConnectionKey = TableEmployees.ConnectionKey
	|			AND (TableEarningsDeductions.Ref = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber AS LineNumber,
	|	Employees.Recorder
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Company = &Company)
	|			AND TableEmployees.Employee = Employees.Employee
	|			AND TableEmployees.Period = Employees.Period
	|			AND (Employees.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEarningsDeductions.LineNumber AS LineNumber,
	|	CompensationPlan.Recorder
	|FROM
	|	InformationRegister.CompensationPlan AS CompensationPlan
	|		INNER JOIN TableEarningsDeductions AS TableEarningsDeductions
	|		ON (CompensationPlan.Company = &Company)
	|			AND CompensationPlan.Employee = TableEarningsDeductions.Employee
	|			AND CompensationPlan.EarningAndDeductionType = TableEarningsDeductions.EarningAndDeductionType
	|			AND CompensationPlan.Currency = TableEarningsDeductions.Currency
	|			AND CompensationPlan.Period = TableEarningsDeductions.Period
	|			AND (CompensationPlan.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableEmployeesTwinsRows.LineNumber) AS LineNumber,
	|	TableEmployeesTwinsRows.Employee
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN TableEmployees AS TableEmployeesTwinsRows
	|		ON TableEmployees.LineNumber <> TableEmployeesTwinsRows.LineNumber
	|			AND TableEmployees.Employee = TableEmployeesTwinsRows.Employee
	|
	|GROUP BY
	|	TableEmployeesTwinsRows.Employee
	|
	|ORDER BY
	|	LineNumber");
	
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Register "Employees".
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, the order validity contradicts the ""%PersonnelOrder%"" personnel order.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%PersonnelOrder%", QueryResultSelection.Recorder);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;

	// Register "Planned earnings and deductions".
	If Not ResultsArray[3].IsEmpty() Then
		QueryResultSelection = ResultsArray[3].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Earnings and deductions"" tabular section, the order validity contradicts the ""%PersonnelOrder%"" personnel order.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%PersonnelOrder%", QueryResultSelection.Recorder);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;
	
	// Row duplicates.
	If Not ResultsArray[4].IsEmpty() Then
		QueryResultSelection = ResultsArray[4].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, the employee is specified again.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;	 
	
EndProcedure

// Controls conflicts.
//
Procedure RunControl(AdditionalProperties, Cancel) 
	
	If Cancel Then
		Return;	
	EndIf;
	
	Query = New Query(
	"SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.LineNumber AS LineNumber,
	|	Employees.StructuralUnit
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS Period
	|	FROM
	|		TableEmployees AS TableEmployees
	|			LEFT JOIN InformationRegister.Employees AS Employees
	|			ON (Employees.Employee = TableEmployees.Employee)
	|				AND (Employees.Company = &Company)
	|				AND (Employees.Period <= TableEmployees.Period)
	|				AND (Employees.Recorder <> &Ref)
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND NestedSelect.Period = Employees.Period
	|			AND (Employees.Company = &Company)
	|
	|ORDER BY
	|	LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	// Employee is not employed by the company as of the date of occupation change.
	QueryResultSelection = Result.Select();
	While QueryResultSelection.Next() Do
		If Not ValueIsFilled(QueryResultSelection.StructuralUnit) Then
		    MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, it is indicated that the %Employee% employee is not hired to the %Company% company.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%Company%", AdditionalProperties.ForPosting.Company);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndIf; 
	EndDo;	 
	
EndProcedure

// Controls the staff list.
//
Procedure RunControlStaffSchedule(AdditionalProperties, Cancel) 
	
	If Cancel OR Not Constants.UseHeadcountBudget.Get() Then
		Return;	
	EndIf;
	
	If OperationKind = Enums.OperationTypesTransferAndPromotion.PaymentFormChange Then
		Return;
	EndIf; 
	
	Query = New Query("
	|SELECT
	|	CASE
	|		WHEN ISNULL(TotalStaffList.CountOfRatesBySSh, 0) - ISNULL(TotalBusyBids.OccupiedRates, 0) < 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FontsContradiction,
	|	CASE
	|		WHEN TotalStaffList.LineNumber IS NULL 
	|			THEN TotalBusyBids.LineNumber
	|		ELSE TotalStaffList.LineNumber
	|	END AS LineNumber
	|FROM
	|	(SELECT
	|		StaffListMaxPeriods.LineNumber AS LineNumber,
	|		HeadcountBudget.NumberOfRates AS CountOfRatesBySSh,
	|		HeadcountBudget.StructuralUnit AS StructuralUnit,
	|		HeadcountBudget.Position AS Position,
	|		HeadcountBudget.Company AS Company
	|	FROM
	|		(SELECT
	|			HeadcountBudget.Company AS Company,
	|			HeadcountBudget.StructuralUnit AS StructuralUnit,
	|			HeadcountBudget.Position AS Position,
	|			MAX(HeadcountBudget.Period) AS Period,
	|			StaffDisplacementEmployees.LineNumber AS LineNumber
	|		FROM
	|			Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|				INNER JOIN InformationRegister.HeadcountBudget AS HeadcountBudget
	|				ON (HeadcountBudget.Company = &Company)
	|					AND StaffDisplacementEmployees.StructuralUnit = HeadcountBudget.StructuralUnit
	|					AND StaffDisplacementEmployees.Position = HeadcountBudget.Position
	|					AND StaffDisplacementEmployees.Period >= HeadcountBudget.Period
	|		WHERE
	|			StaffDisplacementEmployees.Ref = &Ref
	|		
	|		GROUP BY
	|			HeadcountBudget.Position,
	|			HeadcountBudget.StructuralUnit,
	|			HeadcountBudget.Company,
	|			StaffDisplacementEmployees.LineNumber) AS StaffListMaxPeriods
	|			LEFT JOIN InformationRegister.HeadcountBudget AS HeadcountBudget
	|			ON StaffListMaxPeriods.Period = HeadcountBudget.Period
	|				AND StaffListMaxPeriods.Company = HeadcountBudget.Company
	|				AND StaffListMaxPeriods.StructuralUnit = HeadcountBudget.StructuralUnit
	|				AND StaffListMaxPeriods.Position = HeadcountBudget.Position) AS TotalStaffList
	|		Full JOIN (SELECT
	|			Employees.StructuralUnit AS StructuralUnit,
	|			Employees.Position AS Position,
	|			SUM(Employees.OccupiedRates) AS OccupiedRates,
	|			Employees.Company AS Company,
	|			EmployeesMaximalPeriods.LineNumber AS LineNumber
	|		FROM
	|			(SELECT
	|				Employees.Company AS Company,
	|				MAX(Employees.Period) AS Period,
	|				StaffDisplacementEmployees.LineNumber AS LineNumber,
	|				Employees.Employee AS Employee,
	|				StaffDisplacementEmployees.StructuralUnit AS StructuralUnit,
	|				StaffDisplacementEmployees.Position AS Position
	|			FROM
	|				Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|					LEFT JOIN InformationRegister.Employees AS Employees
	|					ON (Employees.Company = &Company)
	|						AND StaffDisplacementEmployees.Period >= Employees.Period
	|			WHERE
	|				StaffDisplacementEmployees.Ref = &Ref
	|			
	|			GROUP BY
	|				Employees.Company,
	|				StaffDisplacementEmployees.LineNumber,
	|				Employees.Employee,
	|				StaffDisplacementEmployees.StructuralUnit,
	|				StaffDisplacementEmployees.Position) AS EmployeesMaximalPeriods
	|				INNER JOIN InformationRegister.Employees AS Employees
	|				ON (Employees.Company = &Company)
	|					AND EmployeesMaximalPeriods.Employee = Employees.Employee
	|					AND EmployeesMaximalPeriods.StructuralUnit = Employees.StructuralUnit
	|					AND EmployeesMaximalPeriods.Position = Employees.Position
	|					AND EmployeesMaximalPeriods.Period = Employees.Period
	|		WHERE
	|			Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|		
	|		GROUP BY
	|			Employees.StructuralUnit,
	|			Employees.Position,
	|			Employees.Company,
	|			EmployeesMaximalPeriods.LineNumber) AS TotalBusyBids
	|		ON TotalStaffList.LineNumber = TotalBusyBids.LineNumber
	|
	|ORDER BY
	|	LineNumber");
						  
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If Selection.FontsContradiction Then
			MessageText = NStr("en = 'Row #%Number% of the ""Employees"" tabular section: employment rates are not provided in the staff list.'");
			MessageText = StrReplace(MessageText, "%Number%", Selection.LineNumber);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				Selection.LineNumber,
				"OccupiedRates",
				);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region EventHandlers

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Precheck
	RunPreliminaryControl(Cancel); 
	
	If OperationKind = Enums.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange Then
		CheckedAttributes.Add("Employees.StructuralUnit");
		CheckedAttributes.Add("Employees.Position");
		CheckedAttributes.Add("Employees.CurrentPositions");
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.TransferAndPromotion.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCompensationPlan(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	RunControl(AdditionalProperties, Cancel);
	RunControlStaffSchedule(AdditionalProperties, Cancel);	
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
		
EndProcedure

#EndRegion

#EndIf
