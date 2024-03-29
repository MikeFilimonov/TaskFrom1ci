﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	EmptyRefPresentation = String(TypeOf(Object.EmptyRefValue));
	
	If Not Users.InfobaseUserWithFullAccess(, True)
	 OR Catalogs.MetadataObjectIDs.FullNameChangeIsProhibited(Object) Then
		
		Items.FormEnableEditingAbility.Visible = False;
	EndIf;
	
	If CommonUse.IsSubordinateDIBNode() Then
		Items.FormEnableEditingAbility.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	Items.FormEnableEditingAbility.Enabled = False;
	
EndProcedure

&AtClient
Procedure FullNameWhenChanging(Item)
	
	FullName = Object.FullName;
	UpdateIdentificatorProperty();
	
	If FullName <> Object.FullName Then
		Object.FullName = FullName;
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Metadata object is not found by full name:
			     |%1.'"),
			FullName));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateIdentificatorProperty()
	
	Catalogs.MetadataObjectIDs.UpdateIdentificatorProperty(Object);
	
EndProcedure

#EndRegion
