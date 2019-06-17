
&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ShowCreateGroup") Then
		Items.FormCreateFolder.Visible = Parameters.ShowCreateGroup;
	EndIf;
	
EndProcedure
