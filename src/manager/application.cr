require "./application/*"

module Manager::Application
  def self.logs(application, prefix = PREFIX, error = false)
    File.read "#{Path.new(prefix).app}/#{application}/#{error ? LOG_ERROR_PATH : LOG_OUTPUT_PATH}"
  end
end
