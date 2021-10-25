# author: Vasil Kalchev
# date: 2020-10-23
# version: 1.0.0

<#
.SYNOPSIS
Link files from multiple directories into one.
.DESCRIPTION
Creates hard or symbolic links inside the destination directory to every file
from the source directories.

This can be useful when you want to specify multiple folders to be consumed by
a program, but the program only allows selecting a single folder and it doesn't
iterate through its sub-directories (e.g. "Windows 10 Desktop Background
Slideshow"). This way you'll be able to quickly reconfigure the set of folders
that will be consumed.

How to create a parametrized, runnable shortcut?
Create the shortcut. In "Properties", field "Target": prepend "powershell"
before "/path/link_Nto1.ps1" and after it, append the desired
arguments.

.NOTES
Files with equal names are considered the same.

.PARAMETER dst
Destination directory.
.PARAMETER srcs
One or more source directories.
.PARAMETER ItemType
Either 'HardLink' or 'SymbolicLink'. Default: 'HardLink'

.EXAMPLE
PS> ./link_Nto1.ps1 dst_dir src_dir1,src_dir2
.EXAMPLE
PS> ./link_Nto1.ps1 -dst dst_dir -srcs src_dir1 -ItemType SymbolicLink

.LINK
https://github.com/VaSe7u/link_Nto1
#>


param(
	[parameter(mandatory)] [string] $dst,
	[parameter(mandatory)] [Object[]] $srcs,
	[validateset('HardLink','SymbolicLink')] [string] $ItemType='HardLink'
)

$dst_files = @()  # array that will be populated with all destination file names
$src_files = @()  # array that will be populated with all source file names

# populate the `dst_files` array
Write-Verbose("Populating ``dst_files``:")
Get-ChildItem "./$dst" |
ForEach-Object {
	$dst_files += $_.ToString()
	Write-Verbose(" - $_")
}

# determine the linking verb string
$verb = ""
if ($ItemType -eq 'SymbolicLink') {
	$verb = "soft"
} elseif ($ItemType -eq 'HardLink') {
	$verb = "hard"
} else {
	# should never happen, since `ItemType` parameter is validated
	Write-Error("unknown ``ItemType``, terminating")
	Exit(1)
}


$srcs_cntr = 0
foreach($src in $srcs) {  # iterate through the specified source directories

	# srcs progress bar ---
	$srcs_cntr++
	$srcs_progress_activity = "Iterating directory"
	$status = "$srcs_cntr/$($srcs.count)"
	$percent = (($srcs_cntr / $($srcs.count)) * 100)
	Write-Progress -Id 0 -Activity $srcs_progress_activity -Status $status -CurrentOperation $src -PercentComplete $percent
	# Start-Sleep -Seconds 3
	# srcs progress bar ~~~

	Write-Host("Iterating directory ./$src :")

	$file_cntr = 0
	Get-ChildItem "./$src" |
	Foreach-Object {
		
		# files progress bar ---
		$file_cntr++
		$files_progress_activity = ($verb.toCharArray()[0].tostring().toUpper() + $verb.remove(0, 1)) + " linking"
		$status = "$file_cntr/$((Get-ChildItem "./$src").count)"
		$percent = (($file_cntr / $((Get-ChildItem "./$src").count)) * 100)
		Write-Progress -Id 1 -ParentId 0 -Activity $files_progress_activity -Status $status -CurrentOperation $_ -PercentComplete $percent
		# files progress bar ~~~

		Write-Host(" - $verb linking ./$src/$_ to ./$dst/$_") -NoNewline

		# linking will fail if the file already exists
		try {
			New-Item -ItemType $ItemType -ErrorAction Stop -Path "./$dst/$_" -Target "./$src/$_" > $null
			Write-Host(" - success")
		} catch [System.IO.IOException] {
			Write-Host(" - file already exists")
		}
		
		$src_files += $_.ToString()  # remember every file that was linked

	}
}

# get rid of the progress bars
Write-Progress -Id 0 -Activity $srcs_progress_activity -Status "Ready" -Completed
Write-Progress -Id 1 -ParentId 0 -Activity $files_progress_activity -Status "Ready" -Completed


Write-Verbose("Deleting missing files from destination:")
$file_cntr = 0
foreach($file in $dst_files) {

	# del progress bar ---
	$file_cntr++
	$deleting_progress_activity = "Deleting missing files from destination"
	$status = "$file_cntr/$($dst_files.count)"
	$percent = (($file_cntr / $($dst_files.count)) * 100)
	Write-Progress -Id 2 -Activity $deleting_progress_activity -Status $status -CurrentOperation $file -PercentComplete $percent
	# del progress bar ~~~

	if ($file -notin $src_files) {
		Write-Verbose " - $file"
		Remove-Item ./$dst/$file
	}
}
