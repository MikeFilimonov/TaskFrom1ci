#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ElectronicSignature = Parameters.ElectronicSignature;
	
	CertificateValidUntil = CommonUse.ObjectAttributeValue(
		ElectronicSignature, "ValidUntil");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	If DoNotRemindMore Then
		SetMarkAtServer(ElectronicSignature);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SetMarkAtServer(ElectronicSignature)
	
	CertificateObject = ElectronicSignature.GetObject();
	CertificateObject.UserNotifiedOnValidityInterval = True;
	CertificateObject.Write();
	
EndProcedure

#EndRegion
