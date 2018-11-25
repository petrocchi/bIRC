#!/usr/bin/ruby

=begin

bIRC - Easy IRC Client for SSL IRC server

Copyright (C) 2018 Luca Petrocchi <petrocchi@myoffset.me>

DATE:		25/10/2018
AUTHOR:		Luca Petrocchi
EMAIL:		petrocchi@myoffset.me
WEBSITE:	https://myoffset.me/
URL:		https://github.com/petrocchi

bIRC is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
bIRC.rb is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along
with this program.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'socket'
require 'openssl'
require 'securerandom'

CA_FILE = '/etc/ssl/certs/ca-certificates.crt'


LOGO = <<END
 _    ___ ____   ____    ___   _ 
| |__|_ _|  _ \\\ / ___|  / _ \\ / |
| '_ \\| || |_) | |     | | | || |
| |_) | ||  _ <| |___  | |_| || |
|_.__/___|_| \\_\\\\____|  \\___(_)_|

END

COM_PAN = <<END

-------------------------------------------------
Commands:
/c #channel	Set channel for chatting

All irc's commands...
/privmsg #chan <msg>
/mode #chan +o <nick>

Brevius commands:
/j <chan>	join
/p <chan>	part
/q		quit
-------------------------------------------------

END

class IRC
	def inizialize(host, port, nick)
		@nick = nick
		@user = SecureRandom.urlsafe_base64(8)
		@realname = SecureRandom.urlsafe_base64(8)
		@socket = TCPSocket.new(host, port)
		@ssl_socket = connect(host, port)
		@chan = String.new
		@channel = String.new
	end
	
	def main(host, port, nick)
		inizialize(host, port, nick)

		login()

		while true
			ready = select([@ssl_socket, $stdin], nil, nil, nil)
			next if !ready
		
			for str in ready[0]
				if str == $stdin then
					return if $stdin.eof

					str = $stdin.gets
					parser_client(str)
	
					elsif str == @ssl_socket then
					return if @ssl_socket.eof

					str = @ssl_socket.gets
					parser_server(str)
				end
			end
		end
	end

	def parser_client(str)
		case str.strip
			when "/h"
				command_pan()
			when /^\/j (.+)$/i
				join_chan($1)
			when /^\/p (.+)$/i
				part_chan($1)
			when "\/q"
				@ssl_socket.puts "/quit bIRC 0.1"
				@ssl_socket.close
				@socket.close
				exit 0
			when /^\/c (.+)$/i
				@channel = $1
				puts "[+] Set channel #{@channel} for msg\n"
			when /^\/(.+)$/i
				@ssl_socket.puts "#{$1}"
			else
				@ssl_socket.puts "privmsg #{@channel} #{str}"
		end
	end


	def parser_server(str)
		case str.strip
			when /^PING :(.+)$/i
				@ssl_socket.puts "PONG :#{$1}"
			when /^:(.+) 001 #{@nick} :Welcome(.+)/i
				puts "[+] bIRC is connected"
			when /^:(.+) #{@nick} :Erroneous Nickname(.+)/i
				@nick = SecureRandom.urlsafe_base64(8)
				@ssl_socket.puts "nick #{@nick}"
			else
				puts str
		end
	end


	def join_chan(chan)
		@ssl_socket.puts "join #{chan}"
		puts "[+] join #{chan}"
	end


	def part_chan(chan)
		@ssl_socket.puts "part #{chan}"
		puts "[+] part #{chan}"
	end


	def login()
		puts "[+] Connecting to #{@host}:#{@port}"

		@ssl_socket.puts "nick #{@nick}"
		@ssl_socket.puts "user #{@user} 127.0.0.1 127.0.0.1 #{@realname}"
	end


	def connect(host, port)
		context = OpenSSL::SSL::SSLContext.new

		if @ssl_verify
			context.ca_file = @ssl_ca_file if @ssl_ca_file and not @ssl_ca_file.empty?
			context.ca_path = @ssl_ca_path if @ssl_ca_path and not @ssl_ca_path.empty?
			context.verify_mode = OpenSSL::SSL::VERIFY_PEER 
		else
			context.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end
	
		ssl_socket = OpenSSL::SSL::SSLSocket.new(@socket, context)
		ssl_socket.sync_close = true
	  	ssl_socket.connect

		cert = ssl_socket.peer_cert

		str_cert =  [host, 'OK', cert.not_before.strftime('%F'), cert.signature_algorithm]
		puts "[+] " << str_cert.join("\t")

		return ssl_socket
	end
end


def command_pan()
	puts COM_PAN
end


def usage()
	STDERR.puts "\n[+] bIRC - Easy IRC Client for SSL IRC server\n[+] Usage: ./bIRC.rb <host> <port> <nick>\n\n"
end


begin
	puts LOGO

	if ARGV.empty? || ARGV.length != 3
		usage
		exit 1
	end

	session = IRC.new
	session.main(ARGV[0], ARGV[1], ARGV[2])

	exit 0
end

