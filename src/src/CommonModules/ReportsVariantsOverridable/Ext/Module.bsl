////////////////////////////////////////////////////////////////////////////////
// Subsystem "Report options" (server, overridable).
// 
// It is executed on the server, is
// changed for the applied configuration specific but is intended to use only this subsystem.
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region ProgrammingInterface

// Identifies the sections in which reports panel is available.
//
// Parameters:
//   Sections - ValueList - Sections containing reports panel open commands.
//       * Value - MetadataObject: Subsystem - Subsystem metadata.
//       * Presentation - String - Title of the reports panel of this section.
//
// Definition:
//   It is necessary to add to the Sections
//   the metadata of those first-level subsystems that contain the reports panels call commands.
//
// ForExample:
// Sections.Add(Metadata.Subsystems.SubsystemName);
//
Procedure DetermineSectionsWithReportVariants(Sections) Export
	
	Sections.Add(Metadata.Subsystems.CRM, NStr("en = 'CRM'"));
	Sections.Add(Metadata.Subsystems.Sales, NStr("en = 'Sales'"));
	Sections.Add(Metadata.Subsystems.Purchases, NStr("en = 'Inventory and purchases'"));
	Sections.Add(Metadata.Subsystems.Services, NStr("en = 'Services'"));
	Sections.Add(Metadata.Subsystems.Production, NStr("en = 'Production'"));
	Sections.Add(Metadata.Subsystems.Finances, NStr("en = 'Funds'"));
	Sections.Add(Metadata.Subsystems.Payroll, NStr("en = 'Payroll and HR'"));
	Sections.Add(Metadata.Subsystems.Enterprise, NStr("en = 'Company'"));
	Sections.Add(Metadata.Subsystems.Analysis, NStr("en = 'Analysis'"));
	
EndProcedure

Procedure MakeMain(Settings,ReportName, OptionsAsString)

	OptionsArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(OptionsAsString);
	
	For Each VariantName In OptionsArray Do
	
		Try
			Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports[ReportName], VariantName);
		Except
			Continue;
		EndTry;
		
		For Each PlacementInSubsystem In Variant.Placement Do
		
			Variant.Placement.Insert(PlacementInSubsystem.Key,"Important");
		
		EndDo; 
	
	EndDo;

EndProcedure

// Moves the specified options of specified report into SeeAlso
//
// Parameters
//   Settings (ValueTree) Used to describe settings of reports
//   and variants see description to ReportsVariants.ReportVariantsConfigurationSettingsTree()
//
//  ReportName  - String - Report name that shall be transferred to SeeAlso
//
//  Variants  - String - Report options, separated
//                 by comma, that shall be transferred into SeeAlso
//
Procedure MakeSecondary(Settings,ReportName, OptionsAsString)

	OptionsArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(OptionsAsString);
	
	For Each VariantName In OptionsArray Do
	
		Try
			Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports[ReportName], VariantName);
		Except
			Continue;
		EndTry;
		
		For Each PlacementInSubsystem In Variant.Placement Do
		
			Variant.Placement.Insert(PlacementInSubsystem.Key,"SeeAlso");
		
		EndDo; 
	
	EndDo;

EndProcedure

Procedure HighlightKeyReports(Settings)

	MakeMain(Settings,"AvailableStock","Default");
	MakeMain(Settings,"StatementOfAccount","Statement in currency (briefly)");
	MakeMain(Settings,"SalesOrdersTrend","Default");
	MakeMain(Settings,"PurchaseOrdersOverview","Default");
	MakeMain(Settings,"SupplyPlanning","Default");
	MakeMain(Settings,"StockSummary","Statement");
	MakeMain(Settings,"ProductRelease","Default");
	MakeMain(Settings,"CashBalance","Balance");
	MakeMain(Settings,"CashBalance","Statement");
	MakeMain(Settings,"PaymentCalendar","Default");
	MakeMain(Settings,"EarningsAndDeductions","InCurrency");
	MakeMain(Settings,"PayStatements","StatementInCurrency");
	MakeMain(Settings,"NetSales","GrossProfit");
	MakeMain(Settings,"NetSales","SalesDynamics");
	MakeMain(Settings,"IncomeAndExpenses","Statement");
	MakeMain(Settings,"IncomeAndExpensesByCashMethod","Default");
	MakeMain(Settings,"TrialBalance","TBS");
	MakeMain(Settings,"SalesWithCardBasedDiscounts","SalesWithCardBasedDiscounts");
	MakeMain(Settings,"AutomaticDiscountSales","AutomaticDiscounts");

EndProcedure

// Removes part of reports into "SeeAlso" section
//
// Parameters:
//   Settings (ValueTree) Used to describe settings of reports
//       and variants see description to ReportsVariants.ReportVariantsConfigurationSettingsTree()
//
Procedure HighlightSecondaryReports(Settings)

	MakeSecondary(Settings,"StatementOfAccount","Statement,Balance,Statement in currency,Balance in currency");
	MakeSecondary(Settings,"AccountsReceivableAging","Default");
	MakeSecondary(Settings,"CashRegisterStatement","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"POSSummary","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"StockStatement","Statement,Balance");
	MakeSecondary(Settings,"Backorders","Statement");
	MakeSecondary(Settings,"CashBalance","Statement,Balance,Movements analysis");
	MakeSecondary(Settings,"CashFlowVarianceAnalysis","Default,Planfact analysis");
	MakeSecondary(Settings,"EarningsAndDeductions","Default");
	MakeSecondary(Settings,"PayStatements","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"CashBudget","Planfact analysis");
	MakeSecondary(Settings,"ProfitAndLossBudget","Planfact analysis");
	MakeSecondary(Settings,"CostOfGoodsManufactured","Full");
	MakeSecondary(Settings,"Purchases","Default");
	MakeSecondary(Settings,"StockSummary","Balance");
	MakeSecondary(Settings,"SurplusesAndShortages","Default");
	MakeSecondary(Settings,"StockReceivedFromThirdParties","Statement,Balance");
	MakeSecondary(Settings,"StockTransferredToThirdParties","Statement,Balance");
	MakeSecondary(Settings,"ProductionOrderStatement","Balance");
	MakeSecondary(Settings,"AdvanceHolders","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"AccountsReceivable","Statement,StatementInCurrency,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"SalesOrdersStatement","Statement,Balance");
	MakeSecondary(Settings,"PurchaseOrdersStatement","Statement,Balance");
	MakeSecondary(Settings,"Backorders","Statement,Balance");
	MakeSecondary(Settings,"AccountsPayable","Statement,Balance,StatementInCurrency,BalanceInCurrency");
	MakeSecondary(Settings,"AccountsPayableAging","Default");
	MakeSecondary(Settings,"StatementOfTaxAccount","Balance");
	MakeSecondary(Settings,"StatementOfCost","Balance");
	MakeSecondary(Settings,"StockStatementWithCostLayers","Statement,Balance");
	
EndProcedure

// Contains the settings of report options placement in reports panel.
//   
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//   
// Definition:
//   IN this procedure it is required to specify how the
//   reports predefined variants will be registered in application and shown in the reports panel.
//   
// Auxiliary methods:
//   ReportSettings   = ReportsVariants.ReportDescription(Settings, Metadata.Reports.<ReportName>);
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   ReportsVariants.SetOutputModeInReportPanels(Settings,
//   Metadata.Reports.<ReportName>/Metadata.Subsystems.<SubsystemName>, True/False);
//   ReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.<ReportName>);
//   
//   These functions receive respectively report settings and report option settings of the next structure:
//       * Enabled - Boolean -
//           If False then the report option is not registered in the subsystem.
//           Used to delete technical and contextual report options from all interfaces.
//           These report options can still be opened applicationmatically as report
//           using opening parameters (see help on "Managed form extension for the VariantKeys" report).
//       * VisibleByDefault - Boolean -
//           If False then the report option is hidden by default in the reports panel.
//           User can "enable" it in the reports
//           panel setting mode or open via the "All reports" form.
//       *Description - String - Additional information on the report option.
//           It is displayed as a tooltip in the reports panel.
//           Must decrypt for user the report
//           option content and should not duplicate the report option name.
//           Used for searching.
//       * Placement - Map - Settings for report option location in sections.
//           ** Key     - MetadataObject: Subsystem - Subsystem that hosts the report or the report option.
//           ** Value - String - Optional. Settings for location in the subsystem.
//               ""        - Output report in its group in regular font.
//               WithImportant"  - Output report in its group in bold.
//               WithSeeAlso" - Output report in the group "See also".
//       * FunctionalOptions - Array from String -
//            Names of the functional report option options.
//       * SettingsForSearch - Structure - Additional settings for this report option search.
//           These settings are to be set only in case DCS is not used or is not fully used.
//           For example, DCS can be used only for
//           parameterization and data receiving, and data can be output into fixed tabular document template.
//           ** FieldsDescription - String - Report option fields names. Names separator: Chars.LF.
//           ** ParametersAndReportsDescriptions - String - Names of report option settings. Names separator: Chars.LF.
//       * DefineFormSettings - Boolean - Report has application interface for close integration with
//           the report form. It can also predefine some form settings and subscribe to its events.
//           If True, and the report is connected to
//           common form ReportForm, then a procedure should be defined from a template in the report object module:
//               
//               // Settings of common form for subsystem report "Reports options".
//                 
//                Parameters:
//               //   Form - ManagedForm, Undefined - Report form or report settings form.
//                  //    Undefined when call is without context.
//                  VariantKey - String, Undefined - Name
//                      of the pre//defined one or unique identifier of user report option.
//                      Undefined when call is without context.
//                  Settings - Structure - see return
//                      value Re//portsClientServer.GetReportSettingsByDefault().
//                 
//               Procedure DefineFormSettings(Form, VariantKey, Settings)
//               	 Export Procedure code.
//               EndProcedure
//               
//   
// ForExample:
//   
//  (1) Add a report option to the subsystem.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (2) Disable report option.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Enabled = False;
//   
//  (3) Disable all report options except for the required one.
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Enabled = False;
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName");
// Variant.Enabled = True;
//   
//  (4) Fill the names of fields parameters and filters:
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportNameWithoutScheme, "");
// Variant.SearchSettings.FieldNames =
// 	NStr("en = 'Counterparty
// 	|Contract
// 	|Responsible
// 	|Discount
// 	|Date'");
// Variant.SearchSettings.ParametersAndFiltersNames =
// 	NStr("en = 'Period
// 	|Responsible
// 	|Contract
// 	|Counterparty'");
//   
//  (5) Change the output mode in the reports panel:
//  (5.1) By reports:
// ReportsVariants.SetOutputModeInReportPanels(Settings, Metadata.Reports.ReportName, "ByReports");
//  (5.2) By variants:
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// ReportsVariants.SetOutputModeInReportPanels(Settings, Report, "ByVariants");
//   
// IMPORTANT:
//   Report serves as variants container.
//     By modifying the report settings you can change the settings of all its variants at the same time.
//     However if you receive report option settings directly, they
//     will become the self-service ones, i.e. will not inherit settings changes from the report.See example 3.
//   
//   Initial setting of reports locating by the subsystems
//     is read from metadata and it is not required to duplicate it in the code.
//   
//   Variant functional options are united with the functional options of this report according to the rules as follows:
//     (FO1_Report OR FO2_Report) AND (FO3_Variant OR FO4_Variant).
//   Reports functional options are
//     not read from the metadata, they are applied when the user uses the subsystem.
//   Through the ReportDescription you can add functional options that will be combined
//     according to the rules specified above, but you should keep in mind that these functional options will be valid
//     for predefined report options only.
//   For user report options only functional report options are valid.
//     - they are disabled only along with total report disabling.
//
Procedure ConfigureReportsVariants(Settings) Export
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrdersAnalysis, "Default");
	Variant.Definition = NStr("en = 'Availability and supply status of goods ordered by customers'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrderAnalysis, "Default");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PurchaseOrderAnalysis, "Default");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "StatementBrieflyContext");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AvailableStock, "AvailableBalanceContext");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesContext");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrderPayments, "Default");
	Variant.Definition = NStr("en = 'Payment info by sales orders'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PurchaseOrderPayments, "Default");
	Variant.Definition = NStr("en = 'Payment info by purchase orders'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SupplyPlanning, "Default");
	Variant.Definition = NStr("en = 'Raw materials demand and supply status'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.BalanceSheet, "Default");
	Variant.Definition = NStr("en = 'Balance sheet'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBudget, "Default");
	Variant.Definition = NStr("en = 'The report generates cash flow budget by the specified scenario'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBudget, "Planfact analysis");
	Variant.Definition = NStr("en = 'The report generates cash flow budget by the specified scenario'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProfitAndLossBudget, "Default");
	Variant.Definition = NStr("en = 'The report generates profit and loss budget by the specified scenario'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProfitAndLossBudget, "Planfact analysis");
	Variant.Definition = NStr("en = 'The report generates variance analysis of profit and loss budgets by the specified scenario'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockValueAtSellingPrices, "Default");
	Variant.Definition = NStr("en = 'Stock valuation by a selling price'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "Statement");
	Variant.Definition			= NStr("en = 'Extended opening balance, sales/purchases, payments, extended closing balance of receivables and payables'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "Balance");
	Variant.Definition			= NStr("en = 'Payables and receivables balance'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "Statement in currency");
	Variant.Definition = NStr("en = 'Extended opening balance, sales/purchases, payments, extended closing balance of receivables and payables'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "Balance in currency");
	Variant.Definition			= NStr("en = 'Payables and receivables balance'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfAccount, "Statement in currency (briefly)");
	Variant.Definition = NStr("en = 'Opening balance, sales/purchases, payments, closing balance of receivables and payables'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.VATReturn, "Default");
	Variant.Definition = NStr("en = 'Provides information to estimate VAT payment'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.FixedAssetDepreciation, "Statement");
	Variant.Definition = NStr("en = 'The report provides common data on fixed asset depreciation'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.FixedAssetDepreciation, "Card");
	Variant.Definition = NStr("en = 'Inventory card'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProductRelease, "Default");
	Variant.Definition = NStr("en = 'The report on works performed, services rendered and products released'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.FixedAssetUsage, "Default");
	Variant.Definition = NStr("en = 'The report shows information on fixed asset usage for the specified period of time'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.InventoryFlowCalendar, "Default");
	Variant.Definition = NStr("en = 'On order and expected products by days'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AvailableStock, "Default");
	Variant.Definition = NStr("en = 'Stock on hand, on orders, and available stock by warehouses'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashFlow, "Default");
	Variant.Definition = NStr("en = 'Cash flow statement of a company for the specified period'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "Statement");
	Variant.Definition = NStr("en = 'Opening balance, inflow, outflow, and closing balance by cash accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "Balance");
	Variant.Definition			= NStr("en = 'Cash balance by cash accounts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "Movements analysis");
	Variant.Definition = NStr("en = 'Inflow, outflow, and net cash flow'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, inflow, outflow, and closing balance by cash accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'Cash balance by cash accounts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "Analysis of movements in currency");
	Variant.Definition = NStr("en = 'Inflow, outflow, and net cash flow'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "CashReceiptsDynamics");
	Variant.Definition			= NStr("en = 'Cash inflow trend by cash flow items and days, displayed as a chart'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalance, "CashExpenseDynamics");
	Variant.Definition			= NStr("en = 'Cash outflow trend by cash flow items and days, displayed as a chart'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashRegisterStatement, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, sales, withdrawal, and closing balance in cash registers'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashRegisterStatement, "Balance");
	Variant.Definition			= NStr("en = 'Cash amount in cash registers'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashRegisterStatement, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, sales, withdrawal, and closing balance in cash registers'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Default");
	Variant.Definition = NStr("en = 'Cash flow budget by cash flow items'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "InCurrency");
	Variant.Definition = NStr("en = 'Cash flow budget by cash flow items'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Planfact analysis");
	Variant.Definition = NStr("en = 'Cash flow variance by cash flow items'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Planfact analysis (cur.)");
	Variant.Definition = NStr("en = 'Cash flow variance by cash flow items'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.BankCharges, "BankCharges");
	Variant.Definition = NStr("en = 'Bank charges'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CashBalanceForecast, "Default");
	Variant.Definition = NStr("en = 'Expected cash balance in a selected currency based on payment terms and cash planning documents'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpenses, "Statement");
	Variant.Definition = NStr("en = 'Income and expenses by GL accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpenses, "IncomeAndExpensesByOrders");
	Variant.Definition			= NStr("en = 'Income and expenses by sales orders'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpenses, "IncomeAndExpensesDynamics");
	Variant.Definition			= NStr("en = 'Income and expenses by months displayed as a chart'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpensesByCashMethod, "Default");
	Variant.Definition = NStr("en = 'Income and expenses by GL accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpensesByCashMethod, "IncomeAndExpensesDynamics");
	Variant.Definition			= NStr("en = 'Income and expenses by months displayed as a chart'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpensesBudget, "Statement");
	Variant.Definition = NStr("en = 'The report provides forecast data on income and expenses (by shipment)'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.IncomeAndExpensesBudget, "Planfact analysis");
	Variant.Definition = NStr("en = 'The report provides variance analysis of income and expenses (by shipment)'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.WorkloadVariance, "Default");
	Variant.Definition			= NStr("en = 'The report shows scheduled and completed work orders.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.WorkloadVariance, "ReportToCustomer");
	Variant.Definition = NStr("en = 'The report provides information about performed work orders to the customer'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProductionOrderStatement, "Statement");
	Variant.Definition = NStr("en = 'Opening balance, ordered, produced, and closing balance'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProductionOrderStatement, "Balance");
	Variant.Definition			= NStr("en = 'The report is used to analyze the state of orders for the specified date.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrdersStatement, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, ordered, shipped, and remaining'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrdersStatement, "Balance");
	Variant.Definition			= NStr("en = 'Goods to dispatch'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PurchaseOrdersStatement, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, ordered, received, and expected'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PurchaseOrdersStatement, "Balance");
	Variant.Definition			= NStr("en = 'Expected goods'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.Purchases, "Default");
	Variant.Definition = NStr("en = 'Purchases quantity and amount'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockStatement, "Statement");
	Variant.Definition = NStr("en = 'Opening balance, receipt, consumption, closing balance by products and documents'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockStatement, "Balance");
	Variant.Definition			= NStr("en = 'Quantity, amount, and unit cost by products'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SurplusesAndShortages, "Default");
	Variant.Definition = NStr("en = 'The report provides information on surpluses and shortages according to the physical inventory results'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockTransferredToThirdParties, "Statement");
	Variant.Definition = NStr("en = 'The report provides information about changes of inventory balance received for commission, processing, and safekeeping for the specified period'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockTransferredToThirdParties, "Balance");
	Variant.Definition			= NStr("en = 'The report provides information about inventory balance received for commission, processing, and safekeeping.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockReceivedFromThirdParties, "Statement");
	Variant.Definition = NStr("en = 'The report provides information about changes of inventory balance received for commission, processing, and safekeeping for the specified period'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockReceivedFromThirdParties, "Balance");
	Variant.Definition			= NStr("en = 'The report provides information about inventory balance received for commission, processing, and safekeeping.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EventCalendar, "Default");
	Variant.Definition = NStr("en = 'Planned events'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CounterpartyContactInformation, "Counterparty contact information");
	Variant.Enabled = False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EarningsAndDeductions, "Default");
	Variant.Definition			= NStr("en = 'Earnings and deductions by employees and departments'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EarningsAndDeductions, "InCurrency");
	Variant.Definition = NStr("en = 'Earnings and deductions by employees and departments'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfCost, "Statement");
	Variant.Definition = NStr("en = 'The report shows data on changes of direct and indirect costs of the company. The data is shown by departments drilled down by sales orders'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfCost, "Balance");
	Variant.Definition			= NStr("en = 'The report shows data on the state of direct and indirect costs of the company. The data is shown by departments drilled down by sales orders'");
	Variant.VisibleByDefault	= False;
	
	Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.RawMaterialsCalculation); //Variant does not exist, the description shall be set for report.
	ReportsVariants.SetOutputModeInReportPanels(Settings, Report, True);	
	Report.Definition = NStr("en = 'The report provides information on standards and technologies of works and products'");
	Report.SearchSettings.FieldNames =
		NStr("en = 'Products and services
		     |Technological operation
		     |Accounting price'");
	Report.SearchSettings.ParametersAndFiltersNames =
		NStr("en = 'Date of calculation
		     |Prices kind
		     |Products
		     |Characteristic
		     |Specification'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.InventoryTurnover, "Default");
	Variant.Definition = NStr("en = 'The report is used to analyze the turnover and average storage time of inventory'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.TrialBalance, "TBS");
	Variant.Definition = NStr("en = 'Opening balance, debits, credits, closing balance by GL accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.HoursWorked, "ByDays");
	Variant.Definition = NStr("en = 'Timesheet by days and pay codes'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.HoursWorked, "TotalForPeriod");
	Variant.Definition = NStr("en = 'Timesheet by pay codes'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesVariance, "Default");
	Variant.Definition = NStr("en = 'Sales target vs actual'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProductionVarianceAnalysis, "Default");
	Variant.Definition = NStr("en = 'The report is designed to perform variance analysis of performed works, services rendered, manufacture of products'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesTarget, "Default");
	Variant.Definition = NStr("en = 'The report shows information about planned sales of product grouped by departments'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PaymentCalendar, "Default");
	Variant.Definition = NStr("en = 'Payment calendar'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.ProfitAndLossStatement, "Default");
	Variant.Definition = NStr("en = 'Profit and loss statement'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.BudgetedBalanceSheet, "Default");
	Variant.Definition = NStr("en = 'Budgeted balance sheet'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.BudgetedBalanceSheet, "Planfact analysis");
	Variant.Definition = NStr("en = 'Budgeted balance sheet vs actual'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "Default");
	Variant.Definition			= NStr("en = 'Quantity and net sales by customers and products'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "GrossProfit");
	Variant.Definition = NStr("en = 'Net sales, COGS ,gross profit, and margin by products'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "GrossProfitByProductsCategories");
	Variant.Definition			= NStr("en = 'Net sales, COGS ,gross profit, and margin by products categories'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "GrossProfitByCustomers");
	Variant.Definition			= NStr("en = 'Net sales, COGS ,gross profit, and margin by customers'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "GrossProfitByManagers");
	Variant.Definition			= NStr("en = 'Net sales, COGS ,gross profit, and margin by sales managers'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "GrossProfitBySalesRep");
	Variant.Definition			= NStr("en = 'Net sales, COGS ,gross profit, and margin by sales reps'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesDynamics");
	Variant.Definition = NStr("en = 'Net sales,	COGS, gross profit, and margin by months, displayed as a chart.'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesDynamicsByProducts");
	Variant.Definition			= NStr("en = 'Sales trend by products and days, displayed as a chart.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesDynamicsByProductsCategories");
	Variant.Definition			= NStr("en = 'Sales trend by product categories and days, displayed as a chart.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesDynamicsByCustomers");
	Variant.Definition			= NStr("en = 'Sales trend by customers and days, displayed as a chart.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.NetSales, "SalesDynamicsByManagers");
	Variant.Definition			= NStr("en = 'Sales trend by sales managers and days, displayed as a chart.'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.Backorders, "Statement");
	Variant.Definition = NStr("en = 'Goods that are ordered by customers and currently not in stock but had been ordered in a purchase or production order'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.Backorders, "Balance");
	Variant.Definition			= NStr("en = 'Remaining backorder items'");
	Variant.VisibleByDefault	= False;
	
	Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.PayStatementFixedTemplate);
	ReportsVariants.SetOutputModeInReportPanels(Settings, Report, True);	
	Report.Definition = NStr("en = 'Payroll of an arbitrary form. Intended for internal reporting of the company'");
	Report.SearchSettings.FieldNames = 
		NStr("en = 'Employee ID
		     |Employee
		     |Position
		     |Rate
		     |Department
		     |Company'");
	Report.SearchSettings.ParametersAndFiltersNames = 
		NStr("en = 'Registration period
		     |Department
		     |Currency
		     |Company'");
	
	Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.PaySlips);
	ReportsVariants.SetOutputModeInReportPanels(Settings, Report, True);	
	Report.Definition = NStr("en = 'Payslips for a period'");
	Report.SearchSettings.FieldNames = 
		NStr("en = 'Employee ID
		     |Employee
		     |Position
		     |Rate
		     |Department
		     |Company'");
	Report.SearchSettings.ParametersAndFiltersNames =
		NStr("en = 'Registration period
		     |Department
		     |Currency
		     |Employee'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfTaxAccount, "Statement");
	Variant.Definition = NStr("en = 'Taxes opening balance, accruals, payments, closing balance'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StatementOfTaxAccount, "Balance");
	Variant.Definition			= NStr("en = 'The balance of tax payables'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PayStatements, "Statement");
	Variant.Definition			= NStr("en = 'Salary opening balance, earnings, payments, closing balance'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PayStatements, "Balance");
	Variant.Definition			= NStr("en = 'The balance of salary payable'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PayStatements, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Salary opening balance, earnings, payments, closing balance'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PayStatements, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'The balance of salary payable'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AdvanceHolders, "Statement");
	Variant.Definition			= NStr("en = 'Advance holders debt opening balance, claims, payments, closing balance'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AdvanceHolders, "Balance");
	Variant.Definition			= NStr("en = 'Debt balance of advance holders'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AdvanceHolders, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Advance holders debt opening balance, claims, payments, closing balance'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AdvanceHolders, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'Debt balance of advance holders'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivable, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, sales, payments, and closing balance, separated to credit and advance payments'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivable, "Balance");
	Variant.Definition			= NStr("en = 'Balance of receivables, advance payments, and overdue debts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivable, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, sales, payments, and closing balance, separated to credit and advance payments'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivable, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'Balance of receivables, advance payments, and overdue debts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivableTrend, "DebtDynamics");
	Variant.Definition = NStr("en = 'Receivables by periods displayed as a chart'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayable, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, purchases, payments, and closing balance, separated to credit and advance payments'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayable, "Balance");
	Variant.Definition			= NStr("en = 'Balance of payables, advance payments, and overdue debts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayable, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, purchases, payments, and closing balance, separated to credit and advance payments'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayable, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'Balance of payables, advance payments, and overdue debts'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayableTrend, "DebtDynamics");
	Variant.Definition = NStr("en = 'Payables by periods displayed as a chart'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivableAging, "Default");
	Variant.Definition			= NStr("en = 'Accounts receivable aging, and overdue debts according to payment terms'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsReceivableAging, "InCurrency");
	Variant.Definition = NStr("en = 'Accounts receivable aging, and overdue debts according to payment terms'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayableAging, "Default");
	Variant.Definition			= NStr("en = 'Accounts payable aging, and overdue debts according to payment terms'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AccountsPayableAging, "InCurrency");
	Variant.Definition = NStr("en = 'Accounts payable aging, and overdue debts according to payment terms'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesOrdersTrend, "Default");
	Variant.Definition = NStr("en = 'Payment info, availability and supply status of goods ordered by customers'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.PurchaseOrdersOverview, "Default");
	Variant.Definition = NStr("en = 'Payment info and supply status of goods ordered to suppliers'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EmployeePerformanceReport, "Default");
	Variant.Definition = NStr("en = 'The report is designed to perform variance analysis of technological operations performed by employees within the job sheet'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CostOfGoodsManufactured, "Full");
	Variant.Definition = NStr("en = 'Actual cost of goods manufactured, by cost items'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CostOfGoodsManufactured, "Default");
	Variant.Definition = NStr("en = 'Actual cost of goods manufactured, by expense GL accounts'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.DirectMaterialVariance, "Default");
	Variant.Definition = NStr("en = 'Difference between the standard cost of materials resulting from production activities and the actual costs incurred'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockSummary, "Statement");
	Variant.Definition = NStr("en = 'Opening balance, receipt, consumption, closing balance by products and warehouses'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockSummary, "Balance");
	Variant.Definition			= NStr("en = 'Stock balance by products and warehouses'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EmployeesLists, "EmployeesList");
	Variant.Definition = NStr("en = 'Employee, position, and FTE'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EmployeesLists, "EarningsPlan");
	Variant.Definition = NStr("en = 'Employees compensation plan'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EmployeesLists, "PassportData");
	Variant.Definition = NStr("en = 'Employees identity document data'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.EmployeesLists, "ContactInformation");
	Variant.Definition = NStr("en = 'Employees, postal address, actual address and phone number'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.POSSummary, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, increase, decrease, closing balance of retail value and cost (for Retail Inventory Method)'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.POSSummary, "Balance");
	Variant.Definition			= NStr("en = 'Retail value and cost of goods (for Retail Inventory Method)'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.POSSummary, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, increase, decrease, closing balance of retail value (for Retail Inventory Method)'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.POSSummary, "BalanceInCurrency");
	Variant.Definition			= NStr("en = 'Retail value of goods (for Retail Inventory Method)'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CostOfSales, "Statement");
	Variant.Definition = NStr("en = 'Cost of sales refers to the direct costs attributable to the goods sold or supply of services'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CostOfSalesBudget, "Default");
	Variant.Definition = NStr("en = 'Report presents financial result forecast of the selected scenario'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.CostOfSalesBudget, "Planfact analysis");
	Variant.Definition = NStr("en = 'The report compares forecast and actual financial results'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.HeadcountVariance, "Default");
	Variant.Definition = NStr("en = 'Headcount budget vs actual'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.RawMaterialsConsumption, "Default");
	Variant.Placement.Clear();
	
	// DiscountCards
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesWithCardBasedDiscounts, "SalesWithCardBasedDiscounts");
	Variant.Definition = NStr("en = 'Discounts granted by discount cards'");	
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesWithCardBasedDiscounts, "SalesByDiscountCard");
	Variant.Definition			= NStr("en = 'The report is called from the ""Discount cards"" data processor and displays data on sales by discount cards for a certain period of time in monetary terms'");	
	Variant.Enabled				= False;
	Variant.VisibleByDefault	= False;
	// End DiscountCards
	
	// AutomaticDiscounts
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.AutomaticDiscountSales, "AutomaticDiscounts");
	Variant.Definition = NStr("en = 'Automatic discounts granted'");	
	// End AutomaticDiscounts
	
	// Miscellaneous payable
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.MiscellaneousPayableStatement, "Statement");
	Variant.Definition			= NStr("en = 'Opening balance, debits, credits, closing balance of miscellaneous payable'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.MiscellaneousPayableStatement, "Balances");
	Variant.Definition			= NStr("en = 'The balance of miscellaneous payable'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.MiscellaneousPayableStatement, "StatementInCurrency");
	Variant.Definition = NStr("en = 'Opening balance, debits, credits, closing balance of miscellaneous payable'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.MiscellaneousPayableStatement, "BalancesInCurrency");
	Variant.Definition			= NStr("en = 'The balance of miscellaneous payable'");
	Variant.VisibleByDefault	= False;
	// End miscellaneous payable
	
	// Serial numbers
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SerialNumbersRecords, "Default");
	Variant.Definition = NStr("en = 'The report shows the movement of goods, taking into account the serial numbers.'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SerialNumbersTracking, "Balance");
	Variant.Definition = NStr("en = 'The report shows the rest of the goods in the warehouses with the details by serial number.'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SerialNumbersTracking, "Statement");
	Variant.Definition = NStr("en = 'The report shows a list of goods movement in warehouses with detailed information on serial numbers.'");
	// End Serial numbers
	
	// Loans
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.LoanAccountStatement, "LoansToEmployees");
	Variant.Definition = NStr("en = 'Opening balance, accruals, repayments, closing balance of loans lent'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.LoanAccountStatement, "LoansReceived");
	Variant.Definition = NStr("en = 'Opening balance, accruals, repayments, closing balance of loans borrowed'");
	// End Loans
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SegmentContent, "SegmentContentContext");
	Variant.Definition	= NStr("en = 'The report shows the current counterparty segment.'");
	Variant.Enabled		= False;
	Variant.Placement.Clear();
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.GoodsInvoicedNotShipped, "Default");
	Variant.Definition = NStr("en = 'Goods invoiced, but not yet shipped by goods issue documents'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.GoodsShippedNotInvoiced, "Default");
	Variant.Definition = NStr("en = 'Goods shipped by Goods issue documents, but not yet invoiced'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockStatementWithCostLayers, "Statement");
	Variant.Definition = NStr("en = 'Opening balance, receipt, consumption, closing balance (FIFO)'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.StockStatementWithCostLayers, "Balance");
	Variant.Definition			= NStr("en = 'Closing balance and average item cost (FIFO)'");
	Variant.VisibleByDefault	= False;
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.GoodsReceivedNotInvoiced, "Default");
	Variant.Definition = NStr("en = 'Goods received by Goods receipt documents, but not yet invoiced'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesPipeline, "Comparison");
	Variant.Definition = NStr("en = 'Campaign progress comparison chart as of different dates'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesPipeline, "BySalesReps");
	Variant.Definition = NStr("en = 'Campaign progress chart by sales representatives'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.InvoicesValidForEPD, "InvoicesValidForEPD");
	Variant.Definition = NStr("en = 'Invoices valid for early payment discount'");
	
	Variant = ReportsVariants.VariantDesc(Settings, Metadata.Reports.SalesFunnel, "SalesFunnel");
	Variant.Definition = NStr("en = 'The report shows the conversion rate from lead to repetitive sales'");
	
	HighlightKeyReports(Settings);
	HighlightSecondaryReports(Settings);
	
EndProcedure

// Contains the descriptions of names and report options changes. It
//   is used when updating the infobase in order to
//   control the referential integrity and save option settings made by the administrator.
//
// Parameters:
//   Changes - ValueTable - Option names changes table. Columns:
//       * Report - MetadataObject - Report metadata in the schema of which option name is changed.
//       * VariantOldName - String - Option old name before change.
//       * VariantActualName - String - Option current (last relevant) name.
//
// Definition:
//   Descriptions of changes of option names
//   of the reports connected to the subsystem shall be added to Changes.
//
// ForExample:
// Change = Changes.Add();
// Change.Report = Metadata.Reports.<ReportName>;
// Update.VariantOldName = "<VariantOldName>";
// Update.VariantActualName = "<VariantActualName>";
//
// IMPORTANT:
//   Option old name is reserved and can not be used further.
//   If several changes were made, each update shall
//   be registered specifying the report option last (current) name in the actual option name.
//   Since the names of the report options are
//   not displayed in user interface it is recommended to specify them so that they won't be changed.
//
Procedure RegisterReportVariantsKeysChanges(Changes) Export
	
EndProcedure

// Global settings applied as defaults for subsystem objects.
//
// Parameters:
//   Settings - Subsystem settings collection. Attributes:
//       * OutputReportsInsteadVariants - Boolean - Default hyperlinks output in the reports panel:
//           - True - The report options are hidden by default while the reports are enabled and visible.
//           - False   - Value by default. The report options are visible by default while the reports are disabled.
//       * OutputDescription - Boolean - Default descriptions output in the reports panel:
//           - True - Value by default. Show descriptions in the form of
//               inscriptions under the variants hyperlinks (descriptions reading mode).
//           - False   - Show descriptions in
//               the form of tooltips (as before).
//       * Search - Structure - Settings of report options search.
//           * InputHint - String - ToolTip text is displayed in the search field when search is not specified.
//               It is recommended to specify frequently used terms of applied configuration as an example.
//       * OtherReports - Structure - Form settings "Other reports":
//           * CloseAfterSelection - Boolean - Whether to close the form after selection of the report hyperlink.
//               - True - Value by default. Close "Other reports" after selection.
//               - False   - Do not close.
//           * ShowCheckBox - Boolean - Whether to show the CloseAfterSelection check box.
//               - True - Show the "Close this window after going to another report" check box.
//               - False   - Value by default. Do not show check box.
//
// ForExample:
// Settings.Search.InputHint = NStr("en = 'For example, cost'; ru = 'Например, себестоимость'");
// Settings OtherReports.CloseAfterSelection = False;
// Settings.OtherReports.ShowCheckBox = True;
//
Procedure DefineGlobalSettings(Settings) Export
	
	Settings.OutputDescription = False;
	
EndProcedure

#EndRegion

#EndRegion
