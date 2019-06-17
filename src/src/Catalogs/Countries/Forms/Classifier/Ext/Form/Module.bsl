
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode
	EndIf;
	
	Parameters.Property("ChoiceMode", ChoiceMode);
	Items.Classifier.ChoiceMode = ChoiceMode;
	
	// Internal attributes
	ClassifierFields = "Code, Description, LongDescription, AlphaCode2, AlphaCode3";
	
	Meta = Metadata.Catalogs.Countries;
	ClassifierObjectPresentation = Meta.ExtendedObjectPresentation;
	
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.ObjectPresentation;
	EndIf;
	
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.Presentation();
	EndIf;
	
	If Not IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = " (" + ClassifierObjectPresentation + ")";
	EndIf;
	
	ClassifierData = ClassifierStatus();
	Classifier.Load(ClassifierData);
	
	Filter = Classifier.FindRows(New Structure("Code", Parameters.CurrentRow.Code));
	If Filter.Count() > 0 Then
		Items.Classifier.CurrentRow = Filter[0].GetID();
	EndIf;
	
EndProcedure

#EndRegion

#Region ClassifierFormTableItemEventHandlers

&AtClient
Procedure ClassifierChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ChoiceMode Then 
		Return;
	EndIf;
	
	If TypeOf(SelectedRow)=Type("Array") Then
		SelectedRowID = SelectedRow[0];
	Else
		SelectedRowID = SelectedRow;
	EndIf;
	
	NotifyClassifierItemChoice(SelectedRowID);
	
EndProcedure

&AtClient
Procedure ClassifierValueChoice(Item, Value, StandardProcessing)
	NotifyClassifierItemChoice(Value);
EndProcedure

&AtClient
Procedure ClassifierBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ClassifierBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure NotifyClassifierItemChoice(SelectedRowID)
	
	AllRowData = Classifier.FindByID(SelectedRowID);
	
	If AllRowData<>Undefined Then
		RowData = New Structure(ClassifierFields);
		FillPropertyValues(RowData, AllRowData);
		
		ChoiceData = ClassifierItemChoiceData(RowData);
		If ChoiceData.IsNew Then
			NotifyItemCreation(ChoiceData.Ref);
		EndIf;
		
		NotifyChoice(ChoiceData.Ref);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ClassifierItemChoiceData(Val CountryData)
	// Searching by code only, because all codes are specified in the classifier
	Ref = Catalogs.Countries.FindByCode(CountryData.Code);
	IsNew = Not ValueIsFilled(Ref);
	If IsNew Then
		Country = Catalogs.Countries.CreateItem();
		FillPropertyValues(Country, CountryData);
		Country.Write();
		Ref = Country.Ref;
	EndIf;
	
	Return New Structure("Ref, IsNew, Code", Ref, IsNew, CountryData.Code);
	
EndFunction

&AtServerNoContext
Function ClassifierStatus()
	
	Data = Catalogs.Countries.ClassifierTable();
	
	Data.Columns.Add("IconIndex", New TypeDescription("Number", New NumberQualifiers(2, 0)));
	Data.FillValues(8, "IconIndex");
	
	Query = New Query(
		"SELECT
		|	Countries.Code AS Code
		|FROM
		|	Catalog.Countries AS Countries
		|WHERE
		|	Countries.Predefined");
	
	For Each PredefinedString In Query.Execute().Unload() Do
		DataRow = Data.Find(PredefinedString.Code, "Code");
		If DataRow <> Undefined Then
			DataRow.IconIndex = 5;
		EndIf;
	EndDo;
	
	Return Data;
	
EndFunction

&AtClient
Procedure NotifyItemCreation(Ref)
	NotifyWritingNew(Ref);
	Notify("Catalog.Countries.Update", Ref, ThisObject);
EndProcedure

#EndRegion
