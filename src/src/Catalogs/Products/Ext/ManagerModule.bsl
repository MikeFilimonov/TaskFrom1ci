#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("ProductsType");
	Result.Add("IsFreightService");
	
	Return Result;
	
EndFunction

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("ProductsType");
	EditableAttributes.Add("VATRate");
	EditableAttributes.Add("BusinessLine");
	EditableAttributes.Add("Warehouse");
	EditableAttributes.Add("Cell");
	EditableAttributes.Add("ProductsCategory");
	EditableAttributes.Add("PriceGroup");
	EditableAttributes.Add("CountryOfOrigin");
	EditableAttributes.Add("ReplenishmentMethod");
	EditableAttributes.Add("ReplenishmentDeadline");
	EditableAttributes.Add("Vendor");

	
	Return EditableAttributes;
	
EndFunction

// Returns the basic sale price for the specified items by the specified price kind.
//
// Products (Catalog.Products) - products which price shall be calculated (obligatory for filling);
// PriceKind (Catalog.PriceTypes or Undefined) - If Undefined, we calculate the basic price kind using
// Catalogs.PriceTypes.GetBasicSalePriceKind() method;
//
Function GetMainSalePrice(PriceKind, Products, MeasurementUnit = Undefined) Export
	
	If Not ValueIsFilled(Products) 
		OR Not AccessRight("Read", Metadata.InformationRegisters.Prices) Then
		
		Return 0;
		
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	PricesSliceLast.Price AS MainSalePrice
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			,
	|			PriceKind = &PriceKind
	|				AND Products = &Products
	|				AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				AND Actuality
	|				AND &ParameterMeasurementUnit) AS PricesSliceLast");
	
	Query.SetParameter("PriceKind", 
		?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.GetMainKindOfSalePrices())
		);
	
	Query.SetParameter("Products", 
		Products
		);
		
	If ValueIsFilled(MeasurementUnit) Then
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "MeasurementUnit = &MeasurementUnit");
		Query.SetParameter("MeasurementUnit", MeasurementUnit);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "TRUE");
		
	EndIf;
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.MainSalePrice, 0);
	
EndFunction

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf