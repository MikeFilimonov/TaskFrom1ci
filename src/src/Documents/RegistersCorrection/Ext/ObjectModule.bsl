#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// The procedure sets the activity flag for registers records.
//
Procedure SetActiveForRegisterRecords(ActivityFlag)
	
	For Each RegisterRecord In RegisterRecords Do
		
		RegisterRecord.Read();
		RegisterRecord.SetActive(ActivityFlag);
			
	EndDo;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsNew() AND Ref.DeletionMark <> DeletionMark Then
		SetActiveForRegisterRecords(NOT DeletionMark);
	ElsIf DeletionMark Then
		SetActiveForRegisterRecords(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf