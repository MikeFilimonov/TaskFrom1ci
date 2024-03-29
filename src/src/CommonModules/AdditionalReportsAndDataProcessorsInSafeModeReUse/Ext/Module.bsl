﻿////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", safe mode extension.
// Procedures and functions with repeated use of returned values.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns an array of methods that can
// be run by the safe mode expansion.
//
// Return values: Array(String).
//
Function GetAllowedMethods() Export
	
	Result = New Array();
	
	// AdditionalReportsAndDataProcessorsInSafeMode
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.XMLReaderFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.XMLWriterToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.HTMLReadFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.RecordHTMLToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.FastInfosetReadingFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.RecordFastInfosetToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.CreateComObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ConnectExternalComponentFromCommonConfigurationTemplate");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ConnectExternalComponentFromConfigurationTemplate");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.GetFileFromExternalObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.TransferFileToExternalObject");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.GetFileFromInternet");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.ImportFileInInternet");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.WSConnection");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.PostingDocuments");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeMode.WriteObjects");
	// AdditionalReportsAndDataProcessorsInSafeMode
	
	// AdditionalReportsAndDataProcessorsInSafeModeServerCall
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.DocumentTextFromBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.TextDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.SpreadsheetDocumentFormBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.TabularDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.FormattedDocumentInBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.BinaryDataRow");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.StringToBinaryData");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.UnpackArchive");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.PackFilesInArchive");
	Result.Add("AdditionalReportsAndDataProcessorsInSafeModeServerCall.ExecuteScriptInSafeMode");
	// End AdditionalReportsAndDataProcessorsInSafeModeServerCall
	
	Return New FixedArray(Result);
	
EndFunction

// Returns a dictionary of permissions additional reports and
// data processors kinds synonyms for and their parameters (for display in the user interface).
//
// Returns:
//  FixedMap:
//    Key - XDTOType corresponding
//    permission kind, Value - Structure, keys:
//      Presentation - String, brief presentation type
//      permissions, Description - String, detailed description
//      of permission kind, Parameters - ValueTable, columns:
//        Name - String, property name that
//        is defined for XDTOType, Description - String, description of the permission
//          parameter consequences for
//        the specified parameter value, AnyValueDescription - String, description of
//          the permission parameter consequences for unspecified parameter value.
//
Function Dictionary() Export
	
	Result = New Map();
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	Presentation = NStr("en = 'Receiving data from the Internet'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to receive data from the Internet'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "Host", NStr("en = 'from server %1'"), NStr("en = 'from any server'"));
	AddParameter(Parameters, "Protocol", NStr("en = 'by protocol %1'"), NStr("en = 'by any protocol'"));
	AddParameter(Parameters, "Port", NStr("en = 'via port %1'"), NStr("en = 'via any port'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.GetDataTypeOfInternet(),
		New Structure(
			"Presentation,Definition,Parameters",
			Presentation,
			Definition,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("en = 'Data transfer to Internet'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to send data to the Internet'");
	Effects = NStr("en = 'Warning! Data sending potentially can
	               |used by an additional report or data processor for
	               |acts that are not alleged by administrator of infobases.
	               |
	               |Use this additional report or data processor only if you trust
	               |the developer and control restriction (server, protocol and port),
	               |attached to issued permissions.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "Host", NStr("en = 'to server %1'"), NStr("en = 'on any server'"));
	AddParameter(Parameters, "Protocol", NStr("en = 'by protocol %1'"), NStr("en = 'by any protocol'"));
	AddParameter(Parameters, "Port", NStr("en = 'via port %1'"), NStr("en = 'via any port'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfTransferDataOnInternet(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	Presentation = NStr("en = 'Contacting web services in Internet'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to refer to web services on the Internet (additional report or data processor may receive and send some information on the Internet.'");
	Effects = NStr("en = 'Warning! Appeal to web services potentially
	               |can be used by an additional report or data
	               |processor for actions that are not alleged by infobases administrator.
	               |
	               |Use this additional report or data processor only if you
	               |trust the developer and control restriction (connection address), attached
	               |to issued permissions.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "WsdlDestination", NStr("en = 'at address %1'"), NStr("en = 'by any address'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeWSConnection(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SoapConnect
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	Presentation = NStr("en = 'Create COM object'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to use mechanisms of external software using COM connection'");
	Effects = NStr("en = 'Warning! Use of thirdparty software funds can
	               |be used by an additional report or data processor for
	               |actions that are not alleged by infobase administrator, and also for
	               |unauthorized circumvention of the restrictions imposed by the additional processing in safe mode.
	               |
	               |Use this additional report or data processor only if
	               |you trust the developer and control restriction (application ID),
	               |attached to issued permissions.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "ProgId", NStr("en = 'with programmatic identifier %1'"), NStr("en = 'with any programmatic identifier'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeCreatingCOMObject(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}CreateComObject
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	Presentation = NStr("en = 'Create object of external component'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to use mechanisms of external software by creating object of external component, which is supplied in the configuration template.'");
	Effects = NStr("en = 'Warning! Use of thirdparty software funds can
	               |be used by an additional report or data processor for
	               |actions that are not alleged by infobase administrator, and also for
	               |unauthorized circumvention of the restrictions imposed by the additional processing in safe mode.
	               |
	               |Use this additional report or data processor only if you
	               |trust the developer and control restriction (template name, from which connection
	               |is external component), attached to issued permissions.'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "TemplateName", NStr("en = 'from template %1'"), NStr("en = 'from any template'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeOfConnectionOfExternalComponents(),
		New Structure(
			"Presentation,Definition,Effects,Parameters",
			Presentation,
			Definition,
			Effects,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}AttachAddin
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	Presentation = NStr("en = 'Receive files from external object'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to receive files from external software (for example, using COM connection or external component)'");
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.GetFileTypeFromExternalObject(),
		New Structure(
			"Presentation,Description",
			Presentation,
			Definition));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}GetFileFromExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	Presentation = NStr("en = 'File transfer to the external object'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to transfer files to external software (for example, using COM connection or external component)'");
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypeFileTransferIntoExternalObject(),
		New Structure(
			"Presentation,Description",
			Presentation,
			Definition));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToExternalSoftware
	
	// {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Presentation = NStr("en = 'Documents posting'");
	Definition = NStr("en = 'Additional report or data processor will be allowed to change document posting state'");
	
	Parameters = ParameterTable();
	AddParameter(Parameters, "DocumentType", NStr("en = 'documents with type %1'"), NStr("en = 'any documents'"));
	AddParameter(Parameters, "Action", NStr("en = 'allowed action: %1'"), NStr("en = 'any posting state change'"));
	
	Result.Insert(
		AdditionalReportsAndDataProcessorsInSafeModeInterface.TypePostingDocuments(),
		New Structure(
			"Presentation,Definition,Parameters,ShowToUser",
			Presentation,
			Definition,
			Parameters));
	
	// End {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}SendFileToInternet
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddParameter(Val ParameterTable, Val Name, Val Definition, Val DescriptionOfAnyValue)
	
	Parameter = ParameterTable.Add();
	Parameter.Name = Name;
	Parameter.Definition = Definition;
	Parameter.DescriptionOfAnyValue = DescriptionOfAnyValue;
	
EndProcedure

Function ParameterTable()
	
	Result = New ValueTable();
	Result.Columns.Add("Name", New TypeDescription("String"));
	Result.Columns.Add("Definition", New TypeDescription("String"));
	Result.Columns.Add("DescriptionOfAnyValue", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

#EndRegion
