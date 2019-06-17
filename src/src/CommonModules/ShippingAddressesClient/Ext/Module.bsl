#Region Public

// Opens choice form for shipping address
//
// Parameters:
//  Counterparty - CatalogRef.Counterparties - owner of shipping addresses
//  FormItem - FormField - owner of opening form
//
Procedure OpenShippingAddressesSelectForm(Counterparty, FormItem) Export

	StructureFilter = New Structure;
	StructureFilter.Insert("Owner", Counterparty);
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectShippingAddress", ParameterStructure, FormItem);

EndProcedure

// Opens object form for creating new shipping address
//
// Parameters:
//  Counterparty - CatalogRef.Counterparties - owner of shipping address
//  FormItem - FormField - owner of opening form
//
Procedure OpenShippingAddressesObjectForm(Counterparty, FormItem) Export

	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",			True);
	FormParameters.Insert("ChoiceParameters",	New Structure("Owner", Counterparty));
	FormParameters.Insert("FillingValues",		New Structure("Owner", Counterparty));
	
	OpenForm("Catalog.ShippingAddresses.ObjectForm", FormParameters, FormItem);

EndProcedure

#EndRegion

