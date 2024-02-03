<cfif hasCmsPermission( "kpiExport.manage" )>
	<cfoutput>
		<li>
			<a href="#event.buildAdminLink( linkTo="kpiExport" )#">
				<i class="fa fa-fw fa-database"></i>
				#translateResource( 'kpiExport:navigation.link' )#
			</a>
		</li>
	</cfoutput>
</cfif>