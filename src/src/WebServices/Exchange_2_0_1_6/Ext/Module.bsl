﻿
#Region ServiceProceduresAndFunctions

#Region OperationHandlers

// Corresponds to operation Import.
Function RunExport(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
EndFunction

// Corresponds to operation Export.
Function RunImport(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageStorage.Get());
	
EndFunction

// Corresponds to operation ImportData.
Function ExecuteDataExport(ExchangePlanName,
								CodeOfInfobaseNode,
								FileIDString,
								LongAction,
								ActionID,
								LongOperationAllowed)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID;
	FileIDString = String(FileID);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ExportToFileTransferServiceForInfobaseNode(ExchangePlanName, CodeOfInfobaseNode, FileID);
		
	Else
		
		ExecuteDataExportInClientServerMode(ExchangePlanName, CodeOfInfobaseNode, FileID, LongAction, ActionID, LongOperationAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to operation DataExport.
Function ExecuteDataImport(ExchangePlanName,
								CodeOfInfobaseNode,
								FileIDString,
								LongAction,
								ActionID,
								LongOperationAllowed)
	
	ValidateLockInformationBaseForUpdate();
	
	DataExchangeServer.CheckUseDataExchange();
	
	FileID = New UUID(FileIDString);
	
	If CommonUse.FileInfobase() Then
		
		DataExchangeServer.ImportForInfobaseNodeFromFileTransferService(ExchangePlanName, CodeOfInfobaseNode, FileID);
		
	Else
		
		ImportDataInClientServerMode(ExchangePlanName, CodeOfInfobaseNode, FileID, LongAction, ActionID, LongOperationAllowed);
		
	EndIf;
	
EndFunction

// Corresponds to operation GetIBParameters.
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo)
	
	Result = DataExchangeServer.InfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo);
	Return XDTOSerializer.WriteXDTO(Result);
	
EndFunction

// Corresponds to operation GetIBData.
Function GetInfobaseData(FullTableName)
	
	Return XDTOSerializer.WriteXDTO(DataExchangeServer.CorrespondentData(FullTableName));
	
EndFunction

// Corresponds to operation GetCommonNodsData.
Function GetCommonNodeData(ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	Return XDTOSerializer.WriteXDTO(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// Corresponds to operation CreateExchange.
Function CreateDataExchange(ExchangePlanName, ParameterString, SetupXDTOFilter, ValuesByDefaultXDTO)
	
	DataExchangeServer.CheckUseDataExchange();
	
	SetPrivilegedMode(True);
	
	// Get data processor of the exchange settings assistant on the second base.
	DataSyncWizard = DataProcessors.DataSyncWizard.Create();
	DataSyncWizard.ExchangePlanName = ExchangePlanName;
	
	Cancel = False;
	
	// Import assistant parameters from string to assistant data processor.
	DataSyncWizard.RunAssistantParametersImport(Cancel, ParameterString);
	
	If Cancel Then
		Message = NStr("en = 'When creating exchange setting in the second infobase, errors occurred: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataSyncWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
	DataSyncWizard.AssistantOperationOption = "ContinueDataExchangeSetup";
	DataSyncWizard.ThisIsSettingOfDistributedInformationBase = False;
	DataSyncWizard.ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.WS;
	DataSyncWizard.SourceInfobasePrefixFilled = ValueIsFilled(GetFunctionalOption("GlobalNumerationPrefix"));
	
	// Create exchange setting.
	DataSyncWizard.SetUpNewWebSaaSDataExchange(
											Cancel,
											XDTOSerializer.ReadXDTO(SetupXDTOFilter),
											XDTOSerializer.ReadXDTO(ValuesByDefaultXDTO));
	
	If Cancel Then
		Message = NStr("en = 'When creating exchange setting in the second infobase, errors occurred: %1'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataSyncWizard.ErrorMessageString());
		Raise Message;
	EndIf;
	
EndFunction

// Corresponds to operation UpdateExchange.
Function UpdateDataExchangeSettings(ExchangePlanName, NodeCode, ValuesByDefaultXDTO)
	
	DataExchangeServer.ExternalConnectionRefreshExchangeSettingsData(ExchangePlanName, NodeCode, XDTOSerializer.ReadXDTO(ValuesByDefaultXDTO));
	
EndFunction

// Corresponds to operation RegisterOnlyCatalogData.
Function RecordCatalogChangesOnly(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, True);
	
EndFunction

// Corresponds to operation RegisterAllDataExceptCatalogs.
Function RecordAllChangesExceptCatalogs(ExchangePlanName, NodeCode, LongAction, ActionID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, LongAction, ActionID, False);
	
EndFunction

// Corresponds to operation GetContinuousOperationStatus.
Function GetLongOperationState(ActionID, ErrorMessageString)
	
	BackgroundJobStateMap = New Map;
	BackgroundJobStateMap.Insert(BackgroundJobState.Active,		"Active");
	BackgroundJobStateMap.Insert(BackgroundJobState.Completed,	"Executed");
	BackgroundJobStateMap.Insert(BackgroundJobState.Failed, 	"Failed");
	BackgroundJobStateMap.Insert(BackgroundJobState.Canceled,	"Canceled");
	
	SetPrivilegedMode(True);
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(ActionID));
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	Return BackgroundJobStateMap.Get(BackgroundJob.State);
EndFunction

// Corresponds to operation GetFunctionalOption.
Function GetFunctionalOptionValue(Name)
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Corresponds to operation PrepareGetFile.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	File = New File(SourceFileName);
	
	SourceFileNameInTemporaryDirectory = CommonUseClientServer.GetFullFileName(TemporaryDirectory, File.Name);
	SharedFileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	CreateDirectory(TemporaryDirectory);
	
	MoveFile(SourceFileName, SourceFileNameInTemporaryDirectory);
	
	Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(SourceFileNameInTemporaryDirectory);
	Archiver.Write();
	
	If BlockSize <> 0 Then
		// Divide file into parts
		FileNames = SplitFile(SharedFileName, BlockSize * 1024);
		PartQuantity = FileNames.Count();
	Else
		PartQuantity = 1;
		MoveFile(SharedFileName, SharedFileName + ".1");
	EndIf;
	
EndFunction

// Corresponds to operation GetFilePart.
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileNames = FindFileOfPart(TemporaryExportDirectory(TransferId), PartNumber);
	
	If FileNames.Count() = 0 Then
		
		MessagePattern = NStr("en = 'Fragment %1 of the transfer session with ID %2 is not found'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FileNames.Count() > 1 Then
		
		MessagePattern = NStr("en = 'Several fragments %1 of the transfer session with ID %2 are found'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	FileNamePart = FileNames[0].FullName;
	PartData = New BinaryData(FileNamePart);
	
EndFunction

// Corresponds to operation ReleaseFile.
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Corresponds to operation PutFilePart.
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TemporaryDirectory);
		
	EndIf;
	
	FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
EndFunction

// Corresponds to operation SaveFileFromParts.
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	PartFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessagePattern = NStr("en = 'Fragment of transfer session %1 with ID %2 is not found.
			                      |It is necessary to make sure that
			                      |in application settings parameters ""Directory of temporary files for Linux"" and ""Directory of temporary files for Windows"" are specified.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(PartNumber), String(TransferId));
			Raise(MessageText);
		EndIf;
		
		PartFilesToMerge.Add(FileName);
		
	EndDo;
	
	ArchiveName = CommonUseClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	MergeFiles(PartFilesToMerge, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(TemporaryDirectory);
		Except
			WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("en = 'Archive file contains no data.'"));
	EndIf;
	
	ExportDirectory = DataExchangeReUse.TempFileStorageDirectory();
	
	FileName = CommonUseClientServer.GetFullFileName(ExportDirectory, Dearchiver.Items[0].Name);
	
	Dearchiver.Extract(Dearchiver.Items[0], ExportDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
	Try
		DeleteFiles(TemporaryDirectory);
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextRemovingTemporaryFile(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Corresponds to operation PutFileIntoStorage.
Function PutFileIntoStorage(FileName, FileId)
	
	SetPrivilegedMode(True);
	
	FileId = DataExchangeServer.PutFileToStorage(FileName);
	
EndFunction

// Corresponds to operation GetFileFromStorage.
Function GetFileFromStorage(FileId)
	
	SetPrivilegedMode(True);
	
	SourceFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	File = New File(SourceFileName);
	
	Return File.Name;
EndFunction

// Corresponds to operation FileExists.
Function FileExists(FileName)
	
	SetPrivilegedMode(True);
	
	TempFileFullName = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), FileName);
	
	File = New File(TempFileFullName);
	
	Return File.Exist();
EndFunction

// Corresponds to operation Ping.
Function Ping()
	// Check link.
	Return "";
EndFunction

// Corresponds to operation TestConnection.
Function CheckConnection(ExchangePlanName, NodeCode, Result)
	
	// Check if there are rights to execute the exchange.
	Try
		DataExchangeServer.CheckIfExchangesPossible();
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Check if the infobase is locked for update.
	Try
		ValidateLockInformationBaseForUpdate();
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	SetPrivilegedMode(True);
	
	// Check if there is the exchange plan node (probably the node is already deleted).
	If ExchangePlans[ExchangePlanName].FindByCode(NodeCode).IsEmpty() Then
		Result = NStr("en = 'Configuring data synchronization is disabled online by the application administrator.'");
		Return False;
	EndIf;
	
	Return True;
EndFunction

#EndRegion

#Region LocalServiceProceduresAndFunctions

Procedure ValidateLockInformationBaseForUpdate()
	
	If ValueIsFilled(InfobaseUpdateService.InfobaseLockedForUpdate()) Then
		
		Raise NStr("en = 'Data synchronization is temporary unavailable due to online application update.'");
		
	EndIf;
	
EndProcedure

Procedure ExecuteDataExportInClientServerMode(ExchangePlanName,
														CodeOfInfobaseNode,
														FileID,
														LongAction,
														ActionID,
														LongOperationAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(CodeOfInfobaseNode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName, CodeOfInfobaseNode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en = 'Data synchronization is already being executed.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ExportToFileTransferServiceForInfobaseNode",
										Parameters,
										BackgroundJobKey,
										NStr("en = 'Exchanging data through web service.'"));
	
	Try
		Timeout = ?(LongOperationAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongAction = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en = 'An error occurred when exporting data via web service.'");
	EndIf;
	
EndProcedure

Procedure ImportDataInClientServerMode(ExchangePlanName,
													CodeOfInfobaseNode,
													FileID,
													LongAction,
													ActionID,
													LongOperationAllowed)
	
	Parameters = New Array;
	Parameters.Add(ExchangePlanName);
	Parameters.Add(CodeOfInfobaseNode);
	Parameters.Add(FileID);
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName, CodeOfInfobaseNode);
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	If BackgroundJobs.GetBackgroundJobs (Filter).Count() = 1 Then
		Raise NStr("en = 'Data synchronization is already being executed.'");
	EndIf;
	
	BackgroundJob = BackgroundJobs.Execute("DataExchangeServer.ImportForInfobaseNodeFromFileTransferService",
										Parameters,
										BackgroundJobKey,
										NStr("en = 'Exchanging data through web service.'"));
	
	Try
		Timeout = ?(LongOperationAllowed, 5, Undefined);
		
		BackgroundJob.WaitForCompletion(Timeout);
	Except
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
		
		If BackgroundJob.State = BackgroundJobState.Active Then
			
			ActionID = String(BackgroundJob.UUID);
			LongAction = True;
			Return;
			
		Else
			
			If BackgroundJob.ErrorInfo <> Undefined Then
				Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
			EndIf;
			Raise;
		EndIf;
		
	EndTry;
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
	
	If BackgroundJob.State <> BackgroundJobState.Completed Then
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		
		Raise NStr("en = 'An error occurred when importing data using web service.'");
	EndIf;
	
EndProcedure

Function ExportImportDataBackgroundJobKey(ExchangePlan, NodeCode)
	
	strKey = "ExchangePlan:[ExchangePlan] NodeCode:[NodeCode]";
	strKey = StrReplace(strKey, "[ExchangePlan]", ExchangePlan);
	strKey = StrReplace(strKey, "[NodeCode]", NodeCode);
	
	Return strKey;
EndFunction

Function RegisterDataForInitialExport(Val ExchangePlanName, Val NodeCode, LongAction, ActionID, CatalogsOnly)
	
	SetPrivilegedMode(True);
	
	InfobaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en = 'Exchange plan node is not found; exchange plan name %1; node code %2'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	If CommonUse.FileInfobase() Then
		
		If CatalogsOnly Then
			
			DataExchangeServer.RegisterOnlyCatalogsForInitialLandings(InfobaseNode);
			
		Else
			
			DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExporting(InfobaseNode);
			
		EndIf;
		
	Else
		
		If CatalogsOnly Then
			MethodName = "DataExchangeServer.RegisterOnlyCatalogsForInitialExport";
		Else
			MethodName = "DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport";
		EndIf;
		
		Parameters = New Array;
		Parameters.Add(InfobaseNode);
		
		BackgroundJob = BackgroundJobs.Execute(MethodName, Parameters,, NStr("en = 'Create data exchange.'"));
		
		Try
			BackgroundJob.WaitForCompletion(5);
		Except
			
			BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJob.UUID);
			
			If BackgroundJob.State = BackgroundJobState.Active Then
				
				ActionID = String(BackgroundJob.UUID);
				LongAction = True;
				
			Else
				If BackgroundJob.ErrorInfo <> Undefined Then
					Raise DetailErrorDescription(BackgroundJob.ErrorInfo);
				EndIf;
				
				Raise;
			EndIf;
			
		EndTry;
		
	EndIf;
	
EndFunction

Function GetPartFileName(PartNumber)
	
	Result = "data.zip.[n]";
	
	Return StrReplace(Result, "[n]", Format(PartNumber, "NG=0"));
EndFunction

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonUseClientServer.GetFullFileName(DataExchangeReUse.TempFileStorageDirectory(), TemporaryDirectory);
	
	Return Result;
EndFunction

Function FindFileOfPart(Val Directory, Val FileNumber)
	
	For CountNumberOfBits = CountNumberOfBitsCiesla(FileNumber) To 5 Do
		
		FormatString = StringFunctionsClientServer.SubstituteParametersInString("ND=%1; NLZ=; NG=0", String(CountNumberOfBits));
		
		FileName = StringFunctionsClientServer.SubstituteParametersInString("data.zip.%1", Format(FileNumber, FormatString));
		
		FileNames = FindFiles(Directory, FileName);
		
		If FileNames.Count() > 0 Then
			
			Return FileNames;
			
		EndIf;
		
	EndDo;
	
	Return New Array;
EndFunction

Function CountNumberOfBitsCiesla(Val Number)
	
	Return StrLen(Format(Number, "NFD=0; NG=0"));
	
EndFunction

#EndRegion

#EndRegion
