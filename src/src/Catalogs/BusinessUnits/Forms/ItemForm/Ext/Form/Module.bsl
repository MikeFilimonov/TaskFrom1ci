#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeOfStructuralUnitRetail = Enums.BusinessUnitsTypes.Retail;
	TypeOfStructuralUnitRetailAmmountAccounting = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	TypeOfStructuralUnitWarehouse = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.RetailPriceKind.Visible = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
	
	If Constants.UseSeveralWarehouses.Get()
	 OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Warehouse);
		If Constants.UseRetail.Get() 
			OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Retail 
			OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Retail);
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
		EndIf;
	EndIf;
	
	If Constants.UseSeveralDepartments.Get()
		OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Department);
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Items.StructuralUnitType.ChoiceList.Count() = 1 Then
		Object.StructuralUnitType = Items.StructuralUnitType.ChoiceList[0].Value;
	EndIf;
	
	If Not GetFunctionalOption("UseDataSync") Then
		Items.Company.Visible = False;
	EndIf;
	
	Items.RetailPriceKind.AutoMarkIncomplete = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
	
	If Parameters.Key.IsEmpty() Then
		ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	КонецЕсли;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
	If EventName = "AccountsChangedBusinessUnits" Then
		Object.GLAccountInRetail = Parameter.GLAccountInRetail;
		Object.MarkupGLAccount = Parameter.MarkupGLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
		
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure StructuralUnitTypeOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitType) Then
		
		Items.RetailPriceKind.Visible = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
		
		Items.RetailPriceKind.MarkIncomplete = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryAutotransferClick(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("TransferSource", Object.TransferSource);
	ParametersStructure.Insert("TransferRecipient", Object.TransferRecipient);
	ParametersStructure.Insert("RecipientOfWastes", Object.RecipientOfWastes);
	ParametersStructure.Insert("WriteOffToExpensesSource", Object.WriteOffToExpensesSource);
	ParametersStructure.Insert("WriteOffToExpensesRecipient", Object.WriteOffToExpensesRecipient);
	ParametersStructure.Insert("PassToOperationSource", Object.PassToOperationSource);
	ParametersStructure.Insert("PassToOperationRecipient", Object.PassToOperationRecipient);
	ParametersStructure.Insert("ReturnFromOperationSource", Object.ReturnFromOperationSource);
	ParametersStructure.Insert("ReturnFromOperationRecipient", Object.ReturnFromOperationRecipient);
	
	ParametersStructure.Insert("TransferSourceCell", Object.TransferSourceCell);
	ParametersStructure.Insert("TransferRecipientCell", Object.TransferRecipientCell);
	ParametersStructure.Insert("DisposalsRecipientCell", Object.DisposalsRecipientCell);
	ParametersStructure.Insert("WriteOffToExpensesSourceCell", Object.WriteOffToExpensesSourceCell);
	ParametersStructure.Insert("WriteOffToExpensesRecipientCell", Object.WriteOffToExpensesRecipientCell);
	ParametersStructure.Insert("PassToOperationSourceCell", Object.PassToOperationSourceCell);
	ParametersStructure.Insert("PassToOperationRecipientCell", Object.PassToOperationRecipientCell);
	ParametersStructure.Insert("ReturnFromOperationSourceCell", Object.ReturnFromOperationSourceCell);
	ParametersStructure.Insert("ReturnFromOperationRecipientCell", Object.ReturnFromOperationRecipientCell);
	
	ParametersStructure.Insert("StructuralUnitType", Object.StructuralUnitType);
	
	Notification = New NotifyDescription("AutomovementocksEndClick",ThisForm);
	OpenForm("CommonForm.DefaultRecipientBusinessUnits", ParametersStructure,,,,,Notification);
	
	
EndProcedure

&AtClient
Procedure RetailPriceKindOnChange(Item)
	
	If Not ValueIsFilled(Object.RetailPriceKind) Then
		Return;
	EndIf;
	
	DataStructure = GetRetailPriceKindData(Object.RetailPriceKind);
	
	If Not DataStructure.PriceCurrency = DataStructure.FunctionalCurrency Then
		
		MessageText = NStr("en = 'Specify functional currency (%NatCurrency%) for the ""%PriceKind%"" price kind for retail business unit.'");
		MessageText = StrReplace(MessageText, "%PriceKind%", DataStructure.PriceKindDescription);
		MessageText = StrReplace(MessageText, "%NatCurrency%", DataStructure.FunctionalCurrency);
		
		CommonUseClientServer.MessageToUser(MessageText, , "Object.RetailPriceKind");
		
		Object.RetailPriceKind = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function GetRetailPriceKindData(RetailPriceKind)
	
	DataStructure	 = New Structure;
	
	DataStructure.Insert("PriceKindDescription",	RetailPriceKind.Description);
	DataStructure.Insert("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
	DataStructure.Insert("PriceCurrency", 			RetailPriceKind.PriceCurrency);
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure AutomovementocksEndClick(FillingParameters,Parameters) Export
	
	If TypeOf(FillingParameters) = Type("Structure") Then
		
		FillPropertyValues(Object, FillingParameters);
		
		If Not Modified 
			AND FillingParameters.Modified Then
			
			Modified = True;
			
		EndIf;
		
	EndIf;

	
EndProcedure

#EndRegion

#Region ContactInformationDrive

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationDrive.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationDriveClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationDriveClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationDriveClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationDriveExecuteCommand(Command)
	
	ContactInformationDriveClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisObject);
	
EndProcedure
// End

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

