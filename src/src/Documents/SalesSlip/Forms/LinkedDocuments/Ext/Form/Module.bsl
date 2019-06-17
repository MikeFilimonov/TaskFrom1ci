#Region FormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddressInRelatedDocumentsStorage = Parameters.AddressInRelatedDocumentsStorage;
	LinkedDocuments.Load(GetFromTempStorage(AddressInRelatedDocumentsStorage));
	
	If LinkedDocuments.Count() = 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If LinkedDocuments.Count() = 1 Then
		CurDocument = LinkedDocuments[0].RelatedDocument;
		If ValueIsFilled(CurDocument) Then
			OpenDocument(CurDocument);
		EndIf;
		
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler OK form.
//
&AtClient
Procedure OK(Command)
	
	If Items.LinkedDocuments.CurrentData <> Undefined Then
		CurDocument = Items.LinkedDocuments.CurrentData.RelatedDocument;
		If ValueIsFilled(CurDocument) Then
			OpenDocument(CurDocument);
		EndIf;
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure - Selection PM LinkedDocuments form event handler.
//
&AtClient
Procedure RelatedDocumentsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurDocument = LinkedDocuments[SelectedRow].RelatedDocument;
	If ValueIsFilled(CurDocument) Then
		OpenDocument(CurDocument);
	EndIf;
	
	Close();
	
EndProcedure

// Procedure parses the document value type and opens it form.
//
&AtClient
Procedure OpenDocument(CurDocument)
	
	If TypeOf(CurDocument) = Type("DocumentRef.CashVoucher") Then
		OpenForm("Document.CashVoucher.ObjectForm", New Structure("Key", CurDocument));
	ElsIf TypeOf(CurDocument) = Type("DocumentRef.CreditNote") Then
		OpenForm("Document.CreditNote.ObjectForm", New Structure("Key", CurDocument));
	ElsIf TypeOf(CurDocument) = Type("DocumentRef.ProductReturn") Then
		OpenForm("Document.ProductReturn.ObjectForm", New Structure("Key", CurDocument));
	EndIf;
	
EndProcedure

#EndRegion
