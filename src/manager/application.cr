require "./application/*"

module Manager::Application
  def self.logs(application, prefix = PREFIX, error = false)
    File.read "#{prefix}/#{application}/#{error ? LOG_ERROR_PATH : LOG_OUTPUT_PATH}"
  end
end
