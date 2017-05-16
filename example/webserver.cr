require "http/server"
require "../src/instana"

server = HTTP::Server.new(8080) do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello Crystal World! The time is #{Time.now}"
end

puts "Listening on http://127.0.0.1:8080"
server.listen
