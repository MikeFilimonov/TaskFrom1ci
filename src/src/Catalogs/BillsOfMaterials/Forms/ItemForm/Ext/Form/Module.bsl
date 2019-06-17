#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("TimeNorm", StructureData.Products.TimeNorm);
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Returns the result of checking the match of content row type and product type.
//
Function CorrespondsRowTypeProductsType(StructureData)
	
	If (StructureData.ContentRowType = PredefinedValue("Enum.BOMLineType.Expense")
		AND StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"))
		OR (StructureData.ContentRowType <> PredefinedValue("Enum.BOMLineType.Expense")
		AND StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.Service")) Then
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Mechanism handler "ObjectVersioning".
	ObjectVersioning.OnCreateAtServer(ThisForm);
	
	If Not Constants.UseOperationsManagement.Get() Then
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	Items.ContentDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.BillsOfMaterials.TabularSections.Content, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

#Region TablePartsAttributeEventHandlers

&AtClient
// Procedure - event handler OnChange input field ContentRowType.
//
Procedure ContentTypeOfContentRowOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.ContentRowType)
		AND ValueIsFilled(TabularSectionRow.Products) Then
		
		StructureData = New Structure();
		StructureData.Insert("ContentRowType", TabularSectionRow.ContentRowType);
		StructureData.Insert("Products", TabularSectionRow.Products);
		
		If Not CorrespondsRowTypeProductsType(StructureData) Then
			
			TabularSectionRow.Products = Undefined;
			TabularSectionRow.Characteristic = Undefined;
			TabularSectionRow.MeasurementUnit = Undefined;
			TabularSectionRow.Specification = Undefined;
			TabularSectionRow.Quantity = 1;
			TabularSectionRow.ProductsQuantity = 1;
			TabularSectionRow.CostPercentage = 1;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ContentProductsOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.Characteristic = Undefined;
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.ProductsQuantity = 1;
	TabularSectionRow.CostPercentage = 1;
	
EndProcedure

// Procedure - event handler StartChoice field Products.
//
&AtClient
Procedure ContentProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Set selection parameters of products depending on content row type
	FilterArray = New Array;
	
	If Items.Content.CurrentData.ContentRowType = PredefinedValue("Enum.BOMLineType.Expense") Then
		FilterArray.Add(PredefinedValue("Enum.ProductsTypes.Service"));
	Else
		FilterArray.Add(PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	EndIf;
	
	ChoiceParameter = New ChoiceParameter("Filter.ProductsType", New FixedArray(FilterArray));
	SelectionParametersArray = New Array();
	SelectionParametersArray.Add(ChoiceParameter);
	Item.ChoiceParameters = New FixedArray(SelectionParametersArray);
	
EndProcedure

&AtClient
Procedure ContentProductsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	// Prohibit loop references
	If ValueSelected = Object.Owner Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Products cannot be included in BOM.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure ContentCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Content.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Operation.
//
Procedure OperationsOperationOnChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Operation);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.TimeNorm = StructureData.TimeNorm;
	TabularSectionRow.ProductsQuantity = 1;
	
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

// StandardSubsystems.DataLoadFromFile
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		Object.Content.Clear();
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

// End StandardSubsystems. DataLoadFromFile

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
