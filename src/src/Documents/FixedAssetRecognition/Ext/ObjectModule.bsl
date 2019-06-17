#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Check Row duplicates.
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
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Fixed asset ""%1"" from the line %2 of the ""Fixed assets"" list is duplicated.'"),
							QueryResultSelection.LineNumber,
							QueryResultSelection.FixedAsset);
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
	
	// Check cost.
	TotalOriginalCost = 0;
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	Query.Text =
	"SELECT
	|	ISNULL(SUM(FixedAssets.InitialCost), 0) AS InitialCost
	|FROM
	|	Catalog.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Ref IN(&FixedAssetsList)";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next() Then
		TotalOriginalCost = QuerySelection.InitialCost;
	EndIf;
	
	If TotalOriginalCost <> Amount Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The fixed asset cost: %1 mismatches its initial costs: %2'"),
						TrimAll(String(Amount)),
						TrimAll(String(TotalOriginalCost)));
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			Undefined,
			Undefined,
			"",
			Cancel
		);
	EndIf;
	
	Query.Text =
	"SELECT
	|	NestedSelect.FixedAsset AS FixedAsset
	|FROM
	|	(SELECT
	|		FixedAssetStatus.FixedAsset AS FixedAsset,
	|		SUM(CASE
	|				WHEN FixedAssetStatus.State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)
	|					THEN 1
	|				ELSE -1
	|			END) AS CurrentState
	|	FROM
	|		InformationRegister.FixedAssetStatus AS FixedAssetStatus
	|	WHERE
	|		FixedAssetStatus.Recorder <> &Ref
	|		AND FixedAssetStatus.Company = &Company
	|		AND FixedAssetStatus.FixedAsset IN(&FixedAssetsList)
	|	
	|	GROUP BY
	|		FixedAssetStatus.FixedAsset) AS NestedSelect
	|WHERE
	|	NestedSelect.CurrentState > 0";
	
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	ArrayVAStatus = QueryResult.Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) <> Undefined Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'The current status of the ""%1"" fixed asset from the line %2 of the ""Fixed assets"" list is ""Recognized"".'"),
							TrimAll(String(RowOfFixedAssets.FixedAsset)),
							String(RowOfFixedAssets.LineNumber));
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

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	NewRow.AccrueDepreciation = True;
	NewRow.AccrueDepreciationInCurrentMonth = True;
	
	User = Users.CurrentUser();
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);

	NewRow.StructuralUnit = MainDepartment;
	
	
EndProcedure

#EndRegion

#Region EventsHandlers

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
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	// Correctness of filling.
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.Linear
		   AND RowOfFixedAssets.UsagePeriodForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in string %LineNumber% of list ""Fixed assets"" should be filled with ""Useful life to calculate depreciation"".'");
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
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in string %LineNumber% of list ""Fixed assets"" should be filled with ""Product (work) volume to calculate depreciation in physical units."".'");
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
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetRecognition.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetRecognition.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
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
	
	// Creating control of negative balances.
	Documents.FixedAssetRecognition.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#EndIf