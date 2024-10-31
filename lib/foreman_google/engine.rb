module ForemanGoogle
  class Engine < ::Rails::Engine
    isolate_namespace ForemanGoogle
    engine_name 'foreman_google'

    # Add any db migrations
    initializer 'foreman_google.load_app_instance_data' do |app|
      ForemanGoogle::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_google.register_plugin', before: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_google do
        requires_foreman '>= 3.13.0'
        register_global_js_file 'global'
        register_gettext

        in_to_prepare do
          compute_resource(ForemanGoogle::GCE)
        end
      end
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      ::Host::Managed.include ForemanGoogle::HostManagedExtensions
      ::Api::V2::ComputeResourcesController.include ForemanGoogle::Api::V2::ComputeResourcesExtensions
      ::Api::V2::ComputeResourcesController.include ForemanGoogle::Api::V2::ApipieExtensions
      ::Api::V2::ComputeResourcesController.include Foreman::Controller::Parameters::ComputeResourceExtension
      ::ComputeResourcesController.include Foreman::Controller::Parameters::ComputeResourceExtension
      Google::Cloud::Compute::V1::AttachedDisk.include GoogleExtensions::AttachedDisk
    rescue StandardError => e
      Rails.logger.warn "ForemanGoogle: skipping engine hook (#{e})"
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanGoogle::Engine.load_seed
      end
    end
  end
end
