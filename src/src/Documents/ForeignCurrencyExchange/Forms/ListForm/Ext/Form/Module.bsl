
#Region FormEventHandlers

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

&AtClient
Procedure OnOpen(Cancel)
	
	NewArray = New Array();
	For Each Item In CompaniesList Do
		NewArray.Add(Item.Value);
	EndDo;
	FixedArrayCompanies = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.FilterFromAccount.ChoiceParameters = NewParameters;
	Items.FilterToAccount.ChoiceParameters = NewParameters;
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	If ValueIsFilled(FilterCompany) Then
	
		NewParameter = New ChoiceParameter("Filter.Owner", FilterCompany);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterFromAccount.ChoiceParameters = NewParameters;
		Items.FilterToAccount.ChoiceParameters = NewParameters;
	
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
		Items.FilterFromAccount.ChoiceParameters = NewParameters;
		Items.FilterToAccount.ChoiceParameters = NewParameters;
	
	EndIf; 
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterFromAccountOnChange(Item)
	
	SetCompanyFromAccount(FilterFromAccount);
	DriveClientServer.SetListFilterItem(List, "FromAccount", FilterFromAccount, ValueIsFilled(FilterFromAccount));
	
EndProcedure

&AtClient
Procedure FilterToAccountOnChange(Item)
	
	SetCompanyFromAccount(FilterToAccount);
	DriveClientServer.SetListFilterItem(List, "ToAccount", FilterToAccount, ValueIsFilled(FilterToAccount));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCompanyFromAccount(Account)
	
	FilterCompany = GetCompany(Account);
	FilterCompanyOnChange(Undefined);

EndProcedure

&AtServer
Function GetCompany(Account)
	Return CommonUse.GetAttributeValue(Account, "Owner");
EndFunction

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingForeignCurrencyExchange";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningForeignCurrencyExchange";
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

#EndRegion