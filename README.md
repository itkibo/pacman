# P.A.C.M.A.N
> Compress and | or delete files by mask older than N days  

Script performs tasks from configuration file.
It works in two modes: 
+ **`bundle`** default mode  
   processes files all together  
   result = one zip file `{yyyyMMdd_HHmmss}_{filescountinbundle}{marker}.zip`
  
+ **`single`** for compressing large size files  
  processes each file separately   
  result = one zip per each source file `{yyyyMMdd_HHmmss}_{sourcefilename}{marker}.zip`)  

## Running
```
# it takes start parameters from default config path .\config.txt
.\pacman.ps1

# or specify config file
.\pacman -config_path .\configs\config.json
```

## Config rules
+ Config file contains array of dictionaries
+ Each element of the array is a task
+ Script processes tasks in same order as in config
+ Params `arc, del, single` may not be specified in config, default values used: `arc=true, del=true, single=false`
+ Params `path, filter, days` are mandatory
+ The `filter` parameter is used for both compression and deletion
+ Filter allowes `*` and `?` wildcards
+ If `days=0`, script processes all files with `dt < {tomorrow date 00:00:00}`
+ If `days=1`, script processes all files with `dt < {today date 00:00:00}`
+ If a critical error occured while checking parameters or performing task, the script stops and exit

## config example .json
```json
[
    {
        "path":  ".\\log",
        "filter":  "*.log",
        "days":  31,
        "comment":  "bundle mode: compress all *.log files in one zip + remove *.log files older than 31 days"
    },
    {
        "arc":  true,
        "path":  ".\\log",
        "del":  true,
        "filter":  "????_*.log",
        "days":  31,
        "single":  true,
        "marker":  "@PACMAN",
        "comment":  "single mode: compress filtered files separately + mark archive name with @PACMAN + remove filtered files"
    },
    {
        "arc":  false,
        "path":  ".\\zip",
        "del":  true,
        "filter":  "*@PACMAN.zip",
        "days":  90,
        "comment":  "no compression, remove files by mask older than 90 days"
    }
]
```
