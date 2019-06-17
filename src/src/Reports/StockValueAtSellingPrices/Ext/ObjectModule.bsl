#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	// From attribute to the composer
	ParameterKindOfPrice							= New DataCompositionParameter("PriceKind");
	ValueOfParameterPriceKind 				= SettingsComposer.Settings.DataParameters.FindParameterValue(ParameterKindOfPrice);
	If Not ValueOfParameterPriceKind = Undefined Then
		
		ValueOfParameterPriceKind.Value 		= PriceKind;
		ValueOfParameterPriceKind.Use 	= True;
		
	EndIf;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod = Date(1,1,1);
	
	ParameterBeginOfPeriod = CompositionTemplate.ParameterValues.Find("BeginOfPeriod");
	If Not ParameterBeginOfPeriod = Undefined Then
		BeginOfPeriod = ParameterBeginOfPeriod.Value;
	EndIf;
	
	ParameterEndOfPeriod = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If Not ParameterEndOfPeriod = Undefined Then
		EndOfPeriod = ParameterEndOfPeriod.Value;
	EndIf;
	
	// Create and initialize the processor layout and precheck parameters
	If Not BeginOfPeriod = Date(1,1,1)
		AND Not EndOfPeriod = Date(1,1,1)
		AND BeginOfPeriod > EndOfPeriod Then
		
		MessageText	 	= NStr("en = 'Period start cannot be greater than period end'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If Not ValueIsFilled(PriceKind)
		OR CompositionTemplate.ParameterValues["PriceKind"].Value = Catalogs.PriceTypes.EmptyRef() Then
		
		MessageText	 	= NStr("en = 'The price kind for report generation is not selected.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	CalculationTable 			= GetCalculationTable(BeginOfPeriod, EndOfPeriod);
	ExternalDataSets 		= New Structure("CalculationTable", CalculationTable);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	// Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	// Main cycle of the report output
	While True Do
		// Get the next item of a composition result
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			// The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If  Not TableFixed 
				  AND ResultItem.ParameterValues.Count() > 0 
				  AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;

			EndIf;
			// Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();
	
EndProcedure

// Generate a table of balances and register records 
//
Function GetCalculationTable(BeginOfPeriod, EndOfPeriod)
	
	// In the base there are documents that were
	// registered by one time, add extra bypass cycle with arrangement of the documents order.
	Query							= New Query;
	Query.Text					= 
	"SELECT ALLOWED
	|	InventoryInWarehouses.SecondPeriod AS SecondPeriod,
	|	InventoryInWarehouses.Recorder AS Recorder,
	|	InventoryInWarehouses.Products AS Products,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	ISNULL(InventoryInWarehouses.QuantityOpeningBalance, 0) AS QuantityOpeningBalance,
	|	ISNULL(InventoryInWarehouses.QuantityReceipt, 0) AS QuantityReceipt,
	|	ISNULL(InventoryInWarehouses.QuantityExpense, 0) AS QuantityExpense,
	|	ISNULL(InventoryInWarehouses.QuantityClosingBalance, 0) AS QuantityClosingBalance,
	|	InventoryInWarehouses.Recorder.PointInTime AS RecorderPointInTime,
	|	0 AS Order
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.BalanceAndTurnovers(&BeginOfPeriod, &EndOfPeriod, AUTO, , ) AS InventoryInWarehouses
	|
	|ORDER BY
	|	RecorderPointInTime";
	
	Query.SetParameter("BeginOfPeriod",	BeginOfPeriod);
	Query.SetParameter("EndOfPeriod",	EndOfPeriod);
	
	InventoryRegisterRecordsTable = Query.Execute().Unload();
	
	For Each InventoryItemRegisterRecord In InventoryRegisterRecordsTable Do
		
		InventoryItemRegisterRecord.Order = InventoryRegisterRecordsTable.IndexOf(InventoryItemRegisterRecord) + 1;
		
	EndDo;
	
	Query.Text					= 
	"SELECT
	|	InventoryInWarehouses.SecondPeriod AS Period,
	|	InventoryInWarehouses.Recorder AS Recorder,
	|	InventoryInWarehouses.Products AS Products,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehouses.QuantityOpeningBalance,
	|	InventoryInWarehouses.QuantityReceipt,
	|	InventoryInWarehouses.QuantityExpense,
	|	InventoryInWarehouses.QuantityClosingBalance,
	|	InventoryInWarehouses.Order
	|INTO BalanceAndTurnovers
	|FROM
	|	&BalanceAndTurnovers AS InventoryInWarehouses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	BEGINOFPERIOD(PricesTable.Period, Day) AS Period,
	|	PricesTable.Recorder,
	|	PricesTable.Products,
	|	PricesTable.Characteristic,
	|	PricesActual.Price,
	|	ISNULL(PricesPrevious.Price, 0) AS OldPrice,
	|	PricesActual.Price - ISNULL(PricesPrevious.Price, 0) AS Delta
	|INTO PriceChanges
	|FROM
	|	(SELECT
	|		ActualPrices.Period AS Period,
	|		MAX(PricesBeforeChanges.Period) AS LastChangeDate,
	|		""Change of the price"" AS Recorder,
	|		ActualPrices.PriceKind AS PriceKind,
	|		ActualPrices.Products AS Products,
	|		ActualPrices.Characteristic AS Characteristic
	|	FROM
	|		InformationRegister.Prices AS ActualPrices
	|			LEFT JOIN InformationRegister.Prices AS PricesBeforeChanges
	|			ON ActualPrices.Products = PricesBeforeChanges.Products
	|				AND ActualPrices.Characteristic = PricesBeforeChanges.Characteristic
	|				AND (PricesBeforeChanges.PriceKind = &PriceKind)
	|				AND ActualPrices.Period > PricesBeforeChanges.Period
	|	WHERE
	|		ActualPrices.PriceKind = &PriceKind
	|	
	|	GROUP BY
	|		ActualPrices.PriceKind,
	|		ActualPrices.Products,
	|		ActualPrices.Characteristic,
	|		ActualPrices.Period) AS PricesTable
	|		LEFT JOIN InformationRegister.Prices AS PricesActual
	|		ON PricesTable.Period = PricesActual.Period
	|			AND PricesTable.PriceKind = PricesActual.PriceKind
	|			AND PricesTable.Products = PricesActual.Products
	|			AND PricesTable.Characteristic = PricesActual.Characteristic
	|		LEFT JOIN InformationRegister.Prices AS PricesPrevious
	|		ON PricesTable.LastChangeDate = PricesPrevious.Period
	|			AND PricesTable.PriceKind = PricesPrevious.PriceKind
	|			AND PricesTable.Products = PricesPrevious.Products
	|			AND PricesTable.Characteristic = PricesPrevious.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PriceTypes.PriceCurrency AS Currency,
	|	TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod AS SecondPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, MINUTE) AS MinutePeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, hour) AS HourPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, Day) AS DayPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, WEEK) AS WeekPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, MONTH) AS MonthPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, QUARTER) AS QuarterPeriod,
	|	BEGINOFPERIOD(TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod, YEAR) AS YearPeriod,
	|	TableInventoryInWarehousesMaximumPeriod.Recorder,
	|	TableInventoryInWarehousesMaximumPeriod.StructuralUnit,
	|	TableInventoryInWarehousesMaximumPeriod.Products,
	|	TableInventoryInWarehousesMaximumPeriod.Characteristic,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityOpeningBalance AS QuantityOpeningBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityReceipt AS QuantityReceipt,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityExpense AS QuantityExpense,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityClosingBalance AS QuantityClosingBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityOpeningBalance * Prices.Price AS AmountOpeningBalance,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityReceipt * Prices.Price AS AmountReceipt,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityExpense * Prices.Price AS AmountExpense,
	|	TableInventoryInWarehousesMaximumPeriod.QuantityClosingBalance * Prices.Price AS AmountClosingBalance,
	|	TableInventoryInWarehousesMaximumPeriod.Order AS Order,
	|	TableInventoryInWarehousesMaximumPeriod.RegisterRecordPeriod AS RegistrationDate,
	|	Prices.Price AS CurrentPrice
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Period AS RegisterRecordPeriod,
	|		InventoryInWarehouses.Recorder AS Recorder,
	|		InventoryInWarehouses.Products AS Products,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.QuantityOpeningBalance AS QuantityOpeningBalance,
	|		InventoryInWarehouses.QuantityReceipt AS QuantityReceipt,
	|		InventoryInWarehouses.QuantityExpense AS QuantityExpense,
	|		InventoryInWarehouses.QuantityClosingBalance AS QuantityClosingBalance,
	|		InventoryInWarehouses.Order AS Order,
	|		MAX(Prices.Period) AS PeriodMaximum
	|	FROM
	|		BalanceAndTurnovers AS InventoryInWarehouses
	|			LEFT JOIN PriceChanges AS Prices
	|			ON InventoryInWarehouses.Products = Prices.Products
	|				AND InventoryInWarehouses.Characteristic = Prices.Characteristic
	|				AND InventoryInWarehouses.Period >= Prices.Period
	|	{WHERE
	|		InventoryInWarehouses.Products,
	|		InventoryInWarehouses.Characteristic}
	|	
	|	GROUP BY
	|		InventoryInWarehouses.Period,
	|		InventoryInWarehouses.Recorder,
	|		InventoryInWarehouses.Products,
	|		InventoryInWarehouses.Characteristic,
	|		InventoryInWarehouses.StructuralUnit,
	|		InventoryInWarehouses.QuantityOpeningBalance,
	|		InventoryInWarehouses.QuantityReceipt,
	|		InventoryInWarehouses.QuantityExpense,
	|		InventoryInWarehouses.QuantityClosingBalance,
	|		InventoryInWarehouses.Order) AS TableInventoryInWarehousesMaximumPeriod
	|		LEFT JOIN PriceChanges AS Prices
	|		ON TableInventoryInWarehousesMaximumPeriod.Products = Prices.Products
	|			AND TableInventoryInWarehousesMaximumPeriod.Characteristic = Prices.Characteristic
	|			AND TableInventoryInWarehousesMaximumPeriod.PeriodMaximum = Prices.Period
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON (PriceTypes.Ref = &PriceKind)
	|
	|UNION ALL
	|
	|SELECT
	|	PriceTypes.PriceCurrency,
	|	ClosestBalancesByProducts.Period,
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, MINUTE),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, hour),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, Day),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, WEEK),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, MONTH),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, QUARTER),
	|	BEGINOFPERIOD(ClosestBalancesByProducts.Period, YEAR),
	|	ClosestBalancesByProducts.Recorder,
	|	ClosestBalancesByProducts.StructuralUnit,
	|	ClosestBalancesByProducts.Products,
	|	ClosestBalancesByProducts.Characteristic,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance, 0),
	|	0,
	|	0,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance, 0),
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProducts.OldPrice, 0),
	|	CASE
	|		WHEN ClosestBalancesByProducts.Delta > 0
	|			THEN ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProducts.Delta, 0)
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN ClosestBalancesByProducts.Delta < 0
	|			THEN ISNULL(-InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProducts.Delta, 0)
	|		ELSE 0
	|	END,
	|	ISNULL(InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance * ClosestBalancesByProducts.Price, 0),
	|	ClosestBalancesByProducts.Order,
	|	ClosestBalancesByProducts.Period,
	|	ClosestBalancesByProducts.Price
	|FROM
	|	(SELECT
	|		PriceChanges.Period AS Period,
	|		PriceChanges.Delta AS Delta,
	|		PriceChanges.Price AS Price,
	|		PriceChanges.OldPrice AS OldPrice,
	|		PriceChanges.Products AS Products,
	|		PriceChanges.Characteristic AS Characteristic,
	|		InventoryInWarehousesBalanceAndTurnovers.StructuralUnit AS StructuralUnit,
	|		MAX(InventoryInWarehousesBalanceAndTurnovers.Order) AS Order,
	|		PriceChanges.Recorder AS Recorder
	|	FROM
	|		PriceChanges AS PriceChanges
	|			LEFT JOIN BalanceAndTurnovers AS InventoryInWarehousesBalanceAndTurnovers
	|			ON PriceChanges.Products = InventoryInWarehousesBalanceAndTurnovers.Products
	|				AND PriceChanges.Characteristic = InventoryInWarehousesBalanceAndTurnovers.Characteristic
	|				AND PriceChanges.Period > InventoryInWarehousesBalanceAndTurnovers.Period
	|	WHERE
	|		PriceChanges.Period <= &EndOfPeriod
	|	{WHERE
	|		PriceChanges.Products.*,
	|		PriceChanges.Characteristic.*}
	|	
	|	GROUP BY
	|		PriceChanges.Products,
	|		InventoryInWarehousesBalanceAndTurnovers.StructuralUnit,
	|		PriceChanges.Characteristic,
	|		PriceChanges.Delta,
	|		PriceChanges.Price,
	|		PriceChanges.OldPrice,
	|		PriceChanges.Period,
	|		PriceChanges.Recorder) AS ClosestBalancesByProducts
	|		LEFT JOIN BalanceAndTurnovers AS InventoryInWarehousesBalanceAndTurnovers
	|		ON ClosestBalancesByProducts.Products = InventoryInWarehousesBalanceAndTurnovers.Products
	|			AND ClosestBalancesByProducts.Characteristic = InventoryInWarehousesBalanceAndTurnovers.Characteristic
	|			AND ClosestBalancesByProducts.StructuralUnit = InventoryInWarehousesBalanceAndTurnovers.StructuralUnit
	|			AND ClosestBalancesByProducts.Order = InventoryInWarehousesBalanceAndTurnovers.Order
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON (PriceTypes.Ref = &PriceKind)
	|WHERE
	|	ClosestBalancesByProducts.Order > 0
	|	AND InventoryInWarehousesBalanceAndTurnovers.Order > 0
	|
	|ORDER BY
	|	Order";
	
	
	Query.SetParameter("BalanceAndTurnovers", 	InventoryRegisterRecordsTable);
	Query.SetParameter("PriceKind", 			PriceKind);
	
	// See above
	//
	//Query.SetParameter("BeginOfPeriod", 		ReportObject.BeginOfPeriod);
	//Query.SetParameter("EndOfPeriod", 		ReportObject.EndOfPeriod);
	
	CalculationTable = Query.Execute().Unload();
	
	Return CalculationTable;
	
EndFunction

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = "Stock value at selling prices";
	ParametersToBeIncludedInSelectionText = New Array;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use Then
		
		If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
			BeginOfPeriod = ParameterPeriod.Value.Date;
		Else
			BeginOfPeriod = ParameterPeriod.Value;
		EndIf;
	EndIf;
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterPeriod <> Undefined
		AND ParameterPeriod.Use Then
		
		If TypeOf(ParameterPeriod.Value) = Type("StandardBeginningDate") Then
			EndOfPeriod = ParameterPeriod.Value.Date;
		Else
			EndOfPeriod = ParameterPeriod.Value;
		EndIf;
	EndIf;
	
	ParameterKindOfPrice = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("PriceKind"));
	If ParameterKindOfPrice <> Undefined
		AND ParameterKindOfPrice.Use Then
		
		ParameterKindOfPrice.UserSettingPresentation = NStr("en = 'Price kind'");
		ParametersToBeIncludedInSelectionText.Add(ParameterKindOfPrice);
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod"                  , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"                   , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"              , TitleOutput);
	ReportParameters.Insert("Title"                      , Title);
	ReportParameters.Insert("ParametersToBeIncludedInSelectionText", ParametersToBeIncludedInSelectionText);
	ReportParameters.Insert("ReportId"            , "StockValueAtSellingPrices");
	ReportParameters.Insert("ReportSettings"	              , ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf