# MCD Module Prefix - Load classes before functions
# This file is prepended to the module during build

# Load all class definitions from the Classes folder
# Classes must be loaded in the correct order due to dependencies

# Base models with no dependencies
. "$PSScriptRoot\Classes\WorkspaceContext.ps1"
. "$PSScriptRoot\Classes\BootImageModel.ps1"
. "$PSScriptRoot\Classes\USBModel.ps1"
. "$PSScriptRoot\Classes\ADKInstallerModel.ps1"
. "$PSScriptRoot\Classes\BootImageCacheItem.ps1"

# StepModel depends on StepRules and StepRetryConfig (defined in same file)
. "$PSScriptRoot\Classes\StepModel.ps1"

# WorkflowEditorModel depends on StepModel
. "$PSScriptRoot\Classes\WorkflowEditorModel.ps1"
