#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddressInBasisDocumentsStorage = Parameters.AddressInBasisDocumentsStorage;
	BasisDocuments.Load(GetFromTempStorage(AddressInBasisDocumentsStorage));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WriteBasisDocumentsToStorage();
		Close(DialogReturnCode.OK);
	EndIf;

EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowDocumentsBases In BasisDocuments Do
		LineNumber = LineNumber + 1;
		If Not ValueIsFilled(RowDocumentsBases.BasisDocument) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Please fill the ""Base document"" column in line #%1 of the ""Base documents"" list.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WriteBasisDocumentsToStorage()
	
	BasisDocumentsInStorage = BasisDocuments.Unload(, "BasisDocument");
	PutToTempStorage(BasisDocumentsInStorage, AddressInBasisDocumentsStorage);
	
EndProcedure

#EndRegion
