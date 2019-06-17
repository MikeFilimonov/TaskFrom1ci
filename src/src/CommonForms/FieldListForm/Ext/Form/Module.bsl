
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If NOT Parameters.Property("Mode", Mode) OR NOT Parameters.Property("SchemaURL") OR NOT Parameters.Property("SettingsAddress") Then
		Cancel = True;
		Return;
	EndIf;
	Parameters.Property("ExistsFields", ExistsFields);
	CloseOnChoice = True;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(Parameters.SchemaURL));
	Composer.LoadSettings(GetFromTempStorage(Parameters.SettingsAddress));
	
	SetConditionalAppearance();
	
	Fields.GetItems().Clear();
	If Mode = "GroupFields" Then
		Header = NStr("en = 'Group fields'");
		AddGroupFields();
	ElsIf Mode = "FilterFields" Then
		Header = NStr("en = 'Filter fields'");
		AddFilters();
	EndIf; 
	
EndProcedure

#EndRegion 

#Region FormItemsHandlers

&AtClient
Procedure FieldsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Str = Items.Fields.CurrentData;
	If Str = Undefined OR Str.NotSelect Then
		Return;
	EndIf; 
	
	NotifyChoice(Str.Field);
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	Str = Items.Fields.CurrentData;
	If Str = Undefined OR Str.NotSelect Then
		Return;
	EndIf; 
	
	NotifyChoice(Str.Field);
	
EndProcedure

#EndRegion 

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Fields");

	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("Fields.NotSelect");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.RightValue		= True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);

EndProcedure

&AtServer
Procedure AddGroupFields()
	
	AvailableFields = Composer.Settings.GroupAvailableFields.Items;
	PreviousFieldName = ""; 
	
	For each Field In AvailableFields Do
		
		If Field.Folder OR Field.Resource Then
			Continue;
		EndIf; 
		
		FieldName = String(Field.Field);
		
		If FieldName = PreviousFieldName Then
			Continue;
		EndIf; 
		
		If FieldName = "DynamicPeriod" Then
			Continue;
		EndIf; 
		
		AttributesList = New ValueList;
		PreviousAttributeName = "";
		
		For each Attribute In Field.Items Do
			
			If Attribute.Folder Then
				// Table selection
				Continue;
			EndIf; 
			
			AttributeName = TrimAll(String(Attribute.Field));
			If AttributeName = PreviousAttributeName Then
				Continue;
			EndIf; 
			
			If NOT ExistsFields.FindByValue(AttributeName) = Undefined Then
				Continue;
			EndIf;
			
			If NOT AttributesList.FindByValue(AttributeName) = Undefined Then
				Continue;
			EndIf;
			
			AttributesList.Add(AttributeName, Attribute.Header);
			PreviousAttributeName = AttributeName;
			
		EndDo;
		
		InExists = NOT ExistsFields.FindByValue(FieldName) = Undefined;
		
		If InExists AND AttributesList.Count()=0 Then
			Continue;
		EndIf;
		
		StrField = Fields.GetItems().Add();
		StrField.Field			= FieldName;
		StrField.Presentation	= Field.Header;
		PreviousFieldName		= FieldName;
		
		For each ListItem In AttributesList Do
			
			StrAttribute = StrField.GetItems().Add();
			StrAttribute.Field			= ListItem.Value;
			StrAttribute.Presentation	= TextAfterDot(ListItem.Presentation, Field.Header);
			StrAttribute.Picture		= 1;
			
		EndDo; 
		
		If InExists Then
			StrField.NotSelect = True;
		EndIf;
		
		StrField.Picture = ?(StrField.NotSelect, 0, ?(Field.Resource, 2, 1))
	EndDo; 
	
EndProcedure

&AtServer
Procedure AddFilters()
	
	For each Field In Composer.Settings.FilterAvailableFields.Items Do
		
		If Field.Folder Then
			Continue;
		EndIf;
		
		FieldName = String(Field.Field);
		If FieldName = "DynamicPeriod" Then
			Continue;
		EndIf; 
		
		If TextAfterDot(FieldName) = "Ref" Then
			Continue;
		EndIf;
		
		InExists = NOT ExistsFields.FindByValue(FieldName) = Undefined;
		
		StrField 				= Fields.GetItems().Add();
		StrField.Field			= FieldName;
		StrField.Presentation	= Field.Title;
		
		SkipNested	= False;
		
		If Field.Type.Types().Count() = 1 
			AND Enums.AllRefsType().ContainsType(Field.Type.Types().Get(0)) Then
				SkipNested = True;
		EndIf; 
		
		If NOT SkipNested Then
			
			For each Attribute In Field.Items Do
				
				AttributeName = TrimAll(String(Attribute.Field));
				If TextAfterDot(AttributeName, FieldName) = "Ref" Then
					Continue;
				EndIf;
				
				If NOT ExistsFields.FindByValue(AttributeName)=Undefined Then
					Continue;
				EndIf;
				
				If Attribute.Folder AND Right(AttributeName, 5) = ".Tags" Then
					Continue;
				EndIf;
				
				StrAttribute				= StrField.GetItems().Add();
				StrAttribute.Field			= AttributeName;
				StrAttribute.Presentation	= StrReplace(Attribute.Title, Field.Title + ".", "");
				
				If Attribute.Folder Then
					
					StrAttribute.Picture	= 0;
					StrAttribute.NotSelect	= True;
					
					For each TSAttribute In Attribute.Items Do
						
						TSAttributeName = TrimAll(String(TSAttribute.Field));
						
						If NOT ExistsFields.FindByValue(TSAttributeName) = Undefined Then
							Continue;
						EndIf; 
						
						If TextAfterDot(TSAttributeName, AttributeName) = "Ref" Then
							Continue;
						EndIf; 
						
						AttributeTSRow = StrAttribute.GetItems().Add();
						AttributeTSRow.Field		= TSAttributeName;
						AttributeTSRow.Presentation	= StrReplace(TSAttribute.Title, Attribute.Title + ".", "");
						AttributeTSRow.Picture		= 1;
						
					EndDo; 
				Else
					StrAttribute.Picture = 1;
				EndIf;  
			EndDo; 
		EndIf;
		
		If InExists AND StrField.GetItems().Count() = 0 Then
			Fields.GetItems().Delete(StrField);
			Continue; 
		ElsIf InExists Then
			StrField.NotSelect = True;
		EndIf;
		
		SelectionField		= Composer.Settings.SelectionAvailableFields.FindField(Field.Field);
		StrField.Picture	= ?(StrField.NotSelect, 0, ?(NOT SelectionField = Undefined AND SelectionField.Resource, 2, 1))
	EndDo; 
	
EndProcedure

&AtServer
Function TextAfterDot(Val Text, Val ParentText = "")
	
	If IsBlankString(ParentText) Then
		Return Text;
	EndIf;
	
	Return StrReplace(Text, ParentText + ".", "");
	
EndFunction

#EndRegion
 

 