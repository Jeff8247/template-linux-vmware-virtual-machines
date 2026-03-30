# Linux VMware VMs — Terraform Template

Terraform template for deploying multiple Linux virtual machines on vSphere in a single run. Wraps the [`Jeff8247/module-vmware-virtual-machine`](https://github.com/Jeff8247/module-vmware-virtual-machine) module using `for_each`, with a per-VM override pattern — each VM entry in the `vms` map can override any setting, falling back to the global defaults defined alongside it.

## Requirements

| Tool | Version |
|------|---------|
| Terraform | `>= 1.3, < 2.0` |
| vSphere provider | `~> 2.6` |
| vCenter | 7.0+ recommended |

A Linux VM template with VMware Tools installed must already exist in vCenter and have `open-vm-tools` (or VMware Tools) running to support guest customization.

## Quick Start

```bash
# 1. Copy the example vars file and fill in your values
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 2. Set credentials via environment variables (recommended — avoids storing them in files)
export TF_VAR_vsphere_password="..."
export TF_VAR_windows_domain_password="..."   # only if joining AD

# 3. Initialize and deploy
terraform init
terraform plan
terraform apply
```

## Credentials

Passwords should **not** be stored in `terraform.tfvars`. Use environment variables instead:

```bash
export TF_VAR_vsphere_password="your-vcenter-password"
export TF_VAR_windows_domain_password="your-domain-join-password"   # if joining AD
```

The `.gitignore` in this repo excludes `terraform.tfvars` and `*.auto.tfvars` to prevent accidental commits of credentials.

## How It Works

All VMs are defined in the `vms` map. Each key becomes the VM name in vSphere. Any field omitted from a VM entry falls back to the matching global variable:

```hcl
vms = {
  "linux-app-01" = {
    num_cpus = 8        # overrides global num_cpus
    memory   = 16384    # overrides global memory
  }
  "linux-app-02" = {}   # inherits everything from global defaults
}

# Global defaults — apply to any VM that doesn't override them
num_cpus = 2
memory   = 4096
```

This means you only need to specify what differs between VMs. A common pattern is to set shared infrastructure (datacenter, cluster, datastore, network, template, domain join) as globals, and only override the per-VM specifics (CPU, memory, disks, IP).

## Examples

### Minimal — all VMs use global defaults

```hcl
vsphere_server = "vcenter.example.com"
vsphere_user   = "administrator@vsphere.local"

datacenter    = "dc01"
cluster       = "cluster01"
datastore     = "datastore01"
template_name = "ubuntu-22.04-template"

network_interfaces = [{ network_name = "VM Network" }]

vms = {
  "linux-app-01" = {}
  "linux-app-02" = {}
  "linux-app-03" = {}
}
```

### Per-VM CPU, memory, and static IP

```hcl
vms = {
  "linux-app-01" = {
    num_cpus    = 8
    memory      = 16384
    ip_settings = [{ ipv4_address = "10.0.1.101", ipv4_netmask = 24 }]
    ipv4_gateway = "10.0.1.1"
  }
  "linux-app-02" = {
    num_cpus    = 4
    memory      = 8192
    ip_settings = [{ ipv4_address = "10.0.1.102", ipv4_netmask = 24 }]
    ipv4_gateway = "10.0.1.1"
  }
  "linux-app-03" = {}   # DHCP, global CPU/memory defaults
}
```

### Multiple disks with a second SCSI controller

```hcl
# Global two-disk default
disks = [
  { label = "OS",   size = 100, unit_number = 0 },
  { label = "Data", size = 200, unit_number = 1 },
]

# Per-VM override with a second SCSI bus for high-I/O data drives
# Bus 1, Unit 0 = unit_number 16  (Bus * 16 + Unit = 1 * 16 + 0)
vms = {
  "linux-db-01" = {
    scsi_controller_count = 2
    disks = [
      { label = "OS",   size = 100, unit_number = 0  },
      { label = "Data", size = 500, unit_number = 16 },
    ]
  }
}
```

### Active Directory domain join

The template automatically constructs and runs a `realmd`/`sssd` domain join script during guest customization when `windows_domain` and `windows_domain_password` are set. The script detects the package manager at runtime and works on both RHEL-family and Debian/Ubuntu guests.

> **Note:** The domain join variables use `windows_domain*` names intentionally — this allows a single shared `terraform.tfvars` file to drive both this template and the Windows multi-VM template simultaneously.

```hcl
windows_domain         = "corp.example.com"
windows_domain_netbios = "CORP"
windows_domain_user    = "svc-domainjoin@corp.example.com"
windows_domain_ou      = "OU=AppServers,OU=Servers,DC=corp,DC=example,DC=com"
# windows_domain_password via TF_VAR_windows_domain_password
```

### Per-VM first-boot script

`linux_script_text` runs as root during guest customization, after the hostname and network have been applied. When domain join is also enabled, the per-VM script runs **after** the domain join script.

```hcl
vms = {
  "linux-app-01" = {
    linux_script_text = <<-EOT
      apt-get install -y nginx
      systemctl enable nginx
    EOT
  }
}
```

> **Note:** Do not include a `#!/bin/bash` shebang in `linux_script_text` — the domain join script prepends one. If domain join is disabled the shebang is added automatically.

## Variable Reference

### vCenter Connection

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vsphere_server` | `string` | required | vCenter server hostname or IP |
| `vsphere_user` | `string` | required | vCenter username |
| `vsphere_password` | `string` | required | vCenter password (sensitive) |
| `vsphere_allow_unverified_ssl` | `bool` | `false` | Skip TLS certificate verification |

**`vsphere_server`** — hostname or IP address only, no protocol or port (e.g. `vcenter.example.com`, not `https://vcenter.example.com`).

**`vsphere_user`** — UPN format (`user@domain`, e.g. `administrator@vsphere.local`) or `DOMAIN\user` format.

### VM List

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vms` | `map(object)` | 3 default entries | Map of VM name to per-VM overrides. Omit any field to inherit the global default. |

Each key in the `vms` map becomes the VM name in vSphere. Every field in the object is optional — omitting a field causes it to fall back to the corresponding global variable. The object supports all the same fields as the global variables below.

### Infrastructure Placement

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `datacenter` | `string` | `"MYDC01"` | vSphere datacenter name |
| `cluster` | `string` | `"MYCLU01"` | vSphere cluster name |
| `datastore` | `string` | `"MYDS01"` | Datastore name |
| `resource_pool` | `string` | `null` | Resource pool name; `null` uses the cluster root pool |
| `vm_folder` | `string` | `null` | vSphere folder path, e.g. `"VMs/Linux"` |

All inventory names must match **exactly** as they appear in the vCenter inventory — they are case-sensitive.

### VM Identity

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `annotation` | `string` | `null` | Notes/description applied to all VMs |
| `tags` | `map(string)` | `{}` | vSphere tags as `{ category = "tag-name" }`. Tag categories and values must already exist in vCenter. |

Tags are key/value pairs where the key is the **tag category** name and the value is the **tag name**, both as they appear in vCenter.

```hcl
tags = {
  "Environment" = "Production"
  "Owner"       = "platform-team"
  "CostCentre"  = "CC-1234"
}
```

### Template

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `template_name` | `string` | `"template-ubuntu-22.04-lts"` | vSphere template to clone |

### CPU

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `num_cpus` | `number` | `2` | Total vCPU count |
| `num_cores_per_socket` | `number` | `null` | Cores per socket — defaults to `num_cpus` (single socket) |
| `cpu_hot_add_enabled` | `bool` | `false` | Allow CPU hot-add without power cycling |

### Memory

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `memory` | `number` | `4096` | Memory in MB — must be a multiple of 4 |
| `memory_hot_add_enabled` | `bool` | `false` | Allow memory hot-add without power cycling |

### Storage

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `disks` | `list(object)` | single 40 GB thin disk | List of disks — see [Disk Object](#disk-object) |
| `scsi_type` | `string` | `"pvscsi"` | SCSI controller type: `pvscsi` or `lsilogicsas` |
| `scsi_controller_count` | `number` | `1` | Number of SCSI controllers (max 4) |

#### Disk Object

```hcl
{
  label            = "disk0"   # required — unique per VM
  size             = 40        # required — size in GB
  unit_number      = 0         # optional — SCSI unit number
  thin_provisioned = true      # optional — default true
  eagerly_scrub    = false     # optional — default false
}
```

For multiple SCSI controllers, calculate `unit_number` as `(bus * 16) + unit`. For example, Bus 1 Unit 0 = `16`, Bus 1 Unit 1 = `17`.

### Networking

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `network_interfaces` | `list(object)` | `[{ network_name = "NET01" }]` | List of NICs — see [Network Interface Object](#network-interface-object) |
| `ip_settings` | `list(object)` | `[]` | Static IP per NIC — leave empty for DHCP |
| `ipv4_gateway` | `string` | `null` | Default IPv4 gateway |
| `dns_servers` | `list(string)` | `[]` | DNS server addresses |
| `dns_suffix_list` | `list(string)` | `[]` | DNS search suffixes |

#### Network Interface Object

```hcl
{
  network_name = "VM Network"   # required — port group or DVS port group name
  adapter_type = "vmxnet3"      # optional — vmxnet3 (default), e1000e, or e1000
}
```

#### IP Settings Object

```hcl
{
  ipv4_address = "10.0.1.100"   # required
  ipv4_netmask = 24             # required — prefix length, 1–32
}
```

One entry per NIC, in the same order as `network_interfaces`. Leave `ip_settings = []` to use DHCP on all NICs.

### Guest OS — Linux

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `guest_id` | `string` | inherited from template | vSphere guest OS identifier. Omit to inherit from the source template |
| `domain` | `string` | `null` | DNS search domain suffix applied during customization (e.g. `corp.example.com`) |
| `time_zone` | `string` | `"Australia/Brisbane"` | Linux timezone in Olson format |
| `linux_script_text` | `string` | `null` | Inline shell script to run during guest customization. Runs after domain join when both are enabled. Do not include a shebang. |

Common `guest_id` values:

| OS | `guest_id` |
|----|-----------|
| Ubuntu 24.04 | `ubuntu64Guest` |
| Ubuntu 22.04 | `ubuntu64Guest` |
| RHEL 9 | `rhel9_64Guest` |
| RHEL 8 | `rhel8_64Guest` |
| Debian 12 | `debian12_64Guest` |
| Rocky Linux 9 | `rockylinux_64Guest` |
| AlmaLinux 9 | `almalinux_64Guest` |

Common `time_zone` values:

| Timezone | String |
|----------|--------|
| UTC | `UTC` |
| Eastern | `America/New_York` |
| Central | `America/Chicago` |
| Pacific | `America/Los_Angeles` |
| London | `Europe/London` |
| Brisbane | `Australia/Brisbane` |
| Sydney | `Australia/Sydney` |

Full list: [IANA Time Zone Database](https://www.iana.org/time-zones)

### Domain Join

These variables use `windows_domain*` names so that a single shared `terraform.tfvars` can drive both this template and the [Windows multi-VM template](https://github.com/Jeff8247/template-windows-vmware-virtual-machines) simultaneously.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `windows_domain` | `string` | `null` | AD domain to join (e.g. `corp.example.com`). `null` skips domain join |
| `windows_domain_netbios` | `string` | `null` | NetBIOS name of the domain (e.g. `CORP`). Falls back to `windows_domain` if null |
| `windows_domain_user` | `string` | `null` | AD user with machine join permissions |
| `windows_domain_password` | `string` | `null` | Domain join password (sensitive) — set via `TF_VAR_windows_domain_password` |
| `windows_domain_ou` | `string` | `null` | OU distinguished name for the computer object. `null` uses the default Computers container |

When `windows_domain` and `windows_domain_password` are set, the template automatically constructs and runs a `realmd`/`sssd` join script during customization. The script installs required packages, joins the domain, configures SSSD, Kerberos, and applies PAM hardening to disable null password logins.

### Hardware

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `firmware` | `string` | `"bios"` | Firmware type: `bios` or `efi` |
| `hardware_version` | `number` | `null` | VMware hardware version; `null` keeps the template version |
| `tools_upgrade_policy` | `string` | `"upgradeAtPowerCycle"` | VMware Tools upgrade policy: `manual` or `upgradeAtPowerCycle` |
| `enable_disk_uuid` | `bool` | `true` | Expose disk UUIDs to the guest OS |
| `wait_for_guest_net_timeout` | `number` | `5` | Minutes to wait for guest networking (`0` disables) |
| `wait_for_guest_net_routable` | `bool` | `true` | Require a routable IP before marking VM ready |
| `customize_timeout` | `number` | `30` | Minutes to wait for guest customization to complete |
| `extra_config` | `map(string)` | `{}` | Additional VMX key/value pairs |

## Outputs

All outputs are maps keyed by VM name.

| Output | Description |
|--------|-------------|
| `vm_names` | Name of each deployed VM |
| `vm_ids` | Managed object ID (MOID) of each VM |
| `vm_uuids` | BIOS UUID of each VM — useful for CMDB and monitoring integration |
| `power_states` | Current power state of each VM |
| `default_ip_addresses` | Primary IP address of each VM as reported by VMware Tools |
| `ip_addresses` | All IP addresses reported by VMware Tools, per VM |

Example output:

```
default_ip_addresses = {
  "linux-app-01" = "10.0.1.101"
  "linux-app-02" = "10.0.1.102"
  "linux-app-03" = "10.0.1.103"
}
```

## File Structure

```
.
├── main.tf                    # Domain join locals, module call with for_each
├── variables.tf               # All input variables with validation
├── outputs.tf                 # Map outputs keyed by VM name
├── versions.tf                # Terraform and provider version constraints
├── providers.tf               # vSphere provider configuration
├── terraform.tfvars.example   # Annotated example — copy to terraform.tfvars
└── .gitignore                 # Excludes state, .terraform/, and tfvars files
```

## Security Notes

- `vsphere_password` and `windows_domain_password` are marked `sensitive = true` and will not appear in plan/apply output.
- `terraform.tfvars` is excluded by `.gitignore` to prevent accidental credential commits. All passwords should be passed via `TF_VAR_*` environment variables — the resulting `terraform.tfvars` contains no sensitive values and should be committed to track the deployed configuration.
- `vsphere_allow_unverified_ssl` defaults to `false`. Only set to `true` in non-production lab environments.
- Terraform state (`terraform.tfstate`) contains all resource attributes including sensitive values. Store state in a secured remote backend (e.g. S3 with encryption, Terraform Cloud) for any shared or production use. See `versions.tf` for where to add a backend block.
