resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  sku_tier = "Free"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.aks_subnet_id
    orchestrator_version         = var.kubernetes_version
    type                         = "VirtualMachineScaleSets"
    enable_auto_scaling          = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systmp"
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    pod_cidr            = "10.244.0.0/16"
    outbound_type       = "loadBalancer"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  automatic_channel_upgrade = "patch"

  lifecycle {
    ignore_changes = [
      microsoft_defender,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.create_user_node_pool ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_pool.vm_size
  vnet_subnet_id        = var.aks_subnet_id
  orchestrator_version  = var.kubernetes_version
  enable_auto_scaling   = true
  min_count             = var.user_pool.min_count
  max_count             = var.user_pool.max_count
  node_labels = {
    workload = "general"
  }
  upgrade_settings {
    max_surge = "10%"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "npdev" {
  count                 = var.create_workload_node_pools ? 1 : 0
  name                  = "npdev"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.npdev.vm_size
  vnet_subnet_id        = var.aks_subnet_id
  orchestrator_version  = var.kubernetes_version
  enable_auto_scaling   = true
  min_count             = var.npdev.min_count
  max_count             = var.npdev.max_count
  node_labels = {
    env = "dev"
  }
  node_taints = ["env=dev:NoSchedule"]
  upgrade_settings {
    max_surge = "10%"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "npstg" {
  count                 = var.create_workload_node_pools ? 1 : 0
  name                  = "npstg"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.npstg.vm_size
  vnet_subnet_id        = var.aks_subnet_id
  orchestrator_version  = var.kubernetes_version
  enable_auto_scaling   = true
  min_count             = var.npstg.min_count
  max_count             = var.npstg.max_count
  node_labels = {
    env = "stage"
  }
  node_taints = ["env=stage:NoSchedule"]
  upgrade_settings {
    max_surge = "10%"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "npprod" {
  count                 = var.create_workload_node_pools ? 1 : 0
  name                  = "npprod"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.npprod.vm_size
  vnet_subnet_id        = var.aks_subnet_id
  orchestrator_version  = var.kubernetes_version
  enable_auto_scaling   = true
  min_count             = var.npprod.min_count
  max_count             = var.npprod.max_count
  zones                 = var.npprod.zones
  node_labels = {
    env = "prod"
  }
  node_taints = ["env=prod:NoSchedule"]
  upgrade_settings {
    max_surge = "10%"
  }
}
