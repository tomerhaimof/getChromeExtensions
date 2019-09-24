# This script will get all user's extensions ID's and query Google for its names.
# Eventually, it will print all the relevant information
# Written By Tomer Haimof


# This script will get all user's extensions ID's and query Google for its names.
# Eventually, it will print all the relevant information
# Written By Tomer Haimof


function checkExtensions
{
    Param($result,$folderName,$extensionID,$url,$headers)

    try{
    $response = Invoke-RestMethod -Uri "$url/$extensionID" -Method Get -Headers $headers
    $status=200}
    catch{
    $status=$_.Exception.Response.StatusCode.value__}

    if ($status -eq 200)
    {
        $name = [regex]::match($response,'title" content="(.*?)"').Groups[1].Value
        [void]$result.add(@{folder=$folderName;extension=$extensionID;name=$name})
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
        if(Test-Path "$baseDir\Local State"){
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
                            checkExtensions -result $results -folderName $f -extensionID $e -url $url -headers $headers
                        }
                        Write-Host "`nPrinting extensions for user $u\$username`:" -ForegroundColor Green
                        foreach ($r in $results)
                        {
                            Write-Host `t $r.folder ": " $r.extension ": " $r.name
                        }
                    }
            
                }
            }
          }
    }
}


