#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region UpdateHandlers

Procedure SetPropertiesForCompanyWebpagePredefinedItem() Export
	
	CompanyWebpageRef = CompanyWebpage;
	
	If ValueIsFilled(CommonUse.ObjectAttributeValue(CompanyWebpageRef, "Type")) Then
		Return;
	EndIf;
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= CompanyWebpageRef;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationDrive.SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

#EndRegion

#Region Interface

// Returns locked attribute description
//
// Returns:
//     Array - contains strings in format AttributeName[;FormItemName,...]
//             where AttributeName - name of object attribute, 
//                   FormItemName - name of item form corresponding to the attribute
//
Function GetObjectAttributesBeingLocked() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Type;Type");
	AttributesToLock.Add("Parent");
	
	Return AttributesToLock;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes excluded from the batch object modification.
//
// Returns:
//     Array - contains strings with attribute names
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

#EndRegion

#EndIf