﻿
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	
#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
	DomainAndUserTable = OSUsers();
#ElsIf ThinClient Then
	DomainAndUserTable = New FixedArray (OSUsers());
#EndIf
	
	FillDomainList();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersDomainTable

&AtClient
Procedure DomainTableOnActivateRow(Item)
	
	CurrentDomainUsersList.Clear();
	
	If Item.CurrentData <> Undefined Then
		DomainName = Item.CurrentData.DomainName;
		
		For Each Record In DomainAndUserTable Do
			If Record.DomainName = DomainName Then
				
				For Each User In Record.Users Do
					DomainUser = CurrentDomainUsersList.Add();
					DomainUser.UserName = User;
				EndDo;
				Break;
				
			EndIf;
		EndDo;
		
		CurrentDomainUsersList.Sort("UserName");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersUserTable

&AtClient
Procedure DomainUsersTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	If Items.DomainTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select domain.'"));
		Return;
	EndIf;
	DomainName = Items.DomainTable.CurrentData.DomainName;
	
	If Items.DomainUserTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select domain user.'"));
		Return;
	EndIf;
	UserName = Items.DomainUserTable.CurrentData.UserName;
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FillDomainList()
	
	DomainList.Clear();
	
	For Each Record In DomainAndUserTable Do
		Domain = DomainList.Add();
		Domain.DomainName = Record.DomainName;
	EndDo;
	
	DomainList.Sort("DomainName");
	
EndProcedure

&AtClient
Procedure ComposeResultAndCloseForm()
	
	DomainName = Items.DomainTable.CurrentData.DomainName;
	UserName = Items.DomainUserTable.CurrentData.UserName;
	
	ChoiceResult = "\\" + DomainName + "\" + UserName;
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion