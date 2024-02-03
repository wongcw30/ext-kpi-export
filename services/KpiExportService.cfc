/**
 * @singleton      true
 * @presideService true
 */
component {
	/**
	 * @dataExportService.inject        DataExportService
	 * @rulesEngineFilterService.inject RulesEngineFilterService
	 */
	public any function init(
		  required any dataExportService
		, required any rulesEngineFilterService
	){
		_setDataExportService( arguments.dataExportService );
		_setRulesEngineFilterService( arguments.rulesEngineFilterService );

		return this;
	}

	public void function generateKpiReport( string target_object="crm_contact", any logger, any progress ){

		var _logger  = arguments.logger ?: "";
		var canLog   = !isSimpleValue( _logger ) && !isNull( _logger );
		var canError = canLog && _logger.canError();
		var canInfo  = canLog && _logger.canInfo();
		var canWarn  = canLog && _logger.canWarn();

		var extraFilters       = [];
		var having             = "";
		var generatingMesage   = "Generating KPI Report";
		var subscriptionStatus = arguments.subscription_status ?: "all";

		if( arguments.target_object == "crm_organisation" ){
			generatingMesage &= " for Organisation";
		} else {
			generatingMesage &= " for Contact";
		}

		if( canInfo ){
			_logger.info( generatingMesage );
		}

		if( arguments.target_object == "crm_organisation" ){
			var validToFilter  = { filter="valid_to is not null" };
			var organisationSubscriptionQuery = $getPresideObject( "crm_subscription" ).selectData(
				  orderBy      = "valid_to desc"
				, filter       = {
					  product             = "corpmembership"
				  }
				, extraFilters        = [ validToFilter ]
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
				, extraSelectFields   = [ "grade.label as grade_label" ]
			);

			var extraJoins = [];
			extraJoins.append( {
				  subQuery       = organisationSubscriptionQuery.sql
				, subQueryAlias  = "organisationSubscriptionQuery"
				, subQueryColumn = "organisation"
				, joinToTable    = "crm_organisation"
				, joinToColumn   = "id"
				, type           = "left"
			} );
			extraFilters.append( {
				filterParams = organisationSubscriptionQuery.params
			} );

			var organisationSubMembersQuery = $getPresideObject("crm_subscription_member").selectData(
				  selectFields        = [ "distinct subscription.id", "subscription.organisation", "count( subscription.id ) as submembers_count" ]
				, groupBy             = "subscription.id"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = organisationSubMembersQuery.sql
				, subQueryAlias  = "organisationSubMembersQuery"
				, subQueryColumn = "organisation"
				, joinToTable    = "crm_organisation"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			if( subscriptionStatus != "all" ){
				having = " subscription_status = (:subscriptionStatus)";
				extraFilters.append( {
					filterParams = { subscriptionStatus={ value=subscriptionStatus, type="varchar" } }
				} );
			}

			var exportFilePath = _getDataExportService().exportData(
				  exporter     = "csv"
				, objectName   = "crm_organisation"
				, fieldTitles  = {
					  id                         = "ID"
					, label                      = "Organisation Name"
					, grade_label                = "Membership grade"
					, subscription_status        = "Membership status"
					, valid_from                 = "Membership start date"
					, valid_to                   = "Membership renewal date"
					, submembers_count           = "Places used on multi-user subscription"
				}
				, selectFields = [
					  "crm_organisation.id                               as id"
					, "crm_organisation.label                            as label"
					, "organisationSubscriptionQuery.grade_label         as grade_label"
					, "organisationSubscriptionQuery.subscription_status as subscription_status"
					, "organisationSubscriptionQuery.valid_from          as valid_from"
					, "organisationSubscriptionQuery.valid_to            as valid_to"
					, "organisationSubMembersQuery.submembers_count      as submembers_count"
				]
				, extraFilters       = extraFilters
				, orderBy            = "label asc"
				, groupBy            = "crm_organisation.id"
				, exportFileName     = "Organisation KPI report.csv"
				, logger             = arguments.logger   ?: nullValue()
				, progress           = arguments.progress ?: nullValue()
				, extraJoins         = extraJoins
				, having             = having
			);
		} else {

			var validToFilter  = { filter="valid_to is not null" };
			if( subscriptionStatus == "all" ){
				var contactSubscriptionQuery = $getPresideObject( "crm_subscription" ).selectData(
					  orderBy             = "valid_to desc"
					, filter              = { product = ["indmembership","corpmembership"] }
					, extraFilters        = [ validToFilter ]
					, getSqlAndParamsOnly = true
					, formatSqlParams     = true
					, extraSelectFields   = [ "grade.label as grade_label" ]
				);
			} else {
				var contactSubscriptionQuery = $getPresideObject( "crm_subscription" ).selectData(
					  orderBy             = "valid_to desc"
					, filter              = { product = ["indmembership","corpmembership"], subscription_status=subscriptionStatus }
					, extraFilters        = [ validToFilter ]
					, getSqlAndParamsOnly = true
					, formatSqlParams     = true
					, extraSelectFields   = [ "grade.label as grade_label" ]
				);
			}

			var extraJoins = [];
			extraJoins.append( {
				  subQuery       = contactSubscriptionQuery.sql
				, subQueryAlias  = "contactSubscriptionQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );
			extraFilters.append( {
				filterParams = contactSubscriptionQuery.params
			} );

			if( subscriptionStatus != "all" ){
				var subMembersQuery = $getPresideObject( "crm_subscription_member" ).selectData(
					  selectFields  = [ "crm_subscription_member.contact", "subscription.subscription_status" ]
					, filter        = "subscription_status = :subscription_status"
					, filterParams  = { subscription_status={ value=subscriptionStatus, type="varchar" } }
					, groupBy       = "contact"
				);
				var subMembersContactIds = valueList( subMembersQuery.contact );
			}

			var loginCountLastMonthQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "activity_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH) and activity_type='weblogin'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_last_month" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = loginCountLastMonthQuery.sql
				, subQueryAlias  = "loginCountLastMonthQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			var loginCountLastThreeMonthQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "activity_date >= DATE_SUB(NOW(), INTERVAL 3 MONTH) and activity_type='weblogin'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_last_three_month" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = loginCountLastThreeMonthQuery.sql
				, subQueryAlias  = "loginCountLastThreeMonthQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			var loginCountLastYearQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "activity_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR) and activity_type='weblogin'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_last_year" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = loginCountLastYearQuery.sql
				, subQueryAlias  = "loginCountLastYearQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			//event attendance
			var attendanceLastMonthQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "datecreated >= DATE_SUB(NOW(), INTERVAL 1 MONTH) and activity_type='emsEventAttended'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as attendance_last_month_count", "group_concat( distinct reference ) as attendee_ids" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = attendanceLastMonthQuery.sql
				, subQueryAlias  = "attendanceLastMonthQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			var attendanceLastThreeMonthQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "datecreated >= DATE_SUB(NOW(), INTERVAL 3 MONTH) and activity_type='emsEventAttended'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as attendance_last_three_month_count", "group_concat( distinct reference ) as attendee_ids" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = attendanceLastThreeMonthQuery.sql
				, subQueryAlias  = "attendanceLastThreeMonthQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			var attendanceLastYearQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "datecreated >= DATE_SUB(NOW(), INTERVAL 1 YEAR) and activity_type='emsEventAttended'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as attendance_last_year_count", "group_concat( distinct reference ) as attendee_ids" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = attendanceLastYearQuery.sql
				, subQueryAlias  = "attendanceLastYearQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			//event booked
			var bookedLastYearQuery = $getPresideObject( "crm_activity" ).selectData(
				  filter              = "datecreated >= DATE_SUB(NOW(), INTERVAL 1 YEAR) and activity_type='emsEventBooked'"
				, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as booked_last_year_count", "group_concat( distinct reference ) as event_ids" ]
				, groupBy             = "participants_list"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
			);
			extraJoins.append( {
				  subQuery       = bookedLastYearQuery.sql
				, subQueryAlias  = "bookedLastYearQuery"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			var contactIndustryType = $getPresideObject("crm_contact").selectData(
				  selectFields        = [ "crm_contact.id as contact", "group_concat( distinct industry_type.label ) as industry_type_label" ]
				, groupBy             = "crm_contact.id"
				, getSqlAndParamsOnly = true
				, formatSqlParams     = true
				, having              = "industry_type_label is not null"
			);

			extraJoins.append( {
				  subQuery       = contactIndustryType.sql
				, subQueryAlias  = "contactIndustryType"
				, subQueryColumn = "contact"
				, joinToTable    = "crm_contact"
				, joinToColumn   = "id"
				, type           = "left"
			} );

			if( subscriptionStatus != "all" ){
				having = "subscription_status is not null";
				if( !isEmpty( subMembersContactIds ) ){
					having &= " or id in (:subMembersContactIds)";
					extraFilters.append( {
						filterParams = { subMembersContactIds={ value=subMembersContactIds, type="varchar", list=true } }
					} );
				}
			}

			var exportFilePath = _getDataExportService().exportData(
				  exporter     = "CSV"
				, objectName   = "crm_contact"
				, fieldTitles  = {
					  id                                = "ID"
					, label                             = "Contact Name"
					, primary_email_address             = "Primary email address"
					, primary_telephone_number          = "Primary telephone number"
					, date_of_birth                     = "Date of Birth"
					, organisation_label                = "Organisation name"
					, default_address_line_1            = "Address line 1"
					, default_address_line_2            = "Address line 2"
					, default_address_line_3            = "Address line 3"
					, default_address_town              = "Address town"
					, default_address_city              = "Address town/city"
					, default_address_region            = "Address county/region"
					, default_address_country           = "Address country"
					, default_address_postcode          = "Address Postcode"
					, grade_label                       = "Membership grade"
					, valid_from                        = "Membership start date"
					, valid_to                          = "Membership renewal date"
					, subscription_status               = "Membership status"
					, submembers_count                  = "Places used on multi-user subscription"
					, job_title                         = "Job title"
					, job_function                      = "Job function"
					, industry_type_label               = "Industry type"
					, login_count_last_month            = "Login count - last month"
					, login_count_last_three_month      = "Login count - last 3 months"
					, login_count_last_year             = "Login count - last 12 months"
					, attendance_last_month_count       = "Event attendance count - last month"
					, attendee_ids_last_month           = "Event attended - last month"
					, attendance_last_three_month_count = "Event attendance count - last 3 months"
					, attendee_ids_last_three_month     = "Event attended - last 3 months"
					, attendance_last_year_count        = "Event attendance count - last 12 months"
					, attendee_ids_last_year            = "Event attended - last 12 months"
					, booked_last_year_count            = "Number of events registered for in last 12 months"
				}
				, selectFields = [
					  "crm_contact.id                                                  as id"
					, "crm_contact.label                                               as label"
					, "crm_contact.primary_email_address                               as primary_email_address"
					, "crm_contact.primary_telephone_number                            as primary_telephone_number"
					, "crm_contact.date_of_birth                                       as date_of_birth"
					, "organisation.label                                              as organisation_label"
					, "default_address.line_1                                          as default_address_line_1"
					, "default_address.line_2                                          as default_address_line_2"
					, "default_address.line_3                                          as default_address_line_3"
					, "default_address.town                                            as default_address_town"
					, "default_address.city                                            as default_address_city"
					, "default_address.region                                          as default_address_region"
					, "default_address.country                                         as default_address_country"
					, "default_address.postcode                                        as default_address_postcode"
					, "contactSubscriptionQuery.grade_label                            as grade_label"
					, "contactSubscriptionQuery.valid_from                             as valid_from"
					, "contactSubscriptionQuery.valid_to                               as valid_to"
					, "contactSubscriptionQuery.subscription_status                    as subscription_status"
					, "crm_contact.job_title                                           as job_title"
					, "job_function.label                                              as job_function"
					, "contactIndustryType.industry_type_label                         as industry_type_label"
					, "loginCountLastMonthQuery.login_count_last_month                 as login_count_last_month"
					, "loginCountLastThreeMonthQuery.login_count_last_three_month      as login_count_last_three_month"
					, "loginCountLastYearQuery.login_count_last_year                   as login_count_last_year"
					, "attendanceLastMonthQuery.attendance_last_month_count            as attendance_last_month_count"
					, "attendanceLastMonthQuery.attendee_ids                           as attendee_ids_last_month"
					, "attendanceLastThreeMonthQuery.attendance_last_three_month_count as attendance_last_three_month_count"
					, "attendanceLastThreeMonthQuery.attendee_ids                      as attendee_ids_last_three_month"
					, "attendanceLastYearQuery.attendance_last_year_count              as attendance_last_year_count"
					, "attendanceLastYearQuery.attendee_ids                            as attendee_ids_last_year"
					, "bookedLastYearQuery.booked_last_year_count                      as booked_last_year_count"

				]
				, extraFilters       = extraFilters
				, having             = having
				, orderBy            = "label asc"
				, groupBy            = "crm_contact.id"
				, exportFileName     = "Contact KPI report.csv"
				, logger             = arguments.logger   ?: nullValue()
				, progress           = arguments.progress ?: nullValue()
				, extraJoins         = extraJoins
				, recordsetDecorator = function( required query records ){
					_validateRecords( arguments.records, _logger );
				}
			);

		}
	}

	public void function generateEngagementReport( string target_object="crm_contact", any logger, any progress ){

		var _logger  = arguments.logger ?: "";
		var canLog   = !isSimpleValue( _logger ) && !isNull( _logger );
		var canError = canLog && _logger.canError();
		var canInfo  = canLog && _logger.canInfo();
		var canWarn  = canLog && _logger.canWarn();

		var extraFilters       = [];
		var having             = "";
		var generatingMesage   = "Generating Engagement Report";
		var organisationId     = arguments.organisationId ?: "";
		var contactIds         = "";
		var engagementSubscriptionRule = $getPresideSetting( "lookup", "engagement_subscription_rule" );

		if( canInfo ){
			_logger.info( generatingMesage );
		}

		var contactIdsQuery = $getPresideObject("crm_contact").selectData(
			  selectFields = ["id"]
			, filter       = { organisation=organisationId }
			, extraFilters = [ _getRulesEngineFilterService().prepareFilter( objectName="crm_contact", filterId=engagementSubscriptionRule ) ]
		);
		contactIds          = valueList( contactIdsQuery.id );
		var subMembersQuery = $getPresideObject( "crm_subscription_member" ).selectData(
			  selectFields  = [ "crm_subscription_member.id", "crm_subscription_member.subscription", "crm_subscription_member.contact", "subscription.subscription_status", "contact.organisation" ]
			, filter        = "contact.organisation = :organisation"
			, filterParams  = { organisation={ value=organisationId, type="varchar" } }
			, groupBy       = "contact"
		);
		var subMembersQueryContactIds = valueList( subMembersQuery.contact );
		contactIds = listAppend(contactIds, subMembersQueryContactIds);

		var validToFilter  = { filter="valid_to is not null" };
		var contactSubscriptionQuery = $getPresideObject( "crm_subscription" ).selectData(
			  orderBy             = "valid_to desc"
			, filter              = { product = ["indmembership","corpmembership"] }
			, extraFilters        = [ validToFilter ]
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
			, extraSelectFields   = [ "grade.label as grade_label" ]
		);

		var extraJoins = [];
		extraJoins.append( {
			  subQuery       = contactSubscriptionQuery.sql
			, subQueryAlias  = "contactSubscriptionQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );
		extraFilters.append( {
			filterParams = contactSubscriptionQuery.params
		} );

		var loginCountSinceBeginningQuery = $getPresideObject( "crm_activity" ).selectData(
			  filter              = "activity_type='weblogin'"
			, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_since_beginning" ]
			, groupBy             = "participants_list"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = loginCountSinceBeginningQuery.sql
			, subQueryAlias  = "loginCountSinceBeginningQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );

		var loginCountLastMonthQuery = $getPresideObject( "crm_activity" ).selectData(
			  filter              = "activity_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH) and activity_type='weblogin'"
			, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_last_month" ]
			, groupBy             = "participants_list"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = loginCountLastMonthQuery.sql
			, subQueryAlias  = "loginCountLastMonthQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );

		var loginCountLastYearQuery = $getPresideObject( "crm_activity" ).selectData(
			  filter              = "activity_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR) and activity_type='weblogin'"
			, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as login_count_last_year" ]
			, groupBy             = "participants_list"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = loginCountLastYearQuery.sql
			, subQueryAlias  = "loginCountLastYearQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );

		//event attendance
		var attendanceQuery = $getPresideObject( "crm_activity" ).selectData(
			  filter              = "datecreated >= DATE_SUB(NOW(), INTERVAL 1 YEAR) and activity_type='emsEventAttended'"
			, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as attendance_count", "group_concat( distinct reference ) as attendee_ids" ]
			, groupBy             = "participants_list"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = attendanceQuery.sql
			, subQueryAlias  = "attendanceQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );

		//event booked
		var eventBookedQuery = $getPresideObject( "crm_activity" ).selectData(
			  filter              = "activity_type='emsEventBooked'"
			, selectFields        = [ "crm_activity.participants_list as contact", "count( participants_list ) as booked_count", "group_concat( distinct reference ) as booking_ids" ]
			, groupBy             = "participants_list"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = eventBookedQuery.sql
			, subQueryAlias  = "eventBookedQuery"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );

		var userGroupMembership = $getPresideObject( "user_group_membership" ).selectData(
			  filter              = "user_group_membership.contact in (:groupContact)"
			, filterParams        = { groupContact={ value=contactIds, type="varchar", list=true } }
			, selectFields        = [ "count( user_group_membership.contact ) as group_count", "user_group_membership.contact" ]
			, groupBy             = "user_group_membership.contact"
			, getSqlAndParamsOnly = true
			, formatSqlParams     = true
		);
		extraJoins.append( {
			  subQuery       = userGroupMembership.sql
			, subQueryAlias  = "userGroupMembership"
			, subQueryColumn = "contact"
			, joinToTable    = "crm_contact"
			, joinToColumn   = "id"
			, type           = "left"
		} );
		extraFilters.append( {
			filterParams = userGroupMembership.params
		} );

		var organisationSubMembersQuery = $getPresideObject("crm_subscription_member").selectData(
			  selectFields        = [ "distinct subscription.id", "subscription.organisation", "count( subscription.id ) as submembers_count" ]
			, filter              = "subscription.organisation = :memberOrganisation"
			, filterParams        = { memberOrganisation={ value=organisationId, type="varchar" } }
			, groupBy             = "subscription.id"
		);
		var subMembersCount = organisationSubMembersQuery.submembers_count ?: 0;

		var exportFilePath = _getDataExportService().exportData(
			  exporter     = "CSV"
			, objectName   = "crm_contact"
			, fieldTitles  = {
				  organisation_label                = "Organisation name"
				, id                                = "Contact ID"
				, label                             = "Contact Name"
				, primary_email_address             = "Contact Email Address"
				, job_title                         = "Contact Job title"
				, grade_label                       = "Membership grade"
				, valid_from                        = "Date the contact joined"
				, valid_to                          = "Date the contact expires"
				, subscription_status               = "Membership status"
				, submembers_count                  = "Places used on multi-user subscription"
				, login_count_since_beginning       = "Login Count - All"
				, login_count_last_month            = "Login count - last month"
				, login_count_last_year             = "Login count - last 12 months"
				, booked_count                      = "Number of events registered"
				, booking_ids                       = "Event registered"
				, attendance_count                  = "Number of event attendances"
				, attendee_ids                      = "Event attended"
				, group_count                       = "How many groups the contact is part of"
			}
			, selectFields = [
				  "organisation.label                                              as organisation_label"
				, "crm_contact.id                                                  as id"
				, "crm_contact.label                                               as label"
				, "crm_contact.primary_email_address                               as primary_email_address"
				, "crm_contact.job_title                                           as job_title"
				, "contactSubscriptionQuery.grade_label                            as grade_label"
				, "contactSubscriptionQuery.valid_from                             as valid_from"
				, "contactSubscriptionQuery.valid_to                               as valid_to"
				, "contactSubscriptionQuery.subscription_status                    as subscription_status"
				, "''                                                              as submembers_count"
				, "loginCountSinceBeginningQuery.login_count_since_beginning       as login_count_since_beginning"
				, "loginCountLastMonthQuery.login_count_last_month                 as login_count_last_month"
				, "loginCountLastYearQuery.login_count_last_year                   as login_count_last_year"
				, "eventBookedQuery.booked_count                                   as booked_count"
				, "eventBookedQuery.booking_ids                                    as booking_ids"
				, "attendanceQuery.attendance_count                                as attendance_count"
				, "attendanceQuery.attendee_ids                                    as attendee_ids"
				, "userGroupMembership.group_count                                 as group_count"

			]
			, filter             = "crm_contact.id in (:id)"
			, filterParams       = { id=listToArray(contactIds) }
			, extraFilters       = extraFilters
			, having             = having
			, orderBy            = "label asc"
			, groupBy            = "crm_contact.id"
			, exportFileName     = "Engagement report.csv"
			, logger             = arguments.logger   ?: nullValue()
			, progress           = arguments.progress ?: nullValue()
			, extraJoins         = extraJoins
			, recordsetDecorator = function( required query records ){
				_validateEngagementRecords( arguments.records, _logger, subMembersCount );
			}
		);
		
	}

//Private helpers
	private void function _validateRecords( required query records, struct _logger=_buildLoggerProxy() ){
		var numberOfRecords    = arguments.records.recordCount;

		arguments._logger.info( "Validating #numberOfRecords# record#numberOfRecords > 1 ? "s" : ""#" );

		arguments.records.each( ( struct record, numeric index, query resultSet ) => {

			if ( len( trim( record.attendee_ids_last_month?:'' ) ) ) {
				var eventLabels = $getPresideObject( "ems_attendee" ).selectData(
					  selectFields = [ "ems_attendee.id", "ems_event.name as event_name", "ems_event.id as event_id" ]
					, filter       = { id=listToArray( record.attendee_ids_last_month ) }
				);
				resultSet.attendee_ids_last_month[ index ] = "";
				if( eventLabels.recordCount ){
					resultSet.attendee_ids_last_month[ index ] = valueList( eventLabels.event_name );
				}
			}


			if ( len( trim( record.attendee_ids_last_three_month?:'' ) ) ) {
				var eventLabels = $getPresideObject( "ems_attendee" ).selectData(
					  selectFields = [ "ems_attendee.id", "ems_event.name as event_name", "ems_event.id as event_id" ]
					, filter       = { id=listToArray( record.attendee_ids_last_three_month ) }
				);
				resultSet.attendee_ids_last_three_month[ index ] = "";
				if( eventLabels.recordCount ){
					resultSet.attendee_ids_last_three_month[ index ] = valueList( eventLabels.event_name );
				}
			}

			if ( len( trim( record.attendee_ids_last_year?:'' ) ) ) {
				var eventLabels = $getPresideObject( "ems_attendee" ).selectData(
					  selectFields = [ "ems_attendee.id", "ems_event.name as event_name", "ems_event.id as event_id" ]
					, filter       = { id=listToArray( record.attendee_ids_last_year ) }
				);
				resultSet.attendee_ids_last_year[ index ] = "";
				if( eventLabels.recordCount ){
					resultSet.attendee_ids_last_year[ index ] = valueList( eventLabels.event_name );
				}
			}

			if( !len( trim( record.grade_label?:"" ) ) ){
				var subMembers = $getPresideObject( "crm_subscription_member" ).selectData(
					  filter            = { contact=record.id }
					, extraSelectFields = [ "subscription$grade.id as grade_id", "subscription$grade.label as grade_label", "subscription.valid_from", "subscription.valid_to", "subscription.subscription_status" ]
				);

				if( subMembers.recordCount && len( trim( subMembers.grade_label?:'' ) ) ){
					resultSet.grade_label[ index ]         = subMembers.grade_label;
					resultSet.valid_from[ index ]          = subMembers.valid_from;
					resultSet.valid_to[ index ]            = subMembers.valid_to;
					resultSet.subscription_status[ index ] = subMembers.subscription_status;
				}
			}

			if ( index % 1000 == 0 ) {
				_logger.info( "Validated 1000 records." );
			}
		} );
	}

	private void function _validateEngagementRecords( required query records, struct _logger=_buildLoggerProxy(), numeric subMembersCount=0 ){
		var numberOfRecords = arguments.records.recordCount;
		var subMembersCount = arguments.subMembersCount ?: 0;

		arguments._logger.info( "Validating #numberOfRecords# record#numberOfRecords > 1 ? "s" : ""#" );

		arguments.records.each( ( struct record, numeric index, query resultSet ) => {
			if ( len( trim( record.attendee_ids?:'' ) ) ) {
				var eventLabels = $getPresideObject( "ems_attendee" ).selectData(
					  selectFields = [ "ems_attendee.id", "ems_event.name as event_name", "ems_event.id as event_id" ]
					, filter       = { id=listToArray( record.attendee_ids ) }
				);
				resultSet.attendee_ids[ index ] = "";
				if( eventLabels.recordCount ){
					resultSet.attendee_ids[ index ] = valueList( eventLabels.event_name );
				}
			}

			if ( len( trim( record.booking_ids?:'' ) ) ) {
				var eventLabels = $getPresideObject( "ems_event_booking" ).selectData(
					  selectFields = [ "ems_event_booking.id", "ems_event.name as event_name", "ems_event.id as event_id" ]
					, filter       = { id=listToArray( record.booking_ids ) }
				);
				resultSet.booking_ids[ index ] = "";
				if( eventLabels.recordCount ){
					resultSet.booking_ids[ index ] = valueList( eventLabels.event_name );
				}
			}

			if( !len( trim( record.grade_label?:"" ) ) ){
				var subMembers = $getPresideObject( "crm_subscription_member" ).selectData(
					  filter            = { contact=record.id }
					, extraSelectFields = [ "subscription$grade.id as grade_id", "subscription$grade.label as grade_label", "subscription.valid_from", "subscription.valid_to", "subscription.subscription_status" ]
				);

				if( subMembers.recordCount && len( trim( subMembers.grade_label?:'' ) ) ){
					resultSet.grade_label[ index ]         = subMembers.grade_label;
					resultSet.valid_from[ index ]          = subMembers.valid_from;
					resultSet.valid_to[ index ]            = subMembers.valid_to;
					resultSet.subscription_status[ index ] = subMembers.subscription_status;
				}
			}

			resultSet.submembers_count[index] = subMembersCount;

			if ( index % 100 == 0 ) {
				_logger.info( "Validated 100 records." );
			}
		} );
	}

// GETTER & SETTER
	private any function _getDataExportService(){
		return _dataExportService;
	}
	private void function _setDataExportService( required any dataExportService ){
		_dataExportService = arguments.dataExportService;
	}

	private any function _getRulesEngineFilterService() {
		return _rulesEngineFilterService;
	}

	private void function _setRulesEngineFilterService( required any rulesEngineFilterService ) {
		_rulesEngineFilterService = arguments.rulesEngineFilterService;
	}


}