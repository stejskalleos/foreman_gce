# rubocop:disable Metrics/MethodLength
class ForemanGCEToForemanGoogleGCE < ActiveRecord::Migration[6.0]
  def up
    User.without_auditing do
      original_type = 'Foreman::Model::GCE'
      new_type = 'ForemanGoogle::GCE'

      # First update the type to avoid error:
      # ActiveRecord::SubclassNotFound: The single-table inheritance
      # mechanism failed to locate the subclass: 'Foreman::Model::GCE'
      ComputeResource.unscoped.where(type: original_type).update_all(type: new_type)

      ComputeResource.unscoped.where(type: new_type).find_each do |cr|
        unless cr.attrs[:key_path]
          say("Compute resource [#{cr.name}] is missing path to JSON key file, can't load the data. Please update the resource manually.")
          next
        end
        json_data = File.read(cr.attrs[:key_path])
        cr.update(password: json_data)
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
