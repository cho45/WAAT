#!/usr/bin/env ruby

require "em-websocket"
require "json"
require "./cat.rb"

port = ARGV.shift || '/dev/ttyAMA0'

@cat = CAT::FT450D.new({ :port => port})

EM::run do
	@channel = EM::Channel.new
	@status  = nil

	EM::WebSocket.start(:host => "0.0.0.0", :port => 51234) do |ws|
		ws.onopen do
			p :onopen
			ws.send(JSON.generate(@status)) if @status

			sid = @channel.subscribe do |mes|
				ws.send(mes)
			end

			ws.onclose do
				p :onclose
				@channel.unsubscribe(sid)
			end
		end

		ws.onmessage do |msg|
			cmd = JSON.parse(msg)
			p cmd
			begin
				case cmd["command"]
				when "power"
					@cat.power = cmd["value"]
				when "frequency"
					@cat.frequency = cmd["value"]
				when "mode"
					@cat.mode = cmd["value"]
				when "width"
					@cat.width = cmd["value"]
				when "noise_reduction"
					@cat.noise_reduction = cmd["value"]
				when "status"
					ws.send(JSON.generate(@status)) if @status
				end
				if cmd["id"]
					ws.send(JSON.generate({ "id" => cmd["id"] }))
				end
			rescue Timeout::Error
				puts "timeout"
				ws.send(JSON.generate({ "id" => cmd["id"], "error" => "timeout" }))
			end
		end

		ws.onerror do |error|
			p error
		end
	end

	EM::defer do
		begin
			@cat.status do |status|
				@status = status
				p @status
				@channel.push JSON.generate(@status)
			end
		rescue Timeout::Error
			warn "timeout"
			sleep 1
			retry
		end
	end
end


