#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	ExportingHSCodeChoiceListFilling()
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure CodeOnChange(Item)
	
	DafaultExportingHSCode = DafaultExportingHSCode();
	
	If IsBlankString(Object.ExportingHSCode) Then
		
		Object.ExportingHSCode = DafaultExportingHSCode;
		
	EndIf;
	
	ExportingHSCodeChoiceListFilling(DafaultExportingHSCode);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function DafaultExportingHSCode()
	
	Return Left(TrimL(Object.Code), 8);
	
EndFunction

&AtClient
Procedure ExportingHSCodeChoiceListFilling(DafaultExportingHSCode = Undefined)
	
	If DafaultExportingHSCode = Undefined Then
		
		DafaultExportingHSCode = DafaultExportingHSCode();
		
	EndIf;
	
	ExportingHSCodeChoiceList = Items.ExportingHSCode.ChoiceList;
	ExportingHSCodeChoiceList.Clear();
	
	If Not IsBlankString(DafaultExportingHSCode) Then
		
		ExportingHSCodeChoiceList.Add(DafaultExportingHSCode);
		
	EndIf;
	
EndProcedure

#EndRegion