﻿&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "IncomeAndExpenses");
	Variant.Insert("VariantKey", "IncomeAndExpensesDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
