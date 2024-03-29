﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Function InformationExchangeAbsoluteDirectory(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	DataAreaTransportExchangeSettings.InformationExchangeDirectory AS InformationExchangeDirectoryRelative,
	|	ISNULL(DataAreasTransportExchangeSettings.FILEInformationExchangeDirectory, """") AS CommonInformationExchangeDirectory
	|FROM
	|	InformationRegister.DataAreaTransportExchangeSettings AS DataAreaTransportExchangeSettings
	|		LEFT JOIN InformationRegister.DataAreasTransportExchangeSettings AS DataAreasTransportExchangeSettings
	|		ON (DataAreasTransportExchangeSettings.CorrespondentEndPoint = DataAreaTransportExchangeSettings.CorrespondentEndPoint)
	|WHERE
	|	DataAreaTransportExchangeSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Connection settings for the ""%1"" correspondent are not specified.'"), String(Correspondent));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	CommonInformationExchangeDirectory = Selection.CommonInformationExchangeDirectory;
	InformationExchangeDirectoryRelative = Selection.InformationExchangeDirectoryRelative;
	
	If IsBlankString(CommonInformationExchangeDirectory)
		OR IsBlankString(InformationExchangeDirectoryRelative) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Connection settings for the ""%1"" correspondent are not specified.'"), String(Correspondent));
	EndIf;
	
	Return CommonUseClientServer.GetFullFileName(CommonInformationExchangeDirectory, InformationExchangeDirectoryRelative);
EndFunction

Function TransportKind(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	ISNULL(DataAreasTransportExchangeSettings.ExchangeMessageTransportKindByDefault, UNDEFINED) AS TransportKind
	|FROM
	|	InformationRegister.DataAreaTransportExchangeSettings AS DataAreaTransportExchangeSettings
	|		LEFT JOIN InformationRegister.DataAreasTransportExchangeSettings AS DataAreasTransportExchangeSettings
	|		ON (DataAreasTransportExchangeSettings.CorrespondentEndPoint = DataAreaTransportExchangeSettings.CorrespondentEndPoint)
	|WHERE
	|	DataAreaTransportExchangeSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.TransportKind;
EndFunction

Function TransportSettings(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	"""" AS FILEInformationExchangeDirectory,
	|	"""" AS FTPConnectionPath,
	|	
	|	DataAreaTransportExchangeSettings.InformationExchangeDirectory AS InformationExchangeDirectoryRelative,
	|	
	|	DataAreasTransportExchangeSettings.FILEInformationExchangeDirectory AS FILEInformationExchangeCommonDirectory,
	|	DataAreasTransportExchangeSettings.FILECompressOutgoingMessageFile,
	|	
	|	DataAreasTransportExchangeSettings.FTPConnectionPath AS FTPCommonInformationExchangeDirectory,
	|	DataAreasTransportExchangeSettings.FTPCompressOutgoingMessageFile,
	|	DataAreasTransportExchangeSettings.FTPConnectionMaximumValidMessageSize,
	|	DataAreasTransportExchangeSettings.FTPConnectionPassword,
	|	DataAreasTransportExchangeSettings.FTPConnectionPassiveConnection,
	|	DataAreasTransportExchangeSettings.FTPConnectionUser,
	|	DataAreasTransportExchangeSettings.FTPConnectionPort,
	|	
	|	DataAreasTransportExchangeSettings.ExchangeMessageTransportKindByDefault,
	|	DataAreasTransportExchangeSettings.ExchangeMessageArchivePassword,
	|	
	|	ExchangeTransportSettings.WSURLWebService,
	|	ExchangeTransportSettings.WSUserName,
	|	ExchangeTransportSettings.WSPassword
	|	
	|FROM
	|	InformationRegister.DataAreaTransportExchangeSettings AS DataAreaTransportExchangeSettings
	|		LEFT JOIN InformationRegister.DataAreasTransportExchangeSettings AS DataAreasTransportExchangeSettings
	|		ON (DataAreasTransportExchangeSettings.CorrespondentEndPoint = DataAreaTransportExchangeSettings.CorrespondentEndPoint)
	|		
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON (ExchangeTransportSettings.Node = DataAreaTransportExchangeSettings.CorrespondentEndPoint)
	|WHERE
	|	DataAreaTransportExchangeSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Result = DataExchangeServer.QueryResultIntoStructure(QueryResult);
	
	Result.FILEInformationExchangeDirectory = CommonUseClientServer.GetFullFileName(
		Result.FILEInformationExchangeCommonDirectory,
		Result.InformationExchangeDirectoryRelative);
	
	Result.FTPConnectionPath = CommonUseClientServer.GetFullFileName(
		Result.FTPCommonInformationExchangeDirectory,
		Result.InformationExchangeDirectoryRelative);
	
	Result.Insert("UseTempDirectoryForSendingAndReceivingMessages", True);
	
	If Result.ExchangeMessageTransportKindByDefault = Enums.ExchangeMessagesTransportKinds.FTP Then
		
		FTPParameters = DataExchangeServer.FTPServerNameAndPath(Result.FTPConnectionPath);
		
		Result.Insert("FTPServer", FTPParameters.Server);
		Result.Insert("FTPPath",   FTPParameters.Path);
		
	Else
		Result.Insert("FTPServer", "");
		Result.Insert("FTPPath",   "");
	EndIf;
	
	DataExchangeServer.AddTransactionItemCountToTransportSettings(Result);
	
	Return Result;
EndFunction

Function TransportSettingsWS(Val Correspondent) Export
	
	QueryText =
	"SELECT
	|	ExchangeTransportSettings.WSURLWebService,
	|	ExchangeTransportSettings.WSUserName,
	|	ExchangeTransportSettings.WSPassword
	|FROM
	|	InformationRegister.DataAreaTransportExchangeSettings AS DataAreaTransportExchangeSettings
	|		LEFT JOIN InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|		ON (ExchangeTransportSettings.Node = DataAreaTransportExchangeSettings.CorrespondentEndPoint)
	|WHERE
	|	DataAreaTransportExchangeSettings.Correspondent = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Web service connection settings are not specified for the correspondent %1.'"),
			String(Correspondent));
	EndIf;
	
	Return DataExchangeServer.QueryResultIntoStructure(QueryResult);
EndFunction

//

// Updates the record in the register by the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateRecordToInformationRegister(RecordStructure, "DataAreaTransportExchangeSettings");
	
EndProcedure

// Adds the record to the register by the passed structure values
//
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreaTransportExchangeSettings");
	
EndProcedure

#EndRegion

#EndIf
