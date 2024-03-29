﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

#Region LocalVariables

Var CurrentInitialization;
Var CurrentFileName;
Var ReadStream;
Var CurrentObject;
Var CurrentArtifacts;

#EndRegion

#EndRegion

#Region ServiceProgramInterface

Procedure OpenFile(Val FileName) Export
	
	If CurrentInitialization Then
		
		Raise NStr("en = 'The object has already been initialized earlier.'");
		
	Else
		
		CurrentFileName = FileName;
		
		ReadStream = New XMLReader();
		ReadStream.OpenFile(FileName);
		ReadStream.MoveToContent();

		If ReadStream.NodeType <> XMLNodeType.StartElement
			Or ReadStream.Name <> "Data" Then
			
			Raise(NStr("en = 'XML reading error. Invalid file format. Awaiting Data item start.'"));
		EndIf;

		If Not ReadStream.Read() Then
			Raise(NStr("en = 'XML reading error. File end is detected.'"));
		EndIf;
		
		//
		
		CurrentInitialization = True;
		
	EndIf;
	
EndProcedure

Function ReadInfobaseDataObject() Export
	
	If ReadStream.NodeType = XMLNodeType.StartElement Then
		
		If ReadStream.Name <> "DumpElement" Then
			Raise NStr("en = 'XML reading error. Invalid file format. Awaiting DumpElement item start.'");
		EndIf;
		
		ReadStream.Read(); // <DumpElement>
		
		CurrentArtifacts = New Array();
		
		If ReadStream.Name = "Artefacts" Then
			
			ReadStream.Read(); // <Artefacts>
			While ReadStream.NodeType <> XMLNodeType.EndElement Do
				
				URIElement = ReadStream.NamespaceURI;
				ItemName = ReadStream.Name;
				ArtifactType = XDTOFactory.Type(URIElement, ItemName);
				
				Try
					
					ArtifactFragment = ReadFlowFragment();
					ArtifactReadStream = FragmentReadStream(ArtifactFragment);
					
					Artifact = XDTOFactory.ReadXML(ArtifactReadStream, ArtifactType);
					
				Except
					
					OriginalException = DetailErrorDescription(ErrorInfo());
					XMLReaderCallException(ArtifactFragment, OriginalException);
					
				EndTry;
				
				CurrentArtifacts.Add(Artifact);
				
			EndDo;
			ReadStream.Read(); // </Artefacts>
			
		EndIf;
		
		Try
			
			ObjectFragment = ReadFlowFragment();
			ObjectReadStream = FragmentReadStream(ObjectFragment);
			
			CurrentObject = XDTOSerializer.ReadXML(ObjectReadStream);
			
		Except
			
			OriginalException = DetailErrorDescription(ErrorInfo());
			XMLReaderCallException(ObjectFragment, OriginalException);
			
		EndTry;
		
		ReadStream.Read(); // </DumpElement>
		
		Return True;
		
	Else
		
		CurrentObject = Undefined;
		CurrentArtifacts = Undefined;
		
		Return False;
		
	EndIf;
	
EndFunction

Function CurrentObject() Export
	
	Return CurrentObject;
	
EndFunction

Function CurrentObjectArtifacts() Export
	
	Return CurrentArtifacts;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// The current item of the XML reader is being copied.
//
// Parameters:
// ReadStream - XMLReader - Export reader.
//
// Returns:
// String - XML fragment.
//
Function ReadFlowFragment()
	
	WriteFragment = New XMLWriter;
	WriteFragment.SetString();
	
	FragmentNodeName = ReadStream.Name;
	
	RootNode = True;
	Try
		
		While Not (ReadStream.NodeType = XMLNodeType.EndElement
				AND ReadStream.Name = FragmentNodeName) Do
			
			WriteFragment.WriteCurrent(ReadStream);
			
			If ReadStream.NodeType = XMLNodeType.StartElement Then
				
				If RootNode Then
					NamespaceURI = ReadStream.NamespaceContext.NamespaceURI();
					For Each URI In NamespaceURI Do
						WriteFragment.WriteNamespaceMapping(ReadStream.NamespaceContext.FindPrefix(URI), URI);
					EndDo;
					RootNode = False;
				EndIf;
				
				ElementNamespaceURIPrefixes = ReadStream.NamespaceContext.NamespaceMappings();
				For Each KeyAndValue In ElementNamespaceURIPrefixes Do
					Prefix = KeyAndValue.Key;
					URI = KeyAndValue.Value;
					WriteFragment.WriteNamespaceMapping(Prefix, URI);
				EndDo;
				
			EndIf;
			
			ReadStream.Read();
		EndDo;
		
		WriteFragment.WriteCurrent(ReadStream);
		
		ReadStream.Read();
	Except
		TextEL = ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'An error occurred while copying a fragment of the source file. Partially copied
			     |fragment:%1'"),
				WriteFragment.Close());
		WriteLogEvent(NStr("en = 'Import/export data.XML reading error'", 
			ServiceTechnologyIntegrationWithSSL.MainLanguageCode()), EventLogLevel.Error, , , TextEL);
		Raise;
	EndTry;
	
	Fragment = WriteFragment.Close();
	
	Return Fragment;
	
EndFunction

Function FragmentReadStream(Val Fragment)
	
	FragmentReading = New XMLReader();
	FragmentReading.SetString(Fragment);
	FragmentReading.MoveToContent();
	
	Return FragmentReading;
	
EndFunction

Procedure XMLReaderCallException(Val Fragment, Val ErrorText)
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'An error occurred while reading data from file %1: while reading fragment 
		     |
		     |%2
		     |
		     |an error occurred:
		     |
		     |%3.'"),
		CurrentFileName,
		Fragment,
		ErrorText
	);
	
EndProcedure

#EndRegion

#Region Initialize

CurrentInitialization = False;

#EndRegion

#EndIf