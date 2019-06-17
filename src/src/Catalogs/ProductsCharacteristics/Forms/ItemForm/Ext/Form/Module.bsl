
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered)
	
	If WrapValuesEntered Then
		PropertiesManagementOverridable.MovePropertiesValues(Object.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = PropertiesManagementOverridable.FillValuesPropertiesTree(Object.Ref, Object.AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	
EndProcedure

&AtServerNoContext
// Function returns products owner category.
//
Function GetOwnerProductsCategory(ProductsOwner)
	
	Return ProductsOwner.ProductsCategory;
	
EndFunction

&AtClient
// Procedure traverses the value tree recursively.
//
Procedure RecursiveBypassOfValueTree(TreeItems, String)
	
	For Each TreeRow In TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			If IsBlankString(TreeRow.FormatProperties) Then
				String = String + TreeRow.Value + ", ";
			Else
				String = String + Format(TreeRow.Value, TreeRow.FormatProperties) + ", ";
			EndIf;
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		RecursiveBypassOfValueTree(NextTreeItem, String);
		
	EndDo;
	
EndProcedure

&AtClient
// Function sets new characteristic description by the property values.
//
// Parameters:
//  PropertiesValuesCollection - a value collection with property Value.
//
// Returns:
//  String - generated description.
//
Function GenerateDescription(PropertiesValuesCollection)

	TreeItems = PropertiesValuesCollection.GetItems();
	
	String = "";
	RecursiveBypassOfValueTree(TreeItems, String);
	
	String = Left(String, StrLen(String) - 2);

	If IsBlankString(String) Then
		String = "<Properties aren't assigned>";
	EndIf;

	Return String;

EndFunction

&AtServer
// Procedure - fills choice list for attribute Owner.
//
Procedure FillChoiceListOwner()
	
	Items.Owner.ChoiceList.Clear();
	If ValueIsFilled(ProductsCategory) Then
		Items.Owner.ChoiceList.Add(ProductsCategory);
	EndIf;
	If ValueIsFilled(Products) Then
		Items.Owner.ChoiceList.Add(Products);
	EndIf;
	
EndProcedure

&AtClient
// Procedure - fills choice list for attribute Description.
//
Procedure FillChoiceListItems()
	
	Items.Description.ChoiceList.Clear();
	Items.Description.ChoiceList.Add(GenerateDescription(PropertiesValuesTree));
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// 1. Checking.
	If ValueIsFilled(Object.Owner)
		AND TypeOf(Object.Owner) = Type("CatalogRef.Products")
		AND Not Object.Owner.UseCharacteristics Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The products are not accounted by characteristics!
		                    |Select the ""Use characteristics"" check box in products card'");
		Message.Message();
		Cancel = True;
		
	// 2. Filling.
	ElsIf Parameters.Property("FillingValues") AND Parameters.FillingValues.Property("Owner") Then
		
		If TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.Products") Then
		
			ProductsCategory = Parameters.FillingValues.Owner.ProductsCategory;
			Products = Parameters.FillingValues.Owner;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.ProductsCategories") Then
			
			ProductsCategory = Parameters.FillingValues.Owner;
			Products = Undefined;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("ValueList") Then
			
			For Each ListIt In Parameters.FillingValues.Owner Do
				
				If TypeOf(ListIt.Value) = Type("CatalogRef.ProductsCategories") Then
					
					Object.Owner = ListIt.Value;
					ProductsCategory = ListIt.Value;
					
				Else
					
					Products = ListIt.Value;
					
				EndIf;
				
			EndDo;
		
		EndIf;
		
	// 3 Open.
	ElsIf ValueIsFilled(Parameters.Key) Then
		
		If TypeOf(Parameters.Key.Owner) = Type("CatalogRef.Products") Then
		
			ProductsCategory = Parameters.Key.Owner.ProductsCategory;
			Products = Parameters.Key.Owner;
			
		ElsIf TypeOf(Parameters.Key.Owner) = Type("CatalogRef.ProductsCategories") Then
			
			ProductsCategory = Parameters.Key.Owner;
			Products = Undefined;

		EndIf;
		
	Else
		
		ProductsCategory = Undefined;
		Products = Undefined;
		
	EndIf;
	
	// Fill the property value tree.
	If Not Cancel Then
		FillChoiceListOwner();
		FillValuesPropertiesTree(False);
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Deploy property value tree.
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	FillChoiceListItems();
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Transfer the values from property value tree in tabular object section.
	PropertiesManagementOverridable.MovePropertiesValues(CurrentObject.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange field Owner.
//
Procedure OwnerOnChange(Item)
	
	If TypeOf(Object.Owner) = Type("CatalogRef.Products") Then
		
		ProductsCategory = GetOwnerProductsCategory(Object.Owner);
		
	ElsIf TypeOf(Object.Owner) = Type("CatalogRef.ProductsCategories") Then
		
		ProductsCategory = Object.Owner;
		
	Else
		
		ProductsCategory = Undefined;
		
	EndIf;
	
	// Fill the property value tree.
	FillValuesPropertiesTree(True);
	
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure

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

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure PropertyValueTreeOnChange(Item)
	
	Object.Description = GenerateDescription(PropertiesValuesTree);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	DriveClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure

&AtClient
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	DriveClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#EndRegion
