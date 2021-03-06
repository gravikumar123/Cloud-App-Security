﻿<#
.Synopsis
   Gets all General, Security, and Compliance info for a provided app ID.

.DESCRIPTION
    By passing in an App Id, the user can retrive information about those apps straight from the SaaS DB. This information is returned in an object format that can be formatted for the user's needs.

.EXAMPLE
    Get-MCASAppInfo -AppId 11114 | select name, category

    name       category
    ----       --------
    Salesforce SAASDB_CATEGORY_CRM

.EXAMPLE
    Get-MCASAppInfo -AppId 18394 | select name, @{N='Compliance';E={"{0:N0}" -f $_.revised_score.compliance}}, @{N='Security';E={"{0:N0}" -f $_.revised_score.security}}, @{N='Provider';E={"{0:N0}" -f $_.revised_score.provider}}, @{N='Total';E={"{0:N0}" -f $_.revised_score.total}} | ft

    name        Compliance Security Provider Total
    ----        ---------- -------- -------- -----
    Blue Coat   4          8        6        6

    This example creates a table with just the app name and high level scores.

.FUNCTIONALITY
       Get-MCASAppInfo is designed to query the saasdb one service at a time, not in bulk fashion.
#>
function Get-MCASAppInfo
{
    [CmdletBinding()]
    [Alias('Get-CASAppInfo')]
    Param
    (
        # Specifies the URL of your CAS tenant, for example 'contoso.portal.cloudappsecurity.com'.
        [Parameter(Mandatory=$false)]
        [ValidateScript({(($_.StartsWith('https://') -eq $false) -and ($_.EndsWith('.adallom.com') -or $_.EndsWith('.cloudappsecurity.com')))})]
        [string]$TenantUri,

        # Specifies the CAS credential object containing the 64-character hexadecimal OAuth token used for authentication and authorization to the CAS tenant.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]$Credential,

        # Specifies the maximum number of results to retrieve when listing items matching the specified filter criteria.
        [Parameter(ParameterSetName='List', Mandatory=$false)]
        [ValidateRange(1,100)]
        [int]$ResultSetSize = 100,

        # Specifies the number of records, from the beginning of the result set, to skip.
        [Parameter(ParameterSetName='List', Mandatory=$false)]
        [ValidateScript({$_ -gt -1})]
        [int]$Skip = 0,

        # Limits the results to items related to the specified service IDs, such as 11161,11770 (for Office 365 and Google Apps, respectively).
        [Parameter(ParameterSetName='List', Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d{5}$')]
        [Alias("Service","Services")]
        [int[]]$AppId
    )
    Begin {
        Try {$TenantUri = Select-MCASTenantUri}
            Catch {Throw $_}

        Try {$Token = Select-MCASToken}
            Catch {Throw $_}

        $AppIdList = @()
    }
    Process {
        $AppIdList += $AppId
    }
    End {
        $Body = @{'skip'=$Skip;'limit'=$ResultSetSize} # Base request body
        
        $FilterSet = @() # Filter set array

        # Simple filters
        If ($AppIdList.Count -gt 0) {$FilterSet += @{'appId'= @{'eq'=$AppIdList}}}

        # Get the matching alerts and handle errors
        Try {
            $Response = Invoke-MCASRestMethod2 -Uri "https://$TenantUri/api/v1/saasdb/" -Method Post -Body $Body -Token $Token -FilterSet $FilterSet
            
        }
        Catch {
            Throw $_  #Exception handling is in Invoke-MCASRestMethod, so here we just want to throw it back up the call stack, with no additional logic
        }

        # Get the response parts and format we need
        $Response = $Response.content

        $Response = $Response | ConvertFrom-Json

        $Response = Invoke-MCASResponseHandling -Response $Response -IdentityProperty 'appId'

        $Response
    }
}
