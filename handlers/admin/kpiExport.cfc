component extends="preside.system.base.AdminHandler" {

	property name="kpiExportService" inject="KpiExportService";

	function prehandler( event, rc, prc ) output=false {
		super.preHandler( argumentCollection = arguments );

		if ( !hasCmsPermission( permissionKey="kpiExport.manage" ) ) {
			event.adminAccessDenied();
		}

		event.addAdminBreadCrumb(
			  title = translateResource( "kpiExport:crumb"  )
			, link  = event.buildAdminLink( linkTo="kpiExport" )
		);
	}

	function index( event, rc, prc, args={} ){
		prc.pageTitle    = translateResource( "kpiExport:name"        );
		prc.pageSubTitle = translateResource( "kpiExport:description" );
		prc.pageIcon     = translateResource( "kpiExport:iconClass"   );
	}

	public function submitAction( event, rc, prc, args={} ){
		var action           = rc.action ?: "";
		var formName         = "admin.kpiExport.filter";
		var formData         = event.getCollectionForForm( formName );
		var validationResult = validateForm( formName=formName, formData=formData );
		var validCsrfToken   = event.validateCsrfToken( rc.csrfToken ?: "" );
		var persistStruct    = {};

		if ( validationResult.validated() && validCsrfToken ) {
			if ( action == "download" && hasCmsPermission( permissionKey="kpiExport.download" ) ) {
				var taskId = createTask(
					  event     = "admin.kpiExport.downloadReport"
					, args      = { target_object=formData.target_object?:"", subscription_status=formData.subscription_status?:"all" }
					, runNow    = true
					, title     = "Generate Contact KPI report"
					, resultUrl = event.buildAdminLink( linkTo="dataHelpers.downloadExport", queryString="taskId={taskId}" )
					, returnUrl = event.buildAdminLink( linkTo="kpiExport.index"                                       )
				);

				setNextEvent( url=event.buildAdminLink( linkTo="adHocTaskManager.progress", queryString="taskId=#taskId#" ) );
			}

			persistStruct.append( formData );
		} else {
			persistStruct.validationResult = validationResult;

			if ( !validCsrfToken ) {
				persistStruct.errorMessage = "Invalid CSRF Token";
			} else {
				persistStruct.errorMessage = "Sorry, there was an error in the form, please try again.";
			}
		}

		setNextEvent( url=event.buildAdminLink( linkTo="kpiExport" ), persistStruct=persistStruct );
	}

	private boolean function downloadReport( event, rc, prc, args, logger, progress ){
		kpiExportService.generateKpiReport(
			  argumentCollection = args
			, logger             = arguments.logger   ?: nullValue()
			, progress           = arguments.progress ?: nullValue()
		);

		return true;
	}

	public boolean function downloadEngagementReport( event, rc, prc, args, logger, progress ){
		kpiExportService.generateEngagementReport(
			  argumentCollection = args
			, logger             = arguments.logger   ?: nullValue()
			, progress           = arguments.progress ?: nullValue()
		);

		return true;
	}

}