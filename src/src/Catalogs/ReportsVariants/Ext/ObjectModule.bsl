#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	AttributesToExclude = New Array;
	
	If Not User Then
		AttributesToExclude.Add("Author");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	
	If Description <> "" AND ReportsVariants.DescriptionIsBooked(Report, Ref, Description) Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '""%1"" is already used, enter another name.'"),
				Description
			),
			,
			"Description");
	EndIf;
EndProcedure

Procedure BeforeWrite(Cancel)
	If AdditionalProperties.Property("PredefinedOnesFilling") Then
		CheckFillingPredefined(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeletionMarkIsChangedByUser = (
		Not IsNew()
		AND DeletionMark <> Ref.DeletionMark
		AND Not AdditionalProperties.Property("PredefinedOnesFilling"));
	
	If Not User AND DeletionMarkIsChangedByUser Then
		If DeletionMark Then
			ErrorText = NStr("en = 'Cannot mark predefined report option for deletion.'");
		Else
			ErrorText = NStr("en = 'Cannot unmark the predefined report option for deletion.'");
		EndIf;
		ReportsVariants.ErrorByVariant(Ref, ErrorText);
		Raise ErrorText;
	EndIf;
	
	If Not DeletionMark AND DeletionMarkIsChangedByUser Then
		DescriptionIsBooked = ReportsVariants.DescriptionIsBooked(Report, Ref, Description);
		VariantKeyIsBooked  = ReportsVariants.VariantKeyIsBooked(Report, Ref, VariantKey);
		If DescriptionIsBooked OR VariantKeyIsBooked Then
			ErrorText = NStr("en = 'An error occurred when clearing the deletion mark of report option:'");
			If DescriptionIsBooked Then
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Name ""%1"" is already used by another option of this report.'"),
					Description);
			Else
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Key of option ""%1"" is already used by another option of this report.'"),
					VariantKey);
			EndIf;
			ErrorText = ErrorText + NStr("en = 'Before unchecking the deletion mark
			                             |of the report option it is necessary to install the deletion mark of the controversial report option.'");
			ReportsVariants.ErrorByVariant(Ref, ErrorText);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Deletion of items marked for deletion from the subsystems tabular section.
	RowToDeleteArray = New Array;
	For Each RowOfPlacement In Placement Do
		If RowOfPlacement.Subsystem.DeletionMark = True Then
			RowToDeleteArray.Add(RowOfPlacement);
		EndIf;
	EndDo;
	For Each RowOfPlacement In RowToDeleteArray Do
		Placement.Delete(RowOfPlacement);
	EndDo;
	
	// Filling the attributes "FieldNames" and "ParametersAndFiltersNames".
	IndexSettings();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure IndexSettings()
	If User Or ReportType = Enums.ReportsTypes.Additional Then
		Try
			ReportsVariants.IndexSchemaContent(ThisObject);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot index a scheme of option ""%1"" of report ""%2"":'"),
				VariantKey,
				String(Report));
			ReportsVariants.ErrorByVariant(Ref, ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo()));
		EndTry;
	Else
		// For predefined report options the data is stored in the undivided catalog.
		If FieldNames <> "" Then
			FieldNames = "";
		EndIf;
		If ParametersAndFiltersNames <> "" Then
			ParametersAndFiltersNames = "";
		EndIf;
	EndIf;
EndProcedure

// Fills the parent of the option report based on the report references and predefined settings.
Procedure FillParent() Export
	QueryText =
	"SELECT ALLOWED TOP 1
	|	Predetermined.Ref AS PredefinedVariant
	|INTO TTPredefined
	|FROM
	|	Catalog.PredefinedReportsVariants AS Predetermined
	|WHERE
	|	Predetermined.Report = &Report
	|	AND Predetermined.DeletionMark = FALSE
	|	AND Predetermined.GroupByReport
	|
	|ORDER BY
	|	Predetermined.Enabled DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	ReportsVariants.Ref
	|FROM
	|	TTPredefined AS TTPredefined
	|		INNER JOIN Catalog.ReportsVariants AS ReportsVariants
	|		ON TTPredefined.PredefinedVariant = ReportsVariants.PredefinedVariant
	|WHERE
	|	ReportsVariants.DeletionMark = FALSE";
	Query = New Query;
	Query.SetParameter("Report", Report);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Parent = Selection.Ref;
	EndIf;
EndProcedure

// Basic checks of the data correctness of the predefined reports.
Procedure CheckFillingPredefined(Cancel)
	If DeletionMark Or Not Predefined Then
		Return;
	ElsIf Not ValueIsFilled(Report) Then
		ErrorText = NotFilledField("Report");
	ElsIf Not ValueIsFilled(ReportType) Then
		ErrorText = NotFilledField("ReportType");
	ElsIf Not ReportsTypesMatch() Then
		ErrorText = ControversialFieldValues("ReportType", "Report");
	ElsIf ReportType = Enums.ReportsTypes.Internal
		AND Not ValueIsFilled(PredefinedVariant) Then
		ErrorText = NotFilledField("PredefinedVariant");
	Else
		Return;
	EndIf;
	Cancel = True;
	ReportsVariants.ErrorByVariant(Ref, ErrorText);
EndProcedure

Function NotFilledField(FieldName)
	Return StrReplace(NStr("en = 'The ""%1"" field is not filled in'"), "%1", FieldName);
EndFunction

Function ReportsTypesMatch()
	If TypeOf(Report) = Type("CatalogRef.MetadataObjectIDs") Then
		ExpectedType = Enums.ReportsTypes.Internal;
	ElsIf TypeOf(Report) = Type("String") Then
		ExpectedType = Enums.ReportsTypes.External;
	Else
		ExpectedType = Enums.ReportsTypes.Additional;
	EndIf;
	Return ReportType = ExpectedType;
EndFunction

Function ControversialFieldValues(FieldName1, FieldName2)
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Inconsistent values of fields ""%1"" and ""%2""'"),
		FieldName1,
		FieldName2
	);
EndFunction

#EndRegion

#EndIf
