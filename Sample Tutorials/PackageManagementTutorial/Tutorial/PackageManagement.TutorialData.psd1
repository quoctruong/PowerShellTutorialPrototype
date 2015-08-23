@{
	"TutorialData" = @(
	,@{
		"instruction" = "Let's try to find the available packageprovider on this machine with Get-PackageProvider"
		"hints" = @{
			1 = "Run Get-PackageProvider without any arguments"
		}

		"answers" = @(
			"Get-PackageProvider"
		)
	}
	,@{
		"instruction" = "Let's try to bootstrap the packageprovider nuget on your machine with -ForceBootStrap"
		"hints" = @{
			1 = "Run Get-PackageProvider Nuget with ForceBootStrap option"
		}

        "verification" = "(Get-PackageProvider | Where-Object {`$_.Name -eq `"Nuget`"}).Count -ne 0"
	}
	,@{
		"instruction" = @"
Before installing a package with nuget provider, we need to register a package source.
Use Register-PackageSource to register http://www.nuget.org/api/v2/ for Nuget provider.
You can give a name to this package source with -name option
"@
		"hints" = @{
			1 = "Run Register-PackageSource with Nuget as ProviderName and Location as http://www.nuget.org/api/v2/"
		}

        "verification" = "(Get-PackageSource -ProviderName Nuget | Where-Object {`$_.Location.Contains(`"nuget.org/api/v2`")}).Count -ne 0"
	}    
	,@{
		"instruction" = @"
Now find the jquery package from nuget gallery with nuget provider and the source you just registered.
"@
		"hints" = @{
            1 = "Use Get-Command Find-Package -Syntax to see the syntax"
			3 = "Use Find-Package cmdlet with Source as nugetgallery and ProviderName as nuget"
		}

		"answers" = @(
			"Find-Package -Name jquery -ProviderName Nuget -Source http://www.nuget.org/api/v2/"
		)
	}
	,@{
		"instruction" = "Now let's try to install the jquery package with to directory C:\test with Install-Package"
		"hints" = @{
			1 = "Use Get-Command Install-Package -Syntax to see the syntax"
			3 = "Try Install-Package -Name jquery -ProviderName Nuget -Destination C:\test"
            "Install-package jquery -Providername nuget" = "Did you forget to specify destination?"
		}

		"verification" = "(Get-Package -ProviderName Nuget -Name jquery -Destination C:\test) -ne `$null"
	}
    ,@{
		"instruction" = "Now let's try to uninstall the jquery package in the directory C:\test with Uninstall-Package"
		"hints" = @{
			1 = "Use Get-Command Install-Package -Syntax to see the syntax"
			3 = "Try Install-Package -Name jquery -ProviderName Nuget -Destination C:\test"
            "Uninstall-package jquery -Providername nuget" = "Did you forget to specify destination?"
		}

		"verification" = "(Get-Package -ProviderName Nuget -Name jquery -Destination C:\test) -eq `$null"
    }

	)
}