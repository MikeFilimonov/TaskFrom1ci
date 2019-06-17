
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Description	= Object.Description;
	
	SetFormConditionalAppearance();
	
	FunctionalCurrency	= Constants.FunctionalCurrency.Get();
	FixedContractAmount	= (Object.Amount <> 0);
	
	If Object.Ref.IsEmpty() Then
		
		FillPriceKind(True);
		FillSupplierPriceTypes();
		
		If Not ValueIsFilled(Object.Company) Then
			
			CompanyByDefault = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
			If ValueIsFilled(CompanyByDefault) Then
				Object.Company = CompanyByDefault;
			Else
				Object.Company = Catalogs.Companies.MainCompany;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Object.SettlementsCurrency) Then
			Object.SettlementsCurrency	= FunctionalCurrency;
		EndIf;
		
		If Not IsBlankString(Parameters.FillingText) Then
			Object.ContractNo	= Parameters.FillingText;
			Object.Description	= GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
		EndIf;
		
		TitleStagesOfPayment = StagesOfPaymentClientServer.TitleStagesOfPayment(ThisForm);
		
	EndIf;
	
	SetContractKindsChoiceList();
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
	EndIf;
	
	If Parameters.Property("Document") Then 
		OpeningDocument	= Parameters.Document;
	Else
		OpeningDocument	= Undefined;
	EndIf;
	
	GetBlankParameters();
	ShowDocumentBeginning	= True;
	DocumentCreated		= False;
	GenerateAndShowContract();
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	TitleStagesOfPayment = StagesOfPaymentClientServer.TitleStagesOfPayment(ThisForm);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PredefinedTemplateRestoration" Then 
		If Parameter = Object.ContractForm Then 
			FilterParameters = New Structure;
			FilterParameters.Insert("FormRefs", Object.ContractForm);
			ParameterArray = Object.EditableParameters.FindRows(FilterParameters);
			For Each String In ParameterArray Do 
				String.Value = "";
			EndDo;
		EndIf;
	EndIf;
	
	If EventName = "ContractTemplateChangeAndRecordAtServer" Then 
		If Parameter = Object.ContractForm Then 
			DocumentCreated = False;
			GetBlankParameters();
			GenerateAndShowContract();
			Modified = True;
			ShowDocumentBeginning = True;
			CurrentParameterClicked = "";
		EndIf;
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If FixedContractAmount AND Object.Amount = 0 Then
		
		ErrorText = NStr("en = 'Fill the contract amount.'");
		CommonUseClientServer.MessageToUser(
			ErrorText,
			Object.Ref,
			"Object.Amount",
			,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHadlers

&AtClient
Procedure ContractNoOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure ContractDateOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure SettlementsCurrencyOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure DiscountMarkupKindOnChange(Item)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountMarkupKindClear(Item, StandardProcessing)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	Items.ContractForm.AutoMarkIncomplete = False;
	If Modified Then
		DocumentCreated = False;
	EndIf;
	
	If Items.Pages.CurrentPage = Items.GroupPrintContract
		AND Not DocumentCreated Then 
		
		GenerateAndShowContract();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractFormOnChange(Item)
	
	If Item.EditText = "" Then
		DocumentCreated = False;
		GenerateAndShowContract();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractFormChoiceDataProcessor(Item, ValueSelected, StandardProcessing)
	
	If ValueIsFilled(Object.ContractForm) Then
		ShowDocumentBeginning = True;
	Else
		ShowDocumentBeginning = False;
	EndIf;
	If Object.ContractForm = ValueSelected Then
		DocumentCreated = True;
		ShowDocumentBeginning = False;
		Return;
	EndIf;
	CurrentParameterClicked = "";
	Object.ContractForm = ValueSelected;
	GetBlankParameters();
	DocumentCreated = False;
	GenerateAndShowContract();
	
EndProcedure

&AtClient
Procedure EditableParametersOnActivateCell(Item)
	
	If ValueIsFilled(Object.ContractForm) Then
		If Item.CurrentData <> Undefined Then
			If Not ShowDocumentBeginning Then
				SelectParameter(Item.CurrentData.ID);
			EndIf;
			ShowDocumentBeginning = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersParameterValueOnChange(Item)
	
	ParameterValue = Item.EditText;
	SetAndWriteParameterValue(ParameterValue, True);
	
EndProcedure

&AtClient
Procedure FixedContractAmountOnChange(Item)
	
	If Not FixedContractAmount Then
		Object.Amount = 0;
	EndIf;
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.ValidityStartDate;
	Dialog.Period.EndDate	= Object.ValidityEndDate;
	
	NotifyDescription = New NotifyDescription("SetIntervalCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetIntervalCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		Object.ValidityStartDate	= Result.StartDate;
		Object.ValidityEndDate		= Result.EndDate;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FormManagement()
	
	Items.Amount.Enabled			= FixedContractAmount;
	Items.Amount.AutoMarkIncomplete	= FixedContractAmount;
	
EndProcedure

&AtServer
Procedure FillSupplierPriceTypes()
	
	SetPrivilegedMode(True);
	
	Query = New Query("SELECT ALLOWED * FROM Catalog.SupplierPriceTypes AS CounterpartyPrices WHERE CounterpartyPrices.Owner = &Owner AND NOT CounterpartyPrices.DeletionMark");
	Query.SetParameter("Owner", Object.Owner);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then 
		
		Selection = QueryResult.Select();
		Selection.Next();
		Object.SupplierPriceTypes = Selection.Ref;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

&AtServer
Procedure FillPriceKind(IsNew = False)
	
	If IsNew Then
		
		PriceTypesales = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceTypesales");
		
		If ValueIsFilled(PriceTypesales) Then
			
			Object.PriceKind = PriceTypesales;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateDescription(ContractNo, ContractDate, SettlementsCurrency)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '#%1, dated %2 (%3)'"),
		TrimAll(ContractNo),
		?(ValueIsFilled(ContractDate), TrimAll(String(Format(ContractDate, "DLF=D"))), ""),
		TrimAll(String(SettlementsCurrency)));
	
EndFunction

&AtServer
Procedure SetContractKindsChoiceList()
	
	If Constants.SendGoodsOnConsignment.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.WithAgent);
	EndIf;
	
	If Constants.AcceptConsignedGoods.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.FromPrincipal);
	EndIf;	
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Print the contract. If the parameter is blank - display its title in the tooltip.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EditableParametersValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue		= New DataCompositionField("EditableParameters.ValueIsFilled");
	ItemFilter.ComparisonType	= DataCompositionComparisonType.Equal;
	ItemFilter.RightValue		= False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableCellTextColor);
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("EditableParameters.Presentation"));
	
EndProcedure

#EndRegion
	
#Region PrintContract
	
&AtServer
Procedure GenerateAndShowContract()
	
	If Not DocumentCreated Then
		
		EditableParameters.Clear();
		FilterParameters = New Structure("FormRefs", Object.ContractForm);
		ArrayInfobaseParameters = Object.InfobaseParameters.FindRows(FilterParameters);
		For Each Parameter In ArrayInfobaseParameters Do
			NewRow = EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.Parameter = Parameter.Parameter;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		ArrayEditedParameters = Object.EditableParameters.FindRows(FilterParameters);
		For Each Parameter In ArrayEditedParameters Do
			NewRow = EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		GeneratedDocument = DriveCreationOfPrintedFormsOfContract.GetGeneratedContractHTML(Object, OpeningDocument, EditableParameters);
		If ContractHTMLDocument = GeneratedDocument Then
			DocumentCreated = True;
		EndIf;
		ContractHTMLDocument = GeneratedDocument;
		
		FilterParameters = New Structure("Parameter", PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Facsimile"));
		Rows = EditableParameters.FindRows(FilterParameters);
		For Each String In Rows Do
			ID = String.GetID();
			EditableParameters.Delete(EditableParameters.FindByID(ID));
		EndDo;
		
		FilterParameters.Parameter = PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Logo");
		Rows = EditableParameters.FindRows(FilterParameters);
		For Each String In Rows Do
			ID = String.GetID();
			EditableParameters.Delete(EditableParameters.FindByID(ID))
		EndDo;
		
		For Each String In EditableParameters Do
			If ValueIsFilled(String.Value) Then
				String.ValueIsFilled = True;
			Else
				String.ValueIsFilled = False;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure GetBlankParameters()
	
	FilterParameters = New Structure("FormRefs", Object.ContractForm);
	ObjectEditedParameters		= Object.EditableParameters.FindRows(FilterParameters);
	ObjectInfobaseParameters	= Object.InfobaseParameters.FindRows(FilterParameters);
	
	For Each Parameter In ObjectEditedParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		If Object.ContractForm.EditableParameters.FindRows(FilterParameters).Count() <> 0 Then
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.EditableParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.EditableParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter In Object.ContractForm.EditableParameters Do
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.EditableParameters.FindRows(FilterParameters).Count() > 0 Then 
			Continue;
		EndIf;
		NewRow = Object.EditableParameters.Add();
		NewRow.FormRefs		= Object.ContractForm;
		NewRow.Presentation	= Parameter.Presentation;
		NewRow.ID			= Parameter.ID;
	EndDo;
	
	For Each Parameter In ObjectInfobaseParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		Rows = Object.ContractForm.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() <> 0 Then
			Parameter.Presentation = Rows[0].Presentation;
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.InfobaseParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter In Object.ContractForm.InfobaseParameters Do 
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.InfobaseParameters.FindRows(FilterParameters).Count() > 0 Then
			Continue;
		EndIf;
		NewRow = Object.InfobaseParameters.Add();
		NewRow.FormRefs		= Object.ContractForm;
		NewRow.Presentation	= Parameter.Presentation;
		NewRow.ID			= Parameter.ID;
		NewRow.Parameter	= Parameter.Parameter;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectParameter(Parameter)
	
	If Not DocumentCreated Then
		Return;
	EndIf;
	
	document = Items.ContractHTMLDocument.Document;
	
	If ValueIsFilled(CurrentParameterClicked) Then
		lastParameter = document.getElementById(CurrentParameterClicked);
		If lastParameter.className = "Filled" Then 
			lastParameter.style.backgroundColor = "#FFFFFF";
		ElsIf lastParameter.className = "Empty" Then 
			lastParameter.style.backgroundColor = "#DCDCDC";
		EndIf;
	EndIf;
	
	chosenParameter = document.getElementById(Parameter);
	If chosenParameter <> Undefined Then
		chosenParameter.style.backgroundColor = "#CCFFCC";
		chosenParameter.scrollIntoView();
		
		CurrentParameterClicked = Parameter;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractHTMLDocumentDocumentCreated(Item)
	
	document = Items.ContractHTMLDocument.Document;
	EditedParametersOnPage = document.getElementsByName("parameter");
	
	Iterator = 0;
	For Each Parameter In EditedParametersOnPage Do 
		FilterParameters = New Structure("ID", Parameter.id);
		String = EditableParameters.FindRows(FilterParameters);
		If String.Count() > 0 Then 
			RowIndex = EditableParameters.IndexOf(String[0]);
			Shift = Iterator - RowIndex;
			If Shift <> 0 Then 
				EditableParameters.Move(RowIndex, Shift);
			EndIf;
		EndIf;
		Iterator = Iterator + 1;
	EndDo;
	
	DocumentCreated = True;
	
EndProcedure

&AtServer
Function ThisIsInfobaseParameter(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters"), True, False);
	
EndFunction

&AtServer
Function ThisIsAdditionalAttribute(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"), True, False);
	
EndFunction

&AtServer
Function GetParameterValue(Parameter, Presentation, ID)
	
	If ThisIsInfobaseParameter(Parameter) Then
		Return DriveCreationOfPrintedFormsOfContract.GetParameterValue(Object, , Parameter, Presentation);
	ElsIf ThisIsAdditionalAttribute(Parameter) Then
		Return DriveCreationOfPrintedFormsOfContract.GetAdditionalAttributeValue(Object, OpeningDocument, Parameter);
	Else
		Return DriveCreationOfPrintedFormsOfContract.GetFilledFieldValueOnGeneratingPrintedForm(Object, ID);
	EndIf;
	
EndFunction

&AtClient
Procedure EditableParametersOnStartEdit(Item, NewRow, Copy)
	
	If Not ValueIsFilled(CurrentParameterClicked) Then
		SelectParameter(Item.CurrentData.ID);
	EndIf;
	
	Rows = EditableParameters.FindRows(New Structure("ID", CurrentParameterClicked));
	If Rows.Count() > 0 Then
		Rows[0].ValueIsFilled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersOnEditEnd(Item, NewRow, CancelEdit)
	
	Rows = EditableParameters.FindRows(New Structure("ID", CurrentParameterClicked));
	If Rows.Count() > 0 Then
		If ValueIsFilled(Rows[0].Value) Then
			Rows[0].ValueIsFilled = True;
		Else
			Rows[0].ValueIsFilled = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersParameterValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Parameter = Items.EditableParameters.CurrentData;
	ParameterValue = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
	Items.EditableParameters.CurrentData.Value = ParameterValue;
	
	SetAndWriteParameterValue(ParameterValue, False);
	
EndProcedure

&AtClient
Procedure SetAndWriteParameterValue(ParameterValue, WriteValue)
	
	document = Items.ContractHTMLDocument.Document;
	chosenParameter = document.getElementById(CurrentParameterClicked);
	
	If ValueIsFilled(ParameterValue) Then
		chosenParameter.innerText = ParameterValue;
		chosenParameter.className = "Filled";
		Items.EditableParameters.CurrentData.ValueIsFilled = True;
	Else
		chosenParameter.innerText = "__________";
		chosenParameter.className = "Empty";
		Items.EditableParameters.CurrentData.ValueIsFilled = False;
	EndIf;
	
	WorkingTable = Undefined;
	Parameter = Items.EditableParameters.CurrentData;
	If ThisIsInfobaseParameter(Parameter.Parameter) OR ThisIsAdditionalAttribute(Parameter.Parameter) Then
		WorkingTable = Object.InfobaseParameters;
		If WriteValue Then
			ParameterValueInInfobase = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
			If ParameterValue = ParameterValueInInfobase Then
				WriteValue = False;
			EndIf;
		EndIf;
	Else
		WorkingTable = Object.EditableParameters;
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ID", CurrentParameterClicked);
	Rows = EditableParameters.FindRows(FilterParameters);
	If Rows.Count() > 0 Then 
		ParameterIndex = Rows[0].LineNumber - 1;
	Else
		ParameterIndex = Undefined;
	EndIf;
	
	If ParameterIndex = Undefined Then
		Return;
	EndIf;
	
	If WriteValue Then
		WorkingTable[ParameterIndex].Value = ParameterValue;
	Else
		WorkingTable[ParameterIndex].Value = "";
	EndIf;
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

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
// End StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisForm);
	
EndProcedure

&AtClient
Procedure FieldStagesOfPaymentClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Try
		LockFormDataForEdit();
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	FormOptions = New Structure();
	FormOptions.Insert("PaymentMethod", Object.PaymentMethod);
	FormOptions.Insert("ProvideEPD", Object.ProvideEPD);
	FormOptions.Insert("UUID", UUID);
	FormOptions.Insert("AddressInTempStorage", PutToTempStorageAtServer());
	FormOptions.Insert("ContractKind", Object.ContractKind);
	PaymentOptions = Undefined;
	
	OpenForm(
		"Catalog.CounterpartyContracts.Form.StagesOfPaymentForm", 
		FormOptions, ThisForm,,,,
		New NotifyDescription("FieldStagesOfPaymentClickEnd", ThisObject),
		FormWindowOpeningMode.LockWholeInterface);
		
	
EndProcedure
	
&AtClient
Procedure FieldStagesOfPaymentClickEnd(Result, Options) Export
	
	PaymentOptions = Result;
	
	If PaymentOptions <> Undefined Then
		
		Modified = True;
		Object.PaymentMethod = PaymentOptions.PaymentMethod;
		Object.ProvideEPD = PaymentOptions.ProvideEPD;
		Object.StagesOfPayment.Clear();
		If ValueIsFilled(PaymentOptions.AddressInTempStorage) Then
			FillStagesOfPaymentFromTempStorage(PaymentOptions.AddressInTempStorage);
		EndIf;
		
		TitleStagesOfPayment = StagesOfPaymentClientServer.TitleStagesOfPayment(ThisForm);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillStagesOfPaymentFromTempStorage(AddressInTempStorage)
	
	StructureForTables = GetFromTempStorage(AddressInTempStorage);
	
	Object.StagesOfPayment.Load(StructureForTables.StagesOfPayment);
	Object.EarlyPaymentDiscounts.Load(StructureForTables.EarlyPaymentDiscounts);
	
EndProcedure

&AtServer
Function PutToTempStorageAtServer()
	
	StructureForTables = New Structure;
	StructureForTables.Insert("StagesOfPayment", Object.StagesOfPayment.Unload());
	StructureForTables.Insert("EarlyPaymentDiscounts", Object.EarlyPaymentDiscounts.Unload());
	
	Return PutToTempStorage(StructureForTables);
	
EndFunction

&AtClient
Procedure ContractKindOnChange(Item)
	
	TitleStagesOfPayment = StagesOfPaymentClientServer.TitleStagesOfPayment(ThisForm);
	
EndProcedure

#EndRegion
