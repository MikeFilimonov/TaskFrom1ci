﻿
#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DeleteRecords(Command)
	
	QuestionText = NStr("en = 'Deletion of object version records can lead to inability to perform analysis of the whole object change chain. Continue?'");
		
	NotifyDescription = New NotifyDescription("DeleteRecordsEnd", ThisObject, Items.List.SelectedRows);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Warning'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure DeleteRecordsEnd(QuestionResult, RecordList) Export
	If QuestionResult = DialogReturnCode.Yes Then
		DeleteVersionsFromRegister(RecordList);
	EndIf;
EndProcedure

&AtServer
Procedure DeleteVersionsFromRegister(Val RecordList)
	
	For Each RecordKey In RecordList Do
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		
		RecordSet.Filter.Object.Value = RecordKey.Object;
		RecordSet.Filter.Object.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.Object.Use = True;
		
		RecordSet.Filter.VersionNumber.Value = RecordKey.VersionNumber;
		RecordSet.Filter.VersionNumber.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.VersionNumber.Use = True;
		
		RecordSet.Write(True);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
