﻿properties {
    $BaseDirectory = Resolve-Path ..     
    $Nuget = "$BaseDirectory\Tools\NuGet.exe"
	$SlnFile = "$BaseDirectory\FluentAssertions.sln"
	$PackageDirectory = "$BaseDirectory\Package"
	$ApiKey = ""
    $BuildNumber = 9999
    $MsBuildLoggerPath = ""
	$Branch = ""
	$MsTestPath = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\MSTest.exe"
	$VsTestPath = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
}

task default -depends Clean, ApplyAssemblyVersioning, ApplyPackageVersioning, Compile, RunTests, BuildPackage, PublishToMyget

task Clean {	
    TeamCity-Block "Clean" {
		Get-ChildItem $PackageDirectory *.nupkg | ForEach { Remove-Item $_.FullName }
    }
}

task ApplyAssemblyVersioning {
    TeamCity-Block "Updating assembly version with build number $BuildNumber" {   
	
		$fullName = "$BaseDirectory\SolutionInfo.cs"

	    Set-ItemProperty -Path $fullName -Name IsReadOnly -Value $false

	    $content = Get-Content $fullName
	    $content = $content -replace '"(\d+)\.(\d+)\.(\d+)"', ('"$1.$2.' + $BuildNumber + '"')
	    Set-Content -Path $fullName $content
	}
}

task ApplyPackageVersioning {
    TeamCity-Block "Updating package version with build number $BuildNumber" {   
	
		$fullName = "$BaseDirectory\Package\.nuspec"

	    Set-ItemProperty -Path $fullName -Name IsReadOnly -Value $false

	    $content = Get-Content $fullName
	    $content = $content -replace '<version>(\d+)\.(\d+)\.(\d+)(.*)</version>', ('<version>$1.$2.' + $BuildNumber + '$4</version>')
	    Set-Content -Path $fullName $content
	}
}

task Compile {
    TeamCity-Block "Compiling" {  
       
        if ($MsBuildLoggerPath -ne "")
        {
            Write-Host "Using TeamCity MSBuild logger"
            $logger = "/logger:JetBrains.BuildServer.MSBuildLoggers.MSBuildLogger," + $MsBuildLoggerPath
        }
            
	    exec { msbuild /v:q /p:Platform="Any CPU" $SlnFile /p:Configuration=Release /t:Rebuild $logger}
    }
}

task RunTests {
	TeamCity-Block "Running unit tests" {
	
#        Run-MsTestWithTeamCityOutput `
#			"$MsTestPath"`
#			".NET 4.0"`
#			"$BaseDirectory\FluentAssertions.Net40.Specs\bin\Release\FluentAssertions.Net40.Specs.dll"`
#			"$BaseDirectory\Default.testsettings"
#
#		Run-MsTestWithTeamCityOutput `
#			"$MsTestPath"`
#			".NET 4.5"`
#			"$BaseDirectory\FluentAssertions.Net45.Specs\bin\Release\FluentAssertions.Net45.Specs.dll"`
#			"$BaseDirectory\Default.testsettings"
#
#		Run-MsTestWithTeamCityOutput `
#			"$MsTestPath"`
#			"PCL"`
#			"$BaseDirectory\FluentAssertions.Portable.Specs\bin\Release\FluentAssertions.Portable.Specs.dll"`
#			"$BaseDirectory\Default.testsettings"

		Run-VsTestWithTeamCityOutput `
			"$VsTestPath" `
			"WinRT" `
			"$BaseDirectory\FluentAssertions.WinRT.Specs\AppPackages\WinRT.Specs_1.1.0.0_AnyCPU_Test\WinRT.Specs_1.1.0.0_AnyCPU.appx" `
			"$BaseDirectory\Default.testsettings"
	}
}

task BuildPackage {
    TeamCity-Block "Building NuGet Package" {  
		& $Nuget pack "$PackageDirectory\.nuspec" -o "$PackageDirectory\" 
	}
}

task PublishToMyget -precondition { return ($Branch -eq "master" -or $Branch -eq "<default>") -and ($ApiKey -ne "") } {
    TeamCity-Block "Publishing NuGet Package to Myget" {  
		$packages = Get-ChildItem $PackageDirectory *.nupkg
		foreach ($package in $packages) {
			& $Nuget push $package.FullName $ApiKey -Source "https://www.myget.org/F/fluentassertions/api/v2/package"
		}
	}
}


