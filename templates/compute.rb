SparkleFormation.new(:compute, :provider => :azure) do
  set!('$schema', 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#')
  content_version '1.0.0.0'
  parameters do
    sparkle_image_id do
      type 'string'
      default_value '14.04.2-LTS'
    end
    sparkle_flavor do
      type 'string'
      allowed_values [
           'Standard_A1'
      ]
      end
    storage_account_name.type 'string'
    storage_container_name.type 'string'
  end

  dynamic!(:network_public_ip_addresses, :sparkle) do
    properties do
      set!('publicIPAllocationMethod', 'Dynamic')
      dns_settings.domain_name_label 'sparkle'
    end
  end

  dynamic!(:network_virtual_networks, :sparkle) do
    properties do
      address_space.address_prefixes ['10.0.0.0/16']
      subnets array!(
        ->{
          name 'sparkle-subnet'
          properties.address_prefix '10.0.0.0/24'
        }
      )
    end
  end

  dynamic!(:network_interfaces, :sparkle) do
    properties.ip_configurations array!(
      ->{
        name 'ipconfig1'
        properties do
          set!('privateIPAllocationMethod', 'Dynamic')
          set!('publicIPAddress').id resource_id!(:sparkle_network_public_ip_addresses)
          subnet.id concat!(resource_id!(:sparkle_network_virtual_networks), '/subnets/sparkle-subnet')
        end
      }
    )
  end

  dynamic!(:compute_virtual_machines, :sparkle) do
    properties do
      hardware_profile.vm_size parameters!(:sparkle_flavor)
      os_profile do
        computer_name 'sparkle'
        admin_username 'sparkle'
        admin_password 'SparkleFormation2016'
      end
      storage_profile do
        image_reference do
          publisher 'Canonical'
          offer 'UbuntuServer'
          sku parameters!(:sparkle_image_id)
          version 'latest'
        end
        os_disk do
          name 'osdisk'
          vhd.uri concat!('http://', parameters!(:storage_account_name), '.blob.core.windows.net/', parameters!(:storage_container_name), '/sparkle.vhd')
          caching 'ReadWrite'
          create_option 'FromImage'
        end
        data_disks array!(
          ->{
            name 'datadisk1'
            set!('diskSizeGB', 100)
            lun 0
            vhd.uri concat!('http://', parameters!(:storage_account_name), '.blob.core.windows.net/', parameters!(:storage_container_name), '/sparkle-data.vhd')
            create_option 'Empty'
          }
        )
      end
      network_profile.network_interfaces array!(
        ->{ id resource_id!(:sparkle_network_interfaces) }
      )
    end
  end

  outputs.sparkle_public_address do
    type 'string'
    value reference!(:sparkle_network_public_ip_addresses).ipAddress
  end
end
