
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Template is not filled.'");
		Message.Message();
	EndIf;	
	
EndProcedure
