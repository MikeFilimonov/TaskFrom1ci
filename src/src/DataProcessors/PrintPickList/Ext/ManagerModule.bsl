#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Print

Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	If TemplateName = "PickList" Then
		
		Return PrintPickList(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

Function PrintPickList(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PickList";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintPickListQueryText
	
	Query.Text = 
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	CAST(SalesOrder.Comment AS STRING(1024)) AS Comment,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.Comment AS Comment,
	|	SalesOrder.Number AS SalesOrderNumber,
	|	SalesOrder.Date AS SalesOrderDate,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.ShipmentDate AS ShipmentDate,
	|	Header.Comment AS Comment,
	|	Header.SalesOrderNumber AS SalesOrderNumber,
	|	Header.SalesOrderDate AS SalesOrderDate,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.CompanyLogoFile,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Comment,
	|	Header.Ref,
	|	Header.SalesOrderDate,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	Header.DocumentNumber,
	|	Header.Counterparty,
	|	Header.ShipmentDate,
	|	Header.SalesOrderNumber,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.SKU,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.Products,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyLogoFile,
	|	Header.Counterparty,
	|	Header.ShipmentDate,
	|	Header.Comment,
	|	Header.SalesOrderNumber,
	|	Header.SalesOrderDate,
	|	SalesOrderWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(SalesOrderWorks.Content AS STRING(1024))) <> """"
	|			THEN CAST(SalesOrderWorks.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(SalesOrderWorks.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	SalesOrderWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Factor * SalesOrderWorks.Multiplicity AS NUMBER(15, 3)),
	|	SalesOrderWorks.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	SalesOrderWorks.Products,
	|	CatalogUOMClassifier.Ref,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesOrder.Works AS SalesOrderWorks
	|		ON Header.Ref = SalesOrderWorks.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesOrderWorks.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesOrderWorks.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.ShipmentDate AS ShipmentDate,
	|	Tabular.Comment AS Comment,
	|	Tabular.SalesOrderNumber AS SalesOrderNumber,
	|	Tabular.SalesOrderDate AS SalesOrderDate,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.UOM AS UOM,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(ShipmentDate),
	|	MAX(Comment),
	|	MAX(SalesOrderNumber),
	|	MAX(SalesOrderDate),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesOrderSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesOrderSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesOrderSerialNumbers.Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[5].Select();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PickList";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintPickList.PF_MXL_PickList");
		
		#Region PrintPickListTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintPickListCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintPickListCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		CounterpartyInfoArea.Parameters.SalesOrders = Header.SalesOrderNumber
			+ StringFunctionsClientServer.SubstituteParametersInString(
				" %1 ", NStr("en = 'dated'"))
			+ Format(Header.SalesOrderDate, "DLF=D");
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'"));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'"));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation = DriveServer.InfoAboutLegalEntityIndividual(Header.StructuralUnit, Header.DocumentDate);
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'");
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'");
			
		Else
			
			InfoAboutShippingAddress = DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintPickListCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintPickListTotalsAreaPrefill
		
		TotalsAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		TotalsAreasArray.Add(LineTotalArea);
		
		#EndRegion
		
		#Region PrintPickListLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintPickListTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf
