$cores = ipcsv .\CoreSwitches.csv # Import a CSV of all CORE SWITCHES in the district
$user = 'admin'
$pass = 'password'
$ErrorActionPreference = 'SilentlyContinue'

# Download puTTY tools is necessary
if ( !(Get-ChildItem -ErrorAction SilentlyContinue plink.exe) )
{
    wget https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe
}
if ( !(Get-ChildItem -ErrorAction SilentlyContinue pscp.exe) )
{
    wget https://the.earth.li/~sgtatham/putty/latest/w64/pscp.exe
}

foreach ( $c in $cores )
{
    $coreName = $c.Name
    $coreIP = $c.IPAddress
    $site = $coreName
    $file = "$coreName.csv"
    $switchList = ipcsv $file

    Set-Content -Value "Name,IPAddress" -Path $file
    Add-Content -Value "$coreName,$coreIP" -Path $file

    $startCount = $true
    $endCount = $false

    # Loop through the switches until we find no more
    Do
    {
        $startCount = ($switchList | measure).Count
        foreach ( $s in $switchList )
        {
            #$s.Name # <-- For testing purposes
            $cdp  = (echo 'y' | .\plink.exe $user@$($s.IPAddress) -pw $pass "sh cdp nei det" | Out-String).Trim()
            $names = ($cdp | sls '(?<=Device ID: ).+' -AllMatches).Matches.Value.Trim()
            $addresses = ($cdp | sls '(?<=Entry.+\n  IP address: ).+' -AllMatches).Matches.Value.Trim()
            $i = 0

            foreach ( $n in $names )
            {
                If ( ($n -match "$([regex]::Escape($site))-(MDF|IDF)") -and ([bool]($switchList | ?{$_.Name -match $n}) -eq $false) )
                {
                    Add-Content -Value "$n,$($addresses[$i])" -Path $file
                }

                $i++
            }
        }
        $endCount = ($switchList | measure).Count
        #"$startCount -- $endCount" # <-- For testing purposes
    }
    Until ($startCount -eq $endCount)

    # Create dirs if needed
    If ( (Test-Path $site) -eq $false ) {mkdir $site}
    $date = Get-Date -Format yyyyMMddHH
    If ( (Test-Path "$site\$date") -eq $false ) {mkdir "$site\$date"}

    # Backup configs of found switches
    foreach ( $d in $switchList)
    {
        echo 'y' | .\pscp.exe -scp -pw $pass "$user@$($d.IPAddress):system:/running-config" "$site\$date\$($d.Name).txt"
    }

    # Remove configs over 30 days old
    Get-ChildItem $site | ?{$_.CreationTime -lt (Get-date).AddDays(-30)} | %{Remove-Item $_ -Recurse}
}
