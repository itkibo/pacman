# P.A.C.M.A.N
> Script for compressing and removing files by rules

It performs tasks from configuration file  
Works in two modes:  
+ bundle - processes all files all together (default mode)
+ single - processes each file separately (uses for large size files)

## config example .json
```json
# Config file contains array of dictionaries
# Each element of the array is a task
# Script processes tasks in same order as in config
# Params arc, del, single may not be specified in config, default values used: arc=true, del=true, single=false
# The filtering parameter is used for compression and deletion jobs
# If a critical error occured while checking parameters or performing task, the script stops and exit

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
