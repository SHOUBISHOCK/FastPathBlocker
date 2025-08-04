Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Game Spam Filter Installer"
$form.Size = New-Object System.Drawing.Size(700, 520)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Game Spam Filter Installer"
$title.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20,18)
$title.ForeColor = 'Lime'
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready to install."
$status.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Regular)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(20,52)
$status.ForeColor = 'White'
$form.Controls.Add($status)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$logBox.ForeColor = 'Lime'
$logBox.Font = New-Object System.Drawing.Font("Consolas",10)
$logBox.Size = New-Object System.Drawing.Size(650,320)
$logBox.Location = New-Object System.Drawing.Point(20,80)
$form.Controls.Add($logBox)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = 'Continuous'
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Width = 650
$progress.Height = 22
$progress.Location = New-Object System.Drawing.Point(20,410)
$form.Controls.Add($progress)

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Text = "Install"
$installBtn.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$installBtn.Size = New-Object System.Drawing.Size(120,32)
$installBtn.Location = New-Object System.Drawing.Point(20,450)
$installBtn.BackColor = [System.Drawing.Color]::FromArgb(50,205,50)
$installBtn.ForeColor = 'Black'
$form.Controls.Add($installBtn)

$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text = "Exit"
$exitBtn.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$exitBtn.Size = New-Object System.Drawing.Size(120,32)
$exitBtn.Location = New-Object System.Drawing.Point(550,450)
$exitBtn.BackColor = [System.Drawing.Color]::FromArgb(220,20,60)
$exitBtn.ForeColor = 'White'
$form.Controls.Add($exitBtn)
$exitBtn.Add_Click({
    Start-Process "https://mygamingedge.online/"
    $form.Close()
})

function Write-Log {
    param([string]$msg)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$timestamp] $msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

function Get-BlockedIPs {
    $rules = netsh advfirewall firewall show rule name=all | Select-String "GameSpamFilter"
    $blockedIPs = @()
    foreach ($rule in $rules) {
        $ruleName = ($rule -split ':')[1].Trim()
        $output = netsh advfirewall firewall show rule name="$ruleName"
        foreach ($line in $output) {
            if ($line -match "RemoteIP") { $blockedIPs += $line }
        }
    }
    return $blockedIPs
}

$installBtn.Add_Click({
    $installBtn.Enabled = $false
    $status.Text = "Installing..."
    $progress.Value = 0
    Write-Log "Starting installation..."

    try {
        $progress.Value = 10
        Write-Log "Downloading Rogue IP list..."
        $url = "https://content.hl2dm.org/spamfilter/RogueIPs.txt"
        $dest = "$env:TEMP\RogueIPs.txt"
        Invoke-WebRequest -Uri $url -OutFile $dest
        Write-Log "Downloaded Rogue IPs to: $dest"
        $progress.Value = 30

        Write-Log "Removing old GameSpamFilter firewall rules..."
        $oldRules = netsh advfirewall firewall show rule name=all | Select-String "GameSpamFilter"
        $rcount = 0
        foreach ($rule in $oldRules) {
            $rcount++
            $ruleName = ($rule -split ':')[1].Trim()
            $delOut = netsh advfirewall firewall delete rule name="$ruleName"
            Write-Log "Deleted rule: $delOut"
        }
        Write-Log "Removed $rcount old rules."
        $progress.Value = 50

        Write-Log "Adding new block rules..."
        $ips = Get-Content $dest | Where-Object { $_.Trim() -ne "" }
        $blockSize = 200
        $blockCount = [math]::Ceiling($ips.Count / $blockSize)
        $idx = 0
        for ($i = 0; $i -lt $blockCount; $i++) {
            $ipBlock = $ips[$idx..([math]::Min($idx+$blockSize-1, $ips.Count-1))] -join ","
            $ruleName = "GameSpamFilter$($i+1)"

            $outIn = netsh advfirewall firewall add rule name="$ruleName" protocol=any dir=in action=block remoteip=$ipBlock
            $outOut = netsh advfirewall firewall add rule name="$ruleName" protocol=any dir=out action=block remoteip=$ipBlock
            Write-Log "IN rule: $outIn"
            Write-Log "OUT rule: $outOut"

            $idx += $blockSize
            $progress.Value = 50 + [int](40*($i+1)/$blockCount)
        }
        $progress.Value = 90

        Write-Log "Showing blocked IPs..."
        $blockedIPs = Get-BlockedIPs
        foreach ($ip in $blockedIPs) { Write-Log "$ip" }
        Write-Log "-----------------------------------------------"
        Write-Log "You have now been updated with the current IP's and should have less spam once you refresh the server list."
        Write-Log "Did I miss one? Please paste the IP on my steam profile, http://steamcommunity.com/id/henky"
        $status.Text = "Completed! Click Exit to finish."
        $progress.Value = 100
    }
    catch {
        $progress.Value = 0
        $status.Text = "Install failed!"
        Write-Log "Error: $_"
    }
    finally {
        $installBtn.Enabled = $true
    }
})

[void]$form.ShowDialog()