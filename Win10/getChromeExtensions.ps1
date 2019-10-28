<#
    Get-ChromeExtensions will print out the names of all of the Chrome's extensions from all users (when run with admin permissions)
    You can also call the "checkURLs" argument. this will do 2 things:
        1) Print all of the URLs which were found on all of the json,js,txt,html files.
        2) Check all of the above URLs against urlhaus database and will color malware URLs with red
    
    Written by Tomer Haimof
#>



function checkURLsFromFile
{
    Param($file,$counter,$allFilesURLs)

    #$IP_PATTERN="(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})(?![\.0-9])|(2[0-4][0-9])(?![\.0-9])|(25[0-5])(?![\.0-9])))"
    $URL_PATTERN="(https?:\/\/(((([0-9a-zA-Z\-]?)*\.)+(com|il|net|io|me|org|nl|cz|br|gov|il|ru|ir|ch|af|ax|al|dz|as|ad))|(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\/?[^;^\*^\`"^\{^\}^'^\(^\)^ ^>^\s]*[;\`"\*\{\}' \(\)>]{0})"
    $SAFE_DOMAINS = ("youtube.com","google.com","wikipedia.org","w3.org","googleapis.com","mozilla.org","microsoft.com","jquery.com","custom-cursor.com","jquery.org")

    [System.Collections.ArrayList]$filteredURLs=@()

    $content = Get-Content $file
    
    $urlsExtracted = $content | Select-String $URL_PATTERN -AllMatches
    $urls=$urlsExtracted.Matches.Value | sort -Unique
    #foreach ($url in $urls){if ($allFilesURLs -notcontains $url){$allFilesURLs.add($url)}}
    if ($urls)
    {
        
        foreach ($url in $urls)
        {
            if($allFilesURLs -notcontains $url)
            {
                [void]$allFilesURLs.add($url)
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
                    if ($counter -eq 0){write-host `t`t`t "Checking URLs against urlhaus db (https://urlhaus.abuse.ch), this may take a moment"}
                    $counter=$counter+1
                    if(! $filteredURLs)
                    {
                        $postParam=@{url=$url}
                        $webResponse=Invoke-RestMethod -Uri 'https://urlhaus-api.abuse.ch/v1/url/' -Method Post -Body $postParam
                        $urlStatus=$webResponse.query_status
                        $urlCheck=New-Object psobject -Property @{url=$url;status=$urlStatus}
                        [void]$filteredURLs.add($urlCheck)
                    }
                    elseif($filteredURLs."url".Contains($url) -eq $false)
                    {
                        $postParam=@{url=$url}
                        $webResponse=Invoke-RestMethod -Uri 'https://urlhaus-api.abuse.ch/v1/url/' -Method Post -Body $postParam
                        $urlStatus=$webResponse.query_status
                        if($urlStatus -eq "ok" -and $bad -eq $false){$bad=$true}
                        $urlCheck=New-Object psobject -Property @{url=$url;status=$urlStatus}
                        [void]$filteredURLs.add($urlCheck)
                    }
                        
                }
            }
        }
    }

    return $filteredURLs,$bad,$counter

}

function checkExtensions
{
    Param($result,$folderName,$extensionID,$googleUrl,$headers,$files,$path,$checkURLs)
    
    [System.Collections.ArrayList]$urls=@()
    $bad=$false
    try{
    $response = Invoke-RestMethod -Uri "$googleUrl/$extensionID" -Method Get -Headers $headers
    $status=200}
    catch{$status=$_.Exception.Response.StatusCode.value__}
 
    if ($status -eq 200)
    {
        $name = [regex]::match($response,'title" content="(.*?)"').Groups[1].Value
        $files=Get-ChildItem -Path $path -Recurse -File -Include *.js,*.html,*.json,*.txt
        [System.Collections.ArrayList]$allFilesURLs=@()

        if($checkURLs)
        {
           Write-Host `t`t "Checking '$name' extension's for urls" -ForegroundColor Yellow
           $counter=0
           foreach ($file in $files)
            {
                $filteredURLs,$bad,$counter=checkURLsFromFile -file $file -counter $counter -allFilesURLs $allFilesURLs
                foreach($u in $filteredURLs){[void]$urls.add($u)}
            }
        }
        
        #$ips
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name=$name;urls=$urls;bad=$bad})
        if($checkedExtensions.extension -notcontains $extensionID)
        {
            [void]$checkedExtensions.Add(@{folder=$folderName;extension=$extensionID;name=$name;urls=$urls;bad=$bad})
        }
    }

    elseif($status -eq 404 -and $excludes.contains($extensionID) -eq $false)
    {
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name="UNKNOWN"})
        if($checkedExtensions.extension -notcontains $extensionID)
        {
            [void]$checkedExtensions.Add(@{folder=$folderName;extension=$extensionID;name="UNKNOWN"})
        }
    }
    else
    {
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name="ERROR"})
        if($checkedExtensions.extension -notcontains $extensionID)
        {
            [void]$checkedExtensions.Add(@{folder=$folderName;extension=$extensionID;name="ERROR"})
        }
    } 
}

 
function Get-ChromeExtensions
{

    Param([switch]$checkURLs)

    $googleUrl = "https://chrome.google.com/webstore/detail"
    $headers=@{"accept-language"="en-US,en;q=0.9"}
    $excludes="nmmhkkegccagdldgiimedpiccmgmieda","pkedcjkdefgpdelpbcmbmeomcjbeemfm"
    $users=(Get-ChildItem c:\users -Directory).Name
    [System.Collections.ArrayList]$checkedExtensions=@()

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
                    if(Test-Path "$baseDir\$f\Extensions")
                    {
                        $username=$jsonData.profile.info_cache.$f.name
                        
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
                            if($e -eq "Temp"){break}
                            if($checkedExtensions.extension -contains $e)
                            {
                                foreach($c in $checkedExtensions)
                                {
                                    if($c.extension -eq $e)
                                    {
                                        $na=$c.name
                                        $url=$c.urls
                                        $b=$c.bad
                                        [void]$results.add(@{folder=$f;extension=$e;name=$na;urls=$url;bad=$b})
                                        continue
                                    }
                                }
                                    
                                continue
                            }
                            $path="$baseDir\$f\Extensions\$e"
                            [System.Collections.ArrayList]$files=@()
                            #[System.Collections.ArrayList]$ips=@()
                            
                            checkExtensions -result $results -folderName $f -extensionID $e  -headers $headers -files $files -googleUrl $googleUrl -path $path -checkURLs $checkURLs 
                        }
                        Write-Host "`nPrinting extensions for user $u\$username`:" -BackgroundColor Blue
                        
                        foreach ($r in $results)
                        {
                            if ($r.bad -eq $true){Write-Host `t $r.folder ": " $r.extension ": " $r.name -ForegroundColor Red}
                            else{Write-Host `t $r.folder ": " $r.extension ": " $r.name -ForegroundColor Green}
                            if($r.urls){foreach($url in $r.urls)
                            {
                                if($url."status" -eq "ok")
                                {
                                    write-host `t`t "URL: "  $url.url   -NoNewline ;Write-Host  "   STATUS: Malware Found" -ForegroundColor Red;
                                }
                                else
                                {
                                    write-host `t`t "URL: "  $url.url  -NoNewline ;Write-Host  "   STATUS: OK" -ForegroundColor Green};
                                }
                                Write-Host
                            }
                            #if($r.ips){foreach($i in $r.ips){write-host `t`t $i};}
                            
                        }

                        Write-Host "`t************************************************" -ForegroundColor White
                        Write-Host
                        
                               
                    }
                }
            }
        }
    }
}
