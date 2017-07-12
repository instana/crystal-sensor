require "http/server"
require "../src/instana"

server = HTTP::Server.new(8080) do |context|
  span = ::Instana.tracer.start_span(:hello_crystal)
  span.set_tag(:mime, "text/plain")
  span.set_tag(:code, 200)
  sleep 0.3
  context.response.content_type = "text/plain"
  context.response.print "Hello Crystal World! The time is #{Time.now}"
  span.finish
end

puts "Listening on http://127.0.0.1:8080"
server.listen
