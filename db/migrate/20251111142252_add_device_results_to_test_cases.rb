class AddDeviceResultsToTestCases < ActiveRecord::Migration[8.0]
  def change
    add_column :test_cases, :device_results, :text, comment: "JSON array of device test results: [{device: 'Chrome', status: 'pass'}, ...]"
  end
end
