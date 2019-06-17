
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		
		If Items.Find("ContentEmployeeCode") <> Undefined Then		
			
			Items.ContentEmployeeCode.Visible = False;		
			
		EndIf;
		
	EndIf; 	
	
EndProcedure

#EndRegion
