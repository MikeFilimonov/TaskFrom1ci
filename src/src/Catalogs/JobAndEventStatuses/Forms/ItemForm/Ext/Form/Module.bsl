#Region ProcedureFormEventHandlers

// Procedure OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = New Color(0, 0, 0);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure BeforeWriteAtServer
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = New Color(0, 0, 0) Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;
	
EndProcedure

// Procedure BeforeWriteAtServer
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_JobAndEventStatuses");
	
EndProcedure

#EndRegion
