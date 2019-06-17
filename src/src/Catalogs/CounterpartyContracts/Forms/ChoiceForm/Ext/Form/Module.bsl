
#Region GeneralPurposeProceduresAndFunctions

// Sets the filter and conditional list appearance if a counterparty has the billing details by contracts.
//
&AtServer
Procedure SetFilterAndConditionalAppearance()
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			AND ConditionalAppearanceItem.Presentation = "Mismatch to documents conditions" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	If Not ControlContractChoice Then
		Return;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Owner", Counterparty);
	DriveClientServer.SetListFilterItem(List, "Company", Company);
	
	If ValueIsFilled(Currency) Then
		DriveClientServer.SetListFilterItem(List, "SettlementsCurrency", Currency);
	EndIf;
	
	If Not ControlCorrespondenceWithDocument Then
		Return;
	EndIf;
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	OrGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	OrGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	OrGroup.Use = True;
	
	FilterItem = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Company");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue = Company;
	
	FilterItem = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("ContractKind");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
	FilterItem.RightValue = ContractType;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Mismatch to documents conditions";
	
EndProcedure

// Checks the matching of the contract attributes "Company" and "ContractKind" to the passed parameters.
//
&AtServerNoContext
Function CheckContractToDocumentConditionAccordance(ControlCorrespondenceWithDocument, MessageText, Contract, Company, Counterparty, ContractKindsList)
	
	If Not ControlCorrespondenceWithDocument Then
		Return True;
	EndIf;
	
	Return Catalogs.CounterpartyContracts.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList);
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ControlContractChoice", ControlContractChoice);
	Parameters.Property("Company"  , Company);
	Parameters.Property("Counterparty"   , Counterparty);
	Parameters.Property("ContractType", ContractType);
	Parameters.Property("Currency", Currency);

	If Not DriveReUse.CounterpartyContractsControlNeeded() Then
		ControlCorrespondenceWithDocument = False;
	Else
		ControlCorrespondenceWithDocument = ControlContractChoice;
	EndIf;
	
	SetFilterAndConditionalAppearance();
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, CommandBar);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler ValueSelection of the List table.
//
&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	QuestionText = "";
	If Not CheckContractToDocumentConditionAccordance(ControlCorrespondenceWithDocument, QuestionText, Value, Company, Counterparty, ContractType) Then
		
		StandardProcessing = False;
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("Value", Value);
		
		NotifyDescription = New NotifyDescription("ValueChoiceListEnd", ThisObject, QuestionParameters);
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1
			     |
			     |Do you want to select another contract?'"), QuestionText);
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueChoiceListEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		NotifyChoice(AdditionalParameters.Value);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeAddingBegin of the List table.
//
&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ControlContractChoice
		AND ValueIsFilled(Counterparty)
		AND ValueIsFilled(Company)
		AND ContractType.Count() > 0 Then
		
		Cancel = True;
		
		FillingDataContract = New Structure;
		FillingDataContract.Insert("Owner", Counterparty);
		FillingDataContract.Insert("Company", Company);
		FillingDataContract.Insert("ContractKind", ContractType[0].Value);
		
		FormParameters = New Structure;
		FormParameters.Insert("FillingValues", FillingDataContract);
		
		OpenForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)		
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);	
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
