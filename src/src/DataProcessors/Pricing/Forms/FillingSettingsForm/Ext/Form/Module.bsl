
#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtClient
// The procedure changes the
// availability of the form items depending on the selected filling option
//
// Implementation of the form items
// accessibility using pages is connected to the need to reduce the number of server calls.
//
// FormAttributeName - name of the enabled switcher.
//
Procedure ChangeFormItemsAvailability(FormAttributeName)
	
	MapOfPriceKindPages = New Map;
	MapOfPriceKindPages.Insert(True, 	Items.PriceKindAvailable);
	MapOfPriceKindPages.Insert(False, 		Items.PriceKindIsNotAvailable);
	
	ConformityToPagesBlankPricesBasedOnPrices  = New Map;
	ConformityToPagesBlankPricesBasedOnPrices.Insert(True,	Items.UnfilledPricesByPriceKindAvailable);
	ConformityToPagesBlankPricesBasedOnPrices.Insert(False, 	Items.BlankPricesBasedOnPriceNotAvailable);
	
	MapOfProductsGroupsPages = New Map;
	MapOfProductsGroupsPages.Insert(True, 	Items.ProductsGroupIsAvailable);
	MapOfProductsGroupsPages.Insert(False, 	Items.ProductsGroupIsNotAvailable);
	
	MapOfSupplierInvoicePages = New Map;
	MapOfSupplierInvoicePages.Insert(True, 	Items.GroupSupplierInvoiceAvailable);
	MapOfSupplierInvoicePages.Insert(False, 	Items.GroupSupplierInvoiceNotAvailable);
	
	MapOfPriceGroupsPages = New Map;
	MapOfPriceGroupsPages.Insert(True, 	Items.GroupPriceGroupAvailable);
	MapOfPriceGroupsPages.Insert(False, 	Items.GroupPriceGroupIsNotAvailable);
	
	MapOfAttributesAndRadioButtons = New Map;
	MapOfAttributesAndRadioButtons.Insert("AddOnPrice",				MapOfPriceKindPages);
	MapOfAttributesAndRadioButtons.Insert("AddBlankPricesByPriceKind", ConformityToPagesBlankPricesBasedOnPrices);
	MapOfAttributesAndRadioButtons.Insert("AddByProductsGroup",	MapOfProductsGroupsPages);
	MapOfAttributesAndRadioButtons.Insert("AddToInvoiceReceipt", 	MapOfSupplierInvoicePages);
	MapOfAttributesAndRadioButtons.Insert("AddByPriceGroup", 		MapOfPriceGroupsPages);
	
	For Each MapItem In MapOfAttributesAndRadioButtons Do
		
		SuccessfullyIdentified = (MapItem.Key = FormAttributeName);
		
		If Not SuccessfullyIdentified Then
			
			// Enable the switcher
			ThisForm[MapItem.Key] = ""; 
			
		EndIf;
		
		NewCurrentPage = MapItem.Value.Get(SuccessfullyIdentified);
		NewCurrentPage.Parent.CurrentPage = NewCurrentPage;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler of the OnCreateAtServer form
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CloseOnChoice = False;
	AddOnPrice 			= "AddOnPrice";
	
EndProcedure

&AtClient
// Procedure - form event handler OnOpen
//
Procedure OnOpen(Cancel)
	
	ChangeFormItemsAvailability("AddOnPrice")
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// The procedure initiates adding of new products items
//
Procedure AddProducts(Command)
	
	ParametersStructure = New Structure;
	
	// Empty values of switchers collapse automatically
	MapOfAttributesAndRadioButtons = New Map;
	MapOfAttributesAndRadioButtons.Insert(AddOnPrice,				PriceKind);
	MapOfAttributesAndRadioButtons.Insert(AddBlankPricesByPriceKind, PriceKindOfPriceNezapolnena);
	MapOfAttributesAndRadioButtons.Insert(AddByProductsGroup,	ProductsGroup);
	MapOfAttributesAndRadioButtons.Insert(AddToInvoiceReceipt,	SupplierInvoice);
	MapOfAttributesAndRadioButtons.Insert(AddByPriceGroup, 		PriceGroup);
	
	For Each MapItem In MapOfAttributesAndRadioButtons Do
		
		If ValueIsFilled(MapItem.Key) Then
			
			ParametersStructure.Insert("FillVariant",			MapItem.Key);
			ParametersStructure.Insert("ValueSelected",			MapItem.Value);
			
			If MapItem.Key = "AddOnPrice" Then
				
				ParametersStructure.Insert("ToDate", ?(ValueIsFilled(ToDate), ToDate, CurrentDate()));
				
			ElsIf MapItem.Key = "AddBlankPricesByPriceKind" Then
				
				ParametersStructure.Insert("ToDate", ?(ValueIsFilled(OnDateBlankPrices), OnDateBlankPrices, CurrentDate()));
				
			EndIf;
			
			ParametersStructure.Insert("UseCharacteristics",	UseCharacteristics);
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not ValueIsFilled(ParametersStructure.ValueSelected) Then
		
		MessageText = NStr("en = 'Filter value for filling has not been selected'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	NotifyChoice(ParametersStructure);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute FillByPriceKindOnChange
//
Procedure AddByPriceKindOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute AddBlankPricesByPriceKind
//
Procedure AddBlankPricesByPriceKindOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute FillByProductsGroup
//
Procedure AddByProductsGroupOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute FillByDocument
//
Procedure AddByReceiptInvoiceOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute FillByPricesGroup
//
Procedure AddByPriceGroupOnChange(Item)
	
	ChangeFormItemsAvailability(Item.Name);
	
EndProcedure

#EndRegion
