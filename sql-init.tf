resource "terraform_data" "sql_schema_init" {
  depends_on = [
    azurerm_mssql_database.primary,
    azurerm_linux_virtual_machine_scale_set.web
  ]

  triggers_replace = [
    azurerm_mssql_database.primary.id,
    filesha256("${path.module}/bootstrap.sh")
  ]

  provisioner "local-exec" {
    interpreter = [
      "PowerShell",
      "-NoProfile",
      "-NonInteractive",
      "-Command"
    ]

    command = <<-EOT
      $ErrorActionPreference = "Stop"

      Write-Host "========================================"
      Write-Host "Waiting for VMSS bootstrap..."
      Write-Host "========================================"

      $ready = $false

      for ($i = 1; $i -le 30; $i++) {
        Write-Host "Bootstrap check $i/30..."

        try {
          az vmss run-command invoke `
            --resource-group "${azurerm_resource_group.rg.name}" `
            --name "${azurerm_linux_virtual_machine_scale_set.web.name}" `
            --instance-id 0 `
            --command-id RunShellScript `
            --scripts "test -f /opt/vodafone-platform/backend/src/init-db.js && systemctl is-active --quiet vodafone-backend" `
            --query "value[0].displayStatus" `
            -o tsv | Out-Null

          if ($LASTEXITCODE -eq 0) {
            $ready = $true
            break
          }
        }
        catch {
          Write-Host "VMSS bootstrap is not ready yet."
        }

        Start-Sleep -Seconds 20
      }

      if (-not $ready) {
        Write-Error "VMSS bootstrap did not become ready within the expected time."
        exit 1
      }

      Write-Host "========================================"
      Write-Host "Initializing SQL schema and seed data..."
      Write-Host "========================================"

      az vmss run-command invoke `
        --resource-group "${azurerm_resource_group.rg.name}" `
        --name "${azurerm_linux_virtual_machine_scale_set.web.name}" `
        --instance-id 0 `
        --command-id RunShellScript `
        --scripts "cd /opt/vodafone-platform/backend && /usr/bin/node src/init-db.js"

      if ($LASTEXITCODE -ne 0) {
        Write-Error "SQL schema initialization failed."
        exit 1
      }

      Write-Host "========================================"
      Write-Host "SQL initialization completed successfully."
      Write-Host "========================================"
    EOT
  }
}