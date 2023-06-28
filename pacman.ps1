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
        > path, filter, days are mandatory
        > arc=true, del=true, single=false are optional with defaults

    Filter allowes * and ? wildcards.

    If days=0, script processes all files with dt < {tomorrow date 00:00:00}.
    If days=1, script processes all files with dt < {today date 00:00:00}.

    Result archive file has naming patterns:
        > bundle: "{yyyyMMdd_HHmmss}_{filescountinbundle}{marker}.zip"
        > single: "{yyyyMMdd_HHmmss}_{sourcefilename}{marker}.zip"
        
.EXAMPLE
    Config file content example (json):    
    [
        {
            "path":  ".\\log",
            "filter":  "*.log",
            "days":  31,
            "comment":  "bundle mode (compress + remove source files, by default arc=true, del=true, single=false)"
        },
        {
            "arc":  true,
            "path":  ".\\log",
            "del":  true,
            "filter":  "????_*.log",
            "days":  31,
            "single":  true,
            "marker":  "@PACMAN",
            "comment":  "single mode (compress files separately + mark archive + remove source files)"
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
        [string]$path,              # folder where source files located
        [string]$filter,            # filter to get source files
        [string]$days,              # get files older than N days
        [bool]$arc = $true,         # files compressing enabled
        [bool]$del = $true,         # files removing enabled
        [bool]$single = $false,     # compress and|or delete each file separately
        [string]$marker,            # archive file name marker
        [string]$comment            # task comment
    )

    
    # parameters should be not empty + not null + not whitespace
    foreach ($arg in @($path, $filter, $days)) {
        if ($arg -match "^\s*$") { 
            Write-Error "incorrect external config values"
            return $false
        }
    }
    
    # days are integer >=0
    if (-not($days -match "^\d+$" -and [int]$days -ge 0)) { 
        Write-Error "wrong days value"
        return $false
    }

    # filter format: alphanumeric + some special symbols
    if (-not($filter -match "^[\w\*\?\.\ \-\@]+$")) {     
        Write-Error "wrong file filter"
        return $false 
    }

    # marker format: alphanumeric allowed or empty string
    if (-not($marker -match "^[\w\-\@]+$" -or $marker -match "^\s*$")) { 
        Write-Error "only alphanumeric allowed in marker"
        return $false 
    }

    # check path exists
    if (!(Test-Path -Path $path -PathType Container)) { 
        Write-Error "path $path not exists"
        return $false 
    }

    return $true

} # end validate_params


function get_files {
    param(
        [string]$path,    # archive destination folder
        [string]$filter,  # files filter
        [int]$days        # get files older than N of days
    )

    
    $days = [int]$days

    # calc example -1day:
    # start point of calculating dt is today 00:00:00
    # today 00:00:00 + (1-1day) = today 00:00:00
    # get all files with dt less than today 00:00:00
    $limit_date = (Get-Date).Date.AddDays(1-$days)

    @(
        "get files $path\$filter older than $days days",
        "< $($limit_date.ToString('dd.MM.yyyy HH:mm:ss'))"
    ) | Write-Host
    
    return Get-ChildItem -Path $path -Filter $filter -File | Where-Object {$_.LastWriteTime -lt $limit_date}

}  # end get_files


function compress_bundle {
    <#
        bundle mode:
        compress all files into one archive and|or delete files
        returns path to archive if success
    #>
    param(
        $files,             # source files
        [string]$path,      # archive destination folder
        [string]$marker     # archive file name marker
    )


    if ($marker) {
        $arc_path = "{0}\{1}_{2}{3}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_HHmmss'), $files.count, $marker
    } else {
        $arc_path = "{0}\{1}_{2}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_HHmmss'), $files.count
    }

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
        single mode:
        compress and|or delete each file separately
        returns true if no errors
    #>
    param(
        $files,             # source files
        [string]$path,      # archive destination folder 
        [bool]$arc,         # compress files enable
        [bool]$del,         # delete files enable
        [string]$marker     # archive file name marker
    )


    foreach ($one_file in $files) {

        if ($marker) {
            $arc_path = "{0}\{1}_{2}{3}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_HHmmss'), $one_file.Name, $marker
        } else {
            $arc_path = "{0}\{1}_{2}.zip" -f $path, (Get-Date).ToString('yyyyMMdd_HHmmss'), $one_file.Name
        }    

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
        [string]$filter,
        [string]$days,
        [bool]$arc = $true,
        [bool]$del = $true,
        [bool]$single = $false,
        [string]$marker,
        [string]$comment
    )


    if ($comment) { Write-Host "comment: $comment" }
    
    # nothing to do, skip task
    if ($arc -eq $false -and $del -eq $false) {
        Write-Host "nothing to do (check config), task skipped"
        return $true
    }

    # get files
    if (($files = get_files -path $path -filter $filter -days $days).count -gt 0) {
        Write-Host "$($files.count) files detected"
    } else {
        Write-Host "no files catched, skip task"
        return $true
    }

    # single mode
    if ($single -eq $true) {

        # compress and|or remove
        if (compress_or_remove_single -files $files -path $path -arc $arc -del $del -marker $marker) {
            if ($arc -eq $true) { Write-Host "success! $($files.count) files compressed separately"}
            if ($del -eq $true) { Write-Host "done! $($files.count) files removed"}
        } else {
            Write-Error "can not compress or remove $filter files"
            return $false    
        }

    }  # end if

    # bundle mode
    if ($single -eq $false) {

        # compress
        if ($arc -eq $true) {
            if ($arc_path = compress_bundle -files $files -path $path -marker $marker) {
                Write-Host "done! $($files.count) files compressed into $arc_path"
            } else {
                Write-Error "can not compress $filter files"
                return $false
            }
        }  # end if

        # remove
        if ($del -eq $true) {
            try {
                $files | Remove-Item
            } catch {
                Write-Error "can not remove $filter files"
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

    Write-Host("--- " + "task $($i + 1)/$($config.Count)" + " ---")

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
