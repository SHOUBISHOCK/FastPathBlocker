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

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Text = "Install"
$installBtn.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$installBtn.Size = New-Object System.Drawing.Size(120,32)
$installBtn.Location = New-Object System.Drawing.Point(20,410)
$installBtn.BackColor = [System.Drawing.Color]::FromArgb(50,205,50)
$installBtn.ForeColor = 'Black'
$form.Controls.Add($installBtn)

$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text = "Exit"
$exitBtn.Font = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$exitBtn.Size = New-Object System.Drawing.Size(120,32)
$exitBtn.Location = New-Object System.Drawing.Point(550,410)
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

function Remove-FirewallRules {
    Remove-NetFirewallRule -Name "GameSpamFilter (Inbound)" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -Name "GameSpamFilter (Outbound)" -ErrorAction SilentlyContinue
}

function Test-IsInstalled {
    $netrules = Get-NetFirewallRule -DisplayName "GameSpamFilter*"
    return ($netrules.Length -eq 0)
}

$installBtn.Add_Click({
    $installBtn.Enabled = $false
    $status.Text = "Installing..."
    Write-Log "Starting installation..."

    try {
        Write-Log "Downloading Rogue IP list..."
        $url = "https://content.hl2dm.org/spamfilter/RogueIPs.txt"
        $rogueipwr = Invoke-WebRequest -Uri $url
        
        $rogueips = $rogueipwr.Content.Split("`n")
        
        Write-Log "Removing old GameSpamFilter firewall rules..."
        
        Remove-FirewallRules

        Write-Log "Removed old rules."

        Write-Log "Adding new block rules..."
        
        New-NetFirewallRule -DisplayName "GameSpamFilter (Inbound)" -Direction Inbound -Action Block -RemoteAddress $rogueips
        New-NetFirewallRule -DisplayName "GameSpamFilter (Outbound)" -Direction Outbound -Action Block -RemoteAddress $rogueips

        Write-Log "Showing blocked IPs..."
        $netrules = Get-NetFirewallRule -DisplayName "GameSpamFilter*"
        if ($netrules.Length -eq 0) {
          throw "Failed to add firewall rules"
        }
        $blockedips = ($netrules | Get-NetFirewallAddressFilter).RemoteAddress
        foreach ($ip in $blockedips) { Write-Log "$ip" }
        Write-Log "-----------------------------------------------"
        Write-Log "You have now been updated with the current IP's and should have less spam once you refresh the server list."
        Write-Log "Did I miss one? Please paste the IP on my steam profile, http://steamcommunity.com/id/henky"
        $status.Text = "Completed! Click Exit to finish."
    }
    catch {
        $status.Text = "Install failed!"
        Write-Log "Error: $_"
    }
    finally {
        $installBtn.Enabled = $true
    }
})

if(-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    $installBtn.Enabled = $false
    Write-Log "Please start as Administrator"
}
[void]$form.ShowDialog()