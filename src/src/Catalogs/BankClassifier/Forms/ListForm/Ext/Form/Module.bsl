
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ReadOnly = True;
	EndIf;
	
	CanUpdateClassifier = Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode() // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier); // User with the required rights.

	Items.FormImportClassifier.Visible = CanUpdateClassifier;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportClassifier(Command)
	FormParameters = New Structure("OpenFromList");
	OpenForm("Catalog.BankClassifier.Form.ImportClassifier", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	CommonUseClientServer.MessageToUser(
		NStr("en = 'You can not add the data interactively, 
		     |use the command ""Import classifier"" instead'"),,,,
		Cancel);
	
EndProcedure

#EndRegion