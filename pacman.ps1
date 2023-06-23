<#
.SYNOPSIS
    PACMAN is to compress (zip) and|or remove files older than N days from today.
    https://github.com/itkibo/pacman

.DESCRIPTION
    This script performs tasks from configuration file (json)
    to compress and|or delete files older than a certain number of days.

    It works in two modes: 
        > bundle - process all files all together (default mode)
        > single - process each file one by one for large size files

    Config file contains array of dictionaries.
    Each element of the array is a task.
    Script processes tasks in same order as in config.
    If a critical error occured while checking parameters or performing task, the script stops and exit.

.NOTES
    Parameters:
        > path, ext, days are mandatory
        > arc=true, del=true, single=false (if not explicitly specified)

    Start point of datetime for calculating "old files" is {today date 00:00:00}
    It means if days=0, script processes all files with dt < {today date 00:00:00}

    Result archive file has naming patterns:
        > bundle: "{yyyyMMdd_hhmmss}_{filescountinbundle}.zip"
        > single: "{yyyyMMdd_hhmmss}_{sourcefilename}.zip"
        
.EXAMPLE
    Config file content example (json):    
    [
        {
            "path":  ".\\log",
            "ext":  "log",
            "days":  31,
            "comment":  "this is minimal config: arc=true, del=true, single=false by default"
        },
        {
            "arc":  true,
            "path":  ".\\log",
            "del":  true,
            "ext":  "log",
            "days":  31,
            "single":  true,
            "comment":  "single mode (compress files older than 31 days + remove source files) one by one"
        }
    ]
#>


[CmdletBinding()]
param(
    [string]$config_path = ".\config.txt",  # default external config file
    [string]$err_path = ".\err.txt"         # default error log file
)


function validate_params {
    [CmdletBinding()]
    param(
        [string]$path,              # folder where files to process are located
        [string]$ext,               # filter files by extension
        [string]$days,              # get files older than N days
        [bool]$arc = $true,         # compressing enabled
        [bool]$del = $true,         # removing enabled
        [bool]$single = $false,     # compress each file separately
        [string]$comment            # comment for a task
    )

    
    # parameters should be not empty + not null + not spaces
    foreach ($arg in @($path, $ext, $days)) {
        if ($arg -match "^\s*$") { 
            Write-Error "incorrect external config values"
            return $false
        }
    }
    
    # days are integer >=0
    if (!($days -match "^\d+$") -or !([int]$days -ge 0)) { 
        Write-Error "wrong days value"
        return $false
    }

    # check file extension format
    if (-not($ext -match "^\w{1,4}$")) { 
        Write-Error "wrong file extension"
        return $false 
    }

    # check path exists
    if (!(Test-Path -Path $path -PathType Container)) { 
        Write-Error "path $path not exists"
        return $false 
    }

    return $true

} # end validate_params


function compress_bundle {
    <#
        compress all files into one archive and|or delete files
        returns path to archive if success
    #>
    param(
        $files,         # source files
        [string]$path   # archive destination folder
    )


    $arc_path = "{0}\{1}_{2}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_hhmmss'), $files.count

    try {
        $files | Compress-Archive -DestinationPath $arc_path -CompressionLevel Fastest
    } catch {
        return $false
    }
    
    if (Test-Path -Path $arc_path -PathType Leaf) {
        return $arc_path
    } else {
        return $false
    }

}  # end compress_bundle


function compress_or_remove_single {
    <#
        compress and|or delete each file separately
        returns true if no errors
    #>
    param(
        $files,         # source files
        [string]$path,  # archive destination folder 
        [bool]$arc,     # compress files
        [bool]$del      # delete files
    )


    foreach ($one_file in $files) {

        $arc_path = "{0}\{1}_{2}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_hhmmss'), $one_file.Name

        if ($arc -eq $true) {
            try {
                $one_file | Compress-Archive -DestinationPath $arc_path -CompressionLevel Fastest
            } catch {
                return $false
            }

            if (-not(Test-Path -Path $arc_path -PathType Leaf)) { return $false }
        }

        if ($del -eq $true) {
            try {
                $one_file | Remove-Item
            } catch {
                return $false
            }
        }
        
    }  # end foreach

    return $true

}  # end compress_or_remove_single


function process_task {
    [CmdletBinding()]
    param(
        [string]$path,
        [string]$ext,
        [string]$days,
        [bool]$arc = $true,
        [bool]$del = $true,
        [bool]$single = $false,
        [string]$comment
    )


    if ($comment) { Write-Host "comment: $comment" }
    
    # nothing to do, skip task
    if ($arc -eq $false -and $del -eq $false) {
        Write-Host "nothing to do (check config), task skipped"
        return $true
    }

    # calc limit date (time of a day always 00:00:00)
    $days = [int]$days
    $limit_date = (Get-Date).AddDays(-$days).Date

    Write-Host "get files $path\*.$ext with dt < $($limit_date.ToString('dd.MM.yyyy HH:mm:ss')) (-$days days)"
    $files = Get-ChildItem -Path $path -Filter "*.$ext" -File | Where-Object {$_.LastWriteTime -lt $limit_date}

    # if no files detected, skip current task
    if ($files.count -eq 0) { 
        Write-Host "no files *.$ext detected to process, skip task"
        return $true
    }

    # single mode
    if ($single -eq $true) {

        # compress and|or remove
        if (compress_or_remove_single -files $files -path $path -arc $arc -del $del) {
            if ($arc -eq $true) { Write-Host "success! $($files.count) files compressed separately"}
            if ($del -eq $true) { Write-Host "done! $($files.count) files removed" }
        } else {
            Write-Error "can not compress or remove *.$ext files"
            return $false    
        }

    }  # end if

    # bundle mode
    if ($single -eq $false) {

        # compress
        if ($arc -eq $true) {
            if ($arc_path = compress_bundle -files $files -path $path) {
                Write-Host "done! $($files.count) files compressed into $arc_path"
            } else {
                Write-Error "can not compress *.$ext files"
                return $false
            }
        }  # end if

        # remove
        if ($del -eq $true) {
            try {
                $files | Remove-Item
            } catch {
                Write-Error "can not remove *.$ext files"
                return $false
            }
            Write-Host "done! $($files.count) files removed successfully"
        }  # end if

    }  # end if

} # end process_task


<#
    GO
#>

$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
Set-Location -Path $script_path
$config = $null

# config must be
if (!(Test-path -Path $config_path -PathType Leaf)) {
    Write-Error "no config file $config_path"
    "$(Get-Date -f 'dd.MM.yyyy HH:mm:ss') no config file $config_path" >> $err_path
    exit
}

$config_path = Resolve-Path -Path $config_path

try {
    Write-Host "read parameters from config file $config_path"
    $config = Get-Content -Path $config_path -Raw | ConvertFrom-Json
} catch {
    Write-Error "can not read config as json data $config_path"
    "$(Get-Date -f 'dd.MM.yyyy HH:mm:ss') can not read config as json data $config_path" >> $err_path
    exit
}

# iterate over tasks in config
for($i = 0; $i -lt $config.Count; $i++) {

    Write-Host(">"*4 + " task $($i + 1)/$($config.Count)")

    # hashtable needed for args splatting
    $task_params = @{}
    # make ht from config psobject
    $config[$i].psobject.properties | foreach { $task_params[$_.Name] = $_.Value }

    # validate parameters
    if ((validate_params @task_params) -eq $false) {
        Write-Error "params validation not passed, exit"
        "$(Get-Date -f 'dd.MM.yyyy HH:mm:ss') params validation not passed, exit" >> $err_path
        exit
    }

    # process current task
    if ((process_task @task_params) -eq $false) {
        Write-Error "critical error occured while task processing, exit"
        "$(Get-Date -f 'dd.MM.yyyy HH:mm:ss') critical error occured while task processing, exit" >> $err_path
        exit
    }

}  # end for
