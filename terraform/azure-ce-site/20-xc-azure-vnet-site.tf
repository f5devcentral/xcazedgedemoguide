resource "volterra_namespace" "buytime" {
  name = "buytime-online"
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "volterra_cloud_credentials" "azure_cred" {
  name      = "azure-${var.environment}"
  namespace = "system"
  azure_client_secret {
    client_id = azuread_application.auth.application_id
    client_secret {
        clear_secret_info {
            url = "string:///${base64encode(azuread_service_principal_password.auth.value)}"
        }
    }
    subscription_id = var.azure_subscription_id
    tenant_id       = var.azure_subscription_tenant_id
  }

  depends_on = [ 
    azuread_service_principal_password.auth,
    azuread_application.auth,
    azurerm_role_assignment.auth
  ]
}

resource "volterra_azure_vnet_site" "site" {
  name                     = "${var.environment}"
  namespace                = "system"
  azure_region             = azurerm_resource_group.rg.location
  resource_group           = "${azurerm_resource_group.rg.name}-xc"
  logs_streaming_disabled  = true
  default_blocked_services = true
  machine_type             = var.azure_xc_machine_type
  ssh_key                  = tls_private_key.key.public_key_openssh
  no_worker_nodes          = true

  azure_cred {
    name      = volterra_cloud_credentials.azure_cred.name
    namespace = volterra_cloud_credentials.azure_cred.namespace
  }

  vnet {
    existing_vnet {
      resource_group = azurerm_resource_group.rg.name
      vnet_name      = azurerm_virtual_network.vnet.name
    }
  }

  ingress_egress_gw {
    azure_certified_hw = "azure-byol-multi-nic-voltmesh"
    az_nodes {
      azure_az  = "1"
      disk_size = "80"
      inside_subnet {
        subnet {
          subnet_name         = azurerm_subnet.subnet_a.name
          vnet_resource_group = true
        }
      }
      outside_subnet {
        subnet {
          subnet_name         = azurerm_subnet.subnet_b.name
          vnet_resource_group = true
        }
      }
    }
    no_global_network        = true
    no_inside_static_routes  = true
    no_network_policy        = true
    no_outside_static_routes = true
  }

  lifecycle {
    ignore_changes = [labels]
  }

  depends_on = [
    volterra_cloud_credentials.azure_cred,
    azurerm_subnet.subnet_a,
    azurerm_subnet.subnet_b,
  ]
}

resource "volterra_cloud_site_labels" "labels" {
  name             = volterra_azure_vnet_site.site.name
  site_type        = "azure_vnet_site"
  ignore_on_delete = true
  labels           = {
    "location": "buytime-ce-site"
  }
}

resource "volterra_tf_params_action" "action_apply" {
  site_name        = volterra_azure_vnet_site.site.name
  site_kind        = "azure_vnet_site"
  action           = "apply"
  wait_for_action  = true
  ignore_on_update = true

  depends_on = [
    volterra_cloud_credentials.azure_cred,
    volterra_azure_vnet_site.site,
    azurerm_subnet.subnet_a,
    azurerm_subnet.subnet_b
  ]
}

output "xc_private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}

output "xc_public_key" {
  value = tls_private_key.key.public_key_openssh
}