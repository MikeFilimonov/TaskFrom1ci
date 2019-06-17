#Region Formhandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ValueList = New ValueList;
	CompaniesSelection = Catalogs.Companies.Select();
	While CompaniesSelection.Next() Do
		ValueList.Add(CompaniesSelection.Ref);
	EndDo;
	CompaniesList = ValueList;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterBankAccount 	= Settings.Get("FilterBankAccount");
	FilterTypeOperations 		= Settings.Get("FilterTypeOperations");
	
	If ValueIsFilled(FilterCompany) Then	
		NewParameter = New ChoiceParameter("Filter.Owner", FilterCompany);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterBankAccount.ChoiceParameters = NewParameters;	
	Else	
		NewArray = New Array();	
		For Each Item In CompaniesList Do
		    NewArray.Add(Item.Value);
		EndDo;
		FixedArrayCompanies = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterBankAccount.ChoiceParameters = NewParameters;	
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "BankAccount", FilterBankAccount, ValueIsFilled(FilterBankAccount));
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	If ValueIsFilled(FilterCompany) Then
	
		NewParameter = New ChoiceParameter("Filter.Owner", FilterCompany);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterBankAccount.ChoiceParameters = NewParameters;	
	
	Else
	
		NewArray = New Array();	
		For Each Item In CompaniesList Do
		    NewArray.Add(Item.Value);
		EndDo;
		FixedArrayCompanies = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterBankAccount.ChoiceParameters = NewParameters;
	
	EndIf; 
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterBankAccountOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "BankAccount", FilterBankAccount, ValueIsFilled(FilterBankAccount));
EndProcedure

&AtClient
Procedure FilterOperationKindOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
EndProcedure

#EndRegion

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingPaymentExpense";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningPaymentExpense";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
