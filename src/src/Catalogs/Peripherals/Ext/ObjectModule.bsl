﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure performs the device parameter initialization.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		Parameters = New ValueStorage(New Structure());
	EndIf;
	
EndProcedure

// Procedure checks the catalog
// item description uniqueness for this computer.
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If Not IsBlankString(Description) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Peripherals AS Peripherals
		|WHERE
		|    Peripherals.Description = &Description
		|    AND Peripherals.Workplace = &Workplace
		|    AND Peripherals.Ref <> &Ref
		|");

		Query.SetParameter("Description", Description);
		Query.SetParameter("Workplace", Workplace);
		Query.SetParameter("Ref"      , Ref);

		If Not Query.Execute().IsEmpty() Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Non-unique item name specified. Specify a unique name.'"), ThisObject, , , Cancel);
		EndIf;
	EndIf;

EndProcedure

// Procedure performs attribute cleaning which shouldn't be copied.
// The following attributes are cleared when you copy:
// "Parameters"    - device parameters are reset to Undefined;
// "Description"   - other than the original description is set;
Procedure OnCopy(CopiedObject)
	
	DeviceIsInUse = True;
	Parameters = Undefined;

	Description = NStr("en = '%Description% (copy)'");
	Description = StrReplace(Description, "%Description%", CopiedObject.Description);
	
EndProcedure

// On write
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

EndProcedure

#EndRegion

#EndIf