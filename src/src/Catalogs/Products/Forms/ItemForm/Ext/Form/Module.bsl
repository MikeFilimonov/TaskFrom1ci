#Region ServiceProceduresAndFunctions

// The function returns the file data
//
&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Sets the corresponding value for the GenerateDescriptionFullAutomatically variable.
//
//
&AtClientAtServerNoContext
Function SetFlagToFormDescriptionFullAutomatically(Description, DescriptionFull)
	
	Return (Description = DescriptionFull OR IsBlankString(DescriptionFull));
	
EndFunction

// Prepare the record structure for the basic sale prices
//
&AtServer
Function GetMainSalesPriceFillData()
	
	FillingData = New Structure;
	FillingData.Insert("Period", CurrentSessionDate());
	FillingData.Insert("PriceKind", PriceKind);
	FillingData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
	FillingData.Insert("Price", MainSalePrice);
	FillingData.Insert("Products", Object.Ref);
	FillingData.Insert("MeasurementUnit", Object.MeasurementUnit);
	
	Return FillingData; 
	
EndFunction

// In case the basic sale price is changed, we make it basic at the item form
//
&AtServer
Procedure SetChangeBasicSalesPrice()
	
	If MainSalePrice <> 0 Then
		
		FillingData = GetMainSalesPriceFillData();
		
		If MainSalePrice <> Catalogs.Products.GetMainSalePrice(FillingData.PriceKind, FillingData.Products, FillingData.MeasurementUnit) Then
			
			InformationRegisters.Prices.SetChangeBasicSalesPrice(FillingData);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Fills in the attribute of the MainSalePrice form
//
&AtServer
Procedure FillBasicSalesPriceOnServer()
	
	MainSalePrice = Catalogs.Products.GetMainSalePrice(PriceKind, Object.Ref, Object.MeasurementUnit);
	
EndProcedure

// The procedure initiates the BasicSalesPrice
// form attribute filling and updates the corresponding item of the form
//
&AtClient
Procedure InitiateFillingBasicSalesPriceOnClient()
	
	FillBasicSalesPriceOnServer();
	
	Items.MainSalePrice.UpdateEditText();
	
EndProcedure

// Image view procedure
//
&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	If ValueIsFilled(Object.PictureFile) Then
		
		FileData = GetFileData(Object.PictureFile, UUID);
		AttachedFilesClient.OpenFile(FileData);
		
	Else
		
		MessageText = NStr("en = 'No preview image'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure

// Procedure of the image adding for the products
//
&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, write the object. Write?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddImageAtClientFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.Yes Then
        Write();
    Else 
        Return
    EndIf;
    
    
    AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
	
	Var FileID, Filter;
	
	If ValueIsFilled(Object.PictureFile) Then
		
		SeeAttachedFile();
		
	ElsIf ValueIsFilled(Object.Ref) Then
		
		InsertImagesFromProducts = True;
		FileID = New UUID;
		
		Filter = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All Images %1|All files %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9'"),
			"(*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf",
			"(*.*)|*.*",
			"(*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle",
			"(*.gif*)|*.gif",
			"(*.jpeg;*.jpg)|*.jpeg;*.jpg",
			"(*.png*)|*.png",
			"(*.tif)|*.tif",
			"(*.ico)|*.ico",
			"(*.wmf;*.emf)|*.wmf;*.emf");
		
		AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
		
	EndIf;
	
EndProcedure

// The function returns the file (image) data
//
&AtServerNoContext
Function URLImages(PictureFile, FormID)
	
	SetPrivilegedMode(True);
	Return AttachedFiles.GetFileData(PictureFile, FormID).FileBinaryDataRef;
	
EndFunction

// Procedure opens the list of the image selection from already attached files
//
&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("FileOwner", Object.Ref);
	ChoiceParameters.Insert("ChoiceMode", True);
	ChoiceParameters.Insert("CloseOnChoice", True);
	
	OpenForm("CommonForm.AttachedFiles", ChoiceParameters, ThisForm);
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabled(OnProductsTypeChanged = False)
	
	ProductsTypeNotFilled = NOT ValueIsFilled(Object.ProductsType);
	
	ServiceProductsType = Object.ProductsType = Enums.ProductsTypes.Service;
	
	Items.IsFreightService.Visible = ServiceProductsType;
	
	Items.VATRate.Visible = ProductsTypeNotFilled
							OR Object.ProductsType = Enums.ProductsTypes.InventoryItem
							OR Object.ProductsType = Enums.ProductsTypes.Service
							OR Object.ProductsType = Enums.ProductsTypes.Work;

	Items.BusinessLine.Visible				= Items.VATRate.Visible;
	Items.UseCharacteristics.Visible		= Items.VATRate.Visible;
	Items.OrderCompletionDeadline.Visible	= Items.VATRate.Visible;
	
	Items.Vendor.Visible = ProductsTypeNotFilled
								OR Object.ProductsType = Enums.ProductsTypes.InventoryItem
								OR Object.ProductsType = Enums.ProductsTypes.Service;
	
	Items.Warehouse.Visible = ProductsTypeNotFilled
									OR Object.ProductsType = Enums.ProductsTypes.InventoryItem;
	
	Items.Picture.Visible				= Items.Warehouse.Visible;
	Items.ReplenishmentMethod.Visible	= Items.Warehouse.Visible;
	Items.ReplenishmentDeadline.Visible	= Items.Warehouse.Visible;
	Items.Cell.Visible					= Items.Warehouse.Visible;
	Items.UseBatches.Visible			= Items.Warehouse.Visible;

	Items.Specification.Visible = ProductsTypeNotFilled
										OR (Object.ProductsType = Enums.ProductsTypes.InventoryItem
											AND Constants.UseProductionSubsystem.Get())
										OR (Object.ProductsType = Enums.ProductsTypes.Work
											AND Constants.UseWorkOrders.Get());
	
	Items.TimeNorm.Visible = ProductsTypeNotFilled
								OR Object.ProductsType = Enums.ProductsTypes.Operation;
	
	Items.CountryOfOrigin.Visible = Object.ProductsType = Enums.ProductsTypes.InventoryItem;
	
	Items.UseSerialNumbers.Visible			= Items.CountryOfOrigin.Visible;
	Items.WarrantyMonthsText.Visible		= Items.CountryOfOrigin.Visible;
	Items.WriteOutTheGuaranteeCard.Visible	= Items.CountryOfOrigin.Visible;
	
	If OnProductsTypeChanged Then
		
		Object.ReplenishmentDeadline	= 0;
		Object.UseCharacteristics		= False;
		Object.UseBatches				= False;
		Object.OrderCompletionDeadline	= 0;
		Object.TimeNorm					= 0;
		Object.IsFreightService			= False;
		
		UseProductionSubsystem	= Constants.UseProductionSubsystem.Get();
		AccountingPolicy		= InformationRegisters.AccountingPolicy.GetAccountingPolicy();
		
		If Items.VATRate.Visible Then
			Object.VATRate = AccountingPolicy.DefaultVATRate;
		EndIf;
		
		If Items.BusinessLine.Visible Then
			Object.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		EndIf;
		
		If Items.Warehouse.Visible Then
			Object.Warehouse = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
		
		If Items.ReplenishmentMethod.Visible Then
			Object.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
		EndIf;
		
		If Not ValueIsFilled(Object.ProductsType)
			OR Object.ProductsType = Enums.ProductsTypes.InventoryItem
			OR Object.ProductsType = Enums.ProductsTypes.Work
			OR Object.ProductsType = Enums.ProductsTypes.Operation Then
			
		EndIf;
		
		If Items.ReplenishmentDeadline.Visible Then
			Object.ReplenishmentDeadline = 1;
		EndIf;
		
		If Items.OrderCompletionDeadline.Visible Then
			Object.OrderCompletionDeadline = 1;
		EndIf;
		
	EndIf;
	
	// Prices
	Items.InformationAboutPrices.Visible = AccessRight("Read", Metadata.InformationRegisters.Prices);
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	Items.MainSalePrice.ReadOnly = Not AllowedEditDocumentPrices;
	
EndProcedure

&AtServer
// Procedure sets the form attribute visible
// from the Use Production Subsystem options, Works.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionJobsSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Replenishment method.
		Items.ReplenishmentMethod.ChoiceList.Add(Enums.InventoryReplenishmentMethods.Production);
		
		// Warehouse. Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.Warehouse.ListChoiceMode = True;
			Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Items.Warehouse.ChoiceParameters = NewParameters;
			
		Else
			
			Items.Warehouse.Visible = False;
			
		EndIf;
		
	EndIf;
	
	// Reprocessing.
	If Constants.UseSubcontractorManufacturers.Get() Then
		Items.ReplenishmentMethod.ChoiceList.Add(Enums.InventoryReplenishmentMethods.Processing);
	EndIf;
	
EndProcedure

// Procedure fills the list of the product types available for selection depending on the form parameters and functional
// options
// 
&AtServer
Procedure FillListTypes()
	
	List = Items.ProductsType.ChoiceList;
	
	ProductAndServicesTypeRestriction = Undefined;
	If Not Parameters.FillingValues.Property("ProductsType", ProductAndServicesTypeRestriction) Then
		Parameters.AdditionalParameters.Property("TypeRestriction", ProductAndServicesTypeRestriction);
	EndIf;
		
	If Not ProductAndServicesTypeRestriction = Undefined Then
		If (TypeOf(ProductAndServicesTypeRestriction) = Type("Array") Or TypeOf(ProductAndServicesTypeRestriction) = Type("FixedArray")) 
			AND ProductAndServicesTypeRestriction.Count() > 0 Then
			
			List.Clear();
			For Each Type In ProductAndServicesTypeRestriction Do
				List.Add(Type);
			EndDo;
			
		ElsIf TypeOf(ProductAndServicesTypeRestriction) = Type("EnumRef.ProductsTypes") Then
			
			List.Clear();
			List.Add(ProductAndServicesTypeRestriction);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseOperationsManagement.Get() Then
		FoundOperation = Items.ProductsType.ChoiceList.FindByValue(Enums.ProductsTypes.Operation);
		If FoundOperation <> Undefined Then
			Items.ProductsType.ChoiceList.Delete(FoundOperation);
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.ProductsType) 
		Or Items.ProductsType.ChoiceList.FindByValue(Object.ProductsType) = Undefined Then
			Object.ProductsType = List.Get(0).Value;
	EndIf;
	
	If List.Count() = 1 Then
		Items.ProductsType.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MetadataObject = Object.Ref.Metadata();
	
	SetVisibleAndEnabled();
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(
		Object.Description,
		Object.DescriptionFull);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		FillListTypes();
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
			Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(,);
			Object.VATRate			= Policy.DefaultVATRate;
		EndIf;
		
		If Not IsBlankString(Parameters.FillingText) AND GenerateDescriptionFullAutomatically Then
			Object.DescriptionFull = Parameters.FillingText;
		EndIf;
		
	EndIf;
	
	InsertImagesFromProducts = False;
	
	// Work with prices
	PriceKind = Catalogs.PriceTypes.GetMainKindOfSalePrices();
	FillBasicSalesPriceOnServer();
	
	NotifyPickup = False;
	ItemModified = False;
	
	PictureURL = ?(Object.PictureFile.IsEmpty(), "", URLImages(Object.PictureFile, UUID));
	Items.PictureURL.ReadOnly = Not AccessRight("Edit", Object.Ref.Metadata());
	
	// FO Use the subsystems Production, Work.
	SetVisibleByFOUseProductionJobsSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	ChangeOpenAdditionalAttributesButton();
	
	WarrantyMonthsText = NStr("en = 'months'");
	
EndProcedure

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// SelectionProcessor form event handler procedure
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		Object.PictureFile = ValueSelected;
		PictureURL = URLImages(Object.PictureFile, UUID)
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems(); 
	EndIf;
	
	If EventName = "PriceChanged"
		AND Parameter Then
		
		InitiateFillingBasicSalesPriceOnClient();
		
	ElsIf InsertImagesFromProducts
		AND EventName = "Record_AttachedFile" Then
		
		Modified							= True;
		Object.PictureFile					= ?(TypeOf(Source) = Type("Array"), Source[0], Source);
		PictureURL							= URLImages(Object.PictureFile, UUID);
		InsertImagesFromProducts	= False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
			
	If Modified Then
		ItemModified = True;	
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler  of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
	If ItemModified Then
		NotifyPickup = True;
		ItemModified = False;
	EndIf;
	
	SetChangeBasicSalesPrice();
	
EndProcedure

&AtClient
// BeforeRecord event handler procedure.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogProductsWrite");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If NotifyPickup 
		AND TypeOf(FormOwner) = Type("ManagedForm")
		AND FormOwner.FormName = "CommonForm.PickForm" Then
		Notify("RefreshPickup", True);
	// CWP
	ElsIf NotifyPickup 
		AND TypeOf(FormOwner) = Type("ManagedForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 Then
		Notify("ProductsIsAddedFromCWP", Object.Ref);
	EndIf;
	// End CWP
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - OnChange event handler of the Description field.
//
Procedure DescriptionOnChange(Item)

	If GenerateDescriptionFullAutomatically Then
		
		Object.DescriptionFull = Object.Description;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ProductsType field.
//
Procedure ProductsTypeOnChange(Item)
	SetVisibleAndEnabled(True);
EndProcedure

&AtClient
// Procedure - Open event handler of the Warehouse field.
//
Procedure WarehouseOpening(Item, StandardProcessing)
	
	If Items.Warehouse.ListChoiceMode
		AND Not ValueIsFilled(Object.Warehouse) Then
		
		StandardProcessing = False;
		
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - SelectionStart event handler of the Specification field.
//
Procedure BillsOfMaterialstartChoice(Item,  ChoiceData, StandardProcessing)
		
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		Message = New UserMessage();
		Message.Text = NStr("en = 'Catalog item is not recorded yet'");
		Message.Message();
		
	EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of the ImageFile field.
//
Procedure PictureFileOnChange(Item)
	
	PictureURL = ?(Object.PictureFile.IsEmpty(), "", URLImages(Object.PictureFile, UUID));
	
EndProcedure

&AtClient
Procedure PictureFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
// Procedure - Click event handler of the ImageURL address.
//
Procedure PictureURLClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	If Items.PictureURL.ReadOnly Then
		Return;
	EndIf;
	
	LockFormDataForEdit();
	AddImageAtClient();
	
EndProcedure

// Procedure - OnChange event handler of the DescriptionFull attribute
//
&AtClient
Procedure DescriptionFullOnChange(Item)
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(Object.Description, Object.DescriptionFull);
	
EndProcedure

// Procedure - Click event handler of the History attribute
//
&AtClient
Procedure PriceChangeHistoryClick(Item)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		WarningText = NStr("en = 'Item is not written. Cannot open the price history of an unwritten item.'");
		HeaderText 		= NStr("en = 'Cannot open the price history'");
		
		ShowMessageBox(Undefined,WarningText, 20, HeaderText);
		Return;
		
	EndIf;
	
	StructureFilter = New Structure;
	StructureFilter.Insert("Products", Object.Ref);
	StructureFilter.Insert("PriceKind", PriceKind);
	
	OpenForm("InformationRegister.Prices.ListForm", New Structure("Filter", StructureFilter));
	
EndProcedure

&AtClient
Procedure ProductsCategoryOnChange(Item)
	ProductsCategoryOnChangeAtServer();
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Procedure - AddImage command handler
//
&AtClient
Procedure AddImage(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, write the object. Write?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddImageFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddImageFragment();

EndProcedure

&AtClient
Procedure AddImageFragment()
	Var FileID;
	
	InsertImagesFromProducts = True;
	FileID = New UUID;
	AttachedFilesClient.AddFiles(Object.Ref, FileID);
	
EndProcedure

// Procedure - ChangeImage command handler
//
&AtClient
Procedure ChangeImage(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.PictureFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.PictureFile);
		
	Else
		
		MessageText = NStr("en = 'No image for editing'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure

// Procedure - ClearImage command handler
//
&AtClient
Procedure ClearImage(Command)
	
	Object.PictureFile = Undefined;
	PictureURL = "";
	
EndProcedure

// Procedure - ClearImage command handler
//
&AtClient
Procedure SeeImage(Command)
	
	SeeAttachedFile();
	
EndProcedure

// Procedure - SelectImageFromAttachedFiles command handler
&AtClient
Procedure PictureFromAttachedFiles(Command)
	
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
Procedure OpenAdditionalAttributes(Command)
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", GetOpenAttributesFormStructure(Object.ProductsCategory));
EndProcedure

#Region InternalProceduresAndFunctions

&AtServer
Procedure ProductsCategoryOnChangeAtServer()
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm,, False);
EndProcedure

&AtServer
Procedure ChangeOpenAdditionalAttributesButton()
	
	If Items.AdditionalAttributesPage.ChildItems.Count() > 1 Then
		Items.OpenAdditionalAttributes.Title	= NStr("en = 'Setup additional attributes'");
		Items.OpenAdditionalAttributes.Visible	= Users.RolesAvailable("AddChangeBasicReferenceData");
	Else
		Items.OpenAdditionalAttributes.Title = NStr("en = 'There are no additional attributes for this product. Click here to create attributes'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetOpenAttributesFormStructure(Category)
	Return New Structure("CurrentSet", Category.PropertySet);
EndFunction

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisObject);
	
EndProcedure
// End

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	ChangeOpenAdditionalAttributesButton();
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#EndRegion
