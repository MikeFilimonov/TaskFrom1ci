#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	ContactPerson	= Undefined;
	IsDefault		= False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("Owner") Then
		SalesRep = CommonUse.ObjectAttributeValue(FillingData.Owner, "SalesRep");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf