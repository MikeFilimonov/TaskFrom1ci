#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Cancel Then
		
		WriteAdditionalAttributesCatalog(PropertySet, Catalogs.AdditionalAttributesAndInformationSets.Catalog_Products);
		WriteAdditionalAttributesCatalog(SetOfCharacteristicProperties, Catalogs.AdditionalAttributesAndInformationSets.Catalog_ProductsCharacteristics);
		
	EndIf;	
	
EndProcedure

// Procedure - event handler  AtCopy.
//
Procedure OnCopy(CopiedObject)
	
	PropertySet						= Undefined;
	SetOfCharacteristicProperties	= Undefined;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure WriteAdditionalAttributesCatalog(SetOfProperties, SetParent)
	
	If Not ValueIsFilled(SetOfProperties) Then
		ObjectSet = Catalogs.AdditionalAttributesAndInformationSets.CreateItem();
	Else
		ObjectSet = SetOfProperties.GetObject();
		LockDataForEdit(ObjectSet.Ref);
	EndIf;
	
	ObjectSet.Description	= Description;
	ObjectSet.Parent		= SetParent;
	ObjectSet.DeletionMark	= DeletionMark;
	ObjectSet.Write();
	SetOfProperties = ObjectSet.Ref;

EndProcedure

#EndRegion

#EndIf