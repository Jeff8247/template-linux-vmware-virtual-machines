module "vm" {
  for_each = var.vms
  source   = "github.com/Jeff8247/module-vmware-virtual-machine?ref=v1.0.16"

  # Infrastructure placement
  datacenter    = coalesce(each.value.datacenter, var.datacenter)
  cluster       = coalesce(each.value.cluster, var.cluster)
  datastore     = coalesce(each.value.datastore, var.datastore)
  resource_pool = each.value.resource_pool != null ? each.value.resource_pool : var.resource_pool
  vm_folder     = each.value.vm_folder != null ? each.value.vm_folder : var.vm_folder

  # VM identity
  vm_name       = each.key
  computer_name = each.value.computer_name != null ? each.value.computer_name : each.key
  annotation    = each.value.annotation != null ? each.value.annotation : var.annotation
  tags          = coalesce(each.value.tags, var.tags)

  # Template
  template_name = coalesce(each.value.template_name, var.template_name)

  # CPU
  num_cpus             = coalesce(each.value.num_cpus, var.num_cpus)
  num_cores_per_socket = each.value.num_cores_per_socket != null ? each.value.num_cores_per_socket : var.num_cores_per_socket
  cpu_hot_add_enabled  = coalesce(each.value.cpu_hot_add_enabled, var.cpu_hot_add_enabled)

  # Memory
  memory                 = coalesce(each.value.memory, var.memory)
  memory_hot_add_enabled = coalesce(each.value.memory_hot_add_enabled, var.memory_hot_add_enabled)

  # Storage
  disks                 = coalesce(each.value.disks, var.disks)
  scsi_type             = coalesce(each.value.scsi_type, var.scsi_type)
  scsi_controller_count = coalesce(each.value.scsi_controller_count, var.scsi_controller_count)

  # Networking
  network_interfaces = coalesce(each.value.network_interfaces, var.network_interfaces)
  ip_settings        = coalesce(each.value.ip_settings, var.ip_settings)
  ipv4_gateway       = each.value.ipv4_gateway != null ? each.value.ipv4_gateway : var.ipv4_gateway
  dns_servers        = coalesce(each.value.dns_servers, var.dns_servers)
  dns_suffix_list    = coalesce(each.value.dns_suffix_list, var.dns_suffix_list)

  # Guest OS
  is_windows = false
  guest_id   = each.value.guest_id != null ? each.value.guest_id : var.guest_id
  domain     = each.value.domain != null ? each.value.domain : var.domain
  time_zone  = coalesce(each.value.time_zone, var.time_zone)

  # Domain join (realmd/sssd — activated by module when windows_domain + windows_domain_password are set)
  windows_domain          = each.value.windows_domain != null ? each.value.windows_domain : var.windows_domain
  windows_domain_user     = each.value.windows_domain_user != null ? each.value.windows_domain_user : var.windows_domain_user
  windows_domain_password = each.value.windows_domain_password != null ? each.value.windows_domain_password : var.windows_domain_password
  windows_domain_ou       = each.value.windows_domain_ou != null ? each.value.windows_domain_ou : var.windows_domain_ou
  windows_domain_netbios  = each.value.windows_domain_netbios != null ? each.value.windows_domain_netbios : var.windows_domain_netbios
  linux_script_text       = each.value.linux_script_text != null ? each.value.linux_script_text : var.linux_script_text
  proxy_url               = each.value.proxy_url != null ? each.value.proxy_url : var.proxy_url

  # Hardware
  firmware                    = coalesce(each.value.firmware, var.firmware)
  hardware_version            = each.value.hardware_version != null ? each.value.hardware_version : var.hardware_version
  tools_upgrade_policy        = coalesce(each.value.tools_upgrade_policy, var.tools_upgrade_policy)
  enable_disk_uuid            = coalesce(each.value.enable_disk_uuid, var.enable_disk_uuid)
  wait_for_guest_net_timeout  = coalesce(each.value.wait_for_guest_net_timeout, var.wait_for_guest_net_timeout)
  wait_for_guest_net_routable = coalesce(each.value.wait_for_guest_net_routable, var.wait_for_guest_net_routable)
  customize_timeout           = coalesce(each.value.customize_timeout, var.customize_timeout)
  extra_config                = coalesce(each.value.extra_config, var.extra_config)
}
