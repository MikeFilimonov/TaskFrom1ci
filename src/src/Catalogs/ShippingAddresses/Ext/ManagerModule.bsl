#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Gets default shipping address.
//
// Parameters:
//  Counterparty - Ref to Owner of shipping addresses.
//
// Returns:
//  CatalogRef.ShippingAddresses - if there is shipping address marked as default or 
//  there is only one shipping address.
//  CatalogRef.Counterparties - if there are no delivery addresses.
//  Undefined - if there are several shipping addresses and no one is marked as default.
//
Function GetDefaultShippingAddress(Counterparty) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ShippingAddresses.Ref AS Ref,
	|	ShippingAddresses.IsDefault AS IsDefault
	|FROM
	|	Catalog.ShippingAddresses AS ShippingAddresses
	|WHERE
	|	ShippingAddresses.Owner = &Owner";
	
	Query.SetParameter("Owner", Counterparty);
	
	QueryResultTable = Query.Execute().Unload();
	
	If QueryResultTable.Count() = 0 Then
		Return Counterparty;
	ElsIf QueryResultTable.Count() = 1 Then
		Return QueryResultTable[0].Ref;
	Else
		QueryResultTable.Sort("IsDefault Desc");
	
		If QueryResultTable[0].IsDefault Then
			Return QueryResultTable[0].Ref;
		Else
			Return Undefined;
		EndIf;
	EndIf;
		
EndFunction

// Returns the list of attributes allowed to be changed
// with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("ContactPerson");
	EditableAttributes.Add("Incoterms");
	EditableAttributes.Add("DeliveryTimeFrom");
	EditableAttributes.Add("DeliveryTimeTo");
	EditableAttributes.Add("SalesRep");
	
	Return EditableAttributes;
EndFunction

#Region InfobaseUpdate

// Updates with predefined kinds of contact information for Shipping addresses.
//
Procedure ShippingAddresses_SetKindProperties() Export
	
	ShippingAddress = Catalogs.ContactInformationTypes.ShippingAddress;
	
	If ShippingAddress.Type = Enums.ContactInformationTypes.Address Then
		Return;
	EndIf;
	
	ContactInformationDrive.ShippingAddresses_SetKindProperties();
	
EndProcedure

#EndRegion

#EndRegion

#EndIf