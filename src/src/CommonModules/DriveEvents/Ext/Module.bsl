﻿
#Region SubscriptionToEvents

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentFieldsPresentation(Source, Fields, StandardProcessing) Export
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentFieldsPresentationWriteOnly(Source, Fields, StandardProcessing) Export
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("DeletionMark");
	
EndProcedure

// Predefines a standard presentation of a reference.
//
Procedure GetDocumentPresentation(Source, Data, Presentation, StandardProcessing) Export
	
	If Data.Number = Null
		OR Not ValueIsFilled(Data.Ref) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Status = "";
	If Data.DeletionMark Then
		Status = NStr("en = '(deleted)'");
	ElsIf Data.Property("Posted") AND Not Data.Posted Then
		Status = NStr("en = '(not posted)'");
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 dated %3 %4'"),
		Data.Ref.Metadata().Presentation(),
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		Status);
	
EndProcedure

#EndRegion
