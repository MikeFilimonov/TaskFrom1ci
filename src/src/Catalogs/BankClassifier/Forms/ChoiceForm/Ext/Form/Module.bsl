#Region FormEventsHandlers
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ReadOnly = True;
	EndIf;
	
	CloseOnElementChoice = Parameters.CloseOnChoice;
	
	CanUpdateClassifier =
		Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode()   // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier); // User with the required rights.

	Items.FormImportClassifier.Visible = CanUpdateClassifier;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportClassifier(Command)
	
	OpenForm("Catalog.BankClassifier.Form.ImportClassifier", , ThisObject);
EndProcedure

&AtClient
Procedure ShowInactiveBanks(Command)
	SwitchVisibleInactiveBanks(NOT Items.FormShowInactiveBanks.Check);
EndProcedure

 ////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtServer
Procedure BankClassificatorSelection(Refs)
	
	WorkWithBanksOverridable.BankClassificatorSelection(Refs);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessSelection(SelectedRow, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	ProcessSelection(Value, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ProcessSelection(SelectedRows, StandardProcessing)
	
	If TypeOf(SelectedRows) <> Type("Array") Then
		Return;
	EndIf;
	
	StandardProcessing = CloseOnElementChoice;
	
	Refs = New Array;
	For Each Ref In SelectedRows Do
		If Items.List.RowData(Ref).IsFolder Then
			Continue;
		EndIf;
		
		Refs.Add(Ref);
	EndDo;
	
	If Refs.Count() > 0 Then
		BankClassificatorSelection(Refs);
		Notify("RefreshAfterAdd");
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	CommonUseClientServer.MessageToUser(
		NStr("en = 'You can''t add the data to the classifier interactive.
		     |You should use the command ""Import classifier""'"));
	
EndProcedure

#EndRegion

&AtServer
Procedure SwitchVisibleInactiveBanks(Visible)
	
	Items.FormShowInactiveBanks.Check = Visible;
	
	CommonUseClientServer.SetFilterDynamicListItem(
			List, "ActivityDiscontinued", False, , , Not Visible);
			
EndProcedure
