#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Row duplicates.
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset
	|INTO DocumentTable
	|FROM
	|	&DocumentTable AS DocumentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableOfDocument1.LineNumber) AS LineNumber,
	|	TableOfDocument1.FixedAsset
	|FROM
	|	DocumentTable AS TableOfDocument1
	|		INNER JOIN DocumentTable AS TableOfDocument2
	|		ON TableOfDocument1.LineNumber <> TableOfDocument2.LineNumber
	|			AND TableOfDocument1.FixedAsset = TableOfDocument2.FixedAsset
	|
	|GROUP BY
	|	TableOfDocument1.FixedAsset
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("DocumentTable", FixedAssets);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'The ""%FixedAsset%"" fixed asset in the %LineNumber% line of the ""Fixed assets"" list is duplicated.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", QueryResultSelection.LineNumber);
			MessageText = StrReplace(MessageText, "%FixedAsset%", QueryResultSelection.FixedAsset);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				QueryResultSelection.LineNumber,
				"FixedAsset",
				Cancel
			);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("Period", Date);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	Query.Text =
	"SELECT
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(&Period, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND FixedAsset IN (&FixedAssetsList)
	|				AND State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)) AS FixedAssetStateSliceLast";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'Statuses are not registered for the %FixedAsset% fixed asset in the %LineNumber% line of the ""Fixed assets"" list.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'The current status of the %FixedAsset% fixed asset in line No. %LineNumber% of the ""Fixed assets"" list is ""Not recognized"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DepreciationParametersSliceLast.FixedAsset AS FixedAsset,
	|	DepreciationParametersSliceLast.StructuralUnit AS Department,
	|	DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DepreciationParametersSliceLast.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DepreciationParametersSliceLast.GLExpenseAccount AS GLExpenseAccount,
	|	DepreciationParametersSliceLast.BusinessLine AS BusinessLine,
	|	DepreciationParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast(, FixedAsset = &FixedAsset) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("FixedAsset", FillingData);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Company = Selection.Company;
		
		NewRow = FixedAssets.Add();
		
		NewRow.FixedAsset = Selection.FixedAsset;
		NewRow.UsagePeriodForDepreciationCalculation = Selection.UsagePeriodForDepreciationCalculation;
		NewRow.AmountOfProductsServicesForDepreciationCalculation = Selection.AmountOfProductsServicesForDepreciationCalculation;
		NewRow.CostForDepreciationCalculation = Selection.CostForDepreciationCalculation;
		NewRow.GLExpenseAccount = Selection.GLExpenseAccount;
		NewRow.BusinessLine = Selection.BusinessLine;
		NewRow.StructuralUnit = Selection.Department;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowFixedAssets In FixedAssets Do
			
			If RowFixedAssets.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowFixedAssets.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			Else
				
				RowFixedAssets.BusinessLine = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.Linear
		   AND RowOfFixedAssets.UsagePeriodForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed assets ""%FixedAsset%"" indicated in row No.%LineNumber% of the ""Fixed assets"" list, the ""Useful life to calculate depreciation"" should be filled.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"UsagePeriodForDepreciationCalculation",
				Cancel
			);
		EndIf;
		
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume
		   AND RowOfFixedAssets.AmountOfProductsServicesForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in row No.%LineNumber% of the ""Fixed assets"" list, the ""Product (work) volume to calculate depreciation in physical units"" should be filled."".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"AmountOfProductsServicesForDepreciationCalculation",
				Cancel
			);
		EndIf;
		
		If RowOfFixedAssets.CostForDepreciationCalculation > RowOfFixedAssets.CostForDepreciationCalculationBeforeChanging Then
			CheckedAttributes.Add("FixedAssets.RevaluationAccount");
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetDepreciationChanges.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
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