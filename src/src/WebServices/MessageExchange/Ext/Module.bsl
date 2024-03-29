﻿
#Region ServiceProceduresAndFunctions

#Region OperationHandlers

// Corresponds to operation DeliverMessages.
Function DeliverMessages(SenderCode, StreamStorage)
	
	SetPrivilegedMode(True);
	
	// Get a reference to the sender.
	Sender = ExchangePlans.MessageExchange.FindByCode(SenderCode);
	
	If Sender.IsEmpty() Then
		
		Raise NStr("en = 'Invalid endpoint connection settings.'");
		
	EndIf;
	
	ImportedMessages = Undefined;
	DataReadInPart = False;
	
	// Importing messages into the infobase.
	MessageExchangeInternal.SerializeDataFromStream(
		Sender,
		//StreamStorage.Get(),
		MessageExchangeInternal.ConvertExchangePlanMessageData(StreamStorage.Get()),
		ImportedMessages,
		DataReadInPart);
	
	// Processing the queue of messages.
	If CommonUse.FileInfobase() Then
		
		MessageExchangeInternal.ProcessSystemMessageQueue(ImportedMessages);
		
	Else
		
		BackgroundJobParameters = New Array;
		BackgroundJobParameters.Add(ImportedMessages);
		
		BackgroundJobs.Execute("MessageExchangeInternal.ProcessSystemMessageQueue", BackgroundJobParameters);
		
	EndIf;
	
	If DataReadInPart Then
		
		Raise NStr("en = 'Error occurred when delivering quick messages
		           |- some messages were not delivered due to specified data area locks!
		           |
		           |These messages will be processed within the messages processing queue of the system.'");
		
	EndIf;
	
EndFunction

// Corresponds to operation DeliverMessages.
Function GetInfobaseParameters(ThisEndPointDescription)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(MessageExchangeInternal.ThisNodeCode()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Code = String(New UUID());
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	ElsIf IsBlankString(MessageExchangeInternal.ThisNodeDescription()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Description = ?(IsBlankString(ThisEndPointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndPointDescription);
		ThisNodeObject.Write();
		
	EndIf;
	
	ThisPointParameters = CommonUse.ObjectAttributesValues(MessageExchangeInternal.ThisNode(), "Code, description");
	
	Result = New Structure;
	Result.Insert("Code",          ThisPointParameters.Code);
	Result.Insert("Description", ThisPointParameters.Description);
	
	Return ValueToStringInternal(Result);
EndFunction

// Corresponds to operation ConnectEndPoint.
Function ToConnectEndPoint(Code, Description, RecipientConnectionSettingsString)
	
	Cancel = False;
	
	//MessageExchangeInternal.ConnectEndPointAtRecipient(Cancel, Code, Description, ValueFromStringInternal(RecipientConnectionSettingsString));
	MessageExchangeInternal.ConnectEndpointAtRecipient(Cancel, Code, Description, MessageExchangeInternal.ConvertRecipientConnectionSettings(ValueFromStringInternal(RecipientConnectionSettingsString)));
	
	Return Not Cancel;
EndFunction

// Corresponds to operation UpdateConnectionSettings.
Function RefreshConnectionSettings(Code, ConnectionSettingsString)
	
	//ConnectionSettings = ValueFromStringInternal(ConnectionSettingsString);
	ConnectionSettings = MessageExchangeInternal.ConvertRecipientConnectionSettings(ValueFromStringInternal(ConnectionSettingsString));
	
	SetPrivilegedMode(True);
	
	EndPoint = ExchangePlans.MessageExchange.FindByCode(Code);
	If EndPoint.IsEmpty() Then
		Raise NStr("en = 'Invalid endpoint connection settings.'");
	EndIf;
	
	BeginTransaction();
	Try
		
		// Update the connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", EndPoint);
		RecordStructure.Insert("ExchangeMessageTransportKindByDefault", Enums.ExchangeMessagesTransportKinds.WS);
		
		ConnectionSettings = MessageExchangeInternal.ConvertRecipientConnectionSettings(ConnectionSettings);
		
		RecordStructure.Insert("WSURL",   ConnectionSettings.WSURLWebService);
		RecordStructure.Insert("WSUserName", ConnectionSettings.WSUserName);
		RecordStructure.Insert("WSPassword",          ConnectionSettings.WSPassword);
		RecordStructure.Insert("WSRememberPassword", True);
		
		// add record to the information register
		InformationRegisters.ExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndFunction

// Corresponds to operation SetLeadingEndPoint.
Function SetLeadingEndPoint(ThisEndPointCode, LeadingEndPointCode)
	
	MessageExchangeInternal.SetLeadingEndPointAtRecipient(ThisEndPointCode, LeadingEndPointCode);
	
EndFunction

// Corresponds to operation TestConnectionRecipient.
Function CheckConnectionAtRecipient(ConnectionSettingsString, SenderCode)
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	ConnectionSettingsStructure = MessageExchangeInternal.ConvertRecipientConnectionSettings(ValueFromStringInternal(ConnectionSettingsString));
	WSProxy = MessageExchangeInternal.GetWSProxy(ConnectionSettingsStructure, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	//WSProxy.CheckConnectionAtSender(SenderCode);
	WSProxy.TestConnectionSender(SenderCode);
	
EndFunction

// Corresponds to operation TestConnectionSender.
Function CheckConnectionAtSender(SenderCode)
	
	SetPrivilegedMode(True);
	
	If MessageExchangeInternal.ThisNodeCode() <> SenderCode Then
		
		Raise NStr("en = 'Receiver base connection settings indicate the another sender.'");
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion
