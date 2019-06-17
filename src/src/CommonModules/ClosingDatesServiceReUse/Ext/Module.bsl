////////////////////////////////////////////////////////////////////////////////
// Subsystem "Change prohibition dates".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns properties that characterize the option of embedding.
Function SectionsProperties() Export
	
	Properties = New Structure;
	Properties.Insert("UseExternalUsers", False);
	
	ClosingDatesOverridable.InterfaceSetting(Properties);
	
	Properties.Insert("ExchangePlansNodesEmptyRefs", New Array);
	Properties.Insert("UseProhibitionDatesOfDataImport", False);
	
	SettingRecipientTypes = Metadata.InformationRegisters.ClosingDates
		.Dimensions.User.Type.Types();
	
	For Each SettingRecipientType In SettingRecipientTypes Do
		MetadataObject = Metadata.FindByType(SettingRecipientType);
		If Metadata.ExchangePlans.Contains(MetadataObject) Then
			Properties.UseProhibitionDatesOfDataImport = True;
			Properties.ExchangePlansNodesEmptyRefs.Add(
				CommonUse.ObjectManagerByFullName(
					MetadataObject.FullName()).EmptyRef());
		EndIf;
	EndDo;
	
	Properties.Insert("AllSectionsWithoutObjects", True);
	Properties.Insert("WithoutSectionsAndObjects");
	Properties.Insert("SingleSection");
	Properties.Insert("ShowSections");
	Properties.Insert("SectionsWithoutObjects",   New ValueList);
	Properties.Insert("SectionObjectsTypes", New ValueTable);
	
	Properties.SectionObjectsTypes.Columns.Add(
		"Section", New TypeDescription("ChartOfCharacteristicTypesRef.ClosingDateSections"));
	
	Properties.SectionObjectsTypes.Columns.Add(
		"ObjectTypes", New TypeDescription("ValueList"));
	
	Query = New Query(
	"SELECT
	|	ClosingDateSections.Ref
	|FROM
	|	ChartOfCharacteristicTypes.ClosingDateSections AS ClosingDateSections
	|WHERE
	|	ClosingDateSections.Predefined");
	
	SetPrivilegedMode(True);
	Sections = Query.Execute().Unload().UnloadColumn("Ref");
	
	For Each Section In Sections Do
		
		SectionDescription = Properties.SectionObjectsTypes.Add();
		SectionDescription.Section = Section;
		SectionDescription.ObjectTypes = New ValueList;
		
		For Each Type In Section.ValueType.Types() Do
			If Type <> Type("ChartOfCharacteristicTypesRef.ClosingDateSections") Then
				If CommonUse.IsReference(Type) Then
					TypeMetadata = Metadata.FindByType(Type);
					SectionDescription.ObjectTypes.Add(
							TypeMetadata.FullName(),
							TypeMetadata.ObjectPresentation);
				EndIf;
			EndIf;
		EndDo;
		
		If SectionDescription.ObjectTypes.Count() <> 0 Then
			Properties.AllSectionsWithoutObjects = False;
		Else
			Properties.SectionsWithoutObjects.Add(Section);
		EndIf;
	EndDo;
	
	Properties.WithoutSectionsAndObjects = Sections.Count() = 0;
	Properties.SingleSection   = Sections.Count() = 1;
	Properties.ShowSections    = Not (  Not Properties.AllSectionsWithoutObjects
	                                    AND    Properties.SingleSection);
	
	Return New FixedStructure(Properties);
	
EndFunction

// See comment in the calling function ClosingDates.DataTemplateForChecking().
Function DataTemplateForChecking() Export
	
	DataForChecking = New ValueTable;
	
	DataForChecking.Columns.Add(
		"Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	
	DataForChecking.Columns.Add(
		"Section", New TypeDescription("ChartOfCharacteristicTypesRef.ClosingDateSections"));
	
	DataForChecking.Columns.Add(
		"Object", Metadata.ChartsOfCharacteristicTypes.ClosingDateSections.Type);
	
	Return DataForChecking;
	
EndFunction

// Returns data sources, filled in procedure.
// ClosingDatesOverridable.FillDataSourcesForChangeProhibitionCheck().
//
Function DataSourcesForChangeProhibitionCheck() Export
	
	DataSources = New ValueTable;
	DataSources.Columns.Add("Table",     New TypeDescription("String"));
	DataSources.Columns.Add("DataField",    New TypeDescription("String"));
	DataSources.Columns.Add("Section",      New TypeDescription("String"));
	DataSources.Columns.Add("ObjectField", New TypeDescription("String"));
	
	ClosingDatesOverridable.FillDataSourcesForChangeProhibitionCheck(
		DataSources);
	
	Return DataSources;
	
EndFunction

#EndRegion
