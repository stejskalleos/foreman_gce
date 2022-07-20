require 'foreman_google/google_compute_adapter'

# rubocop:disable Rails/InverseOf, Metrics/ClassLength
module ForemanGoogle
  class GCE < ::ComputeResource
    has_one :key_pair, foreign_key: :compute_resource_id, dependent: :destroy
    before_create :setup_key_pair
    validates :password, :zone, presence: true

    def self.available?
      true
    end

    def to_label
      "#{name} (#{zone}-#{provider_friendly_name})"
    end

    def capabilities
      %i[image new_volume]
    end

    def provided_attributes
      super.merge({ ip: :vm_ip_address })
    end

    def zones
      client.zones.map(&:name)
    end
    alias_method :available_zones, :zones

    def networks
      client.networks.map(&:name)
    end

    def available_networks(_cluster_id = nil)
      client.networks.items
    end

    def machine_types
      client.machine_types(zone)
    end
    alias_method :available_flavors, :machine_types

    def zone
      url
    end

    def zone=(zone)
      self.url = zone
    end

    def new_vm(args = {})
      vm_args = args.deep_symbolize_keys

      # convert rails nested_attributes into a plain hash
      volumes_nested_attrs = vm_args.delete(:volumes_attributes)
      vm_args[:volumes] = nested_attributes_for(:volumes, volumes_nested_attrs) if volumes_nested_attrs

      GoogleCompute.new(client: client, zone: zone, args: vm_args)
    end

    def create_vm(args = {})
      ssh_args = { username: find_os_image(args[:image_id])&.username, public_key: key_pair.public }
      vm = new_vm(args.merge(ssh_args))

      vm.create_volumes
      vm.create_instance
      vm.set_disk_auto_delete

      find_vm_by_uuid vm.hostname
    rescue ::Google::Cloud::Error => e
      vm.destroy_volumes
      raise Foreman::WrappedException.new(e, 'Cannot insert instance!')
    end

    def find_vm_by_uuid(uuid)
      GoogleCompute.new(client: client, zone: zone, identity: uuid.to_s)
    end

    def destroy_vm(uuid)
      client.set_disk_auto_delete(zone, uuid)
      client.delete_instance(zone, uuid)
    rescue ActiveRecord::RecordNotFound
      # if the VM does not exists, we don't really care.
      true
    end

    def available_images(filter: nil)
      client.images(filter: filter)
    end

    def self.model_name
      ComputeResource.model_name
    end

    def setup_key_pair
      require 'sshkey'

      key = ::SSHKey.generate
      build_key_pair name: "foreman-#{id}#{Foreman.uuid}", secret: key.private_key, public: key.ssh_public_key
    end

    def self.provider_friendly_name
      'Google'
    end

    def user_data_supported?
      true
    end

    def new_volume(attrs = {})
      default_attrs = { disk_size_gb: 20 }
      Google::Cloud::Compute::V1::AttachedDisk.new(**attrs.merge(default_attrs))
    end

    def console(uuid)
      vm = find_vm_by_uuid(uuid)

      if vm.ready?
        {
          'output' => vm.serial_port_output, 'timestamp' => Time.now.utc,
          :type => 'log', :name => vm.name
        }
      else
        raise ::Foreman::Exception,
          N_('console is not available at this time because the instance is powered off')
      end
    end

    def associated_host(vm)
      associate_by('ip', [vm.public_ip_address, vm.private_ip_address])
    end

    def vms(attrs = {})
      filtered_attrs = attrs.except(:eager_loading)
      GoogleCloudCompute::ComputeCollection.new(client, zone, filtered_attrs)
    end

    # ----# Google specific #-----

    def google_project_id
      client.project_id
    end

    def vm_ready(vm)
      vm.wait_for do
        vm.reload
        vm.ready?
      end
    end

    private

    def client
      @client ||= ForemanGoogle::GoogleComputeAdapter.new(auth_json_string: password)
    end

    def set_vm_volumes_attributes(vm, vm_attrs)
      return vm_attrs unless vm.respond_to?(:volumes)

      vm_attrs[:volumes_attributes] = Hash[vm.volumes.each_with_index.map { |volume, idx| [idx.to_s, volume.to_h] }]

      vm_attrs
    end

    def find_os_image(uuid)
      os_image = images.find_by(uuid: uuid)
      raise ::Foreman::Exception, N_('Missing an image for operating system!') if os_image.nil?
      os_image
    end
  end
end
# rubocop:enable Rails/InverseOf, Metrics/ClassLength
