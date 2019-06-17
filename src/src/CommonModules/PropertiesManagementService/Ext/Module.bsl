////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"PropertiesManagementService");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"PropertiesManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects"].Add(
		"PropertiesManagementService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"PropertiesManagementService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects"].Add(
			"PropertiesManagementService");
		
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"PropertiesManagementService");
	EndIf;
	
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of UpdateResults common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlersManagement = True;
	Handler.Version = "*";
	Handler.PerformModes = "Promptly";
	Handler.Procedure = "PropertiesManagementService.FillSeparatedDataHandlers";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.PerformModes = "Promptly";
	Handler.Procedure = "PropertiesManagement.UpdateSetsAndPropertiesNames";
	
EndProcedure

// Returns the list of all properties for metadata object.
//
// Parameters:
//  ObjectsKind - String - Full metadata object name;
//  PropertiesKind  - String - "AdditionalAttributes" or "AdditionalInformation".
//
// ReturnValue:
//  ValueTable - Property, Description, ValueType.
//  Undefined    - there is no set of properties for specified kind of object.
//
Function PropertyListForObjectKind(ObjectsKind, Val PropertiesKind) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertiesSets.Ref AS Ref,
	|	PropertiesSets.PredefinedDataName AS PredefinedDataName
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets AS PropertiesSets
	|WHERE
	|	PropertiesSets.Predefined";
	Selection = Query.Execute().Select();
	
	PredefinedDataName = StrReplace(ObjectsKind, ".", "_");
	SetReference = Undefined;
	
	While Selection.Next() Do
		If Selection.PredefinedDataName = PredefinedDataName Then
			SetReference = Selection.Ref;
			Break;
		EndIf;
	EndDo;
	
	If SetReference = Undefined Then
		Return Undefined;
	EndIf;
	
	QueryText = 
	"SELECT
	|	PropertyTable.Property AS Property,
	|	PropertyTable.Property.Description AS Description,
	|	PropertyTable.Property.ValueType AS ValueType
	|FROM
	|	&PropertyTable AS PropertyTable
	|WHERE
	|	PropertyTable.Ref IN HIERARCHY(&Ref)";
	
	FullTableName = "Catalog.AdditionalAttributesAndInformationSets." + PropertiesKind;
	QueryText = StrReplace(QueryText, "&PropertyTable", FullTableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", SetReference);
	
	Result = Query.Execute().Unload();
	Result.GroupBy("Property,Description,ValueType");
	Result.Sort("Description Asc");
	
	Return Result;
	
EndFunction

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - specify the full name of the metadata
//                            object as a key connected to the Deny editing objects attributes subsystem. 
//                            As a value - empty row.
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.FullName(), "");
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalValues.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalValuesHierarchy.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalAttributesAndInformationSets.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// See procedure of the same name in common module PropertiesManagement.
Procedure MoveValuesFromFormAttributesToObject(Form, Object = Undefined, BeforeWrite = False) Export
	
	If Not Form.Properties_UseProperties
	 OR Not Form.Properties_UseAdditAttributes Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDescription = Form.Object;
	Else
		ObjectDescription = Object;
	EndIf;
	
	OldValues = ObjectDescription.AdditionalAttributes.Unload();
	ObjectDescription.AdditionalAttributes.Clear();
	
	For Each String In Form.Properties_AdditionalAttributesDescription Do
		
		Value = Form[String.AttributeNameValue];
		
		If Value = Undefined Then
			Continue;
		EndIf;
		
		If String.ValueType.Types().Count() = 1
		   AND (NOT ValueIsFilled(Value) Or Value = False) Then
			
			Continue;
		EndIf;
		
		If String.Deleted Then
			If ValueIsFilled(Value) AND Not (BeforeWrite AND Form.Properties_HideDeleted) Then
				FillPropertyValues(ObjectDescription.AdditionalAttributes.Add(),
					OldValues.Find(String.Property, "Property"));
			EndIf;
			Continue;
		EndIf;
		
		NewRow = ObjectDescription.AdditionalAttributes.Add();
		NewRow.Property = String.Property;
		NewRow.Value = Value;
		
		// Supporting rows of unlimited length.
		UseOpenEndedString = UseOpenEndedString(
			String.ValueType, String.MultilineTextBox);
		
		If UseOpenEndedString Then
			NewRow.TextString = Value;
		EndIf;
	EndDo;
	
	If BeforeWrite Then
		Form.Properties_HideDeleted = False;
	EndIf;
	
EndProcedure

// Returns the table of accessible properties sets of the owner.
//
// Parameters:
//  PropertiesOwner - Reference to properties owner.
//                    Object of properties owner.
//                    FormDataStructure (by object type of properties owner).
//
Function GetObjectPropertiesSets(Val PropertiesOwner, PurposeKey = Undefined) Export
	
	If TypeOf(PropertiesOwner) = Type("FormDataStructure") Then
		ReferenceType = TypeOf(PropertiesOwner.Ref)
		
	ElsIf CommonUse.IsReference(TypeOf(PropertiesOwner)) Then
		ReferenceType = TypeOf(PropertiesOwner);
	Else
		ReferenceType = TypeOf(PropertiesOwner.Ref)
	EndIf;
	
	GetMainSet = True;
	
	PropertiesSets = New ValueTable;
	PropertiesSets.Columns.Add("Set");
	PropertiesSets.Columns.Add("Height");
	PropertiesSets.Columns.Add("Title");
	PropertiesSets.Columns.Add("ToolTip");
	PropertiesSets.Columns.Add("VerticalStretch");
	PropertiesSets.Columns.Add("HorizontalStretch");
	PropertiesSets.Columns.Add("ReadOnly");
	PropertiesSets.Columns.Add("TitleTextColor");
	PropertiesSets.Columns.Add("Width");
	PropertiesSets.Columns.Add("TitleFont");
	PropertiesSets.Columns.Add("Group");
	PropertiesSets.Columns.Add("Representation");
	PropertiesSets.Columns.Add("ChildItemsWidth");
	PropertiesSets.Columns.Add("Picture");
	PropertiesSets.Columns.Add("ShowTitle");
	
	PropertiesManagementOverridable.FillObjectPropertiesSets(
		PropertiesOwner, ReferenceType, PropertiesSets, GetMainSet, PurposeKey);
	
	If PropertiesSets.Count() = 0
	   AND GetMainSet = True Then
		
		MainSet = GetMainPropertiesSetForObject(PropertiesOwner);
		
		If ValueIsFilled(MainSet) Then
			PropertiesSets.Add().Set = MainSet;
		EndIf;
	EndIf;
	
	Return PropertiesSets;
	
EndFunction

// Returns completed table of object properties values.
Function GetPropertiesValuesTable(AdditionalObjectProperties, Sets, ThisIsAdditionalInformation) Export
	
	If AdditionalObjectProperties.Count() = 0 Then
		// Preliminary fast check of additional properties use.
		Query = New Query;
		Query.SetParameter("PropertiesSets", Sets.UnloadValues());
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS SetsProperties
		|WHERE
		|	SetsProperties.Ref IN(&PropertiesSets)
		|	AND Not SetsProperties.DeletionMark";
		
		If ThisIsAdditionalInformation Then
			Query.Text = StrReplace(
				Query.Text,
				"Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes",
				"Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation");
		EndIf;
		
		SetPrivilegedMode(True);
		PropertiesNotFound = Query.Execute().IsEmpty();
		SetPrivilegedMode(False);
		If PropertiesNotFound Then
			PropertiesDescription = New ValueTable;
			PropertiesDescription.Columns.Add("Set");
			PropertiesDescription.Columns.Add("Property");
			PropertiesDescription.Columns.Add("AdditionalValuesOwner");
			PropertiesDescription.Columns.Add("FillObligatory");
			PropertiesDescription.Columns.Add("Description");
			PropertiesDescription.Columns.Add("ValueType");
			PropertiesDescription.Columns.Add("FormatProperties");
			PropertiesDescription.Columns.Add("MultilineTextBox");
			PropertiesDescription.Columns.Add("Deleted");
			PropertiesDescription.Columns.Add("Value");
			Return PropertiesDescription;
		EndIf;
	EndIf;
	
	Properties = AdditionalObjectProperties.UnloadColumn("Property");
	
	PropertiesSets = New ValueTable;
	
	PropertiesSets.Columns.Add(
		"Set", New TypeDescription("CatalogRef.AdditionalAttributesAndInformationSets"));
	
	PropertiesSets.Columns.Add(
		"SetOrder", New TypeDescription("Number"));
	
	For Each ItemOfList In Sets Do
		NewRow = PropertiesSets.Add();
		NewRow.Set         = ItemOfList.Value;
		NewRow.SetOrder = Sets.IndexOf(ItemOfList);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Properties",      Properties);
	Query.SetParameter("PropertiesSets", PropertiesSets);
	Query.Text =
	"SELECT
	|	PropertiesSets.Set,
	|	PropertiesSets.SetOrder
	|INTO PropertiesSets
	|FROM
	|	&PropertiesSets AS PropertiesSets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PropertiesSets.Set,
	|	PropertiesSets.SetOrder,
	|	SetsProperties.Property,
	|	SetsProperties.DeletionMark,
	|	SetsProperties.LineNumber AS PropertyOrder
	|INTO SetsProperties
	|FROM
	|	PropertiesSets AS PropertiesSets
	|		INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS SetsProperties
	|		ON (SetsProperties.Ref = PropertiesSets.Set)
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|		ON (SetsProperties.Property = Properties.Ref)
	|WHERE
	|	Not SetsProperties.DeletionMark
	|	AND Not Properties.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Properties.Ref AS Property
	|INTO FilledProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|WHERE
	|	Properties.Ref IN(&Properties)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SetsProperties.Set,
	|	SetsProperties.SetOrder,
	|	SetsProperties.Property,
	|	SetsProperties.PropertyOrder,
	|	SetsProperties.DeletionMark AS Deleted
	|INTO AllProperties
	|FROM
	|	SetsProperties AS SetsProperties
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Catalog.AdditionalAttributesAndInformationSets.EmptyRef),
	|	0,
	|	FilledProperties.Property,
	|	0,
	|	TRUE
	|FROM
	|	FilledProperties AS FilledProperties
	|		LEFT JOIN SetsProperties AS SetsProperties
	|		ON FilledProperties.Property = SetsProperties.Property
	|WHERE
	|	SetsProperties.Property IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AllProperties.Set,
	|	AllProperties.Property,
	|	AdditionalAttributesAndInformation.AdditionalValuesOwner,
	|	AdditionalAttributesAndInformation.FillObligatory,
	|	AdditionalAttributesAndInformation.Title AS Description,
	|	AdditionalAttributesAndInformation.ValueType,
	|	AdditionalAttributesAndInformation.FormatProperties,
	|	AdditionalAttributesAndInformation.MultilineTextBox,
	|	AllProperties.Deleted AS Deleted
	|FROM
	|	AllProperties AS AllProperties
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
	|		ON AllProperties.Property = AdditionalAttributesAndInformation.Ref
	|
	|ORDER BY
	|	Deleted,
	|	AllProperties.SetOrder,
	|	AllProperties.PropertyOrder";
	
	If ThisIsAdditionalInformation Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation");
	EndIf;
	
	PropertiesDescription = Query.Execute().Unload();
	PropertiesDescription.Indexes.Add("Property");
	PropertiesDescription.Columns.Add("Value");
	
	// Deleting duplicates of properties in lower set of properties.
	IndexOf = PropertiesDescription.Count()-1;
	
	While IndexOf >= 0 Do
		String = PropertiesDescription[IndexOf];
		FoundString = PropertiesDescription.Find(String.Property);
		
		If FoundString <> Undefined
		   AND FoundString <> String Then
			
			PropertiesDescription.Delete(IndexOf);
		EndIf;
		
		IndexOf = IndexOf-1;
	EndDo;
	
	// Filling in properties values.
	For Each String In AdditionalObjectProperties Do
		PropertyDetails = PropertiesDescription.Find(String.Property, "Property");
		If PropertyDetails <> Undefined Then
			// Supporting rows of unlimited length.
			If Not ThisIsAdditionalInformation
			   AND UseOpenEndedString(
			         PropertyDetails.ValueType, PropertyDetails.MultilineTextBox)
			   AND Not IsBlankString(String.TextString) Then 
				
				PropertyDetails.Value = String.TextString;
			Else
				PropertyDetails.Value = String.Value;
			EndIf;
		EndIf;
	EndDo;
	
	Return PropertiesDescription;
	
EndFunction

// Returns the values of additional data.
Function ReadPropertiesValuesFromInformationRegister(PropertyOwner) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalInformation.Property,
	|	AdditionalInformation.Value
	|FROM
	|	InformationRegister.AdditionalInformation AS AdditionalInformation
	|WHERE
	|	AdditionalInformation.Object = &Object";
	Query.SetParameter("Object", PropertyOwner);
	
	Return Query.Execute().Unload();
	
EndFunction

// Returns metadata object which owns
// the properties values of the set of additional attributes and data.
//
Function PropertiesSetValuesOwnerMetadata(Ref, ConsiderMarkRemoval = True, ReferenceType = Undefined) Export
	
	If Not ValueIsFilled(Ref) Then
		Return Undefined;
	EndIf;
	
	RefProperties = CommonUse.ObjectAttributesValues(
		Ref, "DeletionMark, IsFolder, Predefined, Parent");
	
	If ConsiderMarkRemoval AND RefProperties.DeletionMark Then
		Return Undefined;
	EndIf;
	
	If RefProperties.IsFolder Then
		RefOfPredefined = Ref;
		
	ElsIf RefProperties.Predefined
	        AND RefProperties.Parent = Catalogs.AdditionalAttributesAndInformationSets.EmptyRef() Then
		
		RefOfPredefined = Ref;
	Else
		RefOfPredefined = Ref.Parent;
	EndIf;
	
	PredefinedName = CommonUse.PredefinedName(RefOfPredefined);
	
	Position = Find(PredefinedName, "_");
	
	FirstPartOfTheName =  Left(PredefinedName, Position - 1);
	SecondPartOfName = Right(PredefinedName, StrLen(PredefinedName) - Position);
	
	OwnerMetadata = Metadata.FindByFullName(FirstPartOfTheName + "." + SecondPartOfName);
	
	If OwnerMetadata <> Undefined Then
		ReferenceType = Type(FirstPartOfTheName + "Ref." + SecondPartOfName);
	EndIf;
	
	Return OwnerMetadata;
	
EndFunction

// Returns the use by set of additional attributes and data.
Function SetPropertyTypes(Ref, ConsiderMarkRemoval = True) Export
	
	SetPropertyTypes = New Structure;
	SetPropertyTypes.Insert("AdditionalAttributes", False);
	SetPropertyTypes.Insert("AdditionalInformation",  False);
	
	ReferenceType = Undefined;
	OwnerMetadata = PropertiesSetValuesOwnerMetadata(Ref, ConsiderMarkRemoval, ReferenceType);
	
	If OwnerMetadata = Undefined Then
		Return SetPropertyTypes;
	EndIf;
	
	// Check of additional attributes use.
	SetPropertyTypes.Insert(
		"AdditionalAttributes",
		OwnerMetadata <> Undefined
		AND OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined );
	
	// Check of additional data use.
	SetPropertyTypes.Insert(
		"AdditionalInformation",
		      Metadata.CommonCommands.Find("AdditionalInformationCommandBar") <> Undefined
		    AND Metadata.CommonCommands.AdditionalInformationCommandBar.CommandParameterType.ContainsType(ReferenceType)
		OR   Metadata.CommonCommands.Find("AdditionalInformationNavigationPanel") <> Undefined
		    AND Metadata.CommonCommands.AdditionalInformationNavigationPanel.CommandParameterType.ContainsType(ReferenceType) );
	
	Return SetPropertyTypes;
	
EndFunction

// Defines that the type of value contains the type of additional values of properties.
Function ValueTypeContainsPropertiesValues(ValueType) Export
	
	Return ValueType.ContainsType(Type("CatalogRef.AdditionalValues"))
	    OR ValueType.ContainsType(Type("CatalogRef.AdditionalValuesHierarchy"));
	
EndFunction

// Checks if it is possible to use the row of unlimited length for a property.
Function UseOpenEndedString(PropertyValueType, MultilineTextBox) Export
	
	If PropertyValueType.ContainsType(Type("String"))
	   AND PropertyValueType.Types().Count() = 1
	   AND MultilineTextBox > 1 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Checks the existence of objects that use the property.
// 
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation
// 
// Returns:
//  Boolean. True if at least one object is found.
//
Function AdditionalPropertyInUse(Property) Export
	
	Query = New Query;
	Query.SetParameter("Property", Property);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AdditionalInformation AS AdditionalInformation
	|WHERE
	|	AdditionalInformation.Property = &Property";
	
	If Not Query.Execute().IsEmpty() Then
		Return True;
	EndIf;
	
	MetadataObjectKinds = New Array;
	MetadataObjectKinds.Add("ExchangePlans");
	MetadataObjectKinds.Add("Catalogs");
	MetadataObjectKinds.Add("Documents");
	MetadataObjectKinds.Add("ChartsOfCharacteristicTypes");
	MetadataObjectKinds.Add("ChartsOfAccounts");
	MetadataObjectKinds.Add("ChartsOfCalculationTypes");
	MetadataObjectKinds.Add("BusinessProcesses");
	MetadataObjectKinds.Add("Tasks");
	
	TablesObjects = New Array;
	For Each KindMetadataObjects In MetadataObjectKinds Do
		For Each MetadataObject In Metadata[KindMetadataObjects] Do
			
			If IsMetadataObjectWithAdditionalDetails(MetadataObject) Then
				TablesObjects.Add(MetadataObject.FullName());
			EndIf;
			
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	TableName AS CurrentTable
	|WHERE
	|	CurrentTable.Property = &Property";
	
	For Each Table In TablesObjects Do
		Query.Text = StrReplace(QueryText, "TableName", Table + ".AdditionalAttributes");
		If Not Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks if metadata object is using additional attributes.
// Check is intended for control of
// referential integrity, that is why the check of embedding is skipped.
//
Function IsMetadataObjectWithAdditionalDetails(MetadataObject) Export
	
	If MetadataObject = Metadata.Catalogs.AdditionalAttributesAndInformationSets Then
		Return False;
	EndIf;
	
	TabularSection = MetadataObject.TabularSections.Find("AdditionalAttributes");
	If TabularSection = Undefined Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Property");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	If Not Attribute.Type.ContainsType(Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation")) Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Value");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns the name of
// predefined set received from metadata object found by the name of predefined set.
// 
// Parameters:
//  Set - CatalogRef.AdditionalAttributesAndInformationSets,
//        - String - full name of predefined item.
//
Function DescriptionPredefinedSet(Set) Export
	
	If TypeOf(Set) = Type("String") Then
		PredefinedName = Set;
	Else
		PredefinedName = CommonUse.PredefinedName(Set);
	EndIf;
	
	Position = Find(PredefinedName, "_");
	FirstPartOfTheName =  Left(PredefinedName, Position - 1);
	SecondPartOfName = Right(PredefinedName, StrLen(PredefinedName) - Position);
	
	FullName = FirstPartOfTheName + "." + SecondPartOfName;
	
	MetadataObject = Metadata.FindByFullName(FullName);
	If MetadataObject = Undefined Then
		If TypeOf(Set) = Type("String") Then
			Return "";
		Else
			Return CommonUse.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	If ValueIsFilled(MetadataObject.ObjectPresentation) Then
		Description = MetadataObject.ObjectPresentation;
		
	ElsIf ValueIsFilled(MetadataObject.Synonym) Then
		Description = MetadataObject.Synonym;
	Else
		If TypeOf(Set) = Type("String") Then
			Description = "";
		Else
			Description = CommonUse.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	Return Description;
	
EndFunction

// Update of upper group content for use
// when setting the content of dynamic list fields and setup (selections, ...).
//
// Parameters:
//  Group        - CatalogRef.AdditionalAttributesAndInformationSets,
//                  with a mark IsFolder=True.
//
Procedure CheckRefreshContentFoldersProperties(Group) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Group", Group);
	Query.Text =
	"SELECT DISTINCT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AdditionalInformation.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS AdditionalInformation
	|WHERE
	|	AdditionalInformation.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property";
	
	QueryResult = Query.ExecuteBatch();
	AdditionalAttributesGroups = QueryResult[0].Unload();
	AdditionalInformationGroups  = QueryResult[1].Unload();
	
	ObjectGroup = Group.GetObject();
	
	Refresh = False;
	
	If ObjectGroup.AdditionalAttributes.Count() <> AdditionalAttributesGroups.Count() Then
		Refresh = True;
	EndIf;
	
	If ObjectGroup.AdditionalInformation.Count() <> AdditionalInformationGroups.Count() Then
		Refresh = True;
	EndIf;
	
	If Not Refresh Then
		IndexOf = 0;
		For Each String In ObjectGroup.AdditionalAttributes Do
			If String.Property <> AdditionalAttributesGroups[IndexOf].Property Then
				Refresh = True;
			EndIf;
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
	
	If Not Refresh Then
		IndexOf = 0;
		For Each String In ObjectGroup.AdditionalInformation Do
			If String.Property <> AdditionalInformationGroups[IndexOf].Property Then
				Refresh = True;
			EndIf;
			IndexOf = IndexOf + 1;
		EndDo;
		Return;
	EndIf;
	
	ObjectGroup.AdditionalAttributes.Load(AdditionalAttributesGroups);
	ObjectGroup.AdditionalInformation.Load(AdditionalInformationGroups);
	ObjectGroup.Write();
	
EndProcedure

#Region EventHandlersOfTheSSLSubsystems

// Fills the array with the list of metadata
// objects names that might include references
// to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add("InformationRegister.AdditionalInformation");
	Array.Add("Catalog.AdditionalAttributesAndInformationSets");
	
EndProcedure

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used
// in access restriction templates must be filled, while
// the access types used in access values sets may be
// received from the current data register AccessValueSets.
//
//  To prepare the procedure content
// automatically, you should use the developer tools for subsystem.
// Access management.
//
// Parameters:
//  Definition     - String, multiline string in format <Table>.<Right>.<AccessKind>[.Object table].
//                 For
//                           example,
//                           Document.SupplierInvoice.Read.Company
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.EMails.Read.Object.Document.EMails
//                           Document.EMails.Change.Object.Document.EMails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.EMail
//                 Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.EMail Access
//                 kind Object predefined as literal. This access kind is used in the access limitations templates as
//                 "ref" to another object according to which the current table object is restricted.
//                 When the Object access kind is specified, you should
//                 also specify tables types that are used for this
//                 access kind. I.e. enumerate types that correspond to
//                 the field used in the access limitation template in the pair with the Object access kind. While
//                 enumerating types by the "Object" access kind, you need to list only those field types that the field
//                 has. InformationRegisters.AccessValueSets.Object, the rest types are extra.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Definition) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
	
	If ModuleAccessManagementService.AccessKindExists("AdditionalInformation") Then
		
		Definition = Definition + 
		"
		|Catalog.AdditionalValues.Read.AdditionalInformation
		|Catalog.AdditionalValuesHierarchy.Read.AdditionalInformation
		|ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.Read.AdditionalInformation
		|InformationRegister.AdditionalInformation.Read.AdditionalInformation
		|InformationRegister.AdditionalInformation.Update.AdditionalInformation
		|";
	EndIf;
	
EndProcedure

// Fills kinds of access used by access rights restriction.
// Access types Users and ExternalUsers are complete.
// They can be deleted if they are not used for access rights restriction.
//
// Parameters:
//  AccessKinds - ValuesTable with fields:
//  - Name                    - String - a name used in
//                             the description of delivered access groups profiles and ODD texts.
//  - Presentation          - String - introduces an access type in profiles and access groups.
//  - ValuesType            - Type - Type of access values reference.       For example, Type("CatalogRef.Products").
//  - ValueGroupType       - Type - Reference type of access values groups. For
//  example, Type("CatalogRef.ProductsAccessGroups").
//  - SeveralGroupsOfValues - Boolean - True shows that for access value
//                             (Products) several value groups can be selected (Products access group).
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalInformation";
	AccessKind.Presentation = NStr("en = 'Additional information'");
	AccessKind.ValuesType   = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation");
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - need to receive a list of RIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		Objects.Add(Metadata.Constants.AdditionalAttributesAndInformationParameters);
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes
// registration for this plan. These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.Constants.AdditionalAttributesAndInformationParameters);
	
EndProcedure

#EndRegion

#Region HelperProcedureAndFunctions

// Returns the default set of owner properties.
//
// Parameters:
//  PropertiesOwner - Reference or Object of properties owner.
//
// Returns:
//  CatalogRef.AdditionalAttributesAndInformationSets -
//   when the name of object kind attribute in the procedure is not assigned for the type of properties owner.
//         PropertiesManagementOverridable.GetObjectKindAttributeName(),
//   then a predefined item with a name
//   in the format of metadata object full name with character " is returned." substitued with
//   character "_", otherwise, the value of attribute PropertiesSet
//   is returned in the format included in property owner attribute with the name assigned
//   in an overridable procedure.
//
//  Undefined - when properties owner - group of catalog
//                 items or group of items of characteristic kinds plan.
//  
Function GetMainPropertiesSetForObject(PropertiesOwner)
	
	TransferredObject = False;
	If CommonUse.ReferenceTypeValue(PropertiesOwner) Then
		Ref = PropertiesOwner;
	Else
		TransferredObject = True;
		Ref = PropertiesOwner.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	
	MetadataObjectKind = CommonUse.ObjectKindByRef(Ref);
	PropertiesOwnersKindAttributeName = PropertiesManagementOverridable.GetObjectKindAttributeName(Ref);
	
	If PropertiesOwnersKindAttributeName = "" Then
		If MetadataObjectKind = "Catalog" Or MetadataObjectKind = "ChartOfCharacteristicTypes" Then
			If CommonUse.ObjectIsFolder(PropertiesOwner) Then
				Return Undefined;
			EndIf;
		EndIf;
		ItemName = MetadataObjectKind + "_" + MetadataObjectName;
		Return Catalogs.AdditionalAttributesAndInformationSets[ItemName];
	Else
		If TransferredObject = True Then
			
			Return CommonUse.ObjectAttributeValue(
				PropertiesOwner[PropertiesOwnersKindAttributeName], "PropertySet");
		Else
			Query = New Query;
			Query.Text =
			"SELECT
			|	ObjectPropertiesOwner." + PropertiesOwnersKindAttributeName + ".PropertiesSet
			|AS Set FROM
			|	" + MetadataObjectKind + "." + MetadataObjectName + " AS
			|ObjectPropertiesOwner
			|	WHERE ObjectPropertiesOwner.Reference = &Reference";
			
			Query.SetParameter("Ref", Ref);
			Result = Query.Execute();
			
			If Not Result.IsEmpty() Then
				
				Selection = Result.Select();
				Selection.Next();
				
				If ValueIsFilled(Selection.Set) Then
					Return Selection.Set;
				Else
					Return Catalogs.AdditionalAttributesAndInformationSets.EmptyRef();
				EndIf;
			Else
				Return Catalogs.AdditionalAttributesAndInformationSets.EmptyRef();
			EndIf;
		EndIf;
	EndIf;
	
EndFunction

// Is used at updating an infobase.
Function HasChangesMetadataObjectsWithPropertiesOfPresentation()
	
	SetPrivilegedMode(True);
	
	Catalogs.AdditionalAttributesAndInformationSets
		.RefreshContentOfPredefinedSets();
	
	Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
		"AdditionalAttributesAndInformationParameters");
	
	LastChanges = StandardSubsystemsServer.ApplicationPerformenceParameterChanging(
		Parameters, "PredefinedSetsOfAdditionalDetailsAndInformation");
		
	If LastChanges = Undefined
	 OR LastChanges.Count() > 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#Region InfoBaseUpdate

// Fills the separated data handler which is dependent on the change in unseparated data.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see description 
//    of function NewUpdateHandlersTable of common module.
//    UpdateResults.
//    For the direct call (not using the IB
// version update mechanism) Undefined is passed.
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined AND HasChangesMetadataObjectsWithPropertiesOfPresentation() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.PerformModes = "Promptly";
		Handler.Procedure = "PropertiesManagement.UpdateSetsAndPropertiesNames";
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
