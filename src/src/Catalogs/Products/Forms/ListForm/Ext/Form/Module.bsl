
#Region FormEventHandlers

&AtClient
Procedure ChangeSelected(Command)
	GroupObjectsChangeClient.ChangeSelected(Items.List);
EndProcedure

&AtClient
Procedure FilterBalancesOnChange(Item)
	SetFilterParametersServer();
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)
	SetFilterParametersServer();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetFilterParametersServer();;
	
	// StandardSubsystems.GroupObjectsChange
	If Items.Find("ListBatchObjectChanging") <> Undefined Then
		
		YouCanEdit = AccessRight("Edit", Metadata.Catalogs.Products);
		CommonUseClientServer.SetFormItemProperty(Items, "ListBatchObjectChanging", "Visible", YouCanEdit);
		
	EndIf;
	// End StandardSubsystems.GroupObjectChange
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.FormDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
Procedure ShowBalancesOnChange(Item)
	SetFilterParametersServer();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetFilterParametersServer()
	
	UseQuantityInList = FilterBalances <> 0 OR ShowBalances;
	
	SetQueryTextList();
	SetListFilterItemBalances(List, FilterBalances);
	SetListQueryParameters();
	SetVisibleEnabled();
	
EndProcedure

&AtServer
Procedure SetListFilterItemBalances(ListForFilter, FilterBalances)
	
	UseFilter = FilterBalances <> 0;
	
	If FilterBalances = 2 Then
		FilterComparisonType = DataCompositionComparisonType.LessOrEqual; 
	Else
		FilterComparisonType = DataCompositionComparisonType.Greater;
	EndIf;
	
	DriveClientServer.SetListFilterItem(ListForFilter, "QuantityBalance", 0, UseFilter, FilterComparisonType);
		
EndProcedure

&AtServer
Procedure SetListQueryParameters()
	
	CommonUseClientServer.SetDynamicListParameter(List, "Period", CurrentSessionDate());
	
	If FilterBalances = 2 Then
		CommonUseClientServer.SetDynamicListParameter(List, "AllTypes",	False);
	Else
		CommonUseClientServer.SetDynamicListParameter(List, "AllTypes",	True);
	EndIf;

	If ValueIsFilled(FilterWarehouse) Then
		CommonUseClientServer.SetDynamicListParameter(List, "AllWarehouses",	False);
		CommonUseClientServer.SetDynamicListParameter(List, "Warehouse",		FilterWarehouse);
	Else
		CommonUseClientServer.SetDynamicListParameter(List, "AllWarehouses",	True);
		CommonUseClientServer.SetDynamicListParameter(List, "Warehouse",		PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	EndIf; 
	
EndProcedure

&AtServer
Procedure SetVisibleEnabled()
	
	Items.FilterWarehouse.Visible	= (FilterBalances = 1);
	Items.Balance.Visible			= ShowBalances;
	
EndProcedure

&AtServer
Function SetQueryTextList()
	
	List.QueryText = 
	"SELECT
	|	CatalogProducts.Ref AS Ref,
	|	CatalogProducts.Ref AS Products,
	|	CatalogProducts.DeletionMark,
	|	CatalogProducts.Parent,
	|	CatalogProducts.IsFolder,
	|	CatalogProducts.Code,
	|	CatalogProducts.Description,
	|	CatalogProducts.SKU,
	|	CatalogProducts.ChangeDate,
	|	CAST(CatalogProducts.DescriptionFull AS STRING(1000)) AS DescriptionFull,
	|	CatalogProducts.BusinessLine,
	|	CatalogProducts.ProductsCategory,
	|	CatalogProducts.Vendor,
	|	CatalogProducts.Warehouse,
	|	CatalogProducts.ReplenishmentMethod,
	|	CatalogProducts.ReplenishmentDeadline,
	|	CatalogProducts.VATRate,
	|	CatalogProducts.ProductsType,
	|	CatalogProducts.Cell,
	|	CatalogProducts.PriceGroup,
	|	CatalogProducts.UseCharacteristics,
	|	CatalogProducts.UseBatches AS UseReservation,
	|	CatalogProducts.UseBatches AS UseBatches,
	|	CatalogProducts.OrderCompletionDeadline,
	|	CatalogProducts.TimeNorm,
	|	CatalogProducts.CountryOfOrigin,
	|	CatalogProducts.UseSerialNumbers,
	|	CatalogProducts.GuaranteePeriod,
	|	CatalogProducts.WriteOutTheGuaranteeCard,
	|	Substring(CatalogProducts.Comment, 1, 1000) AS Comment,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	0 AS Price,
	|	&Period";
	
	If UseQuantityInList Then
		List.QueryText = List.QueryText + "
		|	, ISNULL(InventoryInWarehouses.QuantityBalance, 0) AS QuantityBalance";
	Else
		List.QueryText = List.QueryText + "
		|	, 0 AS QuantityBalance";		
	EndIf;
	
	List.QueryText = List.QueryText + "
	|FROM
	|	Catalog.Products AS CatalogProducts";
	
	If UseQuantityInList Then
		List.QueryText = List.QueryText + "
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|		,
		|		&AllWarehouses
		|				OR StructuralUnit = &Warehouse) AS InventoryInWarehouses
		|		ON (InventoryInWarehouses.Products = CatalogProducts.Ref)";
	EndIf;
	
	List.QueryText = List.QueryText + "
	|	WHERE &AllTypes 
	|		OR CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)";
	
EndFunction

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "Products", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		Items.List.Refresh();
		ShowMessageBox(,NStr("en = 'Data import is complete.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.PerformanceMeasurement
&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Group Then
		KeyOperation = "FormCreatingProducts";
		PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	EndIf;

EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Not Item.CurrentData.IsFolder Then
		KeyOperation = "FormOpeningProducts";
		PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	EndIf;
	
EndProcedure

// End StandardSubsystems.PerformanceMeasurement

#EndRegion
