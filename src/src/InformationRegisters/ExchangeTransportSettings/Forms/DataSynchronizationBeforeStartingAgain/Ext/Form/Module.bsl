﻿#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Preliminary update (or update confirmation) of service event cache.
	Constants.ServiceEventsParameters.CreateValueManager().Refresh();
	// It is required to update client work parameters.
	RefreshReusableValues();
	
	InfobaseNode = DataExchangeServer.MasterNode();
	ThisIsOfflineWorkplace = DataExchangeReUse.ThisIsOfflineWorkplace();
	
	If ThisIsOfflineWorkplace Then
		Items.PagesConnectionParameters.CurrentPage = Items.AWSPage;
		ModuleOfflineWorkService = CommonUse.CommonModule("OfflineWorkService");
		AddressForAccountPasswordRecovery = ModuleOfflineWorkService.AddressForAccountPasswordRecovery();
		LongOperationAllowed = True;
		
		If DataExchangeServer.PasswordSynchronizationDataSet(InfobaseNode) Then
			Password = DataExchangeServer.PasswordSynchronizationData(InfobaseNode);
		EndIf;
		
	EndIf;
	
	NodeNameLabel = NStr("en = 'Failed to install the application update
	                     |received from ""%1"".
	                     |Technical information see <a href = ""EventLogMonitor"">Event log monitor</a>.'");
	NodeNameLabel = StringFunctionsClientServer.SubstituteParametersInString(NodeNameLabel, InfobaseNode.Description);
	Items.InformationLabelNodeName.Title = StringFunctionsClientServer.FormattedString(NodeNameLabel);
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InformationLabelNodeNameNavigationRefsProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", FormParameters,,,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SynchronizeAndContinue(Command)
	
	WarningText = "";
	HasErrors = False;
	LongAction = False;
	
	CheckUpdateNecessity();
	
	If StatusUpdate = "RefreshEnabledNotNeeded" Then
		
		SynchronizeViewAndContinueWithoutUpdateIB();
		
	ElsIf StatusUpdate = "UpdateResults" Then
		
		SynchronizeAndContinueWithUpdateOfDB();
		
	ElsIf StatusUpdate = "ConfigurationUpdate" Then
		
		WarningText = NStr("en = 'Changes which are not applied yet were received from the main node.
		                   |It is necessary to open the designer and update the data base configuration.'");
		
	EndIf;
	
	If Not LongAction Then
		
		SynchronizeAndContinueEnd();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DoNotSynchronizeAndContinue(Command)
	
	DoNotSynchronizeAndContinueAtServer();
	
	Close("Continue");
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ConnectionParameters(Command)
	
	Filter              = New Structure("Node", InfobaseNode);
	FillingValues = New Structure("Node", InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter,
		FillingValues, "ExchangeTransportSettings", Undefined);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region ScriptWithoutInfobaseUpdate

&AtClient
Procedure SynchronizeViewAndContinueWithoutUpdateIB()
	
	ImportDataExchangeMessageWithoutUpdate();
	
	If LongAction Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithoutIBUpdateEnd();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithoutIBUpdateEnd()
	
	// Repeat mode requires to be enabled in the following cases.
	// Case 1. Metadata with a new version of the configuration is received i.e IB update will be executed.
	// If Denial = True, then it is unacceptable to continue as duplicates of the generated data can be created,
	// - If Denial = False, then an error may occur while updating IB that may require to import message again.
	// Case 2. Metadata with the same version of the configuration is received i.e. IB will not be updated.
	// If Denial = True, then an error may occur while continuing the start
	//   as the predefined items were not imported,
	// - if Denial = False, then it is possible to continue as you can export it later
	//   (if it is not exported successfully, then you can receive a new message for import later).
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
		
		// If the message is imported successfully, then it is not necessary to import once again.
		If Constants.ImportDataExchangeMessage.Get() = True Then
			Constants.ImportDataExchangeMessage.Set(False);
		EndIf;
		Constants.RetryDataExportExchangeMessagesBeforeStart.Set(False);
		
		Try
			ExportMessageAfterInformationBaseUpdate();
		Except
			// If export wasn't successful still can continue
			// start and export in mode 1C:Enterprise.
		EndTry;
		
	ElsIf ConfigurationChanged() Then
		If Constants.ImportDataExchangeMessage.Get() = False Then
			Constants.ImportDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Changes which should be applied were received from the main node.
		                   |It is necessary to open the designer and update the data base configuration.'");
	Else
		
		If UpdateResults.InfobaseUpdateRequired() Then
			EnableExchangeMessageDataExportRepetitionBeforeRunning();
		EndIf;
		
		WarningText = NStr("en = 'Data receipt out of the main node has completed with errors.
		                   |Look for details in event log.'");
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
		
	EndIf;
	
EndProcedure

Procedure ExportMessageAfterInformationBaseUpdate()
	
	// You can disable the repeat mode after successful import and update of IB.
	DataExchangeServer.DisconnectRepeatExportMessagesExchangeDataBeforeRunning();
	
	Try
		If GetFunctionalOption("UseDataSync") = True Then
			
			InfobaseNode = DataExchangeServer.MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				RunExport = True;
				
				TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(InfobaseNode);
				
				TransportKind = TransportSettings.ExchangeMessageTransportKindByDefault;
				
				If TransportKind = Enums.ExchangeMessagesTransportKinds.WS
					AND Not TransportSettings.WSRememberPassword Then
					
					RunExport = False;
					
					InformationRegisters.InfobasesNodesCommonSettings.SetDataSendSign(InfobaseNode);
					
				EndIf;
				
				If RunExport Then
					
					AuthenticationParameters = ?(ThisIsOfflineWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
					// export only
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(False, InfobaseNode, False, True, TransportKind,,,,, AuthenticationParameters);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithoutUpdate()
	
	Try
		ImportMessageBeforeInformationBaseUpdating();
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemDisplay();
	
EndProcedure

&AtServer
Procedure ImportMessageBeforeInformationBaseUpdating()
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMessagesExchangeDataBeforeRunning") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSync") = True Then
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", True);
			SetPrivilegedMode(False);
			
			// Update objects registration rules before the data import.
			DataExchangeServer.ExecuteUpdateOfDataExchangeRules();
			
			TransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
			
			OperationStartDate = CurrentSessionDate();
			
			AuthenticationParameters = ?(ThisIsOfflineWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode, True, False, TransportKind,
				// import only
				LongAction, ActionID, FileID, LongOperationAllowed, AuthenticationParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ScriptWithInfobaseUpdate

&AtClient
Procedure SynchronizeAndContinueWithUpdateOfDB()
	
	ImportDataExchangeMessageWithUpdate();
	
	If LongAction Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithIBUpdateEnd();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithIBUpdateEnd()
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
		
		If Constants.ImportDataExchangeMessage.Get() = False Then
			Constants.ImportDataExchangeMessage.Set(True);
		EndIf;
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMetadataObjectsBeforeRunningIds", True);
		
	ElsIf ConfigurationChanged() Then
			
		If Constants.ImportDataExchangeMessage.Get() = False Then
			Constants.ImportDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Changes which should be applied were received from the main node.
		                   |It is necessary to open the designer and update the data base configuration.'");
		
	Else
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", False);
		
		EnableExchangeMessageDataExportRepetitionBeforeRunning();
		
		WarningText = NStr("en = 'Data receipt out of the main node has completed with errors.
		                   |Look for details in event log.'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithUpdate()
	
	Try
		BeforeCheckingIdentifiersOfMetadataObjectsInSubordinateNodeDIB();
	Except
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemDisplay();
	
EndProcedure

&AtServer
Procedure BeforeCheckingIdentifiersOfMetadataObjectsInSubordinateNodeDIB()
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMessagesExchangeDataBeforeRunning") Then
		Return;
	EndIf;
	
	If DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart(
			"IgnoreExportMetadataObjectsBeforeRunningIds") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportAllowed", True);
	SetPrivilegedMode(False);
	
	CheckDataSynchronizationUse();
	
	If GetFunctionalOption("UseDataSync") = True Then
		
		InfobaseNode = DataExchangeServer.MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			TransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
			
			OperationStartDate = CurrentSessionDate();
			
			AuthenticationParameters = ?(ThisIsOfflineWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
			
			// Import only parameters works application.
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode, True,
				False, TransportKind, LongAction, ActionID, FileID, LongOperationAllowed, AuthenticationParameters, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ScriptWithoutSynchronization

&AtServer
Procedure DoNotSynchronizeAndContinueAtServer()
	
	SetPrivilegedMode(True);
	
	If Not UpdateResults.InfobaseUpdateRequired() Then
		If Constants.ImportDataExchangeMessage.Get() = True Then
			Constants.ImportDataExchangeMessage.Set(False);
			DataExchangeServer.ClearDataExchangeMessageFromMainNode();
		EndIf;
	EndIf;
	
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
		"IgnoreExportMessagesExchangeDataBeforeRunning", True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CheckUpdateNecessity()
	
	SetPrivilegedMode(True);
	
	If ConfigurationChanged() Then
		StatusUpdate = "ConfigurationUpdate";
	ElsIf UpdateResults.InfobaseUpdateRequired() Then
		StatusUpdate = "UpdateResults";
	Else
		StatusUpdate = "RefreshEnabledNotNeeded";
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizeAndContinueEnd()
	
	SetEnabled();
	
	If IsBlankString(WarningText) Then
		Close("Continue");
	Else
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Sets the flag showing that the import is repeated if an error of import or update occurs.
// Cleans exchange messages storage received from the main node DIB.
//
Procedure EnableExchangeMessageDataExportRepetitionBeforeRunning()
	
	DataExchangeServer.ClearDataExchangeMessageFromMainNode();
	
	Constants.RetryDataExportExchangeMessagesBeforeStart.Set(True);
	
EndProcedure

&AtServer
Procedure SetEnabled()
	
	If DataExchangeServer.ImportDataExchangeMessage()
	   AND UpdateResults.InfobaseUpdateRequired() Then
		
		Items.FormDoesNotSynchronizeAndContinue.Enabled = False;
		Items.InformationLabelDoesNotSynchronize.Enabled = False;
	Else
		Items.FormDoesNotSynchronizeAndContinue.Enabled = True;
		Items.InformationLabelDoesNotSynchronize.Enabled = True;
	EndIf;
	
	SetFormItemDisplay();
	
EndProcedure

&AtClient
Procedure LongOperationIdleHandler()
	
	AuthenticationParameters = ?(ThisIsOfflineWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
	
	ActionState = DataExchangeServerCall.LongOperationStateForInfobaseNode(
		ActionID,
		InfobaseNode,
		AuthenticationParameters,
		WarningText);
	
	If ActionState = "Active" Then
		
		AttachIdleHandler("LongOperationIdleHandler", 5, True);
		
	Else
		
		If ActionState <> "Executed" Then
			
			HasErrors = True;
			
		EndIf;
		
		LongAction = False;
		
		ProcessLongOperationEnd();
		
		If StatusUpdate = "RefreshEnabledNotNeeded" Then
			
			SynchronizeAndContinueWithoutIBUpdateEnd();
			
		ElsIf StatusUpdate = "UpdateResults" Then
			
			SynchronizeAndContinueWithIBUpdateEnd();
			
		EndIf;
		
		SynchronizeAndContinueEnd();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckDataSynchronizationUse()
	
	If GetFunctionalOption("UseDataSync") = False Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			
			UseDataSync = Constants.UseDataSync.CreateValueManager();
			UseDataSync.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			UseDataSync.DataExchange.Load = True;
			UseDataSync.Value = True;
			UseDataSync.Write();
			
		Else
			
			If DataExchangeServer.GetExchangePlansBeingUsed().Count() > 0 Then
				
				UseDataSync = Constants.UseDataSync.CreateValueManager();
				UseDataSync.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSync.DataExchange.Load = True;
				UseDataSync.Value = True;
				UseDataSync.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemDisplay()
	
	Items.MainPanel.CurrentPage = ?(LongAction, Items.LongAction, Items.Begin);
	Items.ButtonGroupLongOperation.Visible = LongAction;
	Items.ButtonGroupMain.Visible = Not LongAction;
	
EndProcedure

&AtClient
Procedure ProcessLongOperationEnd()
	
	If Not HasErrors Then
		
		ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
			InfobaseNode,
			FileID,
			OperationStartDate);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeForInfobaseNodeFinishLongOperation(
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate
	)
	
	DataExchangeServer.CheckIfExchangesPossible();
	
	DataExchangeServer.CheckUseDataExchange();
	
	AuthenticationParameters = ?(ThisIsOfflineWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = DataExchangeServer.GetFileFromStorageInService(New UUID(FileID),
			InfobaseNode,, AuthenticationParameters);
	Except
		DataExchangeServer.FixExchangeFinishedWithError(InfobaseNode,
			Enums.ActionsAtExchange.DataImport,
			OperationStartDate,
			DetailErrorDescription(ErrorInfo()));
			HasErrors = True;
		Return;
	EndTry;
	
	NewMessage = New BinaryData(FileExchangeMessages);
	DataExchangeServer.SetDataExchangeMessageFromMainNode(NewMessage, InfobaseNode);
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
	EndTry;
	
	Try
		
		OnlyParameters = (StatusUpdate = "UpdateResults");
		TransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(HasErrors, InfobaseNode,
			True, False, TransportKind,,,,, AuthenticationParameters, OnlyParameters);
			
	Except
		
		WriteLogEvent(DataExchangeServer.EventLogMonitorMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion
