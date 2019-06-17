#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the structure with the parameters of selection processor
//
// It is used for caching
//
Procedure InformationAboutDocumentStructure(ParametersStructure) Export
	
	ParametersStructure = New Structure;
	
	For Each DataProcessorAttribute In Metadata.DataProcessors.ProductsSelection.Attributes Do
		
		ParametersStructure.Insert(DataProcessorAttribute.Name);
		
	EndDo;
	
EndProcedure

// Returns the structure of the mandatory parameters
//
Function MandatoryParametersStructure()
	
	Return New Structure("Date, ProductsType, OwnerFormUUID",
						NStr("en = 'Date'"),
						NStr("en = 'Product type'"),
						NStr("en = 'Unique identifier of the owner form'"));
	
EndFunction

// Check a minimum level parameters filling
//
Procedure CheckParametersFilling(SelectionParameters, Cancel) Export
	Var Errors;
	
	MandatoryParametersStructure = MandatoryParametersStructure();
	
	For Each StructureItem In MandatoryParametersStructure Do
		
		ValueParameters = Undefined;
		If Not SelectionParameters.Property(StructureItem.Key, ValueParameters) Then
			
			ErrorText = NStr("en = 'Required parameter (%1) required for opening of products selection form is missing.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, StructureItem.Value);
			
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
			
		ElsIf Not ValueIsFilled(ValueParameters) Then
			
			ErrorText = NStr("en = 'Required parameter (%1) required for opening of products selection form is filled in incorrectly.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, StructureItem.Value);
			
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
			
		EndIf;
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndProcedure

// Function returns a full name of the selection form 
//
Function ChoiceFormFullName() Export
	
	Return "DataProcessor.ProductsSelection.Form.MainForm";
	
EndFunction

#EndRegion

#EndIf