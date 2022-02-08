class Client
  require "socket"

  hostname = "localhost"
  port = 1234

  socket = TCPSocket.open(hostname, port)
  socket.puts "hahahahaha"
  # while line = socket.gets
  #   puts line
  # end
  socket.close
end

Client.new
