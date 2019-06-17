#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	Code = "";
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
			
	If Not IsFolder Then
	
		If StrLen(TrimAll(Code)) <> 8 AND StrLen(TrimAll(Code)) <> 11 Then
			MessageText = NStr("en = 'SWIFT must have 8 or 11 characters.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Code",
				Cancel
			);
		EndIf;

	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Code");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf