﻿///////////////////////////////////////////////////////////////////////////////////
// SaaSOperations.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the name of the common attribute that is the common data separator.
//
// Return value: String.
//
Function MainDataSeparator() Export
	
	Return Metadata.CommonAttributes.DataAreaBasicData.Name;
	
EndFunction

// Returns name of common attribute that is helper data separator.
//
// Return value: String.
//
Function SupportDataSplitter() Export
	
	Return Metadata.CommonAttributes.DataAreaAuxiliaryData.Name;
	
EndFunction

// Clears all session parameters except for those associated with general attribute DataArea.
// 
Procedure ClearAllSessionParametersExceptSeparators() Export
	
	CommonUse.ClearSessionParameters(, "DataAreaValue,DataAreasUse");
	
EndProcedure

// Locks data areas.
// 
// Parameters: 
// CheckNoOtherSessions - Boolean - check if
// there are no other user sessions where the separate equals to the current one.
// If other sessions are found, an exception is thrown.
// SeparatedLock - Boolean - set separated
// lock instead of the exclusive one.
// 
Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedLock = False) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Raise(NStr("en = 'Area can be locked only when separator usage is enabled'"));
	EndIf;
	
	KeyVar = CreateAuxiliaryDataRecordKeyOfInformationRegister(
		InformationRegisters.DataAreas,
		New Structure(SupportDataSplitter(), CommonUse.SessionSeparatorValue()));
	
	AttemptCount = 5;
	CurrentTry = 0;
	While True Do
		Try
			LockDataForEdit(KeyVar);
			Break;
		Except
			CurrentTry = CurrentTry + 1;
			
			If CurrentTry = AttemptCount Then
				CommentTemplate = NStr("en = 'Cannot lock the data area
				                       |as %1'");
				TextOfComment = StringFunctionsClientServer.SubstituteParametersInString(CommentTemplate, 
					DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(
					NStr("en = 'Data area locking'", CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					,
					,
					TextOfComment);
					
				TextPattern = NStr("en = 'Cannot lock the data area
				                   |as %1'");
				Text = StringFunctionsClientServer.SubstituteParametersInString(TextPattern, 
					BriefErrorDescription(ErrorInfo()));
					
				Raise(Text);
			EndIf;
		EndTry;
	EndDo;
	
	If CheckNoOtherSessions Then
		
		ConflictSessions = New Array();
		
		For Each Session In GetInfobaseSessions() Do
			If Session.SessionNumber = InfobaseSessionNumber() Then
				Continue;
			EndIf;
			
			ClientApplications = New Array;
			ClientApplications.Add(Upper("1CV8"));
			ClientApplications.Add(Upper("1CV8C"));
			ClientApplications.Add(Upper("WebClient"));
			ClientApplications.Add(Upper("COMConnection"));
			ClientApplications.Add(Upper("WSConnection"));
			ClientApplications.Add(Upper("BackgroundJob"));
			If ClientApplications.Find(Upper(Session.ApplicationName)) = Undefined Then
				Continue;
			EndIf;
			
			ConflictSessions.Add(Session);
			
		EndDo;
		
		If ConflictSessions.Count() > 0 Then
			
			TextSessions = "";
			For Each ConflictSession In ConflictSessions Do
				
				If Not IsBlankString(TextSessions) Then
					TextSessions = TextSessions + ", ";
				EndIf;
				
				TextSessions = TextSessions + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 (session - %2)'", CommonUseClientServer.MainLanguageCode()),
					ConflictSession.User.Name,
					Format(ConflictSession.SessionNumber, "NG=0"));
				
			EndDo;
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Operation cannot be performed as other users are using the application: %1'",
					CommonUseClientServer.MainLanguageCode()),
				TextSessions);
			Raise ErrorMessage;
			
		EndIf;
		
	EndIf;
	
	If Not SeparatedLock Then
		SetExclusiveMode(True);
		Return;
	EndIf;
	
	DataModel = SaaSReUse.GetDataAreaModel();
	
	If SeparatedLock Then
		LockMode = DataLockMode.Shared;
	Else
		LockMode = DataLockMode.Exclusive;
	EndIf;
	
	Block = New DataLock;
	
	For Each ModelItem In DataModel Do
		
		FullMetadataObjectName = ModelItem.Key;
		MetadataObjectDesc = ModelItem.Value;
		
		SpaceLock = FullMetadataObjectName;
		
		If ThisIsFullNameOfRegister(FullMetadataObjectName) Then
			
			LockSets = True;
			If IsFullNameOfRegisterInformation(FullMetadataObjectName) Then
				AreaMetadataObject = Metadata.InformationRegisters.Find(MetadataObjectDesc.Name);
				If AreaMetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					LockSets = False;
				EndIf;
			EndIf;
			
			If LockSets Then
				SpaceLock = SpaceLock + ".RecordSet";
			EndIf;
			
		ElsIf IsFullSequenceName(FullMetadataObjectName) Then
			
			SpaceLock = SpaceLock + ".Records";
			
		ElsIf IsFullDocumentJournalName(FullMetadataObjectName) OR
				IsEnumerationFullName(FullMetadataObjectName) OR
				IsFullSequenceName(FullMetadataObjectName) OR
				IsFullNameForJobSchedule(FullMetadataObjectName) Then
			
			Continue;
			
		EndIf;
		
		LockItem = Block.Add(SpaceLock);
		LockItem.Mode = LockMode;
		
	EndDo;
	
	Block.Lock();
	
EndProcedure

// Releases exclusive area lock from the current data area.
//
Procedure UnlockCurrentDataArea() Export
	
	KeyVar = CreateAuxiliaryDataRecordKeyOfInformationRegister(
		InformationRegisters.DataAreas,
		New Structure(SupportDataSplitter(), CommonUse.SessionSeparatorValue()));
		
	UnlockDataForEdit(KeyVar);
	
	SetExclusiveMode(False);
	
EndProcedure

// Checks the data area lock.
//
// Parameters:
//  DataArea -  Number - separator value of data
// area which lock is to be checked.
//
// Returns:
// Boolean - True data area is locked, otherwise, no.
//
Function DataAreaBlocked(Val DataArea) Export
	
	KeyVar = CreateAuxiliaryDataRecordKeyOfInformationRegister(
		InformationRegisters.DataAreas,
		New Structure(SupportDataSplitter(), DataArea));
	
	Try
		LockDataForEdit(KeyVar);
	Except
		Return True;
	EndTry;
	
	UnlockDataForEdit(KeyVar);
	
	Return False;
	
EndFunction

// Prepares data area to be used. Starts
// IB update procedure and fills
// it in with demo data if needed, sets a new status to the DataArea register.
// 
// Parameters: 
// DataArea - Separator value type - separator
// value of the data area to be prepared for use.
// 
Procedure PrepareDataAreaToUse(Val DataArea, Val ExportFileID, 
												 Val Variant = Undefined) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataRecordKeyOfInformationRegister(
		InformationRegisters.DataAreas,
		New Structure(SupportDataSplitter(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		RecordManager = GetRecordManagerOfDataAreas(DataArea, Enums.DataAreaStatuses.New);
		
		UsersService.AuthenticateCurrentUser();
		
		ErrorInfo = "";
		If Not ValueIsFilled(Variant) Then
			
			ResultOf = PrepareDataFromExportingArea(DataArea, ExportFileID, 
				ErrorInfo);
			
		Else
			
			ResultOf = PrepareDataAreaToUseOfStandard(DataArea, ExportFileID, 
				Variant, ErrorInfo);
				
		EndIf;
		
		ChangeAreasStateAndNotifyManager(RecordManager, ResultOf, ErrorInfo);

	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);

EndProcedure

// Copies data of the data area to another data area.
// 
// Parameters: 
// SourceArea - Separator value type - data
// area separator value - of data source.
// DestinationArea - Separator value type - data
// area separator value - of data receiver.
// 
Procedure CopyAreaData(Val SourceArea, Val DestinationArea) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, SourceArea);
	
	ExportFileName = Undefined;
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataAreasExportImport") Then
		
		CallExceptionNotAvailableSTLSubsystem("ServiceTechnology.SaaS.DataAreasExportImport");
		
	EndIf;
	
	ModuleDataAreasExportImport = CommonUse.CommonModule("DataAreasExportImport");
	
	BeginTransaction();
	
	Try
		ExportFileName = ModuleDataAreasExportImport.ExportCurrentDataAreaToArchive();
	Except
		WriteLogEvent(NStr("en = 'Copy data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		If ExportFileName <> Undefined Then
			Try
				DeleteFiles(ExportFileName);
			Except
			EndTry;
		EndIf;
		Raise;
	EndTry;
	
	CommonUse.SetSessionSeparation(, DestinationArea);
	
	Try
		ModuleDataAreasExportImport.ImportCurrentDataAreaFromArchive(ExportFileName);
	Except
		WriteLogEvent(NStr("en = 'Copy data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
		EndTry;
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
EndProcedure

// Deletes all data of the data area except of
//  the predefined ones, sets the Deleted status for the data area, sends
//  a message with information about area status change to the service manager. After that, the data area will be unusable.
//
// If it is required to delete all area data without changing its
//  status and saving the possibility of the subsequent area usage, you should use the ClearAreaData() procedure.
//
// Parameters: 
//  DataArea - Number(7,0) - separator value of the data area
//   that should be cleared, Data separation should be switched to this area during the procedure call.
//  DeleteUsers - Boolean - shows that IB users
//    should be deleted for this data area.
//
Procedure ClearDataArea(Val DataArea, Val DeleteUsers = True) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataRecordKeyOfInformationRegister(
		InformationRegisters.DataAreas,
		New Structure(SupportDataSplitter(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		
		RecordManager = GetRecordManagerOfDataAreas(DataArea, Enums.DataAreaStatuses.ToDelete);
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.SaaS\OnDeleteDataArea");
		
		For Each Handler In EventHandlers Do
			Handler.Module.OnDeleteDataArea(DataArea);
		EndDo;
		
		SaaSOverridable.OnDeleteDataArea(DataArea);
		
		ClearAreaData(DeleteUsers); // Call clearance
		
		// Recovering predetermined items.
		DataModel = SaaSReUse.GetDataAreaModel();

		For Each ModelItem In DataModel Do
			
			FullMetadataObjectName = ModelItem.Key;
			
			If IsCatalogFullName(FullMetadataObjectName)
				OR IsFullChartOfAccountsName(FullMetadataObjectName)
				OR IsTheFullChartOfCharacteristicTypesOfName(FullMetadataObjectName)
				OR IsTheFullChartOfCalculationTypesName(FullMetadataObjectName) Then
				
				MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
				
				If MetadataObject.GetPredefinedNames().Count() > 0 Then
					
					Manager = CommonUse.ObjectManagerByFullName(FullMetadataObjectName);
					Manager.SetPredefinedDataInitialization(False);
					
				EndIf;
				
			EndIf;
			
		EndDo;		

		ChangeAreasStateAndNotifyManager(RecordManager, "AreaIsDeleted", "");
		
	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);
	
EndProcedure

// Deletes all separated data from the current data area (including on
//  disabled data separation), except for overridable.
//
// Parameters:
//  DeleteUsers - Boolean, a flag
//    showing that IB users are to be deleted.
//
Procedure ClearAreaData(Val DeleteUsers) Export
	
	DataModel = SaaSReUse.GetDataAreaModel();
	
	ClearingExceptions = New Array();
	ClearingExceptions.Add(Metadata.InformationRegisters.DataAreas.FullName());
	
	For Each ModelItem In DataModel Do
		
		FullMetadataObjectName = ModelItem.Key;
		MetadataObjectDesc = ModelItem.Value;
		
		If ClearingExceptions.Find(FullMetadataObjectName) <> Undefined Then
			Continue;
		EndIf;
		
		If IsFullOfConstantName(FullMetadataObjectName) Then
			
			AreaMetadataObject = Metadata.Constants.Find(MetadataObjectDesc.Name);
			ValueManager = Constants[MetadataObjectDesc.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.Value = AreaMetadataObject.Type.AdjustValue();
			ValueManager.Write();
			
		ElsIf IsFullObjectNameOfReferenceType(FullMetadataObjectName) Then
			
			ThisIsExchangePlan = IsFullExchangePlanName(FullMetadataObjectName);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + FullMetadataObjectName + " AS _XMLExport_Table";
			
			If ThisIsExchangePlan Then
				
				Query.Text = Query.Text + "
				|WHERE
				|	_XMLExport_Table.Ref <> &ThisNode";
				Query.SetParameter("ThisNode", ExchangePlans[MetadataObjectDesc.Name].ThisNode());
				
			EndIf;
			
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Delete = New ObjectDeletion(Selection.Ref);
				Delete.DataExchange.Load = True;
				Delete.Write();
			EndDo;
			
		ElsIf ThisIsFullNameOfRegister(FullMetadataObjectName)
				OR IsAFullRecalculationOfName(FullMetadataObjectName) Then
			
			ThisIsInformationRegister = IsFullNameOfRegisterInformation(FullMetadataObjectName);
			If ThisIsInformationRegister Then
				AreaMetadataObject = Metadata.InformationRegisters.Find(MetadataObjectDesc.Name);
				IsIndependentInformationRegister = (AreaMetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent);
			Else
				IsIndependentInformationRegister = False;
			EndIf;
			
			Manager = CommonUse.ObjectManagerByFullName(FullMetadataObjectName);
			
			If IsIndependentInformationRegister Then
				
				RecordSet = Manager.CreateRecordSet();
				RecordSet.DataExchange.Load = True;
				RecordSet.Write();
				
			Else
				
				ParametersSelections = ParametersSelections(FullMetadataObjectName);
				FieldNameRecorder = ParametersSelections.FieldNameRecorder;
				
				Query = New Query;
				Query.Text =
				"SELECT DISTINCT
				|	_XMLExport_Table.Recorder AS Recorder
				|FROM
				|	" + ParametersSelections.Table + " AS _XMLExport_Table";
				
				If FieldNameRecorder <> "Recorder" Then
					Query.Text = StrReplace(Query.Text, "Recorder", FieldNameRecorder);
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					RecordSet = Manager.CreateRecordSet();
					RecordSet.Filter[FieldNameRecorder].Set(Selection[FieldNameRecorder]);
					RecordSet.DataExchange.Load = True;
					RecordSet.Write();
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Users
	If DeleteUsers Then
		
		FirstAdministrator = Undefined;
		
		For Each IBUser In InfobaseUsers.GetUsers() Do
			
			If FirstAdministrator = Undefined AND Users.InfobaseUserWithFullAccess(IBUser, True, False) Then
				
				// Postpone the administrator removal so that the rest
				// infobase users are deleted when they are being removed.
				FirstAdministrator = IBUser;
				
			Else
				
				IBUser.Delete();
				
			EndIf;
			
		EndDo;
		
		If FirstAdministrator <> Undefined Then
			FirstAdministrator.Delete();
		EndIf;
		
	EndIf;
	
	// Settings
	Storages = New Array;
	Storages.Add(ReportsVariantsStorage);
	Storages.Add(FormDataSettingsStorage);
	Storages.Add(CommonSettingsStorage);
	Storages.Add(ReportsUserSettingsStorage);
	Storages.Add(SystemSettingsStorage);
	
	For Each Storage In Storages Do
		If TypeOf(Storage) <> Type("StandardSettingsStorageManager") Then
			// The settings will be deleted when clearing data.
			Continue;
		EndIf;
		
		Storage.Delete(Undefined, Undefined, Undefined);
	EndDo;
	
EndProcedure

// Procedure of a scheduled job with the same name.
// Finds all data areas with statuses
// that require processor using the applied application and
// plans FL start on the maintenance if needed.
// 
Procedure DataAreasMaintenance() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CommonUse.OnStartExecutingScheduledJob();
	
	MaxRetryCount = 3;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea,
	|	DataAreas.Status AS Status,
	|	DataAreas.ExportID AS ExportID,
	|	DataAreas.Variant AS Variant
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.Status IN (VALUE(Enum.DataAreaStatuses.New), VALUE(Enum.DataAreaStatuses.ToDelete))
	|	AND DataAreas.ProcessingError = FALSE
	|
	|ORDER BY
	|	DataArea";
	Result = Query.Execute();
	Selection = Result.Select();
	
	Running = 0;
	
	While Selection.Next() Do
		
		RecordKey = CreateAuxiliaryDataRecordKeyOfInformationRegister(
			InformationRegisters.DataAreas,
			New Structure(SupportDataSplitter(), Selection.DataArea));
		
		Try
			LockDataForEdit(RecordKey);
		Except
			Continue;
		EndTry;
		
		Manager = InformationRegisters.DataAreas.CreateRecordManager();
		Manager.DataAreaAuxiliaryData = Selection.DataArea;
		Manager.Read();
		
		If Manager.Status = Enums.DataAreaStatuses.New Then 
			MethodName = "SaaSOperations.PrepareDataAreaToUse";
		ElsIf Manager.Status = Enums.DataAreaStatuses.ToDelete Then 
			MethodName = "SaaSOperations.ClearDataArea";
		Else
			UnlockDataForEdit(RecordKey);
			Continue;
		EndIf;
		
		If Manager.Repeat < MaxRetryCount Then
		
			JobFilter = New Structure;
			JobFilter.Insert("MethodName", MethodName);
			JobFilter.Insert("Key"     , "1");
			JobFilter.Insert("DataArea", Selection.DataArea);
			Jobs = JobQueue.GetJobs(JobFilter);
			If Jobs.Count() > 0 Then
				UnlockDataForEdit(RecordKey);
				Continue;
			EndIf;
			
			Manager.Repeat = Manager.Repeat + 1;
			
			ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
			FillPropertyValues(ManagerCopy, Manager);
			Manager = ManagerCopy;
			
			Manager.Write();

			MethodParameters = New Array;
			MethodParameters.Add(Selection.DataArea);
			
			If Selection.Status = Enums.DataAreaStatuses.New Then
				
				MethodParameters.Add(Selection.ExportID);
				If ValueIsFilled(Selection.Variant) Then
					MethodParameters.Add(Selection.Variant);
				EndIf;
			EndIf;
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , MethodName);
			JobParameters.Insert("Parameters"    , MethodParameters);
			JobParameters.Insert("Key"         , "1");
			JobParameters.Insert("DataArea", Selection.DataArea);
			JobParameters.Insert("ExclusiveExecution", True);
			
			JobQueue.AddJob(JobParameters);
			
			UnlockDataForEdit(RecordKey);
		Else
			
			ChangeAreasStateAndNotifyManager(Manager, ?(Manager.Status = Enums.DataAreaStatuses.New,
				"FatalError", "ErrorDelete"), NStr("en = 'Number of attempts to process the area is exceeded'"));
			
			UnlockDataForEdit(RecordKey);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns web-service proxy for synchronization of administrative actions in service.
// 
// Returns: 
// WSProxy.
// Proxy of service manager. 
// 
Function GetServiceManagerProxy(Val UserPassword = Undefined) Export
	
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en = 'Parameters of connection with the service manager are not set.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerAddress + "/ws/ManagementApplication_1_0_3_1?wsdl";
	
	If UserPassword = Undefined Then
		UserName = Constants.ServiceManagerOfficeUserName.Get();
		UserPassword = Constants.ServiceManagerOfficeUserPassword.Get();
	Else
		UserName = UserName();
	EndIf;
	
	Proxy = CommonUse.WSProxy(ServiceAddress, "http://www.1c.ru/SaaS/ManageApplication/1.0.3.1",
		"ManageApplication_1_0_3_1", , UserName, UserPassword, 20);
		
	Return Proxy;
	
EndFunction

// Sets the session separation.
//
// Parameters:
// Use - Boolean - Use the DataArea separator in the session.
// DataArea - Number - Value of the DataArea separator.
//
Procedure SetSessionSeparation(Val Use = Undefined, Val DataArea = Undefined) Export
	
	If Not CommonUseReUse.SessionWithoutSeparator() Then
		Raise(NStr("en = 'You can change session separation only from the session running without separators specified'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Use <> Undefined Then
		SessionParameters.DataAreasUse = Use;
	EndIf;
	
	If DataArea <> Undefined Then
		SessionParameters.DataAreaValue = DataArea;
	EndIf;
	
	DataAreaOnChange();
	
EndProcedure

// Returns the separator value of the current data area.
// IN case the value is not set, an error occurs.
// 
// Returns: 
// Separator value type.
// Separator value of the current data area. 
// 
Function SessionSeparatorValue() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return 0;
	Else
		If Not CommonUse.UseSessionSeparator() Then
			Raise(NStr("en = 'Separator value is not set'"));
		EndIf;
		
		// Get a separator value of the current data area.
		Return SessionParameters.DataAreaValue;
	EndIf;
	
EndFunction

// Returns a check box of using the DataArea separator for the current session.
// 
// Returns: 
// Boolean - True separation is used, otherwise, no.
// 
Function UseSessionSeparator() Export
	
	Return SessionParameters.DataAreasUse;
	
EndFunction

// Adds additional parameters to the client work
// parameters structure during the work in service model.
//
// Parameters:
//  Parameters - Structure - structure of the client work parameters.
//
Procedure AddClientParametersSaaS(Val Parameters) Export
	
	If Not CommonUseReUse.DataSeparationEnabled()
		OR Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreaPresentation.Value AS Presentation
	|FROM
	|	Constant.DataAreaPresentation AS DataAreaPresentation
	|WHERE
	|	DataAreaPresentation.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
	SetPrivilegedMode(True);
	Query.SetParameter("DataAreaAuxiliaryData", CommonUse.SessionSeparatorValue());
	// Consider data to be conditionally changed.
	Result = Query.Execute();
	SetPrivilegedMode(False);
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		If CommonUseReUse.SessionWithoutSeparator() Then
			Parameters.Insert("DataAreaPresentation", 
				Format(CommonUse.SessionSeparatorValue(), "NZ=0; NG=") +  " - " + Selection.Presentation);
		ElsIf Not IsBlankString(Selection.Presentation) Then
			Parameters.Insert("DataAreaPresentation", Selection.Presentation);
		EndIf;
	EndIf;
	
EndProcedure

// Adds a parameter description to the parameter table by a constant name.
// Returns an added parameter.
//
// Parameters: 
// ParameterTable - Values table - IB parameters description table.
// ConstantName - String - constant name to be added
// to the IB parameters.
//
// Returns: 
// Value table row.
// String that stores description of the added parameter. 
// 
Function AddConstantToInfobaseParameterTable(Val ParameterTable, Val ConstantName) Export
	
	MetadataConstants = Metadata.Constants[ConstantName];
	
	CurParameterString = ParameterTable.Add();
	CurParameterString.Name = MetadataConstants.Name;
	CurParameterString.Description = MetadataConstants.Presentation();
	CurParameterString.Type = MetadataConstants.Type;
	
	Return CurParameterString;
	
EndFunction

// Returns an IB parameter table.
//
// Returns: 
// Values table.
// Table that describes IB parameters.
// Columns:
// Name - String - parameter name.
// Description - String - parameter description to show in the user interface.
// ReadProhibition - Boolean - shows that the IB parameter can not be read. Can
//                         be set, for example, for passwords.
// WriteProhibition - Boolean - Shows that the IB parameter can not be changed.
// Type - Type description - parameter value type. It is allowed
//                         to use only primitive types and enumerations that are present in the controlling application.
// 
Function GetInfobaseParameterTable() Export
	
	ParameterTable = GetEmptyInfobaseParameterTable();
	
	WhenCompletingTablesOfParametersOfIB(ParameterTable);
	
	SaaSOverridable.GetInfobaseParameterTable(ParameterTable);
	
	Return ParameterTable;
	
EndFunction

// Gets an application name as it was specified by Caller.
//
// Returns - String - application name.
//
Function GetApplicationName() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaPresentation.Get();
	
EndFunction

// Returns block sizes in Mb to send large files by parts.
//
Function GetFileTransferBlockSize() Export
	
	SetPrivilegedMode(True);
	
	FileTransferBlockSize = Constants.FileTransferBlockSize.Get(); // MB
	If Not ValueIsFilled(FileTransferBlockSize) Then
		FileTransferBlockSize = 20;
	EndIf;
	Return FileTransferBlockSize;

EndFunction

// Serializes an object of the structure type.
//
// Parameters:
// StructuralTypeValue - Array, Structure, Correspondence or their fixed analogs.
//
// Returns:
// String - Serialized value of the structure type object.
//
Function WriteStructuralXDTOObjectToString(Val StructuralTypeValue) Export
	
	XDTODataObject = StructuralObjectToXDTOObject(StructuralTypeValue);
	
	Return WriteValueToString(XDTODataObject);
	
EndFunction

// Encodes a string value by algorithm base64.
//
// Parameters:
// String - String.
//
// Returns:
// String - base64-presentation.
//
Function StringToBase64(Val String) Export
	
	Storage = New ValueStorage(String, New Deflation(9));
	
	Return XMLString(Storage);
	
EndFunction

// Decodes base64 presentation of the string to the initial value.
//
// Parameters:
// StringBase64 - String.
//
// Returns:
// Row.
//
Function Base64ToString(Val StringBase64) Export
	
	Storage = XMLValue(Type("ValueStorage"), StringBase64);
	
	Return Storage.Get();
	
EndFunction

// Returns a time zone of the data area.
// Intended to be called from
// sessions with unset separators. You should use GetInfobaseTimeZone()
// in the sessions with the set parents usage.
//
// Parameters:
//  DataArea - Number - separator value of the
//   data area which time zone is to be received.
//
// Returns:
//  String, Undefined - time zone of the
//   data area, Undefined if a time zone is not set.
//
Function GetDataAreaTimeZone(Val DataArea) Export
	
	Manager = Constants.DataAreaTimeZone.CreateValueManager();
	Manager.DataAreaAuxiliaryData = DataArea;
	Manager.Read();
	TimeZone = Manager.Value;
	
	If Not ValueIsFilled(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	Return TimeZone;
	
EndFunction

// Returns an internal address of the service manager.
//
// Returns:
//  String - internal address of the service manager.
//
Function InternalServiceManagerURL() Export
	
	Return Constants.InternalServiceManagerURL.Get();
	
EndFunction

// Returns a service username of the service manager.
//
// Returns:
//  String - service user name of the service manager.
//
Function ServiceManagerOfficeUserName() Export
	
	Return Constants.ServiceManagerOfficeUserName.Get();
	
EndFunction

// Returns the password of the service manager service user.
//
// Returns:
//  String - password of the service manager service user.
//
Function ServiceManagerOfficeUserPassword() Export
	
	Return Constants.ServiceManagerOfficeUserPassword.Get();
	
EndFunction

// Processes the error details received from the web service.
// If not empty error info is passed, writes the
// detailed error presentation to the events log monitor
// and throws an exception with the brief error presentation text.
//
Procedure ProcessInformationAboutWebServiceError(Val ErrorInfo, Val SubsystemName = "", Val WebServiceName = "", Val OperationName = "") Export
	
	If ErrorInfo = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(SubsystemName) Then
		SubsystemName = Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Name;
	EndIf;
	
	EventName = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1.Web service operation call error'", CommonUseClientServer.MainLanguageCode()),
		SubsystemName);
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'An error occurred when calling operation %1 of web service %2: %3'", CommonUseClientServer.MainLanguageCode()),
		OperationName,
		WebServiceName,
		ErrorInfo.DetailErrorDescription);
	
	WriteLogEvent(
		EventName,
		EventLogLevel.Error,
		,
		,
		ErrorText);
		
	Raise ErrorInfo.BriefErrorDescription;
	
EndProcedure

// Returns a user alias to be used in the interface.
//
// Parameters:
//  UserID - UUID
//
// Return value: String, infobase user
//  alias for display in the interface.
//
Function InfobaseUserAlias(Val UserID) Export
	
	Alias = "";
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS\OnDefinineUserAlias");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefinineUserAlias(UserID, Alias);
	EndDo;
	
	Return Alias;
	
EndFunction

#Region FileOperations

// Returns a full attachment file name received from the MS file storage by its identifier.
//
// Parameters:
// FileID - UUID - File identifier in MS file storage.
//
// Returns:
// String - The full name of the extracted file.
//
Function GetFileFromServiceManagerStorage(Val FileID) Export
	
	ServiceManagerAddress = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en = 'Parameters of connection with the service manager are not set.'"));
	EndIf;
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", ServiceManagerAddress);
	StorageAccessParameters.Insert("UserName", Constants.ServiceManagerOfficeUserName.Get());
	StorageAccessParameters.Insert("Password", Constants.ServiceManagerOfficeUserPassword.Get());
	
	FileDescription = GetFileFromStorage(FileID, StorageAccessParameters, True, True);
	If FileDescription = Undefined Then
		Return Undefined;
	EndIf;
	
	FileProperties = New File(FileDescription.DescriptionFull);
	If Not FileProperties.Exist() Then
		Return Undefined;
	EndIf;
	
	Return FileProperties.DescriptionFull;
	
EndFunction

// Adds a file to the service manager storage.
//		
// Parameters:
// AddressDataFile - String/BinaryData/File - Temporary storage address/File data/File.
// FileName - String - Stored attachment file name. 
//		
// Returns:
// UUID - File identifier in the storage.
//
Function PlaceFileIntoServiceManagerStorage(Val AddressDataFile, Val FileName = "") Export
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", Constants.InternalServiceManagerURL.Get());
	StorageAccessParameters.Insert("UserName", Constants.ServiceManagerOfficeUserName.Get());
	StorageAccessParameters.Insert("Password", Constants.ServiceManagerOfficeUserPassword.Get());
	
	Return PutFileToStorage(AddressDataFile, StorageAccessParameters, FileName);

EndFunction

#EndRegion

#EndRegion

#Region ServiceProgramInterface

// Checks possibility to use the configuration in the service model.
//  When it is not possible to use - an exception is issued
//  with indication of the reason why it is not possible to use the configuration in the service model.
//
Procedure CheckPossibilityToUseConfigurationSaaS() Export
	
	SubsystemDescriptions = StandardSubsystemsReUse.SubsystemDescriptions().ByNames;
	STLDescription = SubsystemDescriptions.Get("LibraryServiceTechnology");
	
	If STLDescription = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '1C:Service technology library is not implemented in the configuration.
			     |The configuration can not be used in the service model without this library implementation.
			     |
			     |To use this configuration in the service model, it
			     |is required to embed the 1C:Library of service technology library of the version not less than %1.'", Metadata.DefaultLanguage.LanguageCode),
			RequiredSTLVersion());
		
	Else
		
		STLVersion = STLDescription.Version;
		
		If CommonUseClientServer.CompareVersions(STLVersion, RequiredSTLVersion()) < 0 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'To use configuration in the service model with the current
				     |SSL version, it is required to update used version of the 1C:Library of service technology library.
				     |
				     |Version in use: %1, a version not older than %2 is required!'", Metadata.DefaultLanguage.LanguageCode),
				STLVersion, RequiredSTLVersion());
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Calls an exception from the service technology library if the required subsystem does not exist.
//
// Parameters:
//  SubsystemName - String.
//
Procedure CallExceptionNotAvailableSTLSubsystem(Val SubsystemName) Export
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Cannot perform the operation as subsystem ""%1"" is not implemented in the configuration.
		     |This subsystem is input to the library of service technology content that should be embedded separately to the configuration content.
		     |Check whether subsystem ""%1"" exists and is correctly implemented.'"),
		SubsystemName
	);
	
EndProcedure

// Declares events of the SaaS subsystem.:
//
// Server events:
//   OnDeleteDataArea,
//   OnReceiveIBParametersTable,
//   OnSetIBParameterValues,
//   OnFillingIBParametersTable,
//   OnDefaultRightsSet,
//   AfterDataImportFromAnotherModel.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Called when deleting a data area.
	// IN the procedure you should delete data field
	// data that can not be deleted with the standard mechanism.
	//
	// Parameters:
	// DataArea - Separator value type - value
	// of a separator of the data area being deleted.
	//
	// Syntax:
	// Procedure OnDeleteDataArea(Value DataArea) Export
	//
	// (Same as SaaSOverridable.OnDeleteDataArea).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\OnDeleteDataArea");
	
	// Generates a list of IB parameters.
	//
	// Parameters:
	// ParameterTable - ValueTable - parameters description table.
	// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
	//
	// Syntax:
	// Procedure OnReceiveIBParametersTable(Value ParametersTable) Export
	//
	// (Same as SaaSOverridable.GetInfobaseParameterTable).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\OnReceivingParametersTableIB:");
	
	// Called before attempting to write IB parameter values
	// to the constants with the same name.
	//
	// Parameters:
	// ParameterValues - Structure - values of parameters to be set.
	// If the parameter value is set to this procedure, it
	// is required to delete the corresponding pair KeyAndValue from the structure.
	//
	// Syntax:
	// Procedure OnSetIBParametersValues(Value ParametersValues) Export
	//
	// (same as SaaSOverridable.OnSetInfobaseParameterValues).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\OnSetInfobaseParameterValues");
	
	// Generates a list of IB parameters.
	//
	// Parameters:
	// ParameterTable - ValueTable - parameters description table.
	// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
	//
	// Syntax:
	// Procedure OnFillIBParametersTable(Value ParametersTable) Export
	//
	// For use in other libraries.
	//
	// (Same as SaaSOverridable.GetInfobaseParameterTable).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB");
	
	// Assigns default rights to a user.
	// Called during the work in service model if there
	// is an update of users rights without administration rights in the service manager.
	//
	// Parameters:
	//  User - CatalogRef.Users - user
	//   to set default rights to.
	//
	// Syntax:
	// Procedure OnSetDefaultRights(User) Export
	//
	// (Same as SaaSOverridable.SetDefaultRights).
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\OnDefaultRightSet");
	
	// Called while defining a user's username to display in the interface.
	//
	// Parameters:
	//  UserID - UUID,
	//  Alias - String, username.
	//
	// Syntax:
	// Procedure OnDefineUserAlias (UserIdentifier, Alias) Export
	//
	ServerEvents.Add(
		"StandardSubsystems.SaaS\OnDefinineUserAlias");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
				"SaaSOperations");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"SaaSOperations");
	
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
				"SaaSOperations");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
			"SaaSOperations");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
			"SaaSOperations");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"SaaSOperations");
	EndIf;
	
EndProcedure

#Region HandlersOfTheConditionalCallsIntoThisSubsystem

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("SaaSOperations.PrepareDataAreaToUse");
	
	AccordanceNamespaceAliases.Insert("SaaSOperations.ClearDataArea");
	
EndProcedure

// Generates scheduled
// jobs table with the flag of usage in the service model.
//
// Parameters:
// UsageTable - ValueTable - table that should be filled in with the scheduled jobs a flag of usage, columns:
//  ScheduledJob - String - name of the predefined scheduled job.
//  Use - Boolean - True if scheduled job
//   should be executed in the service model. False - if it should not.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataAreasMaintenance";
	NewRow.Use       = True;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Checks a safe mode of data separation.

// Checks a safe mode of data separation.
// Only for call from the session module.
//
Procedure OnCheckingSafeModeDataSharing() Export
	
	If SafeMode() = False
		AND CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData()
		AND Not CommonUseReUse.SessionWithoutSeparator() Then
		
		SeparationSwitched = Undefined;
		Try
			SessionParameters.DataAreasUse = False; // Special case, standard function can not be used.
			SeparationSwitched = True;
		Except
			// Access rights violation is expected in the correctly published IB.
			SeparationSwitched = False;
		EndTry;
		
		If SeparationSwitched Then
			// Safe mode of data separation is not set.
			WriteLogEvent(NStr("en = 'Publication error'", CommonUseClientServer.MainLanguageCode()), 
				EventLogLevel.Error,
				,
				,
				NStr("en = 'Safe mode for data separation is not enabled on publishing'"));
			Raise(NStr("en = 'Infobase is published incorrectly. The session will be closed.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Checks whether the data area is locked on launch.

// Checks whether the data area is locked on launch.
// Only for call from StandardSubsystemsServer.AddClientWorkParametersOnStart().
//
Procedure WhenCheckingLockDataAreasOnRun(ErrorDescription) Export
	
	If CommonUseReUse.DataSeparationEnabled()
			AND CommonUseReUse.CanUseSeparatedData()
			AND DataAreaBlocked(CommonUse.SessionSeparatorValue()) Then
		
		ErrorDescription =
			NStr("en = 'The application launch is temporarily unavailable.
			     |Scheduled operations of the application maintenance are in progress.
			     |
			     |Try to start the appliation in several minutes.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ControlOfTheUnseparatedData

// Handler of subscription to event ControlUnseparatedObjectsOnWrite.
//
Procedure UndividedObjectsControlOnWrite(Source, Cancel) Export
	
	ControlDataOnWriteBrain(Source);
	
EndProcedure

// Handler of subscription to event ControlUnseparatedRecordSetsOnWrite.
//
Procedure UndividedRecordSetsControlOnWrite(Source, Cancel, Replacing) Export
	
	ControlDataOnWriteBrain(Source);
	
EndProcedure

#EndRegion

#Region ProcessingAuxiliaryAreaData

// Records value of a reference type
// separated by the AuxiliaryDataSeparator separator with switching of the session separator to the record time.
//
// Parameters:
//  ObjectSupportData - value of a reference type or ObjectDeletion.
//
Procedure AuxilaryDataWrite(ObjectSupportData) Export
	
	ProcessingAuxiliaryData(
		ObjectSupportData,
		True,
		False);
	
EndProcedure

// Deletes value of a reference type separated
// by the AuxiliaryDataSeparator separator with switching of the session separator to the record time.
//
// Parameters:
//  ObjectSupportData - value of a reference type.
//
Procedure DeleteAuxiliaryData(ObjectSupportData) Export
	
	ProcessingAuxiliaryData(
		ObjectSupportData,
		False,
		True);
	
EndProcedure

// Creates the Key records for register information vKeyennogo in the content separator DataAreaAuxiliaryData.
//
// Parameters:
//  Manager - InformationRegisterManager, information register
//    manager for which
//  it is required to receive the record key, KeyValue - Structure that contains values to fill out the record key properties.
//    Structure item names must correspond to key field names,
//
// Return value: InformationRegisterRecordKey.
//
Function CreateAuxiliaryDataRecordKeyOfInformationRegister(Val Manager, Val KeyValues) Export
	
	KeyVar = Manager.CreateRecordKey(KeyValues);
	
	DataArea = Undefined;
	Delimiter = SupportDataSplitter();
	
	If KeyValues.Property(Delimiter, DataArea) Then
		
		If KeyVar[Delimiter] <> DataArea Then
			
			Object = XDTOSerializer.WriteXDTO(KeyVar);
			Object[Delimiter] = DataArea;
			KeyVar = XDTOSerializer.ReadXDTO(Object);
			
		EndIf;
		
	EndIf;
	
	Return KeyVar;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions determine metadata object types by
// their full names.

// Referential data types

// Determines whether a metadata object belongs to the "Document" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullDocumentName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Document", "Document");
	
EndFunction

// Determines whether a metadata object belongs to the "Catalog" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsCatalogFullName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Catalog", "Catalog");
	
EndFunction

// Determines whether a metadata object belongs to the "Enumeration" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsEnumerationFullName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Enum", "Enum");
	
EndFunction

// Determines whether a metadata object belongs to the "Exchange plan" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullExchangePlanName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "ExchangePlan", "ExchangePlan");
	
EndFunction

// Defines if a metadata object belongs to the Characteristic kinds
//  chart general type by the metadata object full name.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsTheFullChartOfCharacteristicTypesOfName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "ChartOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	
EndFunction

// Determines whether a metadata object belongs to the "Business process"
//  general type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullNameBusinessProcess(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "BusinessProcess", "BusinessProcess");
	
EndFunction

// Determines whether a metadata object belongs to the "Task" general type
//  by a full name of the metadata object.
// 
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
// 
// Returns:
//  Boolean.
//
Function ThisIsFullNameOfTask(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Task", "Task");
	
EndFunction

// Determines whether a metadata object belongs to the "Accounts plan" general type
//  by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullChartOfAccountsName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "ChartOfAccounts", "ChartOfAccounts");
	
EndFunction

// Defines if a metadata object belongs to the "Calculation kinds chart" general
//  type by the metadata object full name.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsTheFullChartOfCalculationTypesName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "ChartOfCalculationTypes", "ChartOfCalculationTypes");
	
EndFunction

// Registers

// Determines whether a metadata object belongs to the "Information register" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullNameOfRegisterInformation(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "InformationRegister", "InformationRegister");
	
EndFunction

// Defines if a metadata object belongs to the "Accumulation register" general
//  type by the metadata object full name.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function ThisIsFullNameOfRegisterAccumulation(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "AccumulationRegister", "AccumulationRegister");
	
EndFunction

// Defines if a metadata object belongs to the "Accounting register" general
//  type by the metadata object full name.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function ThisIsFullAccountingRegisterName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "AccountingRegister", "AccountingRegister");
	
EndFunction

// Determines whether a metadata object belongs to the "Calculation register" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function ThisIsFullNameOfCalculationRegister(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "CalculationRegister", "CalculationRegister")
		AND Not IsAFullRecalculationOfName(DescriptionFull);
	
EndFunction

// Recalculations

// Determines whether a metadata object belongs to the "Recalculation"
//  general type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsAFullRecalculationOfName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Recalculation", "Recalculation", 2);
	
EndFunction

// Constants

// Determines whether a metadata object belongs to the "Constant" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullOfConstantName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Constant", "Constant");
	
EndFunction

// Document journals

// Defines if a metadata object belongs to the "Documents log" general
//  type by the metadata object full name.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullDocumentJournalName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "DocumentJournal", "DocumentJournal");
	
EndFunction

// Sequences

// Determines whether a metadata object belongs to the "Sequences" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullSequenceName(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "Sequence", "Sequence");
	
EndFunction

// ScheduledJobs

// Determines whether a metadata object belongs to the "Scheduled jobs" general
//  type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullNameForJobSchedule(Val DescriptionFull) Export
	
	Return ObjectTypeMetadataForCheckupDescriptionFull(DescriptionFull, "ScheduledJob", "ScheduledJob");
	
EndFunction

// Common

// Determines whether a metadata object belongs to the register type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function ThisIsFullNameOfRegister(Val DescriptionFull) Export
	
	Return IsFullNameOfRegisterInformation(DescriptionFull)
		OR ThisIsFullNameOfRegisterAccumulation(DescriptionFull)
		OR ThisIsFullAccountingRegisterName(DescriptionFull)
		OR ThisIsFullNameOfCalculationRegister(DescriptionFull)
	;
	
EndFunction

// Determines whether a metadata object belongs to the reference type by a full name of the metadata object.
//
// Parameters:
//  DescriptionFull - String - Full name of the metadata object for
//   which it is required to determine belonging to a specified type.
//
// Returns:
//  Boolean.
//
Function IsFullObjectNameOfReferenceType(Val DescriptionFull) Export
	
	Return IsCatalogFullName(DescriptionFull)
		OR IsFullDocumentName(DescriptionFull)
		OR IsFullNameBusinessProcess(DescriptionFull)
		OR ThisIsFullNameOfTask(DescriptionFull)
		OR IsFullChartOfAccountsName(DescriptionFull)
		OR IsFullExchangePlanName(DescriptionFull)
		OR IsTheFullChartOfCharacteristicTypesOfName(DescriptionFull)
		OR IsTheFullChartOfCalculationTypesName(DescriptionFull)
	;
	
EndFunction

// For an internal use.
//
Function ParametersSelections(Val FullMetadataObjectName) Export
	
	Result = New Structure("Table,FieldNameRecorder");
	
	If ThisIsFullNameOfRegister(FullMetadataObjectName)
			OR IsFullSequenceName(FullMetadataObjectName) Then
		
		Result.Table = FullMetadataObjectName;
		Result.FieldNameRecorder = "Recorder";
		
	ElsIf IsAFullRecalculationOfName(FullMetadataObjectName) Then
		
		Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullMetadataObjectName, ".");
		Result.Table = Substrings[0] + "." + Substrings[1] + "." + Substrings[3];
		Result.FieldNameRecorder = "RecalculationObject";
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ParametersSelections() function should not be used for object %1.'"),
			FullMetadataObjectName);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns a full path to the temporary file directory.
//
// Returns:
// String - Full path to the temporary file directory.
//
Function GetCommonTempFilesDir()
	
	SetPrivilegedMode(True);
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Linux_x86
		OR ServerPlatformType = PlatformType.Linux_x86_64 Then
		
		CommonTempDirectory = Constants.FilesExchangeDirectoryInLinuxSaaS.Get();
		PathSeparator = "/";
	Else
		CommonTempDirectory = Constants.FilesExchangeDirectorySaaS.Get();
		PathSeparator = "\";
	EndIf;
	
	If IsBlankString(CommonTempDirectory) Then
		CommonTempDirectory = TrimAll(TempFilesDir());
	Else
		CommonTempDirectory = TrimAll(CommonTempDirectory);
	EndIf;
	
	If Right(CommonTempDirectory, 1) <> PathSeparator Then
		CommonTempDirectory = CommonTempDirectory + PathSeparator;
	EndIf;
	
	Return CommonTempDirectory;
	
EndFunction

#Region PreparingDataAreas

// Receives in transaction a record manager for register DataAreas.
//
// Parameters:
//  DataArea - data area number.
//  Status - Enums.DataAreasStatuses, expected area status.
//
// Returns:
//  InformationRegisters.DataAreas.RecordManager
//
Function GetRecordManagerOfDataAreas(Val DataArea, Val Status)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Item = Block.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		Block.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		
		If Not RecordManager.Selected() Then
			MessagePattern = NStr("en = 'Data area %1 is not found'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea);
			Raise(MessageText);
		ElsIf RecordManager.Status <> Status Then
			MessagePattern = NStr("en = 'Status of data area %1 is not ""%2""'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, DataArea, Status);
			Raise(MessageText);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Prepare data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Return RecordManager;
	
EndFunction
	
// Updates area status in the DataAreas register, sends message to the service manager.
//
// Parameters:
//  RecordManager - InformationRegisters.DataAreas.RecordManager
//  PreparationResult - String, One in "Success", "RequiredConversion", "FatalError",
//    "ErrorDelete", "AreaIsDeleted" 
//  ErrorInfo - String.
//
Procedure ChangeAreasStateAndNotifyManager(Val RecordManager, Val ResultOf, Val ErrorInfo)
	
	ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
	FillPropertyValues(ManagerCopy, RecordManager);
	RecordManager = ManagerCopy;

	IncludeMessageAboutError = False;
	If ResultOf = "Success" Then
		RecordManager.Status = Enums.DataAreaStatuses.Used;
		MessageType = MessageRemoteAdministratorControlInterface.MessageDataAreaPrepared();
	ElsIf ResultOf = "RequiredConversion" Then
		RecordManager.Status = Enums.DataAreaStatuses.LoadFromFile;
		MessageType = MessageRemoteAdministratorControlInterface.ErrorMessageInDataPreparationAreasRequiredConversion();
	ElsIf ResultOf = "AreaIsDeleted" Then
		RecordManager.Status = Enums.DataAreaStatuses.Deleted;
		MessageType = MessageRemoteAdministratorControlInterface.MessageDataAreaDeleted();
	ElsIf ResultOf = "FatalError" Then
		WriteLogEvent(NStr("en = 'Prepare data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , ErrorInfo);
		RecordManager.ProcessingError = True;
		MessageType = MessageRemoteAdministratorControlInterface.MessageErrorPreparingDataArea();
		IncludeMessageAboutError = True;
	ElsIf ResultOf = "ErrorDelete" Then
		RecordManager.ProcessingError = True;
		MessageType = MessageRemoteAdministratorControlInterface.MessageErrorDeletingDataArea();
		IncludeMessageAboutError = True;
	Else
		Raise NStr("en = 'Unexpected return code'");
	EndIf;
	
	// Send a message on the area readiness to the service manager.
	Message = MessagesSaaS.NewMessage(MessageType);
	Message.Body.Zone = RecordManager.DataAreaAuxiliaryData;
	If IncludeMessageAboutError Then
		Message.Body.ErrorDescription = ErrorInfo;
	EndIf;

	BeginTransaction();
	Try
		MessagesSaaS.SendMessage(
			Message,
			SaaSReUse.ServiceManagerEndPoint());
		
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Imports data to a "typical" area.
// 
// Parameters: 
//   DataArea - number of populated area.
//   ExportFileID - Initial data file ID.
//   Variant - initial data option.
//   ErrorInfo - String, returned, error description.
//
// Returns:
//  String - one of options "Success", "Fatal error".
//
Function PrepareDataAreaToUseOfStandard(Val DataArea, Val ExportFileID, 
												 		  Val Variant, ErrorInfo)
	
	If Constants.CopyDataAreasFromPrototype.Get() Then
		
		Result = ImportAreaOfSuppliedData(DataArea, ExportFileID, Variant, ErrorInfo);
		If Result <> "Success" Then
			Return Result;
		EndIf;
		
	Else
		
		Result = "Success";
		
	EndIf;
	
	UpdateResults.RunInfobaseUpdate();
	
	Return Result;
	
EndFunction
	
// Imports data to the area from user exports.
// 
// Parameters: 
//   DataArea - number of populated area.
//   ExportFileID - Initial data file ID.
//   ErrorInfo - String, returned, error description.
//
// Returns:
//  String - one of options "ConversionRequired", "Success" "FatalError".
//
Function PrepareDataFromExportingArea(Val DataArea, Val ExportFileID, ErrorInfo)
	
	ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
	
	If ExportFileName = Undefined Then
		
		ErrorInfo = NStr("en = 'No initial info file for the area'");
		
		Return "FatalError";
	EndIf;
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataAreasExportImport") Then
		
		CallExceptionNotAvailableSTLSubsystem("ServiceTechnology.SaaS.DataAreasExportImport");
		
	EndIf;
	
	ModuleDataAreasExportImport = CommonUse.CommonModule("DataAreasExportImport");
	
	If Not ModuleDataAreasExportImport.ExportArchiveIsCompatibleWithCurrentConfiguration(ExportFileName) Then
		Result = "RequiredConversion";
	Else
		
		ModuleDataAreasExportImport.ImportCurrentDataAreaFromArchive(ExportFileName);
		Result = "Success";
		
	EndIf;
	
	Try
		DeleteFiles(ExportFileName);
	Except
		WriteLogEvent(NStr("en = 'Prepare data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions determine metadata object types by
// their full names.

Function ObjectTypeMetadataForCheckupDescriptionFull(Val DescriptionFull, Val NationLocalization, Val EnglishLocalization, Val PositionSubstring = 0)
	
	Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DescriptionFull, ".");
	If Substrings.Count() > PositionSubstring Then
		TypeName = Substrings.Get(PositionSubstring);
		Return TypeName = NationLocalization OR TypeName = EnglishLocalization;
	Else
		Return False;
	EndIf;
	
EndFunction

#EndRegion

#Region EventHandlersOfTheSSLSubsystems

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	CheckPossibilityToUseConfigurationSaaS();
	
	SaaSOverridable.OnEnableSeparationByDataAreas();
	
EndProcedure

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// IN case the AvailableNewData sets the Import argument to true, the data is imported, the descriptor and path to the
// data file are passed to the procedure. ProcessNewData. File will be deleted automatically after completion of the procedure.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - the code of data kind processed by the handler.
//        HandlersCode, row(20) - it will be used during restoring data processing after the failure.
//        Handler,  CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle,
//          Import) Export ProcessNewData(Handle,
//          PathToFile) Export DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of UpdateResults common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
		
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "SaaSOperations.ControlDelimitersOnUpgrading";
	Handler.SharedData = True;
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 99;
	Handler.ExclusiveMode = False;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "SaaSOperations.CheckPossibilityToUseConfigurationSaaS";
		Handler.SharedData = True;
		Handler.ExecuteUnderMandatory = True;
		Handler.Priority = 99;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	AddClientParametersSaaS(Parameters);
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientParametersSaaS(Parameters);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.DataAreaKey);
	Types.Add(Metadata.InformationRegisters.DataAreas);
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      Author presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Cannot import to the currency classifier.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.JobQueueDataAreas.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

#EndRegion

#Region CallsToOtherSubsystems

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUseReUse.IsSeparatedConfiguration() Then
		AddConstantToInfobaseParameterTable(ParameterTable, "UseSeparationByDataAreas");
		
		AddConstantToInfobaseParameterTable(ParameterTable, "InfobaseUsageMode");
		
		AddConstantToInfobaseParameterTable(ParameterTable, "CopyDataAreasFromPrototype");
	EndIf;
	
	AddConstantToInfobaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	
	AddConstantToInfobaseParameterTable(ParameterTable, "ServiceManagerOfficeUserName");
	
	CurParameterString = AddConstantToInfobaseParameterTable(ParameterTable, "ServiceManagerOfficeUserPassword");
	CurParameterString.ReadProhibition = True;
	
	// For backward compatibility.
	CurParameterString = AddConstantToInfobaseParameterTable(ParameterTable, "InternalServiceManagerURL");
	CurParameterString.Name = "ServiceURL";
	
	CurParameterString = AddConstantToInfobaseParameterTable(ParameterTable, "ServiceManagerOfficeUserName");
	CurParameterString.Name = "AuxiliaryServiceUserName";
	
	CurParameterString = AddConstantToInfobaseParameterTable(ParameterTable, "ServiceManagerOfficeUserPassword");
	CurParameterString.Name = "AuxiliaryServiceUserPassword";
	CurParameterString.ReadProhibition = True;
	// End For backward compatibility.
	
	CurParameterString = ParameterTable.Add();
	CurParameterString.Name = "ConfigurationVersion";
	CurParameterString.Description = NStr("en = 'Configuration version'");
	CurParameterString.WriteProhibition = True;
	CurParameterString.Type = New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable));
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB");
	
	For Each Handler In EventHandlers Do
		Handler.Module.WhenCompletingTablesOfParametersOfIB(ParameterTable);
	EndDo;
	
EndProcedure

#EndRegion

#Region WorkWithIBParameters

// Returns an empty table of IB parameters.
//
Function GetEmptyInfobaseParameterTable()
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Description", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("ReadProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("WriteProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Return Result;
	
EndFunction

#EndRegion

#Region FileOperations

// Gets a attachment description by its identifier in the Files register.
// If storage on the disk and PathNotData =
// True, in the output structure Data = Undefined, DescriptionFull = File
// full name, otherwise, Data - binary file data, FullName - Undefined.
// Name key value always contains a name in the storage.
//		
// Parameters:
// FileID - UUID
// ConnectionParameters - Structure:
// 						- URL - String - Service URL. It has to exist and to be filled in
// 						- UserName - String - Service username.
// 						- Password - String - Service user password.
// PathNotData - Boolean - What to return. 
// CheckFileExistence - Boolean - Whether to check the file existence if an error occurs on receiving it.
//		
// Returns:
// FileDescription - Structure:
// Name - String - attachment file name in storage.
// Data - BinaryData - file data.
// DescriptionFull - String - full attachment file name.
// 		  - The file will be deleted automatically once the retention period of temporary files expires.
//
Function GetFileFromStorage(Val FileID, Val ConnectionParameters, 
	Val PathNotData = False, Val CheckFileExistence = False) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDescription = FileTransferServiceProxyDescription(ConnectionParameters);
	
	ExchangeOverFS = CanPassViaFSFromServer(ProxyDescription.Proxy, ProxyDescription.HasVersion2Support);
	
	If ExchangeOverFS Then
			
		Try
			Try
				FileName = ProxyDescription.Proxy.WriteFileToFS(FileID);
			Except
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				If CheckFileExistence AND Not ProxyDescription.Proxy.FileExists(FileID) Then
					Return Undefined;
				EndIf;
				Raise ErrorDescription;
			EndTry;
			
			FileProperties = New File(GetCommonTempFilesDir() + FileName);
			If FileProperties.Exist() Then
				FileDescription = CreateFileDescription();
				FileDescription.Name = FileProperties.Name;
				
				SizeReceivedFile = FileProperties.Size();
				
				If PathNotData Then
					FileDescription.Data = Undefined;
					FileDescription.DescriptionFull = FileProperties.DescriptionFull;
				Else
					FileDescription.Data = New BinaryData(FileProperties.DescriptionFull);
					FileDescription.DescriptionFull = Undefined;
					Try
						DeleteFiles(FileProperties.DescriptionFull);
					Except
					EndTry;
				EndIf;
				
				WriteInJournalFileStoreEvent(
					NStr("en = 'Extract'", CommonUseClientServer.MainLanguageCode()),
					FileID,
					SizeReceivedFile,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				
				Return FileDescription;
			Else
				ExchangeOverFS = False;
			EndIf;
		Except
			WriteLogEvent(NStr("en = 'Receive file from the storage'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
			
	EndIf; // ExchangeOverFS
	
	PartCount = Undefined;
	FileNameInCatalog = Undefined;
	FileTransferBlockSize = GetFileTransferBlockSize();
	Try
		If ProxyDescription.HasVersion2Support Then
			TransferID = ProxyDescription.Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, PartCount);
		Else
			TransferID = Undefined;
			ProxyDescription.Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, TransferID, PartCount);
		EndIf;
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		If CheckFileExistence AND Not ProxyDescription.Proxy.FileExists(FileID) Then
			Return Undefined;
		EndIf;
		Raise ErrorDescription;
	EndTry;
	
	FileNames = New Array;
	
	AssemblyDirectory = CreateAssemblyDirectory();
	
	If ProxyDescription.HasVersion2Support Then
		For PartNumber = 1 To PartCount Do
			PartData = ProxyDescription.Proxy.GetFilePart(TransferID, PartNumber, PartCount);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	Else // 1st version.
		For PartNumber = 1 To PartCount Do
			PartData = Undefined;
			ProxyDescription.Proxy.GetFilePart(TransferID, PartNumber, PartData);
			FileNamePart = AssemblyDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	EndIf;
	PartData = Undefined;
	
	ProxyDescription.Proxy.ReleaseFile(TransferID);
	
	ArchiveName = GetTempFileName("zip");
	
	MergeFiles(FileNames, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	If Dearchiver.Items.Count() > 1 Then
		Raise(NStr("en = 'The received archive contains more than one file'"));
	EndIf;
	
	FileName = AssemblyDirectory + Dearchiver.Items[0].Name;
	Dearchiver.Extract(Dearchiver.Items[0], AssemblyDirectory);
	Dearchiver.Close();
	
	ResultFile = New File(GetTempFileName());
	MoveFile(FileName, ResultFile.DescriptionFull);
	SizeReceivedFile = ResultFile.Size();
	
	FileDescription = CreateFileDescription();
	FileDescription.Name = ResultFile.Name;
	
	If PathNotData Then
		FileDescription.Data = Undefined;
		FileDescription.DescriptionFull = ResultFile.DescriptionFull;
	Else
		FileDescription.Data = New BinaryData(ResultFile.DescriptionFull);
		FileDescription.DescriptionFull = Undefined;
		Try
			DeleteFiles(ResultFile.DescriptionFull);
		Except
		EndTry;
	EndIf;
	
	Try
		DeleteFiles(ArchiveName);
		DeleteFiles(AssemblyDirectory);
	Except
	EndTry;
	
	WriteInJournalFileStoreEvent(
		NStr("en = 'Extract'", CommonUseClientServer.MainLanguageCode()),
		FileID,
		SizeReceivedFile,
		CurrentUniversalDate() - ExecutionStarted,
		ExchangeOverFS);
	
	Return FileDescription;
	
EndFunction

// Adds a file to the service manager storage.
//		
// Parameters:
// AddressDataFile - String/BinaryData/File - Temporary storage address/File data/File.
// ConnectionParameters - Structure:
// 						- URL - String - Service URL. It has to exist and to be filled in
// 						- UserName - String - Service username.
// 						- Password - String - Service user password.
// FileName - String - Stored attachment file name. 
//		
// Returns:
// UUID - File identifier in the storage.
//
Function PutFileToStorage(Val AddressDataFile, Val ConnectionParameters, Val FileName = "")
	
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDescription = FileTransferServiceProxyDescription(ConnectionParameters);
	
	Description = GetFileNameWithData(AddressDataFile, FileName);
	FileProperties = New File(Description.Name);
	
	ExchangeOverFS = CanTransferThroughFSToServer(ProxyDescription.Proxy, ProxyDescription.HasVersion2Support);
	If ExchangeOverFS Then
		
		// Save data into file.
		CommonDirectory = GetCommonTempFilesDir();
		TargetFile = New File(CommonDirectory + FileProperties.Name);
		If TargetFile.Exist() Then
			// This is the same file. It can be read directly on the server without passing.
			If FileProperties.DescriptionFull = TargetFile.DescriptionFull Then
				Result = ProxyDescription.Proxy.ReadFileFromFS(TargetFile.Name, FileProperties.Name);
				SizeOfSourceFile = TargetFile.Size();
				WriteInJournalFileStoreEvent(
					NStr("en = 'UOM'", CommonUseClientServer.MainLanguageCode()),
					Result,
					SizeOfSourceFile,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				Return Result;
				// Cannot delete it as it is a source.
			EndIf;
			// Source and receiver - different files. Not to remove someone else's file, give a unique name to the receiver.
			NewID = New UUID;
			TargetFile = New File(CommonDirectory + NewID + FileProperties.Extension);
		EndIf;
		
		Try
			If Description.Data = Undefined Then
				FileCopy(FileProperties.DescriptionFull, TargetFile.DescriptionFull);
			Else
				Description.Data.Write(TargetFile.DescriptionFull);
			EndIf;
			Result = ProxyDescription.Proxy.ReadFileFromFS(TargetFile.Name, FileProperties.Name);
			SizeOfSourceFile = TargetFile.Size();
			WriteInJournalFileStoreEvent(
				NStr("en = 'UOM'", CommonUseClientServer.MainLanguageCode()),
				Result,
				SizeOfSourceFile,
				CurrentUniversalDate() - ExecutionStarted,
				ExchangeOverFS);
		Except
			WriteLogEvent(NStr("en = 'Add file.Exchange via FS'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
		
		DeleteTemporaryFiles(TargetFile.DescriptionFull);
		
	EndIf; // ExchangeOverFS
		
	If Not ExchangeOverFS Then
		
		FileTransferBlockSize = GetFileTransferBlockSize(); // MB
		TransferID = New UUID;
		
		// Save data into file.
		AssemblyDirectory = CreateAssemblyDirectory();
		FullFileName = AssemblyDirectory + FileProperties.Name;
		
		If Description.Data = Undefined Then
			If FileProperties.Exist() Then
				FileCopy(FileProperties.DescriptionFull, FullFileName);
			Else
				Raise(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Add file to the storage. File %1 not found.'"), FileProperties.DescriptionFull));
			EndIf;
		Else
			Description.Data.Write(FullFileName);
		EndIf;
		
		TargetFile = New File(FullFileName);
		SizeOfSourceFile = TargetFile.Size();
		
		// Archive file.
		SharedFileName = GetTempFileName("zip");
		Archiver = New ZipFileWriter(SharedFileName, , , , ZIPCompressionLevel.Minimum);
		Archiver.Add(FullFileName);
		Archiver.Write();
		
		// Divide a file into parts.
		// MB => bytes.
		FileNames = SplitFile(SharedFileName, FileTransferBlockSize * 1024 * 1024, AssemblyDirectory);
		
		Try
			DeleteFiles(SharedFileName);
		Except
		EndTry;
		
		// Send a file using the service by parts.
		PartCount = FileNames.Count();
		If ProxyDescription.HasVersion2Support Then
			For PartNumber = 1 To PartCount Do	// Pass by parts.	
				FileNamePart = FileNames[PartNumber - 1];		
				FileData = New BinaryData(FileNamePart);		
				Try
					DeleteFiles(FileNamePart);
				Except
				EndTry;
				ProxyDescription.Proxy.PutFilePart(TransferID, PartNumber, FileData, PartCount);
			EndDo;
		Else // 1st version.
			For PartNumber = 1 To PartCount Do	// Pass by parts.	
				FileNamePart = FileNames[PartNumber - 1];		
				FileData = New BinaryData(FileNamePart);		
				Try
					DeleteFiles(FileNamePart);
				Except
				EndTry;
				ProxyDescription.Proxy.PutFilePart(TransferID, PartNumber, FileData);
			EndDo;
		EndIf;
		
		Try
			DeleteFiles(AssemblyDirectory);
		Except
		EndTry;
		
		If ProxyDescription.HasVersion2Support Then
			Result = ProxyDescription.Proxy.SaveFileFromParts(TransferID, PartCount); 
		Else // 1st version.
			Result = Undefined;
			ProxyDescription.Proxy.SaveFileFromParts(TransferID, PartCount, Result); 
		EndIf;
		
		WriteInJournalFileStoreEvent(
			NStr("en = 'UOM'", CommonUseClientServer.MainLanguageCode()),
			Result,
			SizeOfSourceFile,
			CurrentUniversalDate() - ExecutionStarted,
			ExchangeOverFS);
		
	EndIf; // Not ExchangeViaFS
	
	Return Result;
	
EndFunction

// Returns the structure with the name and data of the file by the
// address in the temporary storage/information in object File/binary data.
//		
// Parameters:
// AddressDataFile - String/BinaryData/File - File data storage address/File data/File.
// FileName - String.
//		
// Returns:
// Structure:
//   Data - BinaryData - File data.
//   Name - String - File name.
//
Function GetFileNameWithData(Val AddressDataFile, Val FileName = "")
	
	If TypeOf(AddressDataFile) = Type("String") Then // File data address in a temporary storage.
		If IsBlankString(AddressDataFile) Then
			Raise(NStr("en = 'Invalid storage address.'"));
		EndIf;
		FileData = GetFromTempStorage(AddressDataFile);
	ElsIf TypeOf(AddressDataFile) = Type("File") Then // File type object.
		If Not AddressDataFile.Exist() Then
			Raise(NStr("en = 'File is not found.'"));
		EndIf;
		FileData = Undefined;
		FileName = AddressDataFile.DescriptionFull;
	ElsIf TypeOf(AddressDataFile) = Type("BinaryData") Then // File data.
		FileData = AddressDataFile;
	Else
		Raise(NStr("en = 'Invalid data type'"));
	EndIf;
	
	If IsBlankString(FileName) Then
		FileName = GetTempFileName();
	EndIf;
	
	Return New Structure("Data, Name", FileData, FileName);
	
EndFunction

// Checks whether it is possible to send a file using the file system from server to client.
//
// Parameters:
// Proxy - WSProxy - Proxy of service FilesTransfer*.
// HasVersion2Support - Boolean.
//
// Returns:
// Boolean.
//
Function CanPassViaFSFromServer(Val Proxy, Val HasVersion2Support)
	
	If Not HasVersion2Support Then
		Return False;
	EndIf;
	
	FileName = Proxy.WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = ReadTestFile(FileName);
	
	Proxy.DeleteTestFile(FileName);
	
	Return Result;
	
EndFunction

// Checks whether it is possible to send a file using the file system from client to server.
//
// Parameters:
// Proxy - WSProxy - Proxy of service FilesTransfer*.
// HasVersion2Support - Boolean.
//
// Returns:
// Boolean.
//
Function CanTransferThroughFSToServer(Val Proxy, Val HasVersion2Support)
	
	If Not HasVersion2Support Then
		Return False;
	EndIf;
	
	FileName = WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = Proxy.ReadTestFile(FileName);
	
	FullFileName = GetCommonTempFilesDir() + FileName;
	DeleteTemporaryFiles(FullFileName);
	
	Return Result;
	
EndFunction

// Create a directory with unique name to store parts of a separated file.
//
// Returns:
// String - Directory name.
//
Function CreateAssemblyDirectory()
	
	AssemblyDirectory = GetTempFileName();
	CreateDirectory(AssemblyDirectory);
	Return AssemblyDirectory + CommonUseClientServer.PathSeparator();
	
EndFunction

// Reads a test file from disk comparing the content and name: they should match.
// File should be deleted by a called string.
//
// Parameters:
// FileName - String - Without path.
//
// Returns:
// Boolean - True if the file is successfully read and its content corresponds to its name.
//
Function ReadTestFile(Val FileName)
	
	FileProperties = New File(GetCommonTempFilesDir() + FileName);
	If FileProperties.Exist() Then
		Text = New TextReader(FileProperties.DescriptionFull, TextEncoding.ANSI);
		TestID = Text.Read();
		Text.Close();
		Return TestID = FileProperties.BaseName;
	Else
		Return False;
	EndIf;
	
EndFunction

// Writes a test file to the disk returning its name and size.
// File should be deleted by a called string.
//
// Parameters:
// FileSize - Number.
//
// Returns:
// String - Trial attachment file name without a path.
//
Function WriteTestFile() Export
	
	NewID = New UUID;
	FileProperties = New File(GetCommonTempFilesDir() + NewID + ".tmp");
	
	Text = New TextWriter(FileProperties.DescriptionFull, TextEncoding.ANSI);
	Text.Write(NewID);
	Text.Close();
	
	Return FileProperties.Name;
	
EndFunction

// Creates an unfilled structure of the required format.
//
// Returns:
// Structure:
//   Name - String - File name in storage.
//   Data - BinaryData - File data.
// 	 DescriptionFull - String - File name with a path.
//
Function CreateFileDescription()
	
	FileDescription = New Structure;
	FileDescription.Insert("Name");
	FileDescription.Insert("Data");
	FileDescription.Insert("DescriptionFull");
	FileDescription.Insert("MandatoryParameters", "Name"); // Required parameters.
	Return FileDescription;
	
EndFunction

// Gets a WSProxy object of the web service specified by its base name.
//
// Parameters:
// ConnectionParameters - Structure:
// 						- URL - String - Service URL. It has to exist and to be filled in
// 						- UserName - String - Service username.
// 						- Password - String - Service user password.
// Returns:
//  Proxy
//   Structure - WSProxy
//   HasVersion2Support - Boolean
//
Function FileTransferServiceProxyDescription(Val ConnectionParameters)
	
	BaseServiceName = "FilesTransfer";
	
	SupportedVersionArray = CommonUse.GetInterfaceVersions(ConnectionParameters, "FileTransferServer");
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		HasVersion2Support = False;
		InterfaceVersion = "1.0.1.1"
	Else
		HasVersion2Support = True;
		InterfaceVersion = "1.0.2.1";
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		AND ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		UserPassword = ConnectionParameters.Password;
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	If InterfaceVersion = Undefined Or InterfaceVersion = "1.0.1.1" Then // 1st version.
		ServiceName = BaseServiceName;
	Else // Version 2 and higher.
		ServiceName = BaseServiceName + "_" + StrReplace(InterfaceVersion, ".", "_");
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + StringFunctionsClientServer.SubstituteParametersInString("/ws/%1?wsdl", ServiceName);
	
	Proxy = CommonUse.WSProxy(ServiceAddress, 
		"http://www.1c.ru/SaaS/1.0/WS", ServiceName, , UserName, UserPassword, 600);
		
	Return New Structure("Proxy, HasVersion2Support", Proxy, HasVersion2Support);
		
EndFunction

Procedure WriteInJournalFileStoreEvent(Val Event,
	Val FileID, Val Size, Val Duration, Val TransferThroughFileSystem)
	
	EventData = New Structure;
	EventData.Insert("FileID", FileID);
	EventData.Insert("Size", Size);
	EventData.Insert("Duration", Duration);
	
	If TransferThroughFileSystem Then
		EventData.Insert("Transport", "file");
	Else
		EventData.Insert("Transport", "ws");
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'File storage'", CommonUseClientServer.MainLanguageCode()) + "." + Event,
		EventLogLevel.Information,
		,
		,
		CommonUse.ValueToXMLString(EventData));
	
EndProcedure

#EndRegion

#Region TemporaryFiles

// Delete file(s) from disk.
// If a mask with a path is specified as a attachment file name, divide it into a path and a mask.
//
Procedure DeleteTemporaryFiles(Val FileName)
	
	Try
		If Right(FileName, 1) = "*" Then // Mask.
			IndexOf = StringFunctionsClientServer.FindCharFromEnd(
				FileName, CommonUseClientServer.PathSeparator());
			If IndexOf > 0 Then
				PathToFile = Left(FileName, IndexOf - 1);
				FileMask = Mid(FileName, IndexOf + 1);
				If FindFiles(PathToFile, FileMask, False).Count() > 0 Then
					DeleteFiles(PathToFile, FileMask);
				EndIf;
			EndIf;
		Else
			FileProperties = New File(FileName);
			If FileProperties.Exist() Then
				FileProperties.SetReadOnly(False); // Remove attribute.
				DeleteFiles(FileProperties.DescriptionFull);
			EndIf;
		EndIf;
	Except
		WriteLogEvent(NStr("en = 'Deleting temporary file'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

#EndRegion

#Region Serialization

Function WriteValueToString(Val Value)
	
	Record = New XMLWriter;
	Record.SetString();
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		XDTOFactory.WriteXML(Record, Value, , , , XMLTypeAssignment.Explicit);
	Else
		XDTOSerializer.WriteXML(Record, Value, XMLTypeAssignment.Explicit);
	EndIf;
	
	Return Record.Close();
		
EndFunction

// Shows whether the type is serialized.
//
// Parameters:
// StructuralType - Type.
//
// Returns:
// Boolean.
//
Function StructuralTypeToSerialize(StructuralType);
	
	TypeToSerializeArray = SaaSReUse.StructuralTypesToSerialize();
	
	For Each TypeToSerialize In TypeToSerializeArray Do 
		If StructuralType = TypeToSerialize Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
		
EndFunction

// Gets an XDTO presentation of the structure type object.
//
// Parameters:
// StructuralTypeValue - Array, Structure, Correspondence or their fixed analogs.
//
// Returns:
// XDTO structure object - XDTO presentation of the structure type object.
//
Function StructuralObjectToXDTOObject(Val StructuralTypeValue)
	
	StructuralType = TypeOf(StructuralTypeValue);
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Type ""%1"" is not structural or currently its serialization is not supported.'"),
			StructuralType);
		Raise(ErrorInfo);
	EndIf;
	
	XMLValueType = XDTOSerializer.XMLTypeOf(StructuralTypeValue);
	StructureType = XDTOFactory.Type(XMLValueType);
	XDTOStructure = XDTOFactory.Create(StructureType);
	
	// Traverse possible structure types.
	
	If StructuralType = Type("Structure") Or StructuralType = Type("FixedStructure") Then
		
		PropertyType = StructureType.Properties.Get("Property").Type;
		
		For Each KeyAndValue In StructuralTypeValue Do
			Property = XDTOFactory.Create(PropertyType);
			Property.name = KeyAndValue.Key;
			Property.Value = TypeValueToXDTOValue(KeyAndValue.Value);
			XDTOStructure.Property.Add(Property);
		EndDo;
		
	ElsIf StructuralType = Type("Array") Or StructuralType = Type("FixedArray") Then 
		
		For Each ItemValue In StructuralTypeValue Do
			XDTOStructure.Value.Add(TypeValueToXDTOValue(ItemValue));
		EndDo;
		
	ElsIf StructuralType = Type("Map") Or StructuralType = Type("FixedMap") Then
		
		For Each KeyAndValue In StructuralTypeValue Do
			XDTOStructure.pair.Add(StructuralObjectToXDTOObject(KeyAndValue));
		EndDo;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		XDTOStructure.key = TypeValueToXDTOValue(StructuralTypeValue.Key);
		XDTOStructure.value = TypeValueToXDTOValue(StructuralTypeValue.Value);
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		XDTOVTColumnType = StructureType.Properties.Get("column").Type;
		
		For Each Column In StructuralTypeValue.Columns Do
			
			XDTOColumn = XDTOFactory.Create(XDTOVTColumnType);
			
			XDTOColumn.Name = TypeValueToXDTOValue(Column.Name);
			XDTOColumn.ValueType = XDTOSerializer.WriteXDTO(Column.ValueType);
			XDTOColumn.Title = TypeValueToXDTOValue(Column.Title);
			XDTOColumn.Width = TypeValueToXDTOValue(Column.Width);
			
			XDTOStructure.column.Add(XDTOColumn);
			
		EndDo;
		
		XDTOTypeVTIndex = StructureType.Properties.Get("index").Type;
		
		For Each IndexOf In StructuralTypeValue.Indexes Do
			
			XDTOIndex = XDTOFactory.Create(XDTOTypeVTIndex);
			
			For Each IndexField In IndexOf Do
				XDTOIndex.column.Add(TypeValueToXDTOValue(IndexField));
			EndDo;
			
			XDTOStructure.index.Add(XDTOIndex);
			
		EndDo;
		
		XDTOTypeVTRow = StructureType.Properties.Get("row").Type;
		
		For Each VTRow In StructuralTypeValue Do
			
			XDTORow = XDTOFactory.Create(XDTOTypeVTRow);
			
			For Each ColumnValue In VTRow Do
				XDTORow.value.Add(TypeValueToXDTOValue(ColumnValue));
			EndDo;
			
			XDTOStructure.row.Add(XDTORow);
			
		EndDo;
		
	EndIf;
	
	Return XDTOStructure;
	
EndFunction

// Receives an object of the structural type from XDTO object.
//
// Parameters:
// XDTODataObject - XDTO.
//
// Returns:
// Structure type (Array, Structure, Map or their fixed analogs).
//
Function XDTOObjectToStructuralObject(XDTODataObject)
	
	XMLDataType = New XMLDataType(XDTODataObject.Type().Name, XDTODataObject.Type().NamespaceURI);
	If CanReadXMLDataType(XMLDataType) Then
		StructuralType = XDTOSerializer.FromXMLType(XMLDataType);
	Else
		Return XDTODataObject;
	EndIf;
	
	If StructuralType = Type("String") Then
		Return "";
	EndIf;
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Type ""%1"" is not structural or currently its serialization is not supported.'"),
			StructuralType);
		Raise(ErrorInfo);
	EndIf;
	
	If StructuralType = Type("Structure")	Or StructuralType = Type("FixedStructure") Then
		
		StructuralObject = New Structure;
		
		For Each Property In XDTODataObject.Property Do
			StructuralObject.Insert(Property.name, XDTOValueToTypeValue(Property.Value));          
		EndDo;
		
		If StructuralType = Type("Structure") Then
			Return StructuralObject;
		Else 
			Return New FixedStructure(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Array") Or StructuralType = Type("FixedArray") Then 
		
		StructuralObject = New Array;
		
		For Each ArrayElement In XDTODataObject.Value Do
			StructuralObject.Add(XDTOValueToTypeValue(ArrayElement));          
		EndDo;
		
		If StructuralType = Type("Array") Then
			Return StructuralObject;
		Else 
			Return New FixedArray(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Map") Or StructuralType = Type("FixedMap") Then
		
		StructuralObject = New Map;
		
		For Each KeyAndValueXDTO In XDTODataObject.pair Do
			KeyAndValue = XDTOObjectToStructuralObject(KeyAndValueXDTO);
			StructuralObject.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
		If StructuralType = Type("Map") Then
			Return StructuralObject;
		Else 
			Return New FixedMap(StructuralObject);
		EndIf;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		StructuralObject = New Structure("Key, Value");
		StructuralObject.Key = XDTOValueToTypeValue(XDTODataObject.key);
		StructuralObject.Value = XDTOValueToTypeValue(XDTODataObject.value);
		
		Return StructuralObject;
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		StructuralObject = New ValueTable;
		
		For Each Column In XDTODataObject.column Do
			
			StructuralObject.Columns.Add(
				XDTOValueToTypeValue(Column.Name), 
				XDTOSerializer.ReadXDTO(Column.ValueType), 
				XDTOValueToTypeValue(Column.Title), 
				XDTOValueToTypeValue(Column.Width));
				
		EndDo;
		For Each IndexOf In XDTODataObject.index Do
			
			IndexString = "";
			For Each IndexField In IndexOf.column Do
				IndexString = IndexString + IndexField + ", ";
			EndDo;
			IndexString = TrimAll(IndexString);
			If StrLen(IndexString) > 0 Then
				IndexString = Left(IndexString, StrLen(IndexString) - 1);
			EndIf;
			
			StructuralObject.Indexes.Add(IndexString);
		EndDo;
		For Each XDTORow In XDTODataObject.row Do
			
			VTRow = StructuralObject.Add();
			
			ColumnCount = StructuralObject.Columns.Count();
			For IndexOf = 0 To ColumnCount - 1 Do 
				VTRow[StructuralObject.Columns[IndexOf].Name] = XDTOValueToTypeValue(XDTORow.value[IndexOf]);
			EndDo;
			
		EndDo;
		
		Return StructuralObject;
		
	EndIf;
	
EndFunction

Function CanReadXMLDataType(Val XMLDataType)
	
	Record = New XMLWriter;
	Record.SetString();
	Record.WriteStartElement("Dummy");
	Record.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Record.WriteNamespaceMapping("ns1", XMLDataType.NamespaceURI);
	Record.WriteAttribute("xsi:type", "ns1:" + XMLDataType.TypeName);
	Record.WriteEndElement();
	
	String = Record.Close();
	
	Read = New XMLReader;
	Read.SetString(String);
	Read.MoveToContent();
	
	Return XDTOSerializer.CanReadXML(Read);
	
EndFunction

// Gets a value of the simplest type in XDTO context.
//
// Parameters:
// TypeValue - Value of arbitrary type.
//
// Returns:
// Arbitrary type. 
//
Function TypeValueToXDTOValue(Val TypeValue)
	
	If TypeValue = Undefined
		Or TypeOf(TypeValue) = Type("XDTODataObject")
		Or TypeOf(TypeValue) = Type("XDTODataValue") Then
		
		Return TypeValue;
		
	Else
		
		If TypeOf(TypeValue) = Type("String") Then
			XDTOType = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "string")
		Else
			XMLType = XDTOSerializer.XMLTypeOf(TypeValue);
			XDTOType = XDTOFactory.Type(XMLType);
		EndIf;
		
		If TypeOf(XDTOType) = Type("XDTOObjectType") Then // Structure type value.
			Return StructuralObjectToXDTOObject(TypeValue);
		Else
			Return XDTOFactory.Create(XDTOType, TypeValue); // For example, UUID.
		EndIf;
		
	EndIf;
	
EndFunction

// Gets a platform value analog of the XDTO type.
//
// Parameters:
// XDTODataValue - Value of arbitrary XDTO type.
//
// Returns:
// Arbitrary type. 
//
Function XDTOValueToTypeValue(XDTODataValue)
	
	If TypeOf(XDTODataValue) = Type("XDTODataValue") Then
		Return XDTODataValue.Value;
	ElsIf TypeOf(XDTODataValue) = Type("XDTODataObject") Then
		Return XDTOObjectToStructuralObject(XDTODataValue);
	Else
		Return XDTODataValue;
	EndIf;
	
EndFunction

// Fills out an area with supplied data when preparing for use.
//
// Parameters:
//   DataArea - number of populated area.
//   ExportFileID - Initial data file ID.
//   Variant - initial data option.
//   UseMode - demo or working.
//
// Returns:
//  String - one of options "Success", "Fatal error".
//
Function ImportAreaOfSuppliedData(Val DataArea, Val ExportFileID, Val Variant, MessageAboutFatalError)
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	DataFileFound = False;
	
	Filter = New Array();
	Filter.Add(New Structure("Code, Value", "ConfigurationName", Metadata.Name));
	Filter.Add(New Structure("Code, Value", "ConfigurationVersion", Metadata.Version));
	Filter.Add(New Structure("Code, Value", "Variant", Variant));
	Filter.Add(New Structure("Code, Value", "Mode", 
		?(Constants.InfobaseUsageMode.Get() 
			= Enums.InfobaseUsageModes.Demo, 
			"Demo", "Working")));

	Handle = SuppliedData.HandleSuppliedDataFromCache(ExportFileID);
	If Handle <> Undefined Then
		If SuppliedData.CharacteristicsCoincide(Filter, Handle.Characteristics) Then
			DataTransferStandard = SuppliedData.ProvidedDataFromCache(ExportFileID);
			ExportFileName = GetTempFileName();
			DataTransferStandard.Write(ExportFileName);
			DataFileFound = True;
		Else
			MessageAboutFatalError = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Specified file of initial data is not applicable for this configuration.
			     |Descriptor of file: %1'"),
			SuppliedData.GetDataDescription(Handle));
			Return "FatalError";
		EndIf;
	EndIf;
	
	If Not DataFileFound Then
	
		Descriptors = SuppliedData.ProvidedDataFromManagerDescriptors("DataAreaStandard", Filter);
	
		If Descriptors.Descriptor.Count() = 0 Then
			MessageAboutFatalError = 
			NStr("en = 'Service manager does not include the initial data file for the current configuration version.'");
			Return "FatalError";
		EndIf;
		
		If Descriptors.Descriptor[0].FileGUID <> ExportFileID Then
			MessageAboutFatalError = 
			NStr("en = 'The initial data file available in the service manager differs from the one specified in the message for the area preparation. Cannot prepare the area.'");
			Return "FatalError";
		EndIf;
		
		ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
			
		If ExportFileName = Undefined Then
			MessageAboutFatalError = 
			NStr("en = 'Service manager no longer contains the required file with initial data, it might have been replaced. Area cannot be prepared.'");
			Return False;
		EndIf;
		
		SuppliedData.SaveProvidedDataToCache(Descriptors.Descriptor[0], ExportFileName);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataAreasExportImport") Then
		
		CallExceptionNotAvailableSTLSubsystem("ServiceTechnology.SaaS.DataAreasExportImport");
		
	EndIf;
	
	ModuleDataAreasExportImport = CommonUse.CommonModule("DataAreasExportImport");
	
	Try
		
		ImportInfobaseUsers = False;
		CollapseUsers = (NOT Constants.InfobaseUsageMode.Get() = Enums.InfobaseUsageModes.Demo);
		ModuleDataAreasExportImport.ImportCurrentDataAreaFromArchive(ExportFileName, ImportInfobaseUsers, CollapseUsers);
		
	Except
		
		WriteLogEvent(NStr("en = 'Copy data area'", CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
		EndTry;
		
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
	Return "Success";

EndFunction

#EndRegion

#Region ControlOfTheUnseparatedData

// It is called when checking whether unseparated data is available for writing.
//
Procedure ControlDataOnWriteBrain(Val Source)
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		ExceptionsRepresentation = NStr("en = 'Access right violation'", CommonUseClientServer.MainLanguageCode());
		
		WriteLogEvent(
			ExceptionsRepresentation,
			EventLogLevel.Error,
			Source.Metadata());
		
		Raise ExceptionsRepresentation;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcessingAuxiliaryAreaData

// Processes value of a reference type separated
// by the AuxiliaryDataSeparator separator with switching of the session separator to the record time.
//
// Parameters:
//  ObjectSupportData - value of a reference
//  type or ObjectDeletion, Write - Boolean, a flag showing that a
//  ref type value is being written,Delete - Boolean, a flag showing that a reference type is being deleted.
//
Procedure ProcessingAuxiliaryData(ObjectSupportData, Val Write, Val Delete)
	
	Try
		
		WantedRestorationDivisionSession = False;
		
		If TypeOf(ObjectSupportData) = Type("ObjectDeletion") Then
			VerifiedValue = ObjectSupportData.Ref;
			CheckedRef = True;
		Else
			VerifiedValue = ObjectSupportData;
			CheckedRef = False;
		EndIf;
		
		If Not ExclusiveMode() AND CommonUse.IsSeparatedMetadataObject(VerifiedValue.Metadata(), CommonUseReUse.SupportDataSplitter()) Then
			
			If CommonUseReUse.CanUseSeparatedData() Then
				
				// It is easy to write an object in the separated session.
				If Write Then
					ObjectSupportData.Write();
				EndIf;
				If Delete Then
					ObjectSupportData.Delete();
				EndIf;
				
			Else
				
				// To avoid locks conflict with sessions where another
				// separator value is set, it is required to switch session separations in the undivided session.
				If CheckedRef Then
					SeparatorValue = CommonUse.ObjectAttributeValue(VerifiedValue, CommonUseReUse.SupportDataSplitter());
				Else
					SeparatorValue = ObjectSupportData[CommonUseReUse.SupportDataSplitter()];
				EndIf;
				CommonUse.SetSessionSeparation(True, SeparatorValue);
				WantedRestorationDivisionSession = True;
				If Write Then
					ObjectSupportData.Write();
				EndIf;
				If Delete Then
					ObjectSupportData.Delete();
				EndIf;
				
			EndIf;
			
		Else
			
			If Write Then
				ObjectSupportData.Write();
			EndIf;
			If Delete Then
				ObjectSupportData.Delete();
			EndIf;
			
		EndIf;
		
		If WantedRestorationDivisionSession Then
			CommonUse.SetSessionSeparation(False);
		EndIf;
		
	Except
		
		If WantedRestorationDivisionSession Then
			CommonUse.SetSessionSeparation(False);
		EndIf;
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#Region HandlersOfTheConditionalCallsIntoOtherSubsystems

// Additional actions to be performed when changing the session separation.
//
Procedure DataAreaOnChange() Export
	
	ClearAllSessionParametersExceptSeparators();
	
	If CommonUseReUse.CanUseSeparatedData() Then
		UsersService.AuthenticateCurrentUser();
	EndIf;
	
EndProcedure

#EndRegion

#Region HandlersOfSuppliedDataReceipt

// Registers the handlers of supplied data during the day and since ever.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "DataAreaStandard";
	Handler.ProcessorCode = "DataAreaStandard";
	Handler.Handler = SaaSOperations;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether these data is necessary for the application, and if so, - select the Import
// check box.
// 
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   Import    - Boolean, return.
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = "DataAreaStandard" Then
		For Each Characteristic In Handle.Properties.Property Do
			If Characteristic.Code = "ConfigurationName" AND Characteristic.Value = Metadata.Name Then
				Import = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
		
EndProcedure

// It is called after the call of AvailableNewData, allows you to parse data.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be deleted automatically after
//                  completion of the procedure. If the file was not specified in the service manager - The argument
//                  value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = "DataAreaStandard" Then
		ProcessProvidedConfigurationStandard(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called on cancellation of data processing in case of failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
EndProcedure

Procedure ProcessProvidedConfigurationStandard(Val Handle, Val PathToFile)
	
	If ValueIsFilled(PathToFile) Then
		
		SuppliedData.SaveProvidedDataToCache(Handle, PathToFile);
		
	Else
		
		Filter = New Array;
		For Each Characteristic In Handle.Properties.Property Do
			If Characteristic.IsKey Then
				Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
			EndIf;
		EndDo;

		For Each Refs In SuppliedData.RefOfProvidedDataFromCache(Handle.DataType, Filter) Do
		
			SuppliedData.DeleteProvidedDataFromCache(Refs);
		
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseUpdateHandlers

// Controls metadata structure by the order of common
// attributes criteria in the configuration metadata tree.
//
Procedure ControlDelimitersOnUpgrading() Export
	
	OrderOfApplicationData = 99;
	InternalDataOrder = 99;
	
	SeparatorOfApplied = Metadata.CommonAttributes.DataAreaBasicData;
	InternalSplitter = Metadata.CommonAttributes.DataAreaAuxiliaryData;
	
	Iterator = 0;
	For Each ConfigurationCommonAttribute In Metadata.CommonAttributes Do
		
		If ConfigurationCommonAttribute = SeparatorOfApplied Then
			OrderOfApplicationData = Iterator;
		ElsIf ConfigurationCommonAttribute = InternalSplitter Then
			InternalDataOrder = Iterator;
		EndIf;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
	If OrderOfApplicationData <= InternalDataOrder Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Configuration metadata structure rupture is found: common
			     |attribute %1 must be located in the configuration metadata
			     |tree up to the common attribute %2 in order.'"),
			InternalSplitter.Name,
			SeparatorOfApplied.Name);
		
	EndIf;
	
EndProcedure

// Returns the min version of the 1C:Library of service
// technology library with which you can use the current SSL version.
//
// Return value: String, min supported BTS version as RR{P|PP}.ZZ.SS.
//
Function RequiredSTLVersion()
	
	Return "1.0.2.1";
	
EndFunction

#EndRegion

#EndRegion
