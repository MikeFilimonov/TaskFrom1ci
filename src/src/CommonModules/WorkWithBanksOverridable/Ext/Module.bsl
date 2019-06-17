////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It enables/disables the display of warnings showing the need to update the bank classifier.
//
// Parameters:
//  ShowMessageBox - Boolean.
Procedure OnDeterminingWhetherToShowWarningsAboutOutdatedClassifierBanks(ShowMessageBox) Export
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Update bank of the classifier and also set
// the current state (ManualChanging attribute). We are searching for the link by BIC.
// You shall update only that items which attribute
// does not match the same attribute in the classifier
//
// Parameters:
//
//  - BankList - Array - items with the CatalogRef.BankClassifier type - the list of
//                       banks to be updated if the list is empty, then it is necessary to check all items and update
//                       the changed ones
//
//  - DataArea - Number(1, 0) - data area to be updated for
//                              the local mode = 0 if the data area is not transferred, the update is not performed.
//
Function RefreshBanksFromClassifier(Val BankList = Undefined, Val DataArea) Export
	
	AreaProcessed  = True;
	If DataArea = Undefined Then
		Return AreaProcessed;
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	BankClassifier.Code AS Code,
	|	BankClassifier.Description,
	|	BankClassifier.City,
	|	BankClassifier.Address,
	|	BankClassifier.PhoneNumbers,
	|	BankClassifier.IsFolder,
	|	BankClassifier.Parent.Code,
	|	BankClassifier.Parent.Description,
	|	BankClassifier.ActivityDiscontinued
	|INTO TU_ChangedBanks
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Ref IN(&BankList)
	|
	|INDEX BY
	|	Code
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SubqueryBanks.Bank AS Bank,
	|	SubqueryBanks.Code AS Code,
	|	SubqueryBanks.Description AS Description,
	|	SubqueryBanks.City AS City,
	|	SubqueryBanks.Address AS Address,
	|	SubqueryBanks.PhoneNumbers AS PhoneNumbers,
	|	SubqueryBanks.IsFolder AS IsFolder,
	|	SubqueryBanks.ParentCode AS ParentCode,
	|	SubqueryBanks.ParentDescription AS ParentDescription,
	|	SubqueryBanks.ActivityDiscontinued AS ActivityDiscontinued
	|INTO TU_ChangedItems
	|FROM
	|	(SELECT
	|		Banks.Ref AS Bank,
	|		TU_ChangedBanks.Code AS Code,
	|		TU_ChangedBanks.Description AS Description,
	|		TU_ChangedBanks.City AS City,
	|		TU_ChangedBanks.Address AS Address,
	|		TU_ChangedBanks.PhoneNumbers AS PhoneNumbers,
	|		TU_ChangedBanks.IsFolder AS IsFolder,
	|		TU_ChangedBanks.ParentCode AS ParentCode,
	|		TU_ChangedBanks.ParentDescription AS ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued AS ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Description <> TU_ChangedBanks.Description
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.City <> TU_ChangedBanks.City
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Address <> TU_ChangedBanks.Address
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.PhoneNumbers <> TU_ChangedBanks.PhoneNumbers
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Parent.Code <> TU_ChangedBanks.ParentCode
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.PhoneNumbers,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.ActivityDiscontinued
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND (Banks.ManualChanging = 2)
	|	WHERE
	|		Not Banks.IsFolder) AS SubqueryBanks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_ChangedItems.Bank AS Bank,
	|	TU_ChangedItems.Code AS Code,
	|	TU_ChangedItems.Description AS Description,
	|	TU_ChangedItems.City AS City,
	|	TU_ChangedItems.Address AS Address,
	|	TU_ChangedItems.PhoneNumbers AS PhoneNumbers,
	|	TU_ChangedItems.IsFolder AS IsFolder,
	|	0 AS ManualChanging,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent,
	|	TU_ChangedItems.ParentCode AS ParentCode,
	|	TU_ChangedItems.ParentDescription AS ParentDescription,
	|	TU_ChangedItems.ActivityDiscontinued AS ActivityDiscontinued
	|FROM
	|	TU_ChangedItems AS TU_ChangedItems
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_ChangedItems.ParentCode = Banks.Code
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.ActivityDiscontinued
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND Banks.Description <> TU_ChangedBanks.Description
	|			AND (Banks.ManualChanging = 0)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.ActivityDiscontinued
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND (Banks.ManualChanging = 2)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|ORDER BY
	|	IsFolder DESC";
	
	If BankList = Undefined OR BankList.Count() = 0 Then
		QueryText = StrReplace(QueryText, "
			|WHERE
			|	BankClassifier.Ref IN(&BankList)", "");
	Else
		Query.SetParameter("BankList",  BankList);
	EndIf;
	
	Query.Text = QueryText;
	BanksSelection = Query.Execute().Select();
	
	ExcludingPropertiesForItem = "IsFolder";
	ExcludingPropertiesForGroup = "Address, City, PhoneNumbers, Parent, IsFolder";
	
	LangCode = CommonUseClientServer.MainLanguageCode();
	
	While BanksSelection.Next() Do
		
		Bank = BanksSelection.Bank.GetObject();
		FillPropertyValues(Bank, BanksSelection,,
			?(BanksSelection.IsFolder, ExcludingPropertiesForGroup, ExcludingPropertiesForItem));
		
		If Not BanksSelection.IsFolder AND Not ValueIsFilled(BanksSelection.Parent) AND Not IsBlankString(BanksSelection.ParentCode) Then
			Parent = RefOnBank(BanksSelection.ParentCode, True);
			If Not ValueIsFilled(Parent) Then
				Parent = Catalogs.Banks.CreateFolder();
				Parent.Code          = BanksSelection.ParentCode;
				Parent.Description = BanksSelection.ParentDescription;
				
				Try
					Parent.Write();
				Except
					MessagePattern = NStr("en = 'Error when recording the bank-group (state) %1.
											|%2'",
										LangCode);
					
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
						BanksSelection.ParentDescription,
						DetailErrorDescription(ErrorInfo()));
						
					DataAreaNumber = ?(CommonUseReUse.DataSeparationEnabled(),
						StringFunctionsClientServer.SubstituteParametersInString(NStr("en = ' in area %1'"), DataArea),
						"");
						
					EventName = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Banks refresh %1'",
							LangCode),
						DataAreaNumber);
						
					WriteLogEvent(
						EventName,
						EventLogLevel.Error,,,
						MessageText);
					
					AreaProcessed = False;
					Break;
				EndTry
			EndIf;
			
			Bank.Parent = Parent.Ref;
		EndIf;
		
		Try
			Bank.Write();
		Except
			MessagePattern = NStr("en = 'Error when recording the bank with BIC %1 %2'",
								LangCode);
				
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
				
			DataAreaNumber = 
				?(CommonUseReUse.DataSeparationEnabled(),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = ' in area %1'",
						LangCode),
					DataArea),
				"");
				
			EventName = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Banks refresh %1'",
						LangCode),
					DataAreaNumber);
					
			WriteLogEvent(EventName,
				EventLogLevel.Error,,,
				MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	If Not AreaProcessed Then
		Return AreaProcessed;
	EndIf;
	
	// Find banks with the lost classifier
	// connection and set the appropriate sign
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref AS Bank,
	|	2 AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.BankClassifier AS BankClassifier
	|		ON Banks.Code = BankClassifier.Code
	|WHERE
	|	BankClassifier.Ref IS NULL 
	|	AND Banks.ManualChanging <> 2
	|
	|UNION
	|
	|SELECT
	|	Banks.Ref,
	|	3
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.BankClassifier AS BankClassifier
	|		ON Banks.Code = BankClassifier.Code
	|WHERE
	|	BankClassifier.ActivityDiscontinued
	|	AND Banks.ManualChanging < 2";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Bank = Selection.Bank.GetObject();
		Bank.ManualChanging = Selection.ManualChanging;
		
		Try
			Bank.Write();
		Except
			MessagePattern = NStr("en = 'Error when recording the bank with BIC %1 %2'",
								LangCode);
								
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
				
			DataAreaNumber = ?(CommonUseReUse.DataSeparationEnabled(),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = ' in %1 field'",
						LangCode),
					DataArea),
				"");
			
			EventName = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Banks refresh %1'",
					LangCode),
				DataAreaNumber);
				
			WriteLogEvent(EventName,
				EventLogLevel.Error,,,
				MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	Return AreaProcessed;
	
EndFunction

// Specifies the text of the
// divided object state, sets the availability of the state control buttons and ReadOnly flag form
//
Procedure ProcessManualEditFlag(Val Form)
	
	Items  = Form.Items;
	
	If Form.ManualChanging = Undefined Then
		If Form.ActivityDiscontinued Then
			Form.ManualEditText = "";
		Else
			Form.ManualEditText = NStr("en = 'The item is created manually. Automatic update is impossible.'");
		EndIf;
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = True;
		Items.Code.Enabled      = True;
	ElsIf Form.ManualChanging = True Then
		Form.ManualEditText = NStr("en = 'Automatic item update is disabled.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = False;
		Items.Code.Enabled      = False;
	Else
		Form.ManualEditText = NStr("en = 'Item is updated automatically.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly          = True;
	EndIf;
	
EndProcedure

// It reads the object current state
// and makes the form compliant with it
//
Procedure ReadManualEditFlag(Val Form) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.ManualChanging AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Ref = &Ref";
	
	Query.SetParameter("Ref", Form.Object.Ref);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	If QueryResult.IsEmpty() Then
		
		Form.ManualChanging = Undefined;
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		If Selection.ManualChanging >= 2 Then
			Form.ManualChanging = Undefined;
		Else
			Form.ManualChanging = Selection.ManualChanging;
		EndIf;
		
	EndIf;
	
	If Form.ManualChanging = Undefined Then
		RefToClassifier = ReferenceOnClassifier(Form.Object.Code);
		If ValueIsFilled(RefToClassifier) Then
			Query.SetParameter("Ref", RefToClassifier);
			Query.Text =
			"SELECT
			|	BankClassifier.ActivityDiscontinued
			|FROM
			|	Catalog.BankClassifier AS BankClassifier
			|WHERE
			|	BankClassifier.Ref = &Ref";
			
			Selection = Query.Execute().Select();
			Selection.Next();
			Form.ActivityDiscontinued = Selection.ActivityDiscontinued;
		EndIf;
	EndIf;
	
	ProcessManualEditFlag(Form);
	
EndProcedure

// Function to be changed and Banks catalog record
// by transferred parameters if such bank is not
// in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - Refs - Array with items of the Structure type - Structure keys - names of
//   the catalog attributes, Structure values - attribute data values
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//   
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function RefreshCreateBanksWIB(Refs, IgnoreManualChanging)
	
	BanksArray = New Array;
	
	For ind = 0 To Refs.UBound() Do
		ParametersObject = Refs[ind];
		Bank = ParametersObject.Bank;
		
		If ParametersObject.ManualChanging = 1
			AND Not IgnoreManualChanging Then
			BanksArray.Add(Bank);
			Continue;
		EndIf;
		
		If Bank.IsEmpty() Then
			If ParametersObject.ThisState Then
				BankObject = Catalogs.Banks.CreateFolder();
			Else
				BankObject = Catalogs.Banks.CreateItem();
			EndIf;
		Else
			BankObject = Bank.GetObject();
		EndIf;
		
		Attributes = BankObject.Metadata().Attributes;
		For each Attribute In Attributes Do
			BankObject[Attribute.Name] = Undefined;		
		EndDo;
		
		FillPropertyValues(BankObject, ParametersObject);
		
		BeginTransaction();
		Try
			BankObject.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			
			EventName = ?(EventName = "",
				NStr("en = 'Pick from classifier'"), EventName);
			WriteLogEvent(EventName, 
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
			Break;
		EndTry;
		
		BanksArray.Add(BankObject.Ref);
	EndDo;
	
	Return BanksArray;
	
EndFunction

// The function selects the classifier data to be copied to
// the Banks catalog item if such bank is
// not in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - BankReferences - Array with items of CatalogRef.BankClassifier type - the list
//   of classifier values to be processed
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function BankClassificatorSelection(Val ReferencesBanks, IgnoreManualChanging = False) Export
	
	BanksArray = New Array;
	
	If ReferencesBanks.Count() = 0 Then
		Return BanksArray;
	EndIf;
	
	LinksHierarchy = SupplementArrayWithRefParents(ReferencesBanks);
	
	Query = New Query;
	Query.SetParameter("LinksHierarchy", LinksHierarchy);
	Query.Text =
	"SELECT
	|	BankClassifier.Code AS BIN,
	|	BankClassifier.Description,
	|	BankClassifier.City,
	|	BankClassifier.Address,
	|	BankClassifier.PhoneNumbers,
	|	BankClassifier.IsFolder,
	|	BankClassifier.Parent.Code,
	|	BankClassifier.Country
	|INTO TU_BankClassifier
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Ref IN(&LinksHierarchy)
	|
	|INDEX BY
	|	BIN
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Bank,
	|	TU_BankClassifier.BIN AS Code,
	|	TU_BankClassifier.IsFolder AS ThisState,
	|	TU_BankClassifier.Description,
	|	TU_BankClassifier.City,
	|	TU_BankClassifier.Address,
	|	TU_BankClassifier.PhoneNumbers,
	|	0 AS ManualChanging,
	|	ISNULL(TU_BankClassifier.ParentCode, """") AS ParentCode,
	|	TU_BankClassifier.Country
	|INTO BanksWithoutParents
	|FROM
	|	TU_BankClassifier AS TU_BankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_BankClassifier.BIN = Banks.Code
	|WHERE
	|	NOT TU_BankClassifier.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)),
	|	TU_BankClassifier.BIN,
	|	TU_BankClassifier.IsFolder,
	|	TU_BankClassifier.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	0,
	|	ISNULL(TU_BankClassifier.ParentCode, """"),
	|	NULL
	|FROM
	|	TU_BankClassifier AS TU_BankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_BankClassifier.BIN = Banks.Code
	|WHERE
	|	TU_BankClassifier.IsFolder
	|
	|INDEX BY
	|	ParentCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BanksWithoutParents.Bank,
	|	BanksWithoutParents.Code AS Code,
	|	BanksWithoutParents.ThisState AS ThisState,
	|	BanksWithoutParents.Description,
	|	BanksWithoutParents.City,
	|	BanksWithoutParents.Address,
	|	BanksWithoutParents.PhoneNumbers,
	|	BanksWithoutParents.ManualChanging,
	|	BanksWithoutParents.ParentCode,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent,
	|	BanksWithoutParents.Country
	|FROM
	|	BanksWithoutParents AS BanksWithoutParents
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON BanksWithoutParents.ParentCode = Banks.Parent
	|
	|ORDER BY
	|	ThisState DESC,
	|	Code";
	
	SetPrivilegedMode(True);
	BanksTable = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Refs = New Array;
	For Each ValueTableRow In BanksTable Do
		
		ObjectParameters = CommonUse.ValueTableRowToStructure(ValueTableRow);
		DeleteNoValidKeysStructure(ObjectParameters);
		Refs.Add(ObjectParameters);
		
	EndDo;
	
	BanksArray = RefreshCreateBanksWIB(Refs, IgnoreManualChanging);
	
	Return BanksArray;
	
EndFunction

// Data recovery from the common
// object and it changes the object state
//
Procedure RestoreItemFromSharedData(Val Form) Export
	
	BeginTransaction();
	Try
		Refs = New Array;
		Classifier = ReferenceOnClassifier(
			Form.Object.Code);
		
		If Not ValueIsFilled(Classifier) Then
			Return;
		EndIf;
		
		Refs.Add(Classifier);
		BankClassificatorSelection(Refs, True);
		
		Form.ManualChanging = False;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorMessage = NStr("en = 'Recovery from common data'", CommonUseClientServer.MainLanguageCode());
		WriteLogEvent(ErrorMessage, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Form.Read();
	
EndProcedure

// Receiving the references to the Bank Classifier catalog item by BIC text presentation
// 
Function ReferenceOnClassifier(BIC)
	
	If BIC = "" Then
		Return Catalogs.BankClassifier.EmptyRef();
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	BankClassifier.Ref
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Code = &BIC";
	
	Query.SetParameter("BIC", BIC);
	
	Query.Text = QueryText;
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.BankClassifier.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

// Receiving the references to
// the Banks catalog item by BIC or text presentation
//
Function RefOnBank(BIN, ThisState = False)
	
	If BIN = "" Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Code = &BIN
	|	AND Banks.IsFolder = &IsFolder";
	
	Query.SetParameter("BIN",       BIN);
	Query.SetParameter("IsFolder", ThisState);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function SupplementArrayWithRefParents(Val Refs)
	
	TableName = Refs[0].Metadata().FullName();
	
	RefArray = New Array;
	For Each Ref In Refs Do
		RefArray.Add(Ref);
	EndDo;
	
	CurrentRefs = Refs;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Table.Parent AS Ref
	|FROM
	|	" + TableName + " AS
	|Table
	|WHERE Table.Ref
	|	In (&Refs) And Table.Parent <> VALUE(" + TableName + ".EmptyRef)";
	
	While True Do
		Query.SetParameter("Refs", CurrentRefs);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Break;
		EndIf;
		
		CurrentRefs = New Array;
		Selection = Result.Select();
		While Selection.Next() Do
			CurrentRefs.Add(Selection.Ref);
			RefArray.Add(Selection.Ref);
		EndDo;
	EndDo;
	
	Return RefArray;
	
EndFunction

Procedure DeleteNoValidKeysStructure(ParametersStructureCatalog)
	
	For Each KeyAndValue In ParametersStructureCatalog Do
		If KeyAndValue.Value = Null OR KeyAndValue.Key = "IsFolder" Then
			ParametersStructureCatalog.Delete(KeyAndValue.Key);
		EndIf;
	EndDo;
	
EndProcedure

// It copies all banks to all DE
//
// Parameters  
//   BankTable - ValueTable with the banks
//   AreasForUpdating - Array with a list of area codes
//   FileIdentifier - File UUID for the processed banks
//   ProcessorCode  - String, handler code
//
Procedure BanksExtendedDA(Val BankList, Val FileID, Val ProcessorCode) Export
	
	AreasForUpdating  = SuppliedData.AreasRequiredProcessing(
		FileID, "Banks");
	
	For Each DataArea In AreasForUpdating Do
		AreaProcessed = False;
		SetPrivilegedMode(True);
		CommonUse.SetSessionSeparation(True, DataArea);
		SetPrivilegedMode(False);
		
		BeginTransaction();
		AreaProcessed = RefreshBanksFromClassifier(
			BankList, DataArea);
		
		If AreaProcessed Then
			SuppliedData.AreaProcessed(FileID, ProcessorCode, DataArea);
			CommitTransaction();
		Else
			RollbackTransaction();
		EndIf;
		
	EndDo;
	
EndProcedure

// It loads the bank classifier in the service model from the provided data
//
// Parameters:
//   PathToFile - String - bnk.zip file path received from the provided data
//
Function ImportSuppliedBankClassifier(PathToFile) Export
	
	Return WorkWithBanks.ImportDataFromFile(PathToFile);
	
EndFunction

#EndRegion
