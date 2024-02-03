component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.adminConfigurationMenuItems = settings.adminConfigurationMenuItems ?: [];
		settings.adminConfigurationMenuItems.append( "kpiExport" );

		settings.adminPermissions = settings.adminPermissions ?: {};
		settings.adminPermissions.kpiExport = [ "manage", "download"  ];

		settings.adminRoles = settings.adminRoles ?: {};
		settings.adminRoles.kpiExport = [ "kpiExport.*", "cms.access", "savedExport.*", "adhocTaskManager.*" ];
	}

}