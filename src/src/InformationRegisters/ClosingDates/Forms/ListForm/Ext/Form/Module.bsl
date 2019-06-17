
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Command setting
	SectionsProperties = ClosingDatesServiceReUse.SectionsProperties();
	Items.DataImportProhibitionDateForm.Visible = SectionsProperties.UseProhibitionDatesOfDataImport;
	
	// Order setting
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("User");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Section");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
	OrderingItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderingItem.Field = New DataCompositionField("Object");
	OrderingItem.OrderType = DataCompositionSortDirection.Asc;
	OrderingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderingItem.Use = True;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DataClosingDates(Command)
	
	OpenForm("InformationRegister.ClosingDates.Form.ClosingDates");
	
EndProcedure

&AtClient
Procedure DataClosingDatesOfDataImport(Command)
	
	FormParameters = New Structure("DataClosingDatesOfDataImport", True);
	OpenForm("InformationRegister.ClosingDates.Form.ClosingDates", FormParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	For Each UserType In Metadata.InformationRegisters.ClosingDates.Dimensions.User.Type.Types() Do
		MetadataObject = Metadata.FindByType(UserType);
		If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		
		IssueValue(CommonUse.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef(),
			MetadataObject.Presentation() + ": " + NStr("en = '<All infobases>'"));
	EndDo;
	
	IssueValue(Undefined,
		NStr("en = 'Undefined'"));
	
	IssueValue(Catalogs.Users.EmptyRef(),
		NStr("en = 'Empty user'"));
	
	IssueValue(Catalogs.UserGroups.EmptyRef(),
		NStr("en = 'Empty user group'"));
	
	IssueValue(Catalogs.ExternalUsers.EmptyRef(),
		NStr("en = 'Empty external user'"));
	
	IssueValue(Catalogs.ExternalUserGroups.EmptyRef(),
		NStr("en = 'Empty external user group'"));
	
	IssueValue(Enums.ClosingDateAreas.ForAllUsers,
		"<" + Enums.ClosingDateAreas.ForAllUsers + ">");
	
	IssueValue(Enums.ClosingDateAreas.ForAllDatabases,
		"<" + Enums.ClosingDateAreas.ForAllDatabases + ">");
	
EndProcedure

&AtServer
Procedure IssueValue(Value, Text)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListUser.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.User");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Value;
	
	Item.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

#EndRegion
