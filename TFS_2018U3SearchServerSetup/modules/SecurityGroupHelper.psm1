Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\Constants.psm1 -Force

function GrantPermissions
{
    [CmdletBinding()]
    Param
    (
        [string]$folder,
        [string]$rights,
        [string]$user
    )

    if (-not (Test-Path $folder))
    {
        LogError "$folder does not exists"
        return
    }

    $permissions = ":(OI)(CI)$rights"

    LogVerbose "Setting Permissions: $rights on $folder for user: $user"
    Invoke-Expression -Command ('icacls $folder /grant:r "${user}${permissions}"')
}

function CreateSecurityGroup
{
    [CmdletBinding()]
    Param
    (
        [string]$securityGroupName,
        [string]$securityGroupDescription
    )
    $ComputerName = $env:ComputerName 
    $conn = [ADSI]"WinNT://$ComputerName"
    $group = $conn.Create("Group",$securityGroupName)
    $group.Setinfo()
    $group.description = $securityGroupDescription
    $group.SetInfo()
}

function SecurityGroupExists
{
    [CmdletBinding()]
    Param
    (
        [string]$securityGroupName
    )
    
    $ComputerName = $env:ComputerName
    return [ADSI]::Exists("WinNT://$ComputerName/$securityGroupName")
}

function AddUserToSecurityGroup
{
    [CmdletBinding()]
    Param
    (
        [string]$securityGroupName,
        [string]$domain,
        [string]$username
    )
    $ComputerName = $env:ComputerName
    $securityGroup = [ADSI]"WinNT://$ComputerName/$securityGroupName,group"
    $securityGroup.Invoke('Add', "WinNT://$domain/$username,user")
}

function GetLocalGroupMembers
{
    [CmdletBinding()]
    param
    (
        [string]$GroupName
    )
    
    $ComputerName = $env:ComputerName

    # Initialize an array to hold the results of our query.
    $arr = @()

    $wmi = Get-WmiObject -ComputerName $ComputerName -Query `
    "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`""

    # Parse out the username from each result and append it to the array.
    if ($wmi -ne $null)
    {
        foreach ($item in $wmi)
        {
            $arr += ($item.PartComponent.Substring($item.PartComponent.IndexOf(',') + 1).Replace('Name=', '').Replace("`"", ''))
        }
    }

    return $arr
}

function GetNetworkServiceAccount
{
    try
    {
        $networkServiceAccount = (New-Object System.Security.Principal.SecurityIdentifier $SecurityConstants.DefaultServiceAccountSID).Translate([System.Security.Principal.NTAccount]).Value

        if ($networkServiceAccount -ne $null)
        {
            #Validate the account format
            $domainAndUserNamesArray = GetDomainAndUserFromAccount $networkServiceAccount
            if ($domainAndUserNamesArray.Length -ne 2)
            {
                LogWarning "Fetched NetworkService account not in down-level logon name (DOMAIN\UserName) format"
            }
            else
            {
                return $networkServiceAccount
            }
        }
        else
        {
            LogWarning "Failed to query NetworkService account (SID: S-1-5-20)"
        }
    }    
    catch
    {
        LogWarning "Exception occured while querying for NetworkService account (SID: S-1-5-20)"
        LogWarning $_.Exception.Message
    }

    LogWarning "Defaulting to NT Authority\NETWORK SERVICE as NetworkService account (SID: S-1-5-20)" 
    return $SecurityConstants.DefaultServiceAccountFull
}

function GetDomainAndUserFromAccount
{
    [CmdletBinding()]
    param
    (
        [string]$AccountName
    )

    $separator = "\" # accountName is in standard "down-level logon name" format of DOMAIN\UserName
    $option = [System.StringSplitOptions]::None

    $domainAndUserNamesArray =  $AccountName.Split($separator, $option)
    return $domainAndUserNamesArray
}

Export-ModuleMember -Function GrantPermissions, CreateSecurityGroup, SecurityGroupExists, AddUserToSecurityGroup, GetLocalGroupMembers, GetNetworkServiceAccount, GetDomainAndUserFromAccount
# SIG # Begin signature block
# MIIkSQYJKoZIhvcNAQcCoIIkOjCCJDYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBTaioyhnxa0WYm
# 8JakOxDM7vjxwFcsj34JG9IFYVepoKCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWHjCCFhoCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgPMoCoOG8
# cbuhgNYjsMk5mEX6RIkVUlI9IFuuME7VcBYwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBAH1SwQaqMh5mRhC7jHhT/1/BXGQwdH3pLqZhGWsuQ
# LwhBQOUSDBb/+cozZE1C4Icqr0M7lAVrZ6Dj9PHaWPDNsHaWuoUfSyo5V/miQnnh
# exnWUyy1PkPiOUFcr9hfnX3o2NElbR75VzteYlF/3fHISij8oXaZ24Wx2CogE3UI
# xbbBi1BP0RdUJfauh6M3JDVjtsSj7K43hHWuxqeoZCpkf0L0UzKLeiGjeZPWkGMk
# z2IeRdoF0x4NfY4PkCg9FwNooezK9V+kdbR/U2BGj/PHGyXd/9VhhBNvsIiueoXx
# 1zDbBGEFB59ION0tXhbdc06iC+r3C+oPyjRmI2G6fs4soYITqDCCE6QGCisGAQQB
# gjcDAwExghOUMIITkAYJKoZIhvcNAQcCoIITgTCCE30CAQMxDzANBglghkgBZQME
# AgEFADCCAVMGCyqGSIb3DQEJEAEEoIIBQgSCAT4wggE6AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIFxDG9wGubqjupOvZFkoVwjJSpl+AsMZl5umSNAJ
# dyvtAgZbzehAL08YEjIwMTgxMDI0MjMzNDE3LjgyWjAHAgEBgAIB9KCB0KSBzTCB
# yjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRT
# UyBFU046RjZGRi0yREE3LUJCNzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2Wggg8VMIIGcTCCBFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG
# 9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEy
# MDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIw
# MTAwHhcNMTAwNzAxMjEzNjU1WhcNMjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AKkdDbx3EYo6IOz8E5f1+n9plGt0VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vw
# FVMnBDEfQRsalR3OCROOfGEwWbEwRA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNF
# DdDq9UeBzb8kYDJYYEbyWEeGMoQedGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC7
# 32H8RsEnHSRnEnIaIYqvS2SJUGKxXf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOW
# RH7v0Ev9buWayrGo8noqCjHw2k4GkbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJ
# k3jN/LzAyURdXhacAQVPIk0CAwEAAaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEA
# MB0GA1UdDgQWBBTVYzpcijGQ80N7fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4K
# AFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSME
# GDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRw
# Oi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJB
# dXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8y
# MDEwLTA2LTIzLmNydDCBoAYDVR0gAQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEw
# PQYIKwYBBQUHAgEWMWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9D
# UFMvZGVmYXVsdC5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABv
# AGwAaQBjAHkAXwBTAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQAD
# ggIBAAfmiFEN4sbgmD+BcQM9naOhIW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/1
# 5/B4vceoniXj+bzta1RXCCtRgkQS+7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRW
# S3TvQhDIr79/xn/yN31aPxzymXlKkVIArzgPF/UveYFl2am1a+THzvbKegBvSzBE
# JCI8z+0DpZaPWSm8tv0E4XCfMkon/VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/
# 3cVKC5Em4jnsGUpxY517IW3DnKOiPPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9
# nhquBEKDuLWAmyI4ILUl5WTs9/S/fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5H
# moDF0M2n0O99g/DhO3EJ3110mCIIYdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv3
# 3nJ+YWtvd6mBy6cJrDm77MbL2IK0cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI
# 5pgt6o3gMy4SKfXAL1QnIffIrE7aKLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0
# MkvfY3v1mYovG8chr1m1rtxEPJdQcdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0e
# GTgvvM9YBS7vDaBQNdrvCScc1bN+NR4Iuto229Nfj950iEkSMIIE8TCCA9mgAwIB
# AgITMwAAAONDM5qwOcX41wAAAAAA4zANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0xODA4MjMyMDI3MDhaFw0xOTExMjMyMDI3
# MDhaMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFs
# ZXMgVFNTIEVTTjpGNkZGLTJEQTctQkI3NTElMCMGA1UEAxMcTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgU2VydmljZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AIxUo3ubLCdcum52aMce/e7yGcEk0azv9VJfPKZqlG5hqPhcj+Nb88gCpbgWiggo
# wmxCrj3WlfgkNHKW74bb3pC4ptr1VeBWrLWmIanPLqtjBEaPvvb5twmbpnVjMoI8
# I5eYsHlmZyYXqyK+EG5iY4jVYSrLsPMjZJAfQGpuGLlvWoy9Sp5mC/47yhoqRHob
# NZu/KzHGJGZx4NaI55RlvTO/fDUpWXwvoS0/7XCqX8sOw+Lp8JIHZl/Wgn9oVWiO
# ECh8yPDgJ0uZWSjW/8bnLFo0m+Ka19OTMXKXsvbsZEAsqp/lDM0+Dzl36CF85Fhu
# QFn421mk9wX3y2mVlEAac6sCAwEAAaOCARswggEXMB0GA1UdDgQWBBQgmwrJOQs+
# Xb2PMGQ4V2YRdsIS0jAfBgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBW
# BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUH
# AQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# L2NlcnRzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQBOkUM88Dnr
# q8/4TnX3DD5auTYuqUZnLTl8nn26V8urGT763Gc4suHgQf8XNye6S7nPHQvfJzZn
# z/YIco5sYmedLxrEqrmhRupYWFsv6mKBG2xds4fwzgLlT8uFnSCr+iJv9QWXHOL5
# fqqJn39TYOaxlcR36mtPndgz8E2XIPIOKxxnu0ZefwoIEMdjm8ksro/4PdsXh6wq
# WYo924fj6DSZv5QpR2EJOGALHyoUSE9TP0jFx+4ilKaaSs2E1o9AO0ZmOCOI4jT2
# a/mMuaWomCheEiGOVxmyN9JJX6ISxoEr1o3BbPZzxAyXKsQjJv4xw0xT06oQm/Uk
# RSpHjAHnUmhgoYIDpzCCAo8CAQEwgfqhgdCkgc0wgcoxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkY2RkYtMkRBNy1C
# Qjc1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiUKAQEw
# CQYFKw4DAhoFAAMVAMk0I+cBXO+J5X7L1K8c+khXauL7oIHaMIHXpIHUMIHRMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uQ2lwaGVyIE5UUyBF
# U046MjY2NS00QzNGLUM1REUxKzApBgNVBAMTIk1pY3Jvc29mdCBUaW1lIFNvdXJj
# ZSBNYXN0ZXIgQ2xvY2swDQYJKoZIhvcNAQEFBQACBQDfe2NXMCIYDzIwMTgxMDI0
# MjEzMjA3WhgPMjAxODEwMjUyMTMyMDdaMHYwPAYKKwYBBAGEWQoEATEuMCwwCgIF
# AN97Y1cCAQAwCQIBAAIBCQIB/zAHAgEAAgIYTDAKAgUA33y01wIBADA2BgorBgEE
# AYRZCgQCMSgwJjAMBgorBgEEAYRZCgMBoAowCAIBAAIDFuNgoQowCAIBAAIDB6Eg
# MA0GCSqGSIb3DQEBBQUAA4IBAQBwiLcUxg3xPpct9UfQPlG+2TKnb0wCjxie3bUk
# fB8cwv9+X1nL+T9gW0JMAiye0G2uSY4EWEwEiuXSRgZw4u2PvFp2ug81ljTS6HA5
# 664kvIZPZY8348VfsJk+Bcasbh9HlOQzgs2MMC90Usd4oPmdZ/4u8XhN8kQwiymc
# r6Lk+vFo98+jZ7XXo5JgvVLf3ms2+GOH35QmKwj1tq4UhxSiMdp3Gu0RfDQvbldZ
# YxEKYX3CnXbZORVY9nKVwB2kwYwicrlXBpe6DtRYVlUqijh+Ytez4Eoj2KD/ajh7
# vSznIU0+AUOIPacD8s/gF7YLStaT6A3ZYITZDhTBxX9nSjcWMYIC9TCCAvECAQEw
# gZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAADjQzOasDnF+NcA
# AAAAAOMwDQYJYIZIAWUDBAIBBQCgggEyMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0B
# CRABBDAvBgkqhkiG9w0BCQQxIgQgqeALsdjkaH8T+pbtLyqzgQLzaLwmCMEfAhzL
# SCOM8ZMwgeIGCyqGSIb3DQEJEAIMMYHSMIHPMIHMMIGxBBTJNCPnAVzvieV+y9Sv
# HPpIV2ri+zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMz
# AAAA40MzmrA5xfjXAAAAAADjMBYEFItBWy8NvjD5l0tOw1tO/Y4jlM9/MA0GCSqG
# SIb3DQEBCwUABIIBAD5bdkL1VExSnLYfpNUr2tt5eUObCGyU3oyNABatjyOKa6Zq
# QN8U/3KWqPMCHKzrrusFfuEIBSaFpbU3r3SQEadxatbOgu89PsXGY4ZYOBDpBx5R
# 9sjGBfhVA0Cz2G0zaH57ZcxosoNT69jglk0UHmY8AHqXtuA20eWF0rujNFgfKBQD
# lazS0acZM9Bktowl6IZLNuhaTWkQoRS2IMgPa8zZv3K8RDikHBNDTp6UtT2WpGU6
# FJETO78r8M7PQRZzhnDLlRFINsW3miy99GfjV5yPzcuYBf37rYdsSbVnp/GLvsvn
# P4dex4jQMQHXEGCBkct0DnwIkitH/f39whFGXQM=
# SIG # End signature block
