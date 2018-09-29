require "./application/*"

module Manager::Application
  def self.log_file(application, prefix = PREFIX, error = false)
    "#{Path.new(prefix).app}/#{application}/#{error ? LOG_ERROR_PATH : LOG_OUTPUT_PATH}"
  end
end
