# This script will get all user's extensions ID's and query Google for its names.
# It will also extract all of the URLs and IPs inside JS,HTML,JSON and TXT files within Extension's files.
# Eventually, it will print all the relevant information
# Written By Tomer Haimof
 
$IP_PATTERN="(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})(?![\.0-9])|(2[0-4][0-9])(?![\.0-9])|(25[0-5])(?![\.0-9])))"
$URL_PATTERN="(https?:\/\/(([0-9a-zA-Z\-]?)*\.)+(com|il|net|io|me|org|nl|cz|br|gov|il|ru|ir)\/?[^\*^\`"^\{^\}^'^\(^\)^ ^>^\s]*[\`"\*\{\}' \(\)>]{0})"
$SAFE_DOMAINS = ("youtube.com","google.com","wikipedia.org","w3.org","googleapis.com","mozilla.org","microsoft.com","jquery.com","custom-cursor.com","jquery.org")

function checkExtensions
{
    Param($result,$folderName,$extensionID,$url,$headers,$files,$ips,$urls,$filteredURLs,$path)
 
    try{
    $response = Invoke-RestMethod -Uri "$url/$extensionID" -Method Get -Headers $headers
    $status=200}
    catch{$status=$_.Exception.Response.StatusCode.value__}
 
    if ($status -eq 200)
    {
        $name = [regex]::match($response,'title" content="(.*?)"').Groups[1].Value
        $files=Get-ChildItem -Path $path -Recurse -Include *.js,*.html,*.json,*.txt

        foreach ($file in $files)
        {
            $content = Get-Content $file
            $ipsExtracted = $content | Select-String $IP_PATTERN -AllMatches
            $ips=$ipsExtracted.Matches.Value | sort -Unique
            $urlsExtracted = $content | Select-String $URL_PATTERN -AllMatches
            $urls=$urlsExtracted.Matches.Value | sort -Unique
            if ($urls)
            {
                foreach ($url in $urls)
                {
                    $domainSafe=$false
                    foreach ($s in $SAFE_DOMAINS)
                    {
                        $pattern="(https?:\/\/(([a-zA-Z0-9\-]*\.)*)?$s\/?.*)"
                        if($url | Select-String $pattern)
                        {
                            $domainSafe=$true
                            break
                        }
                    }
                    if($domainSafe -ne $true)
                    {
                        [void]$filteredURLs.add($url)
                    }
                }
            }
        }
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name=$name;urls=$filteredURLs;ips=$ips})
    }

    elseif($status -eq 404 -and $excludes.contains($extensionID) -eq $false)
    {
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name="UNKNOWN"})
    }
    else
    {
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name="ERROR"})
    } 
}

 
$url = "https://chrome.google.com/webstore/detail"
$headers=@{"accept-language"="en-US,en;q=0.9"}
$excludes="nmmhkkegccagdldgiimedpiccmgmieda","pkedcjkdefgpdelpbcmbmeomcjbeemfm"
$users=(Get-ChildItem c:\users -Directory).Name


foreach ($u in $users)
{
    if($u -ne "Public")
    {
        $baseDir = "C:\Users\$u\AppData\Local\Google\Chrome\User Data"
        if(Test-Path "$baseDir\Local State")
        {
            $jsonData = Get-Content -Raw -Path "$baseDir\Local State" | ConvertFrom-Json
            $folders=(Get-ChildItem "$baseDir" -Directory).Name
            foreach ($f in $folders)
            {
                if($f -eq "Default" -or $f.startsWith("Profile "))
                {
                    $username=$jsonData.profile.info_cache.$f.name
                    if (Test-Path "$baseDir\$f\Extensions")
                    {
                        [System.Collections.ArrayList]$extensionsID=(Get-ChildItem "$baseDir\$f\Extensions").Name
                        foreach($e in $excludes)
                        {
                            if($extensionsID.Contains($e))
                            {
                                [void]$extensionsID.Remove($e)
                            }
                        }
                        [System.Collections.ArrayList]$results=@()
                        foreach($e in $extensionsID)
                        {
                            $path="$baseDir\$f\Extensions\$e"
                            [System.Collections.ArrayList]$files=@()
                            [System.Collections.ArrayList]$ips=@()
                            [System.Collections.ArrayList]$urls=@()
                            [System.Collections.ArrayList]$filteredURLs=@()
                            checkExtensions -result $results -folderName $f -extensionID $e -url $url -headers $headers -files $files `
                            -ips $ips -urls $url -filteredURLs $filteredURLs -path $path
                        }
                        Write-Host "`nPrinting extensions for user $u\$username`:" -ForegroundColor Green
                        foreach ($r in $results)
                        {
                            Write-Host `t $r.folder ": " $r.extension ": " $r.name
                            if($r.urls){foreach($u in $r.urls){write-host `t`t $u};write-host}
                            if($r.ips){foreach($i in $r.ips){write-host `t`t $i};write-host}
                            
                        }
                    }         
                }
            }
        }
    }
}
