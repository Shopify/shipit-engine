# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Shipit::Application.initialize!
Mime::Type.register "text/partial+html", :partial
