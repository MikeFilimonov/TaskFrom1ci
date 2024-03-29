﻿////////////////////////////////////////////////////////////////////////////////
// Subscription to notifications of new supplied data reception.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Receives message handler list which this subsystem is processing.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlersTable.
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	AddMessageChannelHandler("SuppliedData\Update", MessagesSuppliedDataMessageHandler, Handlers);
	
EndProcedure

// Processes the body of message from channel in compliance with the algorithm of the current message channel.
//
// Parameters:
//  MessageChannel - String - message channel identifier from which the message was received.
//  MessageBody - Arbitrary - message body which is received from the channel which is subject to processing.
//  Sender - ExchangePlanRef.MessageExchange - end point which is the message sender.
//
Procedure ProcessMessage(Val MessageChannel, Val MessageBody, Val Sender) Export
	
	Try
		Handle = DeserializeXDTO(MessageBody);
		
		If MessageChannel = "SuppliedData\Update" Then
			
			ProcessNewDescriptor(Handle);
			
		EndIf;
	Except
		WriteLogEvent(NStr("en = 'Supplied data.Message processing error'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, ,
			, SuppliedData.GetDataDescription(Handle) + Chars.LF + DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Handles new data. Called in from ProcessMessage and from SuppliedData.ImportAndProcessData.
//
// Parameters:
//  Handle - XDTOObject Descriptor
Procedure ProcessNewDescriptor(Val Handle) Export
	
	Import = False;
	RecordSet = InformationRegisters.SuppliedDataForDataProcessors.CreateRecordSet();
	RecordSet.Filter.FileID.Set(Handle.FileGUID);
	
	For Each Handler In GetHandlers(Handle.DataType) Do
		
		HandlerImport = False;
		
		Handler.Handler.AvailableNewData(Handle, HandlerImport);
		
		If HandlerImport Then
			UnprocessedData = RecordSet.Add();
			UnprocessedData.FileID = Handle.FileGUID;
			UnprocessedData.ProcessorCode = Handler.ProcessorCode;
			Import = True;
		EndIf;
		
	EndDo; 
	
	If Import Then
		SetPrivilegedMode(True);
		RecordSet.Write();
		SetPrivilegedMode(False);
		
		ScheduleDataExport(Handle);
	EndIf;
	
	WriteLogEvent(NStr("en = 'Supplied data.New data is available'", 
		CommonUseClientServer.MainLanguageCode()), 
		EventLogLevel.Information, ,
		, ?(Import, NStr("en = 'Import job was added to the queue.'"), NStr("en = 'Data import is not required.'"))
		+ Chars.LF + SuppliedData.GetDataDescription(Handle));

EndProcedure

// Schedule exporting of data which corresponds to the handle.
//
// Parameters:
//   Handle - XDTOObject Descriptor.
//
Procedure ScheduleDataExport(Val Handle) Export
	Var HandleXML, MethodParameters;
	
	If Handle.RecommendedUpdateDate = Undefined Then
		Handle.RecommendedUpdateDate = CurrentUniversalDate();
	EndIf;
	
	HandleXML = SerializeXDTO(Handle);
	
	MethodParameters = New Array;
	MethodParameters.Add(HandleXML);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "SuppliedDataMessagesMessageHandler.ImportData");
	JobParameters.Insert("Parameters"    , MethodParameters);
	JobParameters.Insert("DataArea", -1);
	JobParameters.Insert("ScheduledStartTime", ToLocalTime(Handle.RecommendedUpdateDate));
	JobParameters.Insert("RestartCountOnFailure", 3);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// Export data which corresponds to the handle.
//
// Parameters:
//   Handle - XDTOObject Descriptor.
//
// Export data which corresponds to the handle.
//
// Parameters:
//   Handle - XDTOObject Descriptor.
//
Procedure ImportData(Val HandleXML) Export
	Var Handle, ExportFileName;
	
	Try
		Handle = DeserializeXDTO(HandleXML);
	Except
		WriteLogEvent(NStr("en = 'Supplied data.An error occurred when working with XML'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ HandleXML);
		Return;
	EndTry;

	WriteLogEvent(NStr("en = 'Supplied data. Data import'", 
		CommonUseClientServer.MainLanguageCode()), 
		EventLogLevel.Information, ,
		, NStr("en = 'Import is started'") + Chars.LF + SuppliedData.GetDataDescription(Handle));

	If ValueIsFilled(Handle.FileGUID) Then
		ExportFileName = GetFileFromStorage(Handle);
	
		If ExportFileName = Undefined Then
			WriteLogEvent(NStr("en = 'Supplied data. Data import'", 
				CommonUseClientServer.MainLanguageCode()), 
				EventLogLevel.Information, ,
				, NStr("en = 'File cannot be imported'") + Chars.LF 
				+ SuppliedData.GetDataDescription(Handle));
			Return;
		EndIf;
	EndIf;
	
	WriteLogEvent(NStr("en = 'Supplied data. Data import'", 
		CommonUseClientServer.MainLanguageCode()), 
		EventLogLevel.Note, ,
		, NStr("en = 'Import is completed successfully'") + Chars.LF + SuppliedData.GetDataDescription(Handle));

	// InformationRegister.SuppliedDataForDataProcessors
	// is used in cases when the execution cycle is interrupted by a server rebooting.
	// IN this case the only way to save information about handlers which were used already (if the number of such handlers
	// is more than 1) - is to promptly record them in the specified register.
	SetRawData = InformationRegisters.SuppliedDataForDataProcessors.CreateRecordSet();
	SetRawData.Filter.FileID.Set(Handle.FileGUID);
	SetRawData.Read();
	HasErrors = False;
	
	For Each Handler In GetHandlers(Handle.DataType) Do
		WriteFound = False;
		For Each WriteRawData In SetRawData Do
			If WriteRawData.ProcessorCode = Handler.ProcessorCode Then
				WriteFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not WriteFound Then 
			Continue;
		EndIf;
			
		Try
			Handler.Handler.ProcessNewData(Handle, ExportFileName);
			SetRawData.Delete(WriteRawData);
			SetRawData.Write();			
		Except
			WriteLogEvent(NStr("en = 'Supplied data. Data processor error'", 
				CommonUseClientServer.MainLanguageCode()), 
				EventLogLevel.Error, ,
				, DetailErrorDescription(ErrorInfo())
				+ Chars.LF + SuppliedData.GetDataDescription(Handle)
				+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Handler code: %1'"), Handler.ProcessorCode));
				
			WriteRawData.AttemptCount = WriteRawData.AttemptCount + 1;
			If WriteRawData.AttemptCount > 3 Then
				NotifyAboutCancelProcessing(Handler, Handle);
				SetRawData.Delete(WriteRawData);
			Else
				HasErrors = True;
			EndIf;
			SetRawData.Write();			
			
		EndTry;
	EndDo; 
	
	Try
		DeleteFiles(ExportFileName);
	Except
	EndTry;
	
	If TransactionActive() Then
			
		While TransactionActive() Do
				
			RollbackTransaction();
				
		EndDo;
			
		WriteLogEvent(NStr("en = 'Supplied data. Data processor error'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, 
			,
			, 
			NStr("en = 'Upon completion of handler execution Transaction was not closed when the handler finished'")
				 + Chars.LF + SuppliedData.GetDataDescription(Handle));
			
	EndIf;
	
	If HasErrors Then
		// We postpone loading for 5 minutes.
		Handle.RecommendedUpdateDate = CurrentUniversalDate() + 5 * 60;
		ScheduleDataExport(Handle);
		WriteLogEvent(NStr("en = 'Supplied data. Data processor error'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Information, , ,
			NStr("en = 'Data processing will be restarted due to handler error.'")
			 + Chars.LF + SuppliedData.GetDataDescription(Handle));
	Else
		SetRawData.Clear();
		SetRawData.Write();
		
		WriteLogEvent(NStr("en = 'Supplied data. Data import'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Information, ,
			, NStr("en = 'New data is processed'") + Chars.LF + SuppliedData.GetDataDescription(Handle));

	EndIf;
	
EndProcedure

Procedure DeleteInfoAboutUnporcessedData(Val Handle)
	
	SetRawData = InformationRegisters.SuppliedDataForDataProcessors.CreateRecordSet();
	SetRawData.Filter.FileID.Set(Handle.FileGUID);
	SetRawData.Read();
	
	For Each Handler In GetHandlers(Handle.DataType) Do
		WriteFound = False;
		
		For Each WriteRawData In SetRawData Do
			If WriteRawData.ProcessorCode = Handler.ProcessorCode Then
				WriteFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not WriteFound Then 
			Continue;
		EndIf;
			
		NotifyAboutCancelProcessing(Handler, Handle);
		
	EndDo; 
	SetRawData.Clear();
	SetRawData.Write();
	
EndProcedure

Procedure NotifyAboutCancelProcessing(Val Handler, Val Handle)
	
	Try
		Handler.Handler.DataProcessingCanceled(Handle);
		WriteLogEvent(NStr("en = 'Supplied data. Cancel processor'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Information, ,
			, SuppliedData.GetDataDescription(Handle)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Handler code: %1'"), Handler.ProcessorCode));
	
	Except
		WriteLogEvent(NStr("en = 'Supplied data. Cancel processor'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Handle)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Handler code: %1'"), Handler.ProcessorCode));
	EndTry;

EndProcedure

Function GetFileFromStorage(Val Handle)
	
	Try
		ExportFileName = SaaSOperations.GetFileFromServiceManagerStorage(Handle.FileGUID);
	Except
		WriteLogEvent(NStr("en = 'Supplied data. Storage error'", 
			CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Handle));
				
		// We postpone loading for 1 hour.
		Handle.RecommendedUpdateDate = Handle.RecommendedUpdateDate + 60 * 60;
		ScheduleDataExport(Handle);
		Return Undefined;
	EndTry;
	
	// If the file was replaced or deleted between restarts of the function - 
	// we delete the old update plan.
	If ExportFileName = Undefined Then
		DeleteInfoAboutUnporcessedData(Handle);
	EndIf;
	
	Return ExportFileName;

EndFunction

Function GetHandlers(Val DataKind)
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("DataKind");
	Handlers.Columns.Add("Handler");
	Handlers.Columns.Add("ProcessorCode");
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefenitionHandlersProvidedData(Handlers);
	EndDo;
	
	SuppliedDataOverridable.GetSuppliedDataHandlers(Handlers);
	
	Return Handlers.Copy(New Structure("DataKind", DataKind), "Handler, HandlerCode");
	
EndFunction

Function SerializeXDTO(Val XDTOObject)
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, XDTOObject, , , , XMLTypeAssignment.Explicit);
	Return Record.Close();
EndFunction

Function DeserializeXDTO(Val XMLString)
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOObject = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return XDTOObject;
EndFunction

// HELPER PROCEDURE AND FUNCTIONS

Procedure AddMessageChannelHandler(Val Channel, Val ChannelHandler, Val Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

#EndRegion