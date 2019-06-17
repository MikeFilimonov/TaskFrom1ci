
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MasterNode = Constants.MasterNode.Get();
	
	If Not ValueIsFilled(MasterNode) Then
		Raise NStr("en = 'Main node is not saved.'");
	EndIf;
	
	If ExchangePlans.MasterNode() <> Undefined Then
		Raise NStr("en = 'Main node is set.'");
	EndIf;
	
	Items.WarningText.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.WarningText.Title, String(MasterNode));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Recall(Command)
	
	RestoreAtServer();
	
	Close(New Structure("Cancel", False));
	
EndProcedure

&AtClient
Procedure Disable(Command)
	
	DisableAtServer();
	
	Close(New Structure("Cancel", False));
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	Close(New Structure("Cancel", True));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure DisableAtServer()
	
	BeginTransaction();
	Try
		MainNodeManager = Constants.MasterNode.CreateValueManager();
		MainNodeManager.Value = Undefined;
		UpdateResults.WriteData(MainNodeManager);
		
		SetAllPredefinedDataInitialization();
		
		SetInfobasePredefinedDataUpdate(
			PredefinedDataUpdate.Auto);
		
		CreateMissingPredefinedData();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure RestoreAtServer()
	
	MasterNode = Constants.MasterNode.Get();
	
	ExchangePlans.SetMasterNode(MasterNode);
	
EndProcedure

&AtServerNoContext
Procedure SetAllPredefinedDataInitialization()
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			Manager.SetPredefinedDataInitialization(True);
		EndDo;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure CreateMissingPredefinedData()
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	Query = New Query;
	QueryText =
	"SELECT
	|	SpecifiedTableAlias.Ref AS Ref,
	|	SpecifiedTableAlias.PredefinedDataName AS Name
	|FROM
	|	&CurrentTable AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Predefined";
	
	SavedDescriptions = New Array;
	For Each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			If MetadataObject = Metadata.ObjectProperties.PredefinedDataUpdate.DontAutoUpdate Then
				Continue;
			EndIf;
			DescriptionFull = MetadataObject.FullName();
			Query.Text = StrReplace(QueryText, "&CurrentTable", DescriptionFull);
			NamesTable = Query.Execute().Unload();
			NamesTable.Indexes.Add("Name");
			names = MetadataObject.GetPredefinedNames();
			SaveExistingPredeterminedObjectsBeforeCreatingMissing(
				MetadataObject, DescriptionFull, NamesTable, names, Query, SavedDescriptions);
		EndDo;
	EndDo;
	
	InitializePredefinedData();
	
	// Restore predefined items existed prior to initialization.
	For Each SavedDescription In SavedDescriptions Do
		Query.Text = SavedDescription.QueryText;
		NamesTable = Query.Execute().Unload();
		NamesTable.Indexes.Add("Name");
		For Each SavedDescription In SavedDescription.NamesTable Do
			If Not SavedDescription.ObjectExists Then
				Continue;
			EndIf;
			String = NamesTable.Find(SavedDescription.Name, "Name");
			If String <> Undefined Then
				UpdateResults.DeleteData(String.Ref.GetObject());
			EndIf;
			UpdateResults.WriteData(SavedDescription.Object);
		EndDo;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SaveExistingPredeterminedObjectsBeforeCreatingMissing(
		MetadataObject, DescriptionFull, NamesTable, names, Query, SavedDescriptions)
	
	InitializationRequired = False;
	PredefinedExist = False;
	NamesTable.Columns.Add("ObjectExists");
	
	For Each Name In names Do
		String = NamesTable.Find(Name, "Name");
		If String = Undefined Then
			InitializationRequired = True;
		Else
			String.ObjectExists = True;
			PredefinedExist = True;
		EndIf;
	EndDo;
	
	If Not InitializationRequired Then
		Return;
	EndIf;
	
	If PredefinedExist Then
		SavedDescription = New Structure;
		SavedDescription.Insert("QueryText", Query.Text);
		SavedDescription.Insert("NamesTable", NamesTable);
		SavedDescriptions.Add(SavedDescription);
		
		NamesTable.Columns.Add("Object");
		For Each String In NamesTable Do
			If String.ObjectExists Then
				Object = String.Ref.GetObject();
				Object.PredefinedDataName = "";
				UpdateResults.WriteData(Object);
				Object.PredefinedDataName = String.Name;
				String.Object = Object;
			EndIf;
		EndDo;
	EndIf;
	
	Manager = CommonUse.ObjectManagerByFullName(DescriptionFull);
	Manager.SetPredefinedDataInitialization(False);
	
EndProcedure

#EndRegion
