

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	Counterparty = Parameters.Counterparty;
	CounterpartyContracts.Load(Parameters.CounterpartyContracts.Unload());
	
	CheckContractsFilling = False;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If CheckContractsFilling Then
	
		For Each Contract In CounterpartyContracts Do
			
			If Not ValueIsFilled(Contract.Contract) Then
				
				MessageText = NStr("en = 'There are rows with a blank counterparty contract in the table'");
				CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
// Procedure command handler OK
//
Procedure OK(Command)
	
	CheckContractsFilling = True;
	Modified = False;
	Close(New Structure("CounterpartyContracts", CounterpartyContracts));
	
EndProcedure

&AtClient
// Procedure command handler Cancel
//
Procedure Cancel(Command)
	
	CheckContractsFilling = False;
	Modified = False;
	Close();
	
EndProcedure

&AtClient
// Procedure command handler SelectCheckboxes
//
Procedure CheckAll(Command)
	
	For Each ListRow In CounterpartyContracts Do
		
		ListRow.Select = True;
		
	EndDo;
	
EndProcedure

&AtClient
// Procedure command handler SelectCheckboxes
//
Procedure UncheckAll(Command)
	
	For Each ListRow In CounterpartyContracts Do
		
		ListRow.Select = False;
		
	EndDo;
	
EndProcedure
// 

#EndRegion
