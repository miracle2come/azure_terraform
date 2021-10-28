################################################################################## 
# PROVIDERS # 
################################################################################## 
terraform { 
    required_providers { 
        azurerm = { 
            source = "hashicorp/azurerm" 
            version = "2.59.0" 
            } 
        } 
    } 
            
    provider "azurerm" { 
        features {} 
        }

###########################
### local variables     ###
###########################

locals {
  tm_location     = "Global"

  aue_shared_rg_name           = "${var.env}-aue-shared-rg"
  aue_fe_rg_name               = "${var.env}-aue-frontend-rg"
  aus_fe_rg_name               = "${var.env}-aus-frontend-rg"
  aue_front_pip                = "${var.env}-aue-appgw-pip"
  aus_front_pip                = "${var.env}-aus-appgw-pip"

  ep_name_aue = "${var.env}-aue-appgw"
  ep_name_aus = "${var.env}-aus-appgw"

  tags = {
    environment = "${var.env}"
    application = "Web"
    purpose     = "High Avilability"
    owner       = "John Smith"
    location    = "${local.tm_location}"
  }
}


#############################
# Data
#############################
## Quering resource groups
data "azurerm_resource_group" "aue_shared" {
  name = local.aue_shared_rg_name
}
data "azurerm_resource_group" "aue_frontend" {
  name = local.aue_fe_rg_name
}
data "azurerm_resource_group" "aus_frontend" {
  name = local.aus_fe_rg_name
}
## Quering public ip addresses
data "azurerm_public_ip" "aue_frontend_pip" {
  name                = local.aue_front_pip
  resource_group_name = data.azurerm_resource_group.aue_frontend.name
}
data "azurerm_public_ip" "aus_frontend_pip" {
  name                = local.aus_front_pip
  resource_group_name = data.azurerm_resource_group.aus_frontend.name
}


############################################
## Resources
############################################
resource "azurerm_traffic_manager_profile" "tm" {
  name                   = "${var.env}-net-tm"
  resource_group_name    = data.azurerm_resource_group.aue_shared.name
  traffic_routing_method = "Priority"
  dns_config {
    relative_name = "${var.env}-aue-tm"
    ttl           = 100
  }

# Create endpoint monitoring
  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/"
    interval_in_seconds          = 60
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
    expected_status_code_ranges  = ["200"]
  }

  traffic_view_enabled = "true"

  tags = local.tags
}

#Create Traffic Manager Endpoint
resource "azurerm_traffic_manager_endpoint" "tm_ep_appgw_aue" {
  name                = "${local.ep_name_aue}-tf"
  resource_group_name = data.azurerm_traffic_manager_profile.tm.resource_group_name
  profile_name        = data.azurerm_traffic_manager_profile.tm.name
  type                = var.ep_type
  target              = data.azurerm_public_ip.aue_frontend_pip.fqdn
  target_resource_id  = data.azurerm_public_ip.aue_frontend_pip.id
  endpoint_location   = var.locationlineaue
  priority            = "1"
  depends_on = [
    data.azurerm_public_ip.aue_frontend_pip
  ]
}
resource "azurerm_traffic_manager_endpoint" "tm_ep_appgw_aus" {
  name                = "${local.ep_name_aus}-tf"
  resource_group_name = data.azurerm_traffic_manager_profile.tm.resource_group_name
  profile_name        = data.azurerm_traffic_manager_profile.tm.name
  type                = var.ep_type
  target              = data.azurerm_public_ip.aus_frontend_pip.fqdn
  target_resource_id  = data.azurerm_public_ip.aus_frontend_pip.id
  endpoint_location   = var.locationlineaus
  priority            = "2"
  depends_on = [
    data.azurerm_public_ip.aus_frontend_pip
  ]
}