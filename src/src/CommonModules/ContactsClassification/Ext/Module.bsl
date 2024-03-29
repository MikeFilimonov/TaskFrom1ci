﻿
#Region ObjectForm

// Procedure creates items of tags display in the form of the object
//
// Parameters:
//  Form	 - 	 - 
Procedure UpdateTagsCloud(Form) Export
	
	Items = Form.Items;
	Object = Form.Object;
	
	ToDeleteArray = New Array;
	For Each ItemTag In Items.TagCloud.ChildItems Do
		If Left(ItemTag.Name, 12) = "StringTags_" AND Not ItemTag.Name = "StringTags_1" Then
			ToDeleteArray.Add(ItemTag);
		EndIf;
	EndDo;
	For Each ItemTag In Items.StringTags_1.ChildItems Do
		If Left(ItemTag.Name, 4) = "Tag_" Then
			ToDeleteArray.Add(ItemTag);
		EndIf;
	EndDo;
	For Each ItemTag In ToDeleteArray Do
		Items.Delete(ItemTag);
	EndDo;
	
	FirstStringMaxLength = 61;
	MaxStringLength = FirstStringMaxLength + 24;
	ItemNumber = 0;
	ItemsStringNumber = 1;
	CurrentStringLength = 0;
	TagsGroup = Items.StringTags_1;
	
	For Each StringTags In Object.Tags Do
		
		ItemNumber = ItemNumber + 1;
		TagPresentation = String(StringTags.Tag);
		If StrLen(TagPresentation) > 15 Then
			TagPresentation = Left(TagPresentation, 15) + "...";
			TagLength = 15 + 1;
		Else
			TagLength = StrLen(TagPresentation) + 2;
		EndIf;
		
		CurrentStringLength = CurrentStringLength + TagLength;
		
		If (ItemsStringNumber = 1 AND CurrentStringLength > FirstStringMaxLength) Or (ItemsStringNumber > 1 AND CurrentStringLength > MaxStringLength) Then
			
			CurrentStringLength = TagLength;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			TagsGroup = Items.Add("StringTags_" + ItemsStringNumber, Type("FormGroup"), ?(ItemsStringNumber = 1, Items.FirstRow, Items.TagCloud));
			TagsGroup.Type = FormGroupType.UsualGroup;
			TagsGroup.Group = ChildFormItemsGroup.Horizontal;
			TagsGroup.ShowTitle = False;
			TagsGroup.Representation = UsualGroupRepresentation.None;
			TagsGroup.VerticalStretch = False;
			TagsGroup.Height = 1;
			
		EndIf;
		
		TagComponents = New Array;
		TagComponents.Add(New FormattedString(TagPresentation + " "));
		TagComponents.Add(New FormattedString(PictureLib.Clear, , , , "TagID_" + StringTags.GetID()));
		
		ItemTag = Items.Add("Tag_" + ItemNumber, Type("FormDecoration"), TagsGroup);
		ItemTag.Type = FormDecorationType.Label;
		ItemTag.Title = New FormattedString(TagComponents);
		ItemTag.ToolTip = String(StringTags.Tag);
		ItemTag.BackColor = StyleColors.FormBackColor;
		ItemTag.Border = New Border(ControlBorderType.Single, 1);
		ItemTag.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemTag.Width = StrLen(TagPresentation) + 2;
		ItemTag.SetAction("URLProcessing", "Attachable_TagURLProcessing");
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ListForm

// Procedure creates form items for filtering by periods
//
// Parameters:
//  Form	 - list form
Procedure RefreshPeriodsFilterValues(Form) Export
	
	Items = Form.Items;
	Form.FilterCreated.Clear();
	
	SessionDate = CurrentSessionDate();
	
	PeriodArbitrary = Form.FilterCreated.Add();
	
	PeriodToday = Form.FilterCreated.Add();
	PeriodToday.Value.Variant = StandardPeriodVariant.Today;
	
	Period3Days = Form.FilterCreated.Add();
	Period3Days.Value.StartDate = BegOfDay(SessionDate) - 2*24*3600;
	Period3Days.Value.EndDate = EndOfDay(SessionDate);
	
	WeekPeriod = Form.FilterCreated.Add();
	WeekPeriod.Value.Variant = StandardPeriodVariant.Last7Days;
	
	MonthPeriod = Form.FilterCreated.Add();
	MonthPeriod.Value.Variant = StandardPeriodVariant.Month;
	
EndProcedure

// Procedure creates item forms for filtering by tags
//
// Parameters:
//  Form					 - list
//  form MaxStringLength	 - Number - maximum number of characters which fit in one string
Procedure RefreshTagFilterValues(Form, MaxStringLength = 85) Export
	
	Items = Form.Items;
	Form.FilterTags.Clear();
	
	DeletedItemsArray = New Array;
	For Each Item In Items.FilterValuesTags.ChildItems Do
		If Left(Item.Name, 4) = "Tag_" Or Left(Item.Name, 11) = "StringTags" Then
			DeletedItemsArray.Add(Item);
		EndIf;
	EndDo;
	For Each Item In DeletedItemsArray Do
		Items.Delete(Item);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tags.Ref,
		|	Tags.Presentation AS Presentation
		|FROM
		|	Catalog.Tags AS Tags
		|WHERE
		|	Tags.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
	
	Selection = Query.Execute().Select();
	
	ItemNumber = 0;
	ItemsStringNumber = 0;
	CurrentStringLength = 0;
	
	While Selection.Next() Do
		
		If StrLen(Selection.Presentation) > 15 Then
			TagPresentation = Left(Selection.Presentation, 15) + "...";
			CurrentStringLength = CurrentStringLength + 15 + 2;
		Else
			TagPresentation = Selection.Presentation;
			CurrentStringLength = CurrentStringLength + StrLen(TagPresentation) + 2;
		EndIf;
		
		StringTagsFilter = Form.FilterTags.Add(Selection.Ref, TagPresentation);
		
		If ItemsStringNumber = 0 Or CurrentStringLength > MaxStringLength Then
			
			CurrentStringLength = StrLen(TagPresentation) + 2;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			TagsGroup = Items.Add("StringTags" + ItemsStringNumber, Type("FormGroup"), Items.FilterValuesTags);
			TagsGroup.Type = FormGroupType.UsualGroup;
			TagsGroup.Group = ChildFormItemsGroup.Horizontal;
			TagsGroup.ShowTitle = False;
			TagsGroup.Representation = UsualGroupRepresentation.None;
			TagsGroup.VerticalStretch = False;
			TagsGroup.Height = 1;
			
		EndIf;
		
		ItemTag = Items.Add("Tag_" + StringTagsFilter.GetID(), Type("FormField"), TagsGroup);
		ItemTag.Type = FormFieldType.LabelField;
		ItemTag.DataPath = "FilterTags[" + ItemNumber + "].Presentation";
		ItemTag.Hyperlink = True;
		ItemTag.TitleLocation = FormItemTitleLocation.None;
		ItemTag.ToolTip = Selection.Presentation;
		ItemTag.TextColor = StyleColors.FieldTextColor;
		ItemTag.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemTag.Width = StrLen(TagPresentation);
		ItemTag.HorizontalStretch = False;
		ItemTag.SetAction("Click", "Attachable_TagFilterClick");
		
		ItemNumber = ItemNumber + 1;
		
	EndDo;
	
	If Selection.Count() = 0 Then
		
		ItemExplanation = Items.Add("Tag_Explanation", Type("FormDecoration"), Items.FilterValuesTags);
		ItemExplanation.Type = FormDecorationType.Label;
		ItemExplanation.Hyperlink = True;
		ItemExplanation.Title = "How to work with tags?";
		ItemExplanation.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemExplanation.SetAction("Click", "Attachable_TagFilterClick");
		
	EndIf;
	
EndProcedure

// Procedure creates form items for filtering by segments
//
// Parameters:
//  Form	 - list
//  form MaxStringLength	 - Number - maximum number of characters which fit in one string
Procedure RefreshSegmentsFilterValues(Form, MaxStringLength = 85) Export
	
	Items = Form.Items;
	Form.FilterSegments.Clear();
	
	DeletedItemsArray = New Array;
	For Each Item In Items.FilterValuesSegments.ChildItems Do
		If Left(Item.Name, 8) = "Segment_" Or Left(Item.Name, 15) = "SegmentsString" Then
			DeletedItemsArray.Add(Item);
		EndIf;
	EndDo;
	For Each Item In DeletedItemsArray Do
		Items.Delete(Item);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Segments.Ref,
		|	Segments.Presentation AS Presentation
		|FROM
		|	Catalog.Segments AS Segments
		|WHERE
		|	Segments.DeletionMark = FALSE
		|	AND Segments.IsFolder = FALSE
		|
		|ORDER BY
		|	Presentation";
	
	Selection = Query.Execute().Select();
	
	ItemNumber = 0;
	ItemsStringNumber = 0;
	CurrentStringLength = 0;
	
	While Selection.Next() Do
		
		If StrLen(Selection.Presentation) > 15 Then
			SegmentPresentation = Left(Selection.Presentation, 15) + "...";
			CurrentStringLength = CurrentStringLength + 15 + 2;
		Else
			SegmentPresentation = Selection.Presentation;
			CurrentStringLength = CurrentStringLength + StrLen(SegmentPresentation) + 2;
		EndIf;
		
		SegmentsFilterString = Form.FilterSegments.Add(Selection.Ref, SegmentPresentation);
		
		If ItemsStringNumber = 0 Or CurrentStringLength > MaxStringLength Then
			
			CurrentStringLength = StrLen(SegmentPresentation) + 2;
			ItemsStringNumber = ItemsStringNumber + 1;
			
			SegmentsGroup = Items.Add("SegmentsString" + ItemsStringNumber, Type("FormGroup"), Items.FilterValuesSegments);
			SegmentsGroup.Type = FormGroupType.UsualGroup;
			SegmentsGroup.Group = ChildFormItemsGroup.Horizontal;
			SegmentsGroup.ShowTitle = False;
			SegmentsGroup.Representation = UsualGroupRepresentation.None;
			SegmentsGroup.VerticalStretch = False;
			SegmentsGroup.Height = 1;
			
		EndIf;
		
		ItemSegment = Items.Add("Segment_" + SegmentsFilterString.GetID(), Type("FormField"), SegmentsGroup);
		ItemSegment.Type = FormFieldType.LabelField;
		ItemSegment.DataPath = "FilterSegments[" + ItemNumber + "].Presentation";
		ItemSegment.Hyperlink = True;
		ItemSegment.TitleLocation = FormItemTitleLocation.None;
		ItemSegment.ToolTip = Selection.Presentation;
		ItemSegment.TextColor = StyleColors.FieldTextColor;
		ItemSegment.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemSegment.Width = StrLen(SegmentPresentation);
		ItemSegment.HorizontalStretch = False;
		ItemSegment.SetAction("Click", "Attachable_SegmentFilterClick");
		
		ItemNumber = ItemNumber + 1;
		
	EndDo;
	
	If Selection.Count() = 0 Then
		
		ItemExplanation = Items.Add("Segment_Explanation", Type("FormDecoration"), Items.FilterValuesSegments);
		ItemExplanation.Type = FormDecorationType.Label;
		ItemExplanation.Hyperlink = True;
		ItemExplanation.Title = "How to work with segments?";
		ItemExplanation.HorizontalAlign = ItemHorizontalLocation.Center;
		ItemExplanation.SetAction("Click", "Attachable_SegmentFilterClick");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

// Tag creation function
//
// Parameters:
//  TagName - String - tag
// name Return value:
//  CatalogRef.Tags - reference to created item
Function CreateTag(TagName) Export
	
	NewTag = Catalogs.Tags.CreateItem();
	NewTag.Description = TagName;
	NewTag.Write();
	
	Return NewTag.Ref;
	
EndFunction

// Procedure changes color of the filter item depending
// on the sign of use It is required to call from the server for connected procedures, otherwise, the color is not rendered
//
// Parameters:
//  Form		 - list
//  form Mark		 - Boolean - Shows that filter by this
//  item ItemName is used	 - String - form item name
Procedure ChangeSelectionItemColor(Form, Mark, ItemName) Export
	
	FilterItem = Form.Items.Find(ItemName);
	If FilterItem = Undefined Then
		Return;
	EndIf;
	
	If Mark Then
		FilterItem.BackColor = StyleColors.FilterActiveValueBackground;
	Else
		FilterItem.BackColor = New Color;
	EndIf;
	
EndProcedure

#EndRegion

#Region Counterparties

Function CounterpartyRelationshipTypeByOperationKind(OperationKind) Export
	
	Result = New Structure("Customer, Supplier, OtherRelationship", False, False, False);
	
	If TypeOf(OperationKind) = Type("EnumRef.OperationTypesGoodsReceipt") Then
		
		If OperationKind = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
			Or OperationKind = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
			Result.Customer = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesGoodsIssue") Then
		
		If OperationKind = Enums.OperationTypesGoodsIssue.SaleToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
			Result.Customer = True;
			Result.Supplier = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesCashReceipt") Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesCashReceipt.Other Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesCashVoucher") Then
		
		If OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesPaymentReceipt") Then
		
		If OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesPaymentExpense") Then
		
		If OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
			Result.OtherRelationship = True;
		EndIf;
		
	ElsIf TypeOf(OperationKind) = Type("EnumRef.OperationTypesArApAdjustments") Then
		
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
			Result.Supplier = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment Then
			Result.Customer = True;
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment Then
			Result.Supplier = True;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
