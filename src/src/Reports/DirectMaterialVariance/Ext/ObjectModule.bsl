#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	Var TableOutput;
	Var TablePlanCostsOnOutput;
	
	StandardProcessing = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ParameterValues = CompositionTemplate.ParameterValues;
	DataCompositionParameter = ParameterValues.Find("EndOfPeriod");
	If Not DataCompositionParameter = Undefined Then
		
		If TypeOf(DataCompositionParameter.Value) = Type("Date")
			AND DataCompositionParameter.Value = Date(1,1,1) Then
		
			DataCompositionParameter.Value = Date(3999,12,31);
			
		EndIf;
	
	EndIf;
	
	GenerateTableOutputAndPlanCosts(TableOutput, TablePlanCostsOnOutput, ParameterValues);
	
	CalculateCostPricePlannedCostsOnOutput(TablePlanCostsOnOutput);
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("TableOutput", TableOutput);
	ExternalDataSets.Insert("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	
	// Create and initialize a composition processor
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

Procedure GenerateTableOutputAndPlanCosts(TableOutput, TablePlanCostsOnOutput, ParameterValues)
	
	PeriodOpenDate = Date(1,1,1);
	EndDatePeriod = Date(3999,12,31);
	
	DataCompositionParameter = ParameterValues.Find("BeginOfPeriod");
	If Not DataCompositionParameter = Undefined 
		AND TypeOf(DataCompositionParameter.Value) = Type("Date")
		AND DataCompositionParameter.Value <> Date(1,1,1) Then
		
		PeriodOpenDate = DataCompositionParameter.Value;
	EndIf;
	
	DataCompositionParameter = ParameterValues.Find("EndOfPeriod");
	If Not DataCompositionParameter = Undefined 
		AND TypeOf(DataCompositionParameter.Value) = Type("Date")
		AND DataCompositionParameter.Value <> Date(1,1,1) Then
		
		EndDatePeriod = DataCompositionParameter.Value;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("BeginOfPeriod", PeriodOpenDate);
	Query.SetParameter("EndOfPeriod",  EndDatePeriod);
	
	Query.Text = 
	"SELECT ALLOWED
	|	ProductReleaseTurnovers.Company AS Company,
	|	ProductReleaseTurnovers.StructuralUnit AS Department,
	|	ProductReleaseTurnovers.Products AS Products,
	|	ProductReleaseTurnovers.Characteristic AS ProductCharacteristic,
	|	ProductReleaseTurnovers.Batch AS BatchProducts,
	|	ProductReleaseTurnovers.SalesOrder AS SalesOrder,
	|	ProductReleaseTurnovers.Specification AS ProductionSpecification,
	|	ProductReleaseTurnovers.QuantityTurnover AS ProductsQuantity,
	|	NULL AS ProductsCorr
	|INTO TemporaryTableOutput
	|FROM
	|	AccumulationRegister.ProductRelease.Turnovers(&BeginOfPeriod, &EndOfPeriod, , Products.ProductsType <> VALUE(Enum.ProductsTypes.Service)) AS ProductReleaseTurnovers
	|
	|INDEX BY
	|	Products,
	|	ProductCharacteristic,
	|	ProductionSpecification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductRelease.Company AS Company,
	|	ProductRelease.Department AS Department,
	|	ProductRelease.Products AS Products,
	|	ProductRelease.ProductCharacteristic AS ProductCharacteristic,
	|	ProductRelease.BatchProducts AS BatchProducts,
	|	ProductRelease.SalesOrder AS SalesOrder,
	|	ProductRelease.ProductionSpecification AS ProductionSpecification,
	|	ProductRelease.ProductsQuantity AS ProductsQuantity
	|FROM
	|	TemporaryTableOutput AS ProductRelease
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductRelease.Company AS Company,
	|	ProductRelease.Department AS Department,
	|	ProductRelease.Products AS Products,
	|	ProductRelease.ProductCharacteristic AS ProductCharacteristic,
	|	ProductRelease.BatchProducts AS BatchProducts,
	|	ProductRelease.SalesOrder AS SalesOrder,
	|	ProductRelease.ProductionSpecification AS SpecificationProductRelease,
	|	CASE
	|		WHEN ProductRelease.ProductionSpecification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			THEN ProductRelease.Products.Specification
	|		ELSE ProductRelease.ProductionSpecification
	|	END AS ProductionSpecification,
	|	ProductRelease.ProductsQuantity AS QuantityProductRelease,
	|	BillsOfMaterialsContent.Products AS Products1,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	CASE
	|		WHEN BillsOfMaterialsContent.MeasurementUnit REFS Catalog.UOM
	|			THEN BillsOfMaterialsContent.Quantity * CAST(BillsOfMaterialsContent.MeasurementUnit AS Catalog.UOM).Factor
	|		ELSE BillsOfMaterialsContent.Quantity
	|	END / ISNULL(BillsOfMaterialsContent.ProductsQuantity, 1) * ProductRelease.ProductsQuantity AS Quantity,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType
	|INTO TemporaryTableContentRelease
	|FROM
	|	TemporaryTableOutput AS ProductRelease
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (NOT BillsOfMaterialsContent.Ref.DeletionMark)
	|			AND (CASE
	|				WHEN ProductRelease.ProductionSpecification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|					THEN ProductRelease.Products.Specification
	|				ELSE ProductRelease.ProductionSpecification
	|			END = BillsOfMaterialsContent.Ref)
	|			AND ProductRelease.Products = BillsOfMaterialsContent.Ref.Owner
	|			AND ProductRelease.ProductCharacteristic = BillsOfMaterialsContent.Ref.ProductCharacteristic
	|			AND (BillsOfMaterialsContent.ContentRowType <> VALUE(Enum.BOMLineType.Expense))
	|			AND (BillsOfMaterialsContent.Products <> ProductRelease.Products)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompositionOutput.Company AS Company,
	|	CompositionOutput.Department AS Department,
	|	CompositionOutput.Products AS Products,
	|	CompositionOutput.ProductCharacteristic AS ProductCharacteristic,
	|	CompositionOutput.BatchProducts AS BatchProducts,
	|	CompositionOutput.SalesOrder AS SalesOrder,
	|	CompositionOutput.SpecificationProductRelease AS SpecificationProductRelease,
	|	CompositionOutput.ProductionSpecification AS ProductionSpecification,
	|	CompositionOutput.QuantityProductRelease AS QuantityProductRelease,
	|	CompositionOutput.Products AS Products1,
	|	CompositionOutput.Characteristic AS Characteristic,
	|	CompositionOutput.Quantity AS Quantity,
	|	CompositionOutput.Specification AS Specification,
	|	CompositionOutput.ContentRowType AS ContentRowType
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompositionOutput.Products AS ProductsNode,
	|	CompositionOutput.Characteristic AS CharacteristicNode,
	|	CompositionOutput.Specification AS SpecificationNode
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.ContentRowType = VALUE(Enum.BOMLineType.Node)";
	
	Result = Query.ExecuteBatch();
	
	TableOutput = Result[1].Unload();
	TablePlanCostsOnOutput = Result[3].Unload();
	TableNodeSpecificationToExplosion = Result[4].Unload();
	
	While TableNodeSpecificationToExplosion.Count() > 0 Do
		
		ExplosionNodesBillsOfMaterials(TableNodeSpecificationToExplosion, TablePlanCostsOnOutput);
		
	EndDo;
	
EndProcedure

Procedure ExplosionNodesBillsOfMaterials(TableNodeSpecificationToExplosion, TablePlanCostsOnOutput)
	
	Query = New Query;
	Query.SetParameter("TableNodeSpecificationToExplosion", TableNodeSpecificationToExplosion);
	Query.SetParameter("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	
	Query.Text = 
	"SELECT DISTINCT
	|	TableNodeSpecificationToExplosion.ProductsNode AS ProductsNode,
	|	TableNodeSpecificationToExplosion.CharacteristicNode AS CharacteristicNode,
	|	TableNodeSpecificationToExplosion.SpecificationNode AS SpecificationNode
	|INTO Tu_TableNodeSpecificationToExplosion
	|FROM
	|	&TableNodeSpecificationToExplosion AS TableNodeSpecificationToExplosion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	BillsOfMaterialsContent.Ref.Owner AS ProductsNode,
	|	BillsOfMaterialsContent.Ref AS SpecificationNode,
	|	BillsOfMaterialsContent.Ref.ProductCharacteristic AS CharacteristicNode,
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Characteristic,
	|	CASE
	|		WHEN BillsOfMaterialsContent.MeasurementUnit REFS Catalog.UOM
	|			THEN BillsOfMaterialsContent.Quantity * CAST(BillsOfMaterialsContent.MeasurementUnit AS Catalog.UOM).Factor
	|		ELSE BillsOfMaterialsContent.Quantity
	|	END / ISNULL(BillsOfMaterialsContent.ProductsQuantity, 1) AS Quantity,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType
	|INTO TemporaryTableCompositionNodes
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	Not BillsOfMaterialsContent.Ref.DeletionMark
	|	AND (BillsOfMaterialsContent.Ref.Owner, BillsOfMaterialsContent.Ref.ProductCharacteristic, BillsOfMaterialsContent.Ref) In
	|			(SELECT
	|				Tu_TableNodeSpecificationToExplosion.ProductsNode,
	|				Tu_TableNodeSpecificationToExplosion.CharacteristicNode,
	|				Tu_TableNodeSpecificationToExplosion.SpecificationNode
	|			FROM
	|				Tu_TableNodeSpecificationToExplosion)
	|	AND BillsOfMaterialsContent.Products <> BillsOfMaterialsContent.Ref.Owner
	|	AND BillsOfMaterialsContent.ContentRowType <> VALUE(Enum.BOMLineType.Expense)
	|
	|INDEX BY
	|	ProductsNode,
	|	CharacteristicNode,
	|	SpecificationNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company,
	|	PlannedCostsOnOutput.Department,
	|	PlannedCostsOnOutput.Products,
	|	PlannedCostsOnOutput.ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts,
	|	PlannedCostsOnOutput.SalesOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease,
	|	PlannedCostsOnOutput.Products AS Products,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	PlannedCostsOnOutput.Quantity,
	|	PlannedCostsOnOutput.Specification AS Specification,
	|	PlannedCostsOnOutput.ContentRowType
	|INTO TemporaryTablePlannedCosts
	|FROM
	|	&TablePlanCostsOnOutput AS PlannedCostsOnOutput
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company,
	|	PlannedCostsOnOutput.Department,
	|	PlannedCostsOnOutput.Products,
	|	PlannedCostsOnOutput.ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts,
	|	PlannedCostsOnOutput.SalesOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease,
	|	ISNULL(CompositionNodes.Products, PlannedCostsOnOutput.Products) AS Products,
	|	ISNULL(CompositionNodes.Characteristic, PlannedCostsOnOutput.Characteristic) AS Characteristic,
	|	CASE
	|		WHEN PlannedCostsOnOutput.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|			THEN CASE
	|					WHEN ISNULL(PlannedCostsOnOutput.Quantity, 0) = 0
	|						THEN 1
	|					ELSE PlannedCostsOnOutput.Quantity
	|				END * CompositionNodes.Quantity
	|		ELSE PlannedCostsOnOutput.Quantity
	|	END AS Quantity,
	|	ISNULL(CompositionNodes.Specification, PlannedCostsOnOutput.Specification) AS Specification,
	|	ISNULL(CompositionNodes.ContentRowType, PlannedCostsOnOutput.ContentRowType) AS ContentRowType,
	|	CASE
	|		WHEN PlannedCostsOnOutput.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND CompositionNodes.ProductsNode IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Explosion
	|INTO TemporaryTableContentRelease
	|FROM
	|	TemporaryTablePlannedCosts AS PlannedCostsOnOutput
	|		LEFT JOIN TemporaryTableCompositionNodes AS CompositionNodes
	|		ON PlannedCostsOnOutput.Products = CompositionNodes.ProductsNode
	|			AND PlannedCostsOnOutput.Characteristic = CompositionNodes.CharacteristicNode
	|			AND PlannedCostsOnOutput.Specification = CompositionNodes.SpecificationNode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompositionOutput.Company,
	|	CompositionOutput.Department,
	|	CompositionOutput.Products,
	|	CompositionOutput.ProductCharacteristic,
	|	CompositionOutput.BatchProducts,
	|	CompositionOutput.SalesOrder,
	|	CompositionOutput.SpecificationProductRelease,
	|	CompositionOutput.ProductionSpecification,
	|	CompositionOutput.QuantityProductRelease,
	|	CompositionOutput.Products,
	|	CompositionOutput.Characteristic,
	|	CompositionOutput.Quantity,
	|	CompositionOutput.Specification,
	|	CompositionOutput.ContentRowType
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.Explosion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompositionOutput.Products AS ProductsNode,
	|	CompositionOutput.Characteristic AS CharacteristicNode,
	|	CompositionOutput.Specification AS SpecificationNode
	|FROM
	|	TemporaryTableContentRelease AS CompositionOutput
	|WHERE
	|	CompositionOutput.ContentRowType = VALUE(Enum.BOMLineType.Node)";
	
	Result = Query.ExecuteBatch();
	
	TablePlanCostsOnOutput = Result[4].Unload();
	TableNodeSpecificationToExplosion = Result[5].Unload();
	
EndProcedure

Procedure CalculateCostPricePlannedCostsOnOutput(TablePlanCostsOnOutput)
	
	BeginOfPeriod = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	EndOfPeriod  = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	
	Query = New Query;
	Query.SetParameter("TablePlanCostsOnOutput", TablePlanCostsOnOutput);
	Query.SetParameter("BeginOfPeriod", ?(BeginOfPeriod = Undefined OR Not BeginOfPeriod.Use, Date(1,1,1), BeginOfPeriod.Value));
	Query.SetParameter("EndOfPeriod",  ?(EndOfPeriod = Undefined OR Not EndOfPeriod.Use, Date(3999,12,31), EndOfPeriod.Value));
	
	Query.Text = 
	"SELECT
	|	PlannedCostsOnOutput.Company AS Company,
	|	PlannedCostsOnOutput.Department AS Department,
	|	PlannedCostsOnOutput.Products AS Products,
	|	PlannedCostsOnOutput.ProductCharacteristic AS ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts AS BatchProducts,
	|	PlannedCostsOnOutput.SalesOrder AS SalesOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease AS SpecificationProductRelease,
	|	PlannedCostsOnOutput.ProductionSpecification AS ProductionSpecification,
	|	PlannedCostsOnOutput.QuantityProductRelease AS QuantityProductRelease,
	|	PlannedCostsOnOutput.Products AS ProductsCorr,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	PlannedCostsOnOutput.Quantity AS Quantity,
	|	PlannedCostsOnOutput.ContentRowType AS ContentRowType
	|INTO TemporaryTablePlannedCostsForProduction
	|FROM
	|	&TablePlanCostsOnOutput AS PlannedCostsOnOutput
	|WHERE
	|	PlannedCostsOnOutput.ContentRowType <> VALUE(Enum.BOMLineType.Node)
	|	AND PlannedCostsOnOutput.ContentRowType <> VALUE(Enum.BOMLineType.Expense)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnitCorr AS Department,
	|	Inventory.ProductsCorr AS Products,
	|	Inventory.CharacteristicCorr AS ProductCharacteristic,
	|	Inventory.BatchCorr AS BatchProducts,
	|	Inventory.CustomerCorrOrder AS SalesOrder,
	|	Inventory.SpecificationCorr AS ProductionSpecification,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Specification AS Specification,
	|	SUM(Inventory.Amount) AS Amount,
	|	SUM(Inventory.Quantity) AS Quantity
	|INTO TemporaryTableCostForProduction
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Inventory.ProductionExpenses
	|	AND Inventory.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND NOT Inventory.Products = VALUE(Catalog.Products.EmptyRef)
	|
	|GROUP BY
	|	Inventory.SpecificationCorr,
	|	Inventory.Characteristic,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.ProductsCorr,
	|	Inventory.BatchCorr,
	|	Inventory.Products,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.CharacteristicCorr,
	|	Inventory.Company,
	|	Inventory.Specification,
	|	Inventory.ProductsCorr
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PlannedCostsOnOutput.Company AS Company,
	|	PlannedCostsOnOutput.Department AS Department,
	|	PlannedCostsOnOutput.Products AS Products,
	|	PlannedCostsOnOutput.ProductCharacteristic AS ProductCharacteristic,
	|	PlannedCostsOnOutput.BatchProducts AS BatchProducts,
	|	PlannedCostsOnOutput.SalesOrder AS SalesOrder,
	|	PlannedCostsOnOutput.SpecificationProductRelease AS ProductionSpecification,
	|	PlannedCostsOnOutput.ProductsCorr AS ProductsCorr,
	|	PlannedCostsOnOutput.Characteristic AS Characteristic,
	|	ActualCostsOnOutput.Specification AS Specification,
	|	PlannedCostsOnOutput.Quantity AS CostsQuantityPlan,
	|	CASE
	|		WHEN ISNULL(ActualCostsOnOutput.Amount, 0) = 0
	|				OR ISNULL(ActualCostsOnOutput.Quantity, 0) = 0
	|			THEN 0
	|		ELSE PlannedCostsOnOutput.Quantity * (ActualCostsOnOutput.Amount / ActualCostsOnOutput.Quantity)
	|	END AS ExpensesCostPlan
	|FROM
	|	TemporaryTablePlannedCostsForProduction AS PlannedCostsOnOutput
	|		LEFT JOIN TemporaryTableCostForProduction AS ActualCostsOnOutput
	|		ON PlannedCostsOnOutput.Company = ActualCostsOnOutput.Company
	|			AND PlannedCostsOnOutput.Department = ActualCostsOnOutput.Department
	|			AND PlannedCostsOnOutput.Products = ActualCostsOnOutput.Products
	|			AND PlannedCostsOnOutput.ProductCharacteristic = ActualCostsOnOutput.ProductCharacteristic
	|			AND PlannedCostsOnOutput.BatchProducts = ActualCostsOnOutput.BatchProducts
	|			AND PlannedCostsOnOutput.SalesOrder = ActualCostsOnOutput.SalesOrder
	|			AND PlannedCostsOnOutput.SpecificationProductRelease = ActualCostsOnOutput.ProductionSpecification
	|			AND PlannedCostsOnOutput.Products = ActualCostsOnOutput.Products
	|			AND PlannedCostsOnOutput.Characteristic = ActualCostsOnOutput.Characteristic";
	
	TablePlanCostsOnOutput = Query.Execute().Unload();
	
EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	TitleOutput = False;
	Title = "Output net cost plan/actual analysis";
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("ItmPeriod"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
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
	ReportParameters.Insert("BeginOfPeriod"            , BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod"             , EndOfPeriod);
	ReportParameters.Insert("TitleOutput"        , TitleOutput);
	ReportParameters.Insert("Title"                , Title);
	ReportParameters.Insert("ReportId"      , "DirectMaterialVariance");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

#EndIf