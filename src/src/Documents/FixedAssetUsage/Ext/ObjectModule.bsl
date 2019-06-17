#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("Period", Date);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	// Check property states.
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
			MessageText = NStr("en = 'The current status for the %FixedAssets% fixed asset specified in the %LineNumber% line of the ""Fixed assets"" list is ""Not recognized"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'The current status for the %FixedAssets% specified in the %LineNumber% line of the ""Fixed assets"" list is ""Not recognized"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DepreciationParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast(, FixedAsset = &FixedAsset) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("FixedAsset", FillingData);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Company = Selection.Company;
	EndIf;
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod <> Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume Then
			MessageText = NStr("en = 'Depreciation method other than ""Units-of-production"" is used for %FixedAssets% specified in the %LineNumber% line of the ""Fixed assets"" list.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
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

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetUsage.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel);
	
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