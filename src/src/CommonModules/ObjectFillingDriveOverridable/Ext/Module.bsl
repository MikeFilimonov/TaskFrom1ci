
#Region Interface

Procedure OnDefiningRulesBusinessUnitsSettings(Rules) Export
	
	Rules[Type("DocumentObject.ObsoleteWorkOrder")]	= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.PurchaseOrder")]		= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.Payroll")]			= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.SalesTarget")]		= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.PayrollSheet")]		= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.OtherExpenses")]		= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.CostAllocation")]	= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.JobSheet")]			= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.Timesheet")]			= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.WeeklyTimesheet")]		= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.Production")]	= Catalogs.BusinessUnits.MainDepartment;
	Rules[Type("DocumentObject.ProductionOrder")]	= Catalogs.BusinessUnits.MainDepartment;
	
	Rules[Type("DocumentObject.AdditionalExpenses")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.CreditNote")]				= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.DebitNote")]					= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.Stocktaking")]	= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryIncrease")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.SubcontractorReportIssued")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.SubcontractorReport")]		= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.IntraWarehouseTransfer")]		= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.FixedAssetRecognition")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.SupplierInvoice")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.GoodsReturn")]				= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.SalesInvoice")]				= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryWriteOff")]			= Catalogs.BusinessUnits.MainWarehouse;
	Rules[Type("DocumentObject.InventoryTransfer")]			= Catalogs.BusinessUnits.MainWarehouse;
	
EndProcedure

#EndRegion
