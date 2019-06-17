
#Region WorkWithTabularSectionProducts

Procedure FillDataInTabularSectionRow(Object, TabularSectionName, TabularSectionRow) Export
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	If WorkWithProductsClientServer.IsObjectAttribute("Characteristic", TabularSectionRow) Then
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	EndIf;
	StructureData.Insert("ProcessingDate", CurrentDate());
	If WorkWithProductsClientServer.IsObjectAttribute("Factor", TabularSectionRow) 
		AND WorkWithProductsClientServer.IsObjectAttribute("Multiplicity", TabularSectionRow) 
		Then
		StructureData.Insert("TimeNorm", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("VATTaxation", Object) Then
		StructureData.Insert("VATTaxation", Object.VATTaxation);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("DocumentCurrency", Object) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("AmountIncludesVAT", Object) Then
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("PriceKind", Object) AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("PriceKind", Object.PriceKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("SupplierPriceTypes", Object) AND ValueIsFilled(Object.SupplierPriceTypes) Then
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("MeasurementUnit", Object) AND TypeOf(TabularSectionRow.MeasurementUnit)=Type("CatalogRef.UOM") Then
		StructureData.Insert("Factor", TabularSectionRow.MeasurementUnit.Factor);
	Else
		StructureData.Insert("Factor", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("WorkKind", Object) AND ValueIsFilled(Object.WorkKind) Then
		StructureData.Insert("WorkKind", Object.WorkKind);
	EndIf; 
	
	UseDiscounts = WorkWithProductsClientServer.IsObjectAttribute("DiscountMarkupKind", Object);
	If UseDiscounts AND ValueIsFilled(Object.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("DiscountCard", Object) AND ValueIsFilled(Object.DiscountCard) Then
		StructureData.Insert("DiscountCard", Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	EndIf; 

	RowFillingData = GetProductDataOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, RowFillingData);
	
	If WorkWithProductsClientServer.IsObjectAttribute("Quantity", TabularSectionRow) Then
		
		If TabularSectionName = "Works" Then
			
			TabularSectionRow.Quantity = StructureData.TimeNorm;
			
			If Not ValueIsFilled(TabularSectionRow.Multiplicity) Then
				TabularSectionRow.Multiplicity = 1;
			EndIf;
			If Not ValueIsFilled(TabularSectionRow.Factor) Then
				TabularSectionRow.Factor = 1;
			EndIf;
			
			TabularSectionRow.ProductsTypeService = StructureData.IsService;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If WorkWithProductsClientServer.IsObjectAttribute("ProductsTypeInventory", Object) Then
				TabularSectionRow.ProductsTypeInventory = StructureData.IsInventory;
			EndIf;
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		ElsIf TabularSectionName = "ConsumerMaterials" Then
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		EndIf;
		
		WorkWithProductsClientServer.CalculateAmountInTabularSectionRow(Object, TabularSectionRow, TabularSectionName);
		
	EndIf;
	
EndProcedure

Function GetProductDataOnChange(StructureData)
	
	StructureData.Insert("BaseMeasurementUnit", StructureData.Products.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
	StructureData.Insert("IsInventory", StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation")
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products.VATRate) Then
		StructureData.Insert("VATRate", StructureData.Products.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		If Not StructureData.Property("DocumentCurrency") AND ValueIsFilled(StructureData.PriceKind) Then
			StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			CurProduct = StructureData.Products;
			StructureData.Products = StructureData.WorkKind;
			StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
			StructureData.Products = CurProduct;
		
		Else
			
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		EndIf;
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind")
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction

Function PrintGuaranteeCard(ObjectsArray, PrintObjects) Export
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		GenerateDocumentGuaranteeCards(SpreadsheetDocument, CurrentDocument, Errors);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	Return SpreadsheetDocument;
	
EndFunction

Function GenerateDocumentGuaranteeCards(SpreadsheetDocument, CurrentDocument, Errors) Export
	
	DocumentName = CurrentDocument.Metadata().Name;
	
	Query = New Query();
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text = 
	"SELECT
	|	PrintDoc.Date AS DocumentDate,
	|	PrintDoc.Number AS Number,
	|	PrintDoc.Company.Prefix AS Prefix,
	|	PrintDoc.Company.LogoFile AS LogoFile,
	|	PrintDoc.Responsible.Ind AS Responsible,
	|	PrintDoc.Inventory.(
	|		LineNumber AS LineNumber,
	|		Products.GuaranteePeriod AS GuaranteePeriod,
	|		Products.WriteOutTheGuaranteeCard AS WriteOutTheGuaranteeCard,
	|		CASE
	|			WHEN (CAST(PrintDoc.Inventory.Products.DescriptionFull AS STRING(100))) = """"
	|				THEN PrintDoc.Inventory.Products.Description
	|			ELSE PrintDoc.Inventory.Products.DescriptionFull
	|		END AS InventoryItem,
	|		Products.SKU AS SKU,
	|		Products.Code AS Code,
	|		MeasurementUnit.Description AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Characteristic,
	|		Products.ProductsType AS ProductsType,
	|		ConnectionKey
	|	),
	|	%1 AS Counterparty,
	|	PrintDoc.Company,
	|	PrintDoc.SerialNumbers.(
	|		SerialNumber,
	|		ConnectionKey
	|	)
	|FROM
	|	Document.%2 AS PrintDoc
	|WHERE
	|	PrintDoc.Ref = &CurrentDocument
	|	AND PrintDoc.Inventory.Products.WriteOutTheGuaranteeCard
	|
	|ORDER BY
	|	LineNumber";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersInString(
		Query.Text,
		?(TypeOf(CurrentDocument) = Type("DocumentRef.SalesSlip"),
			"VALUE(Catalog.Counterparties.EmptyRef)",
			"PrintDoc.Counterparty"),
		DocumentName);
	
	Header = Query.Execute().Select();
	If Header.Count()=0 Then
		MessageText = NStr("en = '__________________
		                   |Document %1.
		                   |None of the goods in the document have the <Issue a warranty card> feature'");
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, CurrentDocument);
		CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
		Return Undefined;
	EndIf;
	Header.Next();
	
	LinesSelectionInventory = Header.Inventory.Select();
	LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_GuaranteeCard";
	
	Template = PrintManagement.PrintedFormsTemplate("CommonTemplate.PF_MXL_WarrantyCard");
	
	DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
	
	If ValueIsFilled(Header.LogoFile) Then
		
		TemplateArea = Template.GetArea("TitleLogo");
		
		PictureData = AttachedFiles.GetFileBinaryData(Header.LogoFile);
		If ValueIsFilled(PictureData) Then
			
			TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
			
		EndIf;
		
	Else // If you have not selected images print normal title
		
		TemplateArea = Template.GetArea("Title");
		
	EndIf;
	
	TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Warranty card #%1 dated %2'"),
		DocumentNumber,
		Format(Header.DocumentDate, "DLF=DD"));
	
	InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
	TemplateArea.Parameters.Company = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,ActualAddress,PhoneNumbers");
	TemplateArea.Parameters.Counterparty = Header.Counterparty;
	
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("TableHeader");
	SpreadsheetDocument.Put(TemplateArea);
	TemplateArea = Template.GetArea("String");
	
	LineNumber = 1;
	While LinesSelectionInventory.Next() Do
		
		If NOT LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
			Continue;
		EndIf;
		
		TemplateArea.Parameters.Fill(LinesSelectionInventory);
		TemplateArea.Parameters.LineNumber = LineNumber;
		
		StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
		TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
			LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
		
		SpreadsheetDocument.Put(TemplateArea);
		
		LineNumber = LineNumber+1;
		
	EndDo;
	
	TemplateArea = Template.GetArea("Total");
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Signatures");
	TemplateArea.Parameters.Fill(Header);
	SpreadsheetDocument.Put(TemplateArea);
	
	SpreadsheetDocument.FitToPage = True;
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion