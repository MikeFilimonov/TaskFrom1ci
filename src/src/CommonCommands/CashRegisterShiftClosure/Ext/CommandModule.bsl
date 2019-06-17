
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Peripherals.Form.CashRegisterShiftClosure", , CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness,,,, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure
