
#Region FormEventHandlers

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Title", Title);
	Parameters.Property("MessageText", MessageText);
	Parameters.Property("VisibleDoNotShowAgain", VisibleDoNotShowAgain);
	
	CommonUseClientServer.SetFormItemProperty(Items, "DontShowAgain", "Visible", VisibleDoNotShowAgain);
	
EndProcedure

&AtClient
// Procedure - the OK command handler
//
Procedure OK(Command)
	
	Close(New Structure("CustomSettingValue", Not DontShowAgain));
	
EndProcedure

#EndRegion
