
&AtServer
Procedure SetFilterByResourceKind(FilterResourceKind)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CompanyResourceTypes.CompanyResource AS CompanyResource
	|FROM
	|	InformationRegister.CompanyResourceTypes AS CompanyResourceTypes
	|WHERE
	|	CompanyResourceTypes.CompanyResourceType = &CompanyResourceType";
	
	Query.SetParameter("CompanyResourceType", FilterResourceKind);
	Selection = Query.Execute().Select();
	ListResourcesKinds = New ValueList;
	While Selection.Next() Do
		ListResourcesKinds.Add(Selection.CompanyResource);
	EndDo;
	
	DriveClientServer.SetListFilterItem(List, "Ref", ListResourcesKinds, True, DataCompositionComparisonType.InList);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FilterResourceKind") Then
		
		FilterResourceKind = Parameters.FilterResourceKind;
		If ValueIsFilled(FilterResourceKind) Then
			SetFilterByResourceKind(FilterResourceKind)
		EndIf;
		
	EndIf;
	
EndProcedure
