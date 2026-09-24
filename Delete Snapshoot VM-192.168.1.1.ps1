# ============================================================
# ESXi VM + SNAPSHOT INFORMATION + SNAPSHOT DELETION
# Optimized for LOCAL Windows PowerShell / NO ONEDRIVE
# VMware PowerCLI 13.x
#
# SNAPSHOT WORKFLOW:
#
#   Select VM
#       |
#       v
#   Select Snapshot
#       |
#       v
#   Delete Snapshot
#       |
#       v
#   Verify Deletion
#       |
#       v
#   RETURN TO SAME VM
#       |
#       +----> Select another snapshot
#       |
#       +----> 0 = Return to VM selection
#
# ============================================================

Clear-Host

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          ESXi VM + SNAPSHOT MANAGEMENT TOOL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# CONFIGURATION
# ============================================================

$ESXiIP   = "192.168.1.1"
$Username = "root"

# Local log directory
$LogDirectory = "C:\VMwareAutomation\Logs"
$LogFile      = Join-Path $LogDirectory "Snapshot-Deletion.log"


# ============================================================
# CREATE LOG DIRECTORY
# ============================================================

if (-not (Test-Path -LiteralPath $LogDirectory)) {

    try {

        New-Item `
            -ItemType Directory `
            -Path $LogDirectory `
            -Force `
            -ErrorAction Stop |
            Out-Null

    }
    catch {

        Write-Host "WARNING: Unable to create log directory." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}


# ============================================================
# CONFIGURATION DISPLAY
# ============================================================

Write-Host "[1/7] Configuration" -ForegroundColor Yellow
Write-Host "ESXi IP : $ESXiIP"
Write-Host "Username: $Username"
Write-Host "Log File: $LogFile"
Write-Host ""


# ============================================================
# CHECK POWERSHELL VERSION
# ============================================================

Write-Host "[2/7] Checking PowerShell..." -ForegroundColor Yellow

Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 5) {

    Write-Host "ERROR: PowerShell 5.1 or newer is required." -ForegroundColor Red
    Write-Host ""

    Read-Host "Press ENTER to close"
    exit
}


# ============================================================
# CHECK VMWARE POWERCLI CORE
# ============================================================

Write-Host "[3/7] Checking VMware PowerCLI Core..." -ForegroundColor Yellow
Write-Host ""

$CoreModule = Get-Module -ListAvailable -Name VMware.VimAutomation.Core |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $CoreModule) {

    Write-Host "VMware.VimAutomation.Core is NOT installed." -ForegroundColor Red
    Write-Host ""

    Write-Host "Install VMware PowerCLI using:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Install-Module VMware.PowerCLI -Scope CurrentUser" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "After installation, run this script again." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Press ENTER to close"
    exit
}

Write-Host "VMware PowerCLI Core detected." -ForegroundColor Green
Write-Host "Version : $($CoreModule.Version)"
Write-Host "Path    : $($CoreModule.Path)"
Write-Host ""


# ============================================================
# LOAD POWERCLI CORE
# ============================================================

Write-Host "Loading VMware.VimAutomation.Core..." -ForegroundColor Yellow

$ModuleLoadStart = Get-Date

try {

    Import-Module VMware.VimAutomation.Core `
        -ErrorAction Stop

}
catch {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "       FAILED TO LOAD VMWARE POWERCLI CORE" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    Write-Host "Module path:" -ForegroundColor Yellow
    Write-Host $CoreModule.Path
    Write-Host ""

    Read-Host "Press ENTER to close"
    exit
}

$ModuleLoadTime = ((Get-Date) - $ModuleLoadStart).TotalSeconds

Write-Host ""
Write-Host "VMware.VimAutomation.Core loaded successfully." -ForegroundColor Green
Write-Host "Module load time: $([math]::Round($ModuleLoadTime,2)) seconds" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# POWERCLI CONFIGURATION
# ============================================================

Write-Host "[4/7] Configuring PowerCLI..." -ForegroundColor Yellow

$ConfigStart = Get-Date

try {

    Set-PowerCLIConfiguration `
        -InvalidCertificateAction Ignore `
        -Confirm:$false `
        -Scope User `
        -ErrorAction Stop |
        Out-Null

    $ConfigTime = ((Get-Date) - $ConfigStart).TotalSeconds

    Write-Host "PowerCLI configuration completed." -ForegroundColor Green
    Write-Host "Configuration time: $([math]::Round($ConfigTime,2)) seconds" -ForegroundColor Cyan

}
catch {

    Write-Host "PowerCLI configuration warning:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

Write-Host ""


# ============================================================
# PASSWORD
# ============================================================

Write-Host "[5/7] Authentication" -ForegroundColor Yellow
Write-Host ""

$Password = Read-Host "Enter password for $Username" -AsSecureString

if (-not $Password) {

    Write-Host "Password was not entered." -ForegroundColor Red

    Read-Host "Press ENTER to close"
    exit
}

$Credential = New-Object System.Management.Automation.PSCredential(
    $Username,
    $Password
)

Write-Host ""


# ============================================================
# TEST NETWORK CONNECTION
# ============================================================

Write-Host "Testing connection to $ESXiIP ..." -ForegroundColor Yellow
Write-Host ""

try {

    $Ping = Test-Connection `
        -ComputerName $ESXiIP `
        -Count 1 `
        -Quiet `
        -ErrorAction SilentlyContinue

    if ($Ping) {

        Write-Host "Network connection successful." -ForegroundColor Green

    }
    else {

        Write-Host "WARNING: ESXi did not respond to ping." -ForegroundColor Yellow
        Write-Host "Ping may be disabled on ESXi, so continuing..." -ForegroundColor Yellow
    }

}
catch {

    Write-Host "Ping test failed, continuing..." -ForegroundColor Yellow
}

Write-Host ""


# ============================================================
# CONNECT TO ESXi
# ============================================================

Write-Host "[6/7] Connecting to ESXi..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Server: $ESXiIP"
Write-Host "Please wait..." -ForegroundColor Cyan
Write-Host ""

$ConnectionStart = Get-Date

try {

    $Connection = Connect-VIServer `
        -Server $ESXiIP `
        -Credential $Credential `
        -ErrorAction Stop

    $ConnectionTime = ((Get-Date) - $ConnectionStart).TotalSeconds

    Write-Host ""
    Write-Host "SUCCESS: Connected to ESXi." -ForegroundColor Green
    Write-Host "Connection time: $([math]::Round($ConnectionTime,2)) seconds" -ForegroundColor Cyan
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "                 CONNECTION FAILED" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "1. Incorrect ESXi IP address"
    Write-Host "2. Incorrect username"
    Write-Host "3. Incorrect password"
    Write-Host "4. ESXi management network is unreachable"
    Write-Host "5. VMware PowerCLI is not compatible"
    Write-Host "6. ESXi HTTPS management service is unavailable"
    Write-Host ""

    Read-Host "Press ENTER to close"
    exit
}


# ============================================================
# GET ESXi INFORMATION
# ============================================================

Write-Host "[7/7] Collecting ESXi information..." -ForegroundColor Yellow
Write-Host ""

try {

    $ESXi = Get-VMHost `
        -Server $Connection `
        -ErrorAction Stop

}
catch {

    Write-Host "Unable to retrieve ESXi host information." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    Disconnect-VIServer `
        -Server $Connection `
        -Confirm:$false `
        -ErrorAction SilentlyContinue

    Read-Host "Press ENTER to close"
    exit
}


# ============================================================
# ESXi DETAILS
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    ESXi DETAILS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Host Name        : $($ESXi.Name)"
Write-Host "IP Address       : $ESXiIP"
Write-Host "Connection State : $($ESXi.ConnectionState)"
Write-Host "Power State      : $($ESXi.PowerState)"
Write-Host "ESXi Version     : $($ESXi.Version)"
Write-Host "Build            : $($ESXi.Build)"
Write-Host "CPU Cores        : $($ESXi.NumCpu)"
Write-Host "CPU Speed        : $([math]::Round($ESXi.CpuTotalMhz / 1000,2)) GHz"
Write-Host "Memory Total     : $([math]::Round($ESXi.MemoryTotalGB,2)) GB"
Write-Host "Memory Used      : $([math]::Round($ESXi.MemoryUsageGB,2)) GB"
Write-Host "Memory Free      : $([math]::Round(($ESXi.MemoryTotalGB - $ESXi.MemoryUsageGB),2)) GB"


# ============================================================
# DATASTORES
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    DATASTORES" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$Datastores = @(
    Get-Datastore `
        -VMHost $ESXi `
        -ErrorAction SilentlyContinue
)

if ($Datastores.Count -gt 0) {

    foreach ($DS in $Datastores) {

        $Capacity = [math]::Round($DS.CapacityGB, 2)
        $Free     = [math]::Round($DS.FreeSpaceGB, 2)
        $Used     = [math]::Round($Capacity - $Free, 2)

        Write-Host "Datastore : $($DS.Name)"
        Write-Host "Type      : $($DS.Type)"
        Write-Host "Capacity  : $Capacity GB"
        Write-Host "Used      : $Used GB"
        Write-Host "Free      : $Free GB"
        Write-Host "------------------------------------------------------------"
    }

}
else {

    Write-Host "No datastores found." -ForegroundColor Yellow
}


# ============================================================
# VIRTUAL MACHINES
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    VIRTUAL MACHINES" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$VMs = @(
    Get-VM `
        -Location $ESXi `
        -ErrorAction SilentlyContinue
)

Write-Host "Total VMs: $($VMs.Count)" -ForegroundColor Green


# ============================================================
# VM INFORMATION
# ============================================================

foreach ($VM in $VMs) {

    Write-Host ""
    Write-Host "************************************************************" -ForegroundColor Yellow
    Write-Host "VM: $($VM.Name)" -ForegroundColor Yellow
    Write-Host "************************************************************" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "VM DETAILS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"

    Write-Host "Name          : $($VM.Name)"
    Write-Host "Power State   : $($VM.PowerState)"
    Write-Host "CPU           : $($VM.NumCpu)"
    Write-Host "Memory        : $($VM.MemoryGB) GB"


    # ========================================================
    # GUEST OS
    # ========================================================

    try {

        $GuestOS = $VM.Guest.OSFullName

    }
    catch {

        $GuestOS = "Not available"
    }

    Write-Host "Guest OS      : $GuestOS"


    # ========================================================
    # IP ADDRESS
    # ========================================================

    try {

        $IPAddresses = @($VM.Guest.IPAddress)

    }
    catch {

        $IPAddresses = @()
    }

    if ($IPAddresses.Count -gt 0) {

        Write-Host "IP Address    : $($IPAddresses -join ', ')"

    }
    else {

        Write-Host "IP Address    : Not available"
    }


    # ========================================================
    # VMWARE TOOLS
    # ========================================================

    try {

        Write-Host "VMware Tools  : $($VM.ExtensionData.Guest.ToolsStatus)"

    }
    catch {

        Write-Host "VMware Tools  : Not available"
    }


    # ========================================================
    # DISKS
    # ========================================================

    Write-Host ""
    Write-Host "VIRTUAL DISKS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"

    $Disks = @(
        Get-HardDisk `
            -VM $VM `
            -ErrorAction SilentlyContinue
    )

    if ($Disks.Count -gt 0) {

        foreach ($Disk in $Disks) {

            Write-Host "Disk          : $($Disk.Name)"
            Write-Host "Capacity      : $($Disk.CapacityGB) GB"
            Write-Host "Format        : $($Disk.StorageFormat)"
            Write-Host ""
        }

    }
    else {

        Write-Host "No disks found."
    }


    # ========================================================
    # SNAPSHOTS
    # ========================================================

    Write-Host ""
    Write-Host "SNAPSHOTS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"

    $Snapshots = @(
        Get-Snapshot `
            -VM $VM `
            -ErrorAction SilentlyContinue
    )

    if ($Snapshots.Count -gt 0) {

        Write-Host "Snapshot Count: $($Snapshots.Count)" -ForegroundColor Yellow
        Write-Host ""

        foreach ($Snapshot in $Snapshots) {

            Write-Host "Snapshot Name : $($Snapshot.Name)"
            Write-Host "Created       : $($Snapshot.Created)"
            Write-Host "Description   : $($Snapshot.Description)"
            Write-Host "Size          : $([math]::Round($Snapshot.SizeGB,2)) GB"
            Write-Host "Quiesced      : $($Snapshot.Quiesced)"
            Write-Host "Power State   : $($Snapshot.PowerState)"

            Write-Host "------------------------------------------------------------"
        }

    }
    else {

        Write-Host "NO SNAPSHOT FOUND" -ForegroundColor Green
    }
}


# ============================================================
# SNAPSHOT DELETION LOG FUNCTION
# ============================================================

function Write-DeletionLog {

    param (
        [string]$VMName,
        [string]$SnapshotName,
        [string]$Action,
        [string]$Result,
        [string]$Details
    )

    try {

        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $LogEntry = "$Timestamp | ESXi=$ESXiIP | VM=$VMName | Snapshot=$SnapshotName | Action=$Action | Result=$Result | Details=$Details"

        Add-Content `
            -Path $LogFile `
            -Value $LogEntry `
            -ErrorAction SilentlyContinue
    }
    catch {

        # Logging failure must never stop the main operation.
    }
}


# ============================================================
# SNAPSHOT MANAGEMENT
# ============================================================

function Start-SnapshotDeletion {

    # ========================================================
    # MAIN MENU
    # ========================================================

    while ($true) {

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "                SNAPSHOT MANAGEMENT" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1] Delete a snapshot"
        Write-Host "[2] Skip snapshot deletion"
        Write-Host "[0] Exit"
        Write-Host ""

        $ManagementChoice = Read-Host "Select an option"


        # ====================================================
        # SKIP
        # ====================================================

        if ($ManagementChoice -eq "2") {

            Write-Host ""
            Write-Host "Snapshot deletion skipped." -ForegroundColor Green

            return
        }


        # ====================================================
        # EXIT
        # ====================================================

        if ($ManagementChoice -eq "0") {

            Write-Host ""
            Write-Host "Exiting snapshot management." -ForegroundColor Yellow

            return
        }


        # ====================================================
        # INVALID MAIN MENU
        # ====================================================

        if ($ManagementChoice -ne "1") {

            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red
            Write-Host ""

            continue
        }


        # ====================================================
        # VM SELECTION LOOP
        # ====================================================

        while ($true) {

            Write-Host ""
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host "              SELECT VM FOR SNAPSHOT DELETE" -ForegroundColor Cyan
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host ""

            if ($VMs.Count -eq 0) {

                Write-Host "No virtual machines were found." -ForegroundColor Red
                Write-Host ""

                return
            }


            for ($i = 0; $i -lt $VMs.Count; $i++) {

                $VMNumber = $i + 1

                Write-Host "[$VMNumber] $($VMs[$i].Name)"
            }

            Write-Host ""
            Write-Host "[0] Cancel"
            Write-Host ""

            $VMChoice = Read-Host "Select VM"


            # ------------------------------------------------
            # CANCEL
            # ------------------------------------------------

            if ($VMChoice -eq "0") {

                Write-Host ""
                Write-Host "Snapshot deletion cancelled." -ForegroundColor Yellow

                return
            }


            # ------------------------------------------------
            # PARSE VM NUMBER
            # ------------------------------------------------

            $VMIndex = 0

            $VMIsNumber = [int]::TryParse(
                $VMChoice,
                [ref]$VMIndex
            )

            if (-not $VMIsNumber) {

                Write-Host ""
                Write-Host "Invalid VM selection." -ForegroundColor Red
                Write-Host ""

                continue
            }


            # ------------------------------------------------
            # CHECK VM RANGE
            # ------------------------------------------------

            if (
                $VMIndex -lt 1 -or
                $VMIndex -gt $VMs.Count
            ) {

                Write-Host ""
                Write-Host "Invalid VM selection." -ForegroundColor Red
                Write-Host ""

                continue
            }


            # ------------------------------------------------
            # GET SELECTED VM
            # ------------------------------------------------

            $SelectedVM = $VMs[$VMIndex - 1]

            Write-Host ""
            Write-Host "Selected VM:" -ForegroundColor Cyan
            Write-Host "$($SelectedVM.Name)" -ForegroundColor Green
            Write-Host ""


            # =================================================
            # SAME VM LOOP
            #
            # THIS IS THE IMPORTANT PART.
            #
            # Everything inside this loop operates on
            # $SelectedVM.
            #
            # After deletion we use "continue".
            #
            # That means:
            #
            #     SAME VM
            #         |
            #         v
            #     GET SNAPSHOTS
            #         |
            #         v
            #     SELECT SNAPSHOT
            #
            # We DO NOT return to VM selection.
            # =================================================

            while ($true) {


                # =================================================
                # GET CURRENT SNAPSHOTS
                # =================================================

                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Host "              SNAPSHOTS FOR SELECTED VM" -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Host ""

                Write-Host "VM: $($SelectedVM.Name)" -ForegroundColor Green
                Write-Host ""

                try {

                    $SelectedVMSnapshots = @(
                        Get-Snapshot `
                            -VM $SelectedVM `
                            -ErrorAction Stop
                    )

                }
                catch {

                    Write-Host ""
                    Write-Host "Unable to retrieve snapshots." -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    Write-Host ""

                    Write-DeletionLog `
                        -VMName $SelectedVM.Name `
                        -SnapshotName "N/A" `
                        -Action "GET SNAPSHOTS" `
                        -Result "FAILED" `
                        -Details $_.Exception.Message

                    Write-Host "[1] Return to VM selection"
                    Write-Host "[0] Exit"
                    Write-Host ""

                    $ErrorChoice = Read-Host "Select an option"

                    if ($ErrorChoice -eq "0") {

                        return
                    }

                    break
                }


                # =================================================
                # NO SNAPSHOTS LEFT
                # =================================================

                if ($SelectedVMSnapshots.Count -eq 0) {

                    Write-Host ""
                    Write-Host "============================================================" -ForegroundColor Green
                    Write-Host "                  NO SNAPSHOTS FOUND" -ForegroundColor Green
                    Write-Host "============================================================" -ForegroundColor Green
                    Write-Host ""

                    Write-Host "VM: $($SelectedVM.Name)" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "This VM has no remaining snapshots." -ForegroundColor Green
                    Write-Host ""

                    Write-Host "[1] Select another VM"
                    Write-Host "[0] Exit"
                    Write-Host ""

                    $NoSnapshotChoice = Read-Host "Select an option"


                    if ($NoSnapshotChoice -eq "1") {

                        # Leave the same VM loop.
                        break
                    }


                    if ($NoSnapshotChoice -eq "0") {

                        return
                    }


                    Write-Host ""
                    Write-Host "Invalid selection." -ForegroundColor Red
                    Write-Host ""

                    continue
                }


                # =================================================
                # DISPLAY SNAPSHOTS
                # =================================================

                Write-Host "Available snapshots:" -ForegroundColor Yellow
                Write-Host ""

                for (
                    $i = 0;
                    $i -lt $SelectedVMSnapshots.Count;
                    $i++
                ) {

                    $SnapshotNumber = $i + 1

                    $Snapshot = $SelectedVMSnapshots[$i]

                    Write-Host "[$SnapshotNumber] $($Snapshot.Name)"

                    Write-Host "    Created  : $($Snapshot.Created)"

                    Write-Host "    Size     : $([math]::Round($Snapshot.SizeGB,2)) GB"

                    Write-Host "    Quiesced : $($Snapshot.Quiesced)"

                    Write-Host "    Power    : $($Snapshot.PowerState)"

                    Write-Host ""
                }


                Write-Host "[0] Return to VM selection"
                Write-Host ""


                # =================================================
                # SNAPSHOT SELECTION
                # =================================================

                $SnapshotChoice = Read-Host "Select snapshot"


                # -------------------------------------------------
                # RETURN TO VM SELECTION
                # -------------------------------------------------

                if ($SnapshotChoice -eq "0") {

                    Write-Host ""
                    Write-Host "Returning to VM selection..." -ForegroundColor Yellow
                    Write-Host ""

                    break
                }


                # -------------------------------------------------
                # PARSE SNAPSHOT NUMBER
                # -------------------------------------------------

                $SnapshotIndex = 0

                $SnapshotIsNumber = [int]::TryParse(
                    $SnapshotChoice,
                    [ref]$SnapshotIndex
                )

                if (-not $SnapshotIsNumber) {

                    Write-Host ""
                    Write-Host "Invalid snapshot selection." -ForegroundColor Red
                    Write-Host ""

                    continue
                }


                # -------------------------------------------------
                # CHECK SNAPSHOT RANGE
                # -------------------------------------------------

                if (
                    $SnapshotIndex -lt 1 -or
                    $SnapshotIndex -gt $SelectedVMSnapshots.Count
                ) {

                    Write-Host ""
                    Write-Host "Invalid snapshot selection." -ForegroundColor Red
                    Write-Host ""

                    continue
                }


                # -------------------------------------------------
                # GET SELECTED SNAPSHOT
                # -------------------------------------------------

                $SelectedSnapshot =
                    $SelectedVMSnapshots[$SnapshotIndex - 1]


                # =================================================
                # DELETE CONFIRMATION
                # =================================================

                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host "                  DELETE CONFIRMATION" -ForegroundColor Red
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host ""

                Write-Host "VM       : $($SelectedVM.Name)"
                Write-Host "Snapshot : $($SelectedSnapshot.Name)"
                Write-Host "Created  : $($SelectedSnapshot.Created)"
                Write-Host "Size     : $([math]::Round($SelectedSnapshot.SizeGB,2)) GB"
                Write-Host "Quiesced : $($SelectedSnapshot.Quiesced)"
                Write-Host ""

                Write-Host "WARNING:" -ForegroundColor Yellow
                Write-Host "Deleting a snapshot can initiate disk consolidation." -ForegroundColor Yellow
                Write-Host "The operation may take time depending on snapshot size" -ForegroundColor Yellow
                Write-Host "and datastore performance." -ForegroundColor Yellow
                Write-Host ""

                Write-Host "To continue, type DELETE exactly." -ForegroundColor Red
                Write-Host "Anything else will cancel the deletion." -ForegroundColor Yellow
                Write-Host ""

                $Confirmation = Read-Host "Type DELETE to confirm"


                # =================================================
                # CANCEL DELETION
                # =================================================

                if ($Confirmation -cne "DELETE") {

                    Write-Host ""
                    Write-Host "Deletion cancelled." -ForegroundColor Green
                    Write-Host "Snapshot was NOT deleted." -ForegroundColor Green
                    Write-Host ""

                    Write-DeletionLog `
                        -VMName $SelectedVM.Name `
                        -SnapshotName $SelectedSnapshot.Name `
                        -Action "DELETE" `
                        -Result "CANCELLED" `
                        -Details "User cancelled confirmation"

                    # Stay on SAME VM.
                    continue
                }


                # =================================================
                # DELETE SNAPSHOT
                # =================================================

                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host "                 DELETING SNAPSHOT" -ForegroundColor Red
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host ""

                Write-Host "VM       : $($SelectedVM.Name)"
                Write-Host "Snapshot : $($SelectedSnapshot.Name)"
                Write-Host ""

                Write-Host "Deletion started..." -ForegroundColor Yellow
                Write-Host "Please wait. Do NOT close this window." -ForegroundColor Yellow
                Write-Host ""


                try {

                    # =================================================
                    # START ASYNC DELETE
                    # =================================================

                    $DeleteTask = Remove-Snapshot `
                        -Snapshot $SelectedSnapshot `
                        -Confirm:$false `
                        -RunAsync `
                        -ErrorAction Stop


                    Write-Host "Snapshot deletion task started." -ForegroundColor Cyan
                    Write-Host ""

                    Write-Host "Waiting for VMware task to complete..." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Please wait..." -ForegroundColor Cyan
                    Write-Host ""


                    # =================================================
                    # WAIT FOR DELETE TASK
                    # =================================================

                    $CompletedTask = Wait-Task `
                        -Task $DeleteTask `
                        -ErrorAction Stop


                    Write-Host ""
                    Write-Host "VMware snapshot deletion task completed." -ForegroundColor Green
                    Write-Host ""

                }
                catch {

                    Write-Host ""
                    Write-Host "============================================================" -ForegroundColor Red
                    Write-Host "              SNAPSHOT DELETION FAILED" -ForegroundColor Red
                    Write-Host "============================================================" -ForegroundColor Red
                    Write-Host ""

                    Write-Host "Error:" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    Write-Host ""


                    Write-DeletionLog `
                        -VMName $SelectedVM.Name `
                        -SnapshotName $SelectedSnapshot.Name `
                        -Action "DELETE" `
                        -Result "FAILED" `
                        -Details $_.Exception.Message


                    Write-Host ""
                    Write-Host "Returning to the same VM..." -ForegroundColor Yellow
                    Write-Host ""

                    # Stay on SAME VM.
                    continue
                }


                # =================================================
                # VERIFY SNAPSHOT DELETION
                # =================================================

                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Host "              VERIFYING SNAPSHOT DELETION" -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Host ""

                Write-Host "Checking VMware snapshot inventory..." -ForegroundColor Yellow


                # -------------------------------------------------
                # Give VMware inventory a short time to refresh.
                # -------------------------------------------------

                Start-Sleep -Seconds 2


                try {

                    $RemainingSnapshots = @(
                        Get-Snapshot `
                            -VM $SelectedVM `
                            -ErrorAction Stop
                    )


                    # -------------------------------------------------
                    # COMPARE USING SNAPSHOT ID
                    # -------------------------------------------------

                    $StillExists = @(
                        $RemainingSnapshots | Where-Object {
                            $_.Id -eq $SelectedSnapshot.Id
                        }
                    )


                    if ($StillExists.Count -eq 0) {

                        Write-Host ""
                        Write-Host "============================================================" -ForegroundColor Green
                        Write-Host "                  DELETION SUCCESSFUL" -ForegroundColor Green
                        Write-Host "============================================================" -ForegroundColor Green
                        Write-Host ""

                        Write-Host "VM       : $($SelectedVM.Name)"
                        Write-Host "Snapshot : $($SelectedSnapshot.Name)"
                        Write-Host ""

                        Write-Host "Snapshot was successfully removed and verified." -ForegroundColor Green


                        Write-DeletionLog `
                            -VMName $SelectedVM.Name `
                            -SnapshotName $SelectedSnapshot.Name `
                            -Action "DELETE" `
                            -Result "SUCCESS" `
                            -Details "Snapshot deleted and verified"

                    }
                    else {

                        Write-Host ""
                        Write-Host "============================================================" -ForegroundColor Yellow
                        Write-Host "             DELETION NOT VERIFIED" -ForegroundColor Yellow
                        Write-Host "============================================================" -ForegroundColor Yellow
                        Write-Host ""

                        Write-Host "The snapshot is still visible in the snapshot list." -ForegroundColor Yellow
                        Write-Host ""

                        Write-Host "DO NOT immediately attempt to delete it again." -ForegroundColor Red

                        Write-Host "Please check the VMware host/vSphere client." -ForegroundColor Yellow


                        Write-DeletionLog `
                            -VMName $SelectedVM.Name `
                            -SnapshotName $SelectedSnapshot.Name `
                            -Action "DELETE" `
                            -Result "NOT VERIFIED" `
                            -Details "Snapshot still visible after deletion task"
                    }

                }
                catch {

                    Write-Host ""
                    Write-Host "Unable to verify snapshot deletion." -ForegroundColor Yellow
                    Write-Host $_.Exception.Message -ForegroundColor Yellow


                    Write-DeletionLog `
                        -VMName $SelectedVM.Name `
                        -SnapshotName $SelectedSnapshot.Name `
                        -Action "DELETE" `
                        -Result "VERIFICATION FAILED" `
                        -Details $_.Exception.Message
                }


                # =================================================
                # IMPORTANT
                #
                # DO NOT ASK:
                #
                # Do you want to manage another snapshot? (Y/N)
                #
                # Instead, continue the SAME VM loop.
                # =================================================

                Write-Host ""
                Write-Host "------------------------------------------------------------"
                Write-Host ""

                Write-Host "Returning to snapshots for:" -ForegroundColor Cyan
                Write-Host "$($SelectedVM.Name)" -ForegroundColor Green
                Write-Host ""

                # =================================================
                # THIS IS THE KEY LINE
                #
                # It returns to the beginning of the SAME VM loop.
                #
                # It does NOT return to VM selection.
                # =================================================

                continue
            }


            # =================================================
            # WE ARE HERE WHEN:
            #
            # User selected [0] from snapshot list
            #
            # OR
            #
            # VM has no snapshots and user selected [1]
            #
            # Therefore leave the same VM loop and go back
            # to VM selection.
            # =================================================

            break
        }


        # ====================================================
        # RETURN TO VM SELECTION
        # ====================================================

        Write-Host ""
        Write-Host "Returning to VM selection..." -ForegroundColor Cyan
        Write-Host ""

        # Continue main VM selection loop.
        continue
    }
}


# ============================================================
# START SNAPSHOT MANAGEMENT
# ============================================================

Start-SnapshotDeletion


# ============================================================
# FINAL SUMMARY
# ============================================================

$TotalSnapshots = 0

foreach ($VM in $VMs) {

    $VMShots = @(
        Get-Snapshot `
            -VM $VM `
            -ErrorAction SilentlyContinue
    )

    $TotalSnapshots += $VMShots.Count
}


Write-Host ""
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                       SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "ESXi Host       : $($ESXi.Name)"
Write-Host "ESXi IP         : $ESXiIP"
Write-Host "ESXi Version    : $($ESXi.Version)"
Write-Host "Total VMs       : $($VMs.Count)"
Write-Host "Total Datastore : $($Datastores.Count)"
Write-Host "Total Snapshots : $TotalSnapshots"

Write-Host ""
Write-Host "PowerCLI Core   : $($CoreModule.Version)"
Write-Host "Module Path     : $($CoreModule.Path)"
Write-Host "Module Load     : $([math]::Round($ModuleLoadTime,2)) seconds"
Write-Host "Connection Time : $([math]::Round($ConnectionTime,2)) seconds"
Write-Host ""
Write-Host "Snapshot Log    : $LogFile"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 REPORT COMPLETED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# DISCONNECT
# ============================================================

Disconnect-VIServer `
    -Server $Connection `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

Write-Host "Disconnected from ESXi." -ForegroundColor Green
Write-Host ""

Read-Host "Press ENTER to close this window"
