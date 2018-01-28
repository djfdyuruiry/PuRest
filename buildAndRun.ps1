function GetProcessesUsingPortsOnWindows
{
    $processes = @((netstat -o -n -a | findstr ":8888"), `
        (netstat -o -n -a | findstr ":4430"))   

    $pids = @()

    if ($processes.Length -gt 0)
    {
        foreach ($process in $processes)
        {
            $columns = $process -split "\s+"
            $pids += $columns[-1]
        }
    }

    ,$pids
}

function KillProcessesUsingServerPorts
{
    $pidsUsingPorts

    if ($PSVersionTable.Platform -and ($PSVersionTable.Platform -eq "Unix"))
    {
        $pidsUsingPorts += lsof -ti tcp:8888
        $pidsUsingPorts += lsof -ti tcp:4430
    }
    else
    {
        $pidsUsingPorts = GetProcessesUsingPortsOnWindows
    }

    foreach ($pidUsingPort in $pidsUsingPorts)
    {
        Write-Host "Killing process with id $pidUsingPort currently using port 8888/4430"
        Stop-Process -Id $pidUsingPort -Force
    }
}

function Main
{        
    & "$PSScriptRoot/scripts/buildServerAndDeployWebApps.ps1"

    KillProcessesUsingServerPorts

    & "$PSScriptRoot/build/release/startServer.ps1"
}

Main
