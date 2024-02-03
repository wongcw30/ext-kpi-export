<cfscript>
	validationResult = ( rc.validationResult ?: "" );
	errorMessage     = rc.errorMessage       ?: "";
	successMessage   = rc.successMessage     ?: "";
</cfscript>

<cfoutput>	
	<cfif !isEmpty( errorMessage )>
		<p class="alert alert-danger">#errorMessage#</p>
	<cfelseif !isEmpty( successMessage )>
		<p class="alert alert-info">#successMessage#</p>
	</cfif>
	<form class="form-horizontal" action="#event.buildAdminLink( linkTo="kpiExport.submitAction" )#" method="GET">
		<input type="hidden" name="csrfToken" value="#event.getCsrfToken()#" />

		#renderForm(
			  formName         = "admin.kpiExport.filter"
			, savedData        = rc.formData ?: {}
			, validationResult = validationResult
		)#

		<div class="row">
			<div class="col-sm-10 pull-right">
				<cfif hasCmsPermission( "kpiExport.download" )>
					<button class="btn btn-primary" name="action" value="download">
						<span class="fa fa-download"></span>
						Export
					</button>
				</cfif>
			</div>
		</div>
	</form>
</cfoutput>