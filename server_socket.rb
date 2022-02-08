require 'json'
require 'pry'
require 'socket'

puts "Started TCP Server"
server = TCPServer.new 1234
loop do
  # client = server.accept    # Wait for a client to connect
  # client.puts "Hello !"
  # client.puts "Time is #{Time.now}"
  # client.close
  # Thread.start(server.accept) do |client|
  #   while client && !client.closed?
  #     s = client.gets
  #     client.puts s
  #   end
  #   client.close
  # end
  # Thread.start(server.accept) do |client|
  #   client.puts "Hello !"
  #   client.puts "Time is #{Time.now}"
  #   client.close
  # end
  Thread.start(server.accept) do |client|
    puts "User connect"
    p "Inside Task"
    string = client.recv(1000).chomp ## Request Data received at the socket port
    p "client say: #{string}"
    # result = JSON.parse(string)
    client.puts "aaaaaaaaaaaa"
    client.close
  end
end
