
#Region FormCommandsEventHandlers

&AtClient
Procedure BackToWork(Command)
	Close();
EndProcedure

&AtClient
Procedure ОК(Command)
	
	If Not ValueIsFilled(RejectionReason) Then
		CommonUseClientServer.MessageToUser(NStr("en = '""Reason"" not filled'"));
		Return;
	EndIf;
	
	RejectedLeadData = New Structure;
	RejectedLeadData.Insert("RejectionReason", RejectionReason);
	RejectedLeadData.Insert("ClosureNote", ClosureNote);
	
	Close(RejectedLeadData);
	
EndProcedure

#EndRegion
