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
			ws.send(JSON.generate({ "id" => nil, "result" => @status })) if @status

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
			method = cmd["method"]
			params = cmd["params"]
			id     = cmd["id"]

			begin
				ret = nil
				case
				when @cat.respond_to?("#{method}=")
					method = @cat.method("#{method}=")
					params = method.parameters.map {|i| params[i[1].to_s] } if params.is_a? Hash
					ret = method.call(*params)
				when @cat.respond_to?(method)
					method = @cat.method(method)
					params = method.parameters.map {|i| params[i[1].to_s] } if params.is_a? Hash
					ret = method.call(*params)
				end

				ws.send(JSON.generate({ "id" => id, "result" => ret, "error" => nil }))
			rescue NameError
				ws.send(JSON.generate({ "id" => id, "result" => nil, "error" => "unknown method" }))
			rescue Timeout::Error
				puts "timeout"
				ws.send(JSON.generate({ "id" => id, "result" => nil, "error" => "timeout" }))
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
				@channel.push JSON.generate({ "id" => nil, "result" => @status })
			end
		rescue Timeout::Error
			warn "timeout"
			sleep 1
			retry
		end
	end
end


