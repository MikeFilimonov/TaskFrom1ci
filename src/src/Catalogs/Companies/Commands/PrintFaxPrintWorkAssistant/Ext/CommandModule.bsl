
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	StructureAdvancedOptions = New Structure("FormTitle", NStr("en = 'How can I quickly and easily create fax signature and printing?'"));
	
	PrintCommandParameters = New Array;
	PrintCommandParameters.Add(CommandParameter);
	
	PrintManagementClient.ExecutePrintCommand("Catalog.Companies", "PrintFaxPrintWorkAssistant", PrintCommandParameters, CommandExecuteParameters, StructureAdvancedOptions);
	
EndProcedure
