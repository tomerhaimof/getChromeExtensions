<#
    Get-ChromeExtensions will print out the names of all of the Chrome's extensions from all users (when run with admin permissions)
    You can also call the "checkURLs" argument (it will be called by default). this will do 2 things:
        1) Print all of the URLs which were found on all of the json,js,txt,html files.
        2) Check all of the above URLs against urlhaus database and will color malware URLs with red
    
    Written by Tomer Haimof
#>



function checkURLsFromFile
{
    Param($file,$urlCounter,$ipCounter,$allFilesURLs,$allFilesIPs)

    $IP_PATTERN="(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})`
                (?![\.0-9])|(2[0-4][0-9])(?![\.0-9])|(25[0-5])(?![\.0-9])))"

    $URL_PATTERN="(https?:\/\/(((([0-9a-zA-Z\-]?)*\.)+(com|net|org|gov|ac|ad|ae|af|ag|ai|al|am|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cu|cv|cw|`
                   cx|cy|cz|de|dj|dk|dm|do|dz|ec|ee|eg|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|`
                   ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|`
                   sb|sc|sd|se|sg|sh|si|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|za|zm|zw))|(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|`
                   25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\/?[^;^\*^\`"^\{^\}^'^\(^\)^ ^>^\s]*[;\`"\*\{\}' \(\)>]{0})"

    $SAFE_DOMAINS = ("youtube.com","google.com","wikipedia.org","w3.org","googleapis.com","mozilla.org","microsoft.com","jquery.com","custom-cursor.com","jquery.org")

    $SAFE_IPS = ("127.0.0.1")

    [System.Collections.ArrayList]$filteredURLs=@()
    [System.Collections.ArrayList]$filteredIPs=@()
    [System.Collections.ArrayList]$CheckedDomains=@()


    $content = Get-Content $file
    
    $ipsExtracted = $content | Select-String $IP_PATTERN -AllMatches
    $ips = $ipsExtracted.Matches.Value | sort -Unique
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
                $URLDomain = ($url).split("/")[2]
                if($CheckedDomains.contains($URLDomain))
                {
                    $urlCheck=New-Object psobject -Property @{url=$url;status=""}
                    [void]$filteredURLs.add($urlCheck)
                }

                elseif($domainSafe -ne $true)
                {
                    if ($urlCounter -eq 0){write-host `t`t`t "Checking URLs against urlhaus db (https://urlhaus.abuse.ch), this may take a moment"}
                    $urlCounter=$urlCounter+1
                    if((! $filteredURLs) -or ($filteredURLs."url".Contains($url) -eq $false))
                    {
                        $domainCheck=Invoke-RestMethod -Uri 'https://urlhaus-api.abuse.ch/v1/host/' -Method Post -Body @{host=$URLDomain}
                        if(($domainCheck.url_count -ge 1) -eq $false){[void]$CheckedDomains.Add($URLDomain)}
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

    if ($ips)
    {
        
        foreach ($ip in $ips)
        {
            if($allFilesIPs -notcontains $ip)
            {
                [void]$allFilesIPs.add($ip)
                $IPSafe=$false
                foreach ($s in $SAFE_IPS)
                {
                    if($ip -eq $s)
                    {
                        $IPSafe=$true
                        break
                    }
                }
                if($IPSafe -ne $true)
                {
                    if ($ipCounter -eq 0){write-host `t`t`t "Checking IP's against urlhaus db (https://urlhaus.abuse.ch), this may take a moment"}
                    $ipCounter=$ipCounter+1
                    if(! $filteredIPs)
                    {
                        $postParam=@{host=$ip}
                        $webResponse=Invoke-RestMethod -Uri 'https://urlhaus-api.abuse.ch/v1/host/' -Method Post -Body $postParam
                        if($webResponse.url_count -ge 1){$IPStatus="URL Found"} else{$IPStatus="OK"}
                        #$IPStatus=$webResponse.query_status
                        if($IPStatus -eq "URL Found" -and $bad -eq $false){$bad=$true}
                        $ipCheck=New-Object psobject -Property @{ip=$ip;status=$IPStatus}
                        [void]$filteredIPs.add($ipCheck)
                    }
                    elseif($filteredIPs."IP".Contains($IP) -eq $false)
                    {
                        $postParam=@{host=$ip}
                        $webResponse=Invoke-RestMethod -Uri 'https://urlhaus-api.abuse.ch/v1/host/' -Method Post -Body $postParam
                        if($webResponse.url_count -ge 1){$IPStatus="URL Found"} else{$IPStatus="Not Found"}
                        #$IPStatus=$webResponse.query_status
                        if($IPStatus -eq "URL Found" -and $bad -eq $false){$bad=$true}
                        $ipCheck=New-Object psobject -Property @{ip=$ip;status=$IPStatus}
                        [void]$filteredIPs.add($ipCheck)
                    }
                        
                }
            }
        }
    }

    return $filteredURLs,$filteredIPs,$bad,$urlCounter,$ipCounter

}

function checkExtensions
{
    Param($result,$folderName,$extensionID,$googleUrl,$headers,$files,$path,$checkURLs)
    
    [System.Collections.ArrayList]$urls=@()
    [System.Collections.ArrayList]$ips=@()
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
        [System.Collections.ArrayList]$allFilesIPs=@()

        if($checkURLs)
        {
           Write-Host `t`t "Checking '$name' extension's for urls" -ForegroundColor Yellow
           $urlCounter=0
           $ipCounter=0
           foreach ($file in $files)
            {
                $filteredURLs,$filteredIPs,$bad,$urlCounter,$ipCounter=checkURLsFromFile -file $file -urlCounter $urlCounter -ipCounter $ipCounter -allFilesURLs $allFilesURLs -allFilesIPs $allFilesIPs
                foreach($u in $filteredURLs){[void]$urls.add($u)}
                foreach($i in $filteredIPs){[void]$ips.add($i)}
            }
        }
        
        #$ips
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name=$name;urls=$urls;ips=$ips;bad=$bad})
        if($checkedExtensions.extension -notcontains $extensionID)
        {
            [void]$checkedExtensions.Add(@{folder=$folderName;extension=$extensionID;name=$name;urls=$urls;ips=$ips;bad=$bad})
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
    
    Param
    (
        [bool]$checkURLs=$true
    )

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
                                        $ip=$c.ips
                                        $na=$c.name
                                        $url=$c.urls
                                        $b=$c.bad
                                        [void]$results.add(@{folder=$f;extension=$e;name=$na;urls=$url;ips=$ip;bad=$b})
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
                                    write-host `t`t "URL: "  $url.url   -NoNewline ;Write-Host  "   STATUS: Malware Found in URL" -ForegroundColor Red;
                                }
                                else
                                {
                                    write-host `t`t "URL: "  $url.url  -NoNewline ;Write-Host  "   STATUS: OK" -ForegroundColor Green};
                                }                                
                            }
                            if($r.ips){foreach($ip in $r.ips)
                            {
                                if($ip."status" -eq "URL Found")
                                {
                                    write-host `t`t "IP: "  $ip.ip   -NoNewline ;Write-Host  "   STATUS: Malicious IP" -ForegroundColor Red;
                                }
                                else
                                {
                                    write-host `t`t "IP: "  $ip.ip  -NoNewline ;Write-Host  "   STATUS: OK" -ForegroundColor Green};
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
