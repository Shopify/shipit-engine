#!/usr/bin/env ruby

path = './fixtures/timeout'
buffer = []
command = Shipit::Command.new({path => {'timeout' => 2}}, env: {}, chdir: __dir__)
begin
  command.stream! do |chunk|
    buffer << chunk
  end
rescue Shipit::Command::TimedOut
  # expected
end

expected_output = [
  "Sleeping for 10 seconds\r\n",
  "\e[1;31mNo output received in the last 2 seconds.\e[0m\n",
  "\e[1;31mSending SIGINT to PID #{command.pid}\n\e[0m",
  "Recieved SIGINT, aborting.\r\n",
]

unless buffer.join == expected_output.join
  puts "Expected: -------"
  puts expected_output.map(&:inspect).join("\n")
  puts "Got: ------------"
  puts buffer.map(&:inspect).join("\n")
  puts "-----------------"
  exit 1
end
